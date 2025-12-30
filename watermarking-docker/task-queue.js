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
  setup: function () {
    console.log('Setting up Firestore task queue listener...');

    // Listen for pending tasks
    unsubscribe = db.collection('tasks')
      .where('status', '==', 'pending')
      .onSnapshot(async (snapshot) => {
        for (const change of snapshot.docChanges()) {
          if (change.type === 'added') {
            const taskDoc = change.doc;
            const taskData = taskDoc.data();
            const taskId = taskDoc.id;

            console.log(`Processing task ${taskId} of type: ${taskData.type}`);

            // Mark as processing
            await taskDoc.ref.update({
              status: 'processing',
              startedAt: new Date()
            });

            try {
              await processTask(taskId, taskData);

              // Mark as completed
              await taskDoc.ref.update({
                status: 'completed',
                completedAt: new Date()
              });
              console.log(`Task ${taskId} completed successfully`);
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
    case 'delete_marked_image':
      await miscTasks.processDeleteMarkedImageTask(data);
      break;
    default:
      throw new Error(`Unknown task type: ${data.type}`);
  }
}
