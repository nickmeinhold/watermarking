// task-queue.js
// ==============
// Custom Firestore-based task queue to replace firebase-queue

var firebaseAdminSingleton = require('./firebase-admin-singleton');
var db = firebaseAdminSingleton.getFirestore();

var markingTasks = require('./marking-queues');
var detectionTasks = require('./detection-queues');
var miscTasks = require('./misc-queues');

// Track active listeners
var unsubscribe = null;

module.exports = {
  setup: async function () {
    console.log('Setting up Firestore task queue listener...');

    // Recover stale "processing" tasks (instance may have crashed)
    await recoverStaleTasks();

    // Listen for pending tasks
    unsubscribe = db.collection('tasks')
      .where('status', '==', 'pending')
      .onSnapshot(async (snapshot) => {
        for (const change of snapshot.docChanges()) {
          if (change.type === 'added') {
            const taskDoc = change.doc;
            const taskData = taskDoc.data();
            const taskId = taskDoc.id;

            // Skip heavy tasks - these are handled by Cloud Run Jobs
            if (taskData.type === 'mark' || taskData.type === 'detect') {
              console.log(`Skipping ${taskData.type} task ${taskId} - handled by Cloud Run Job`);
              continue;
            }

            console.log(`Processing task ${taskId} of type: ${taskData.type}`);

            // Mark as processing
            await taskDoc.ref.update({
              status: 'processing',
              startedAt: new Date()
            });

            try {
              await processTask(taskId, taskData);

              // Delete completed task
              await taskDoc.ref.delete();
              console.log(`Task ${taskId} completed successfully and deleted`);
            } catch (error) {
              console.error(`Task ${taskId} failed:`, error);
              await taskDoc.ref.update({
                status: 'failed',
                error: error.message || String(error),
                failedAt: new Date()
              });
            }
          }
        }
      }, (error) => {
        console.error('Error listening to tasks:', error);
      });

    console.log('Task queue listener active.');
  },

  shutdown: function () {
    if (unsubscribe) {
      unsubscribe();
      console.log('Task queue listener stopped.');
    }
  }
};

async function processTask(taskId, data) {
  switch (data.type) {
    case 'mark':
      await markingTasks.processMarkingTask(taskId, data);
      break;
    case 'detect':
      await detectionTasks.processDetectionTask(taskId, data);
      break;
    case 'get_serving_url':
      await miscTasks.processServingUrlTask(data);
      break;
    case 'delete_original_image':
      await miscTasks.processDeleteOriginalImageTask(data);
      break;
    case 'delete_marked_image':
      await miscTasks.processDeleteMarkedImageTask(data);
      break;
    case 'delete_detection_item':
      await miscTasks.processDeleteDetectionItemTask(data);
      break;
    default:
      throw new Error(`Unknown task type: ${data.type}`);
  }
}

// Recover tasks that were left in "processing" status when instance crashed
async function recoverStaleTasks() {
  const staleThreshold = 5 * 60 * 1000; // 5 minutes
  const now = Date.now();

  try {
    const processingTasks = await db.collection('tasks')
      .where('status', '==', 'processing')
      .get();

    for (const doc of processingTasks.docs) {
      const task = doc.data();
      const startedAt = task.startedAt?.toDate?.() || task.startedAt;

      // Reset if started more than 5 minutes ago (instance likely died)
      if (startedAt && (now - new Date(startedAt).getTime()) > staleThreshold) {
        console.log(`Recovering stale task ${doc.id} (started: ${startedAt})`);
        await doc.ref.update({
          status: 'pending',
          recoveredAt: new Date(),
          previousStartedAt: startedAt
        });
      }
    }
  } catch (error) {
    console.error('Error recovering stale tasks:', error);
  }
}
