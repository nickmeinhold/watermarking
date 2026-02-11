// job.js
// =======
// Cloud Run Job entry point for processing watermarking tasks
// Each job execution processes a single task identified by TASK_ID env var

var firebaseAdminSingleton = require('./firebase-admin-singleton');
var db = firebaseAdminSingleton.getFirestore();

var markingTasks = require('./marking-queues');
var detectionTasks = require('./detection-queues');
var miscTasks = require('./misc-queues');

async function main() {
  const taskId = process.env.TASK_ID;

  if (!taskId) {
    console.error('TASK_ID environment variable is required');
    process.exit(1);
  }

  console.log(`Cloud Run Job starting for task: ${taskId}`);

  try {
    // Fetch the task document
    const taskRef = db.collection('tasks').doc(taskId);
    const taskDoc = await taskRef.get();

    if (!taskDoc.exists) {
      console.error(`Task ${taskId} not found`);
      process.exit(1);
    }

    const taskData = taskDoc.data();

    // Check if task is still pending (avoid double processing)
    if (taskData.status !== 'pending') {
      console.log(`Task ${taskId} is not pending (status: ${taskData.status}), skipping`);
      process.exit(0);
    }

    // Mark as processing
    await taskRef.update({
      status: 'processing',
      startedAt: new Date(),
      jobExecution: true // Flag to indicate job-based processing
    });

    console.log(`Processing task ${taskId} of type: ${taskData.type}`);

    // Process the task
    await processTask(taskId, taskData);

    // Delete completed task
    await taskRef.delete();
    console.log(`Task ${taskId} completed successfully and deleted`);

    process.exit(0);
  } catch (error) {
    console.error(`Task ${taskId} failed:`, error);

    // Update task status to failed
    try {
      const taskRef = db.collection('tasks').doc(taskId);
      await taskRef.update({
        status: 'failed',
        error: error.message || String(error),
        failedAt: new Date()
      });
    } catch (updateError) {
      console.error('Failed to update task status:', updateError);
    }

    process.exit(1);
  }
}

async function processTask(taskId, data) {
  switch (data.type) {
    case 'mark':
      await markingTasks.processMarkingTask(taskId, data);
      break;
    case 'detect':
      await detectionTasks.processDetectionTask(taskId, data);
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

// Run the job
main();
