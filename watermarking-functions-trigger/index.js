/**
 * Cloud Function: Trigger Cloud Run Job on Firestore task creation
 *
 * When a new task document is created in /tasks collection,
 * this function executes a Cloud Run Job to process it.
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { JobsClient } = require('@google-cloud/run').v2;

const PROJECT_ID = 'watermarking-4a428';
const REGION = 'us-central1';
const JOB_NAME = 'watermarking-job';

// Initialize Cloud Run Jobs client
const jobsClient = new JobsClient();

/**
 * Triggered when a new task document is created in /tasks/{taskId}
 */
exports.onTaskCreated = onDocumentCreated(
  {
    document: 'tasks/{taskId}',
    region: REGION,
  },
  async (event) => {
    const taskId = event.params.taskId;
    const data = event.data.data();

    console.log(`Task created: ${taskId}, type: ${data.type}, status: ${data.status}`);

    // Only process pending tasks
    if (data.status !== 'pending') {
      console.log(`Task ${taskId} is not pending, skipping`);
      return;
    }

    // Execute Cloud Run Job with TASK_ID environment variable
    const jobPath = jobsClient.jobPath(PROJECT_ID, REGION, JOB_NAME);

    try {
      console.log(`Executing Cloud Run Job for task: ${taskId}`);

      const [operation] = await jobsClient.runJob({
        name: jobPath,
        overrides: {
          containerOverrides: [
            {
              env: [
                { name: 'TASK_ID', value: taskId }
              ]
            }
          ]
        }
      });

      console.log(`Job execution started for task ${taskId}, operation: ${operation.name}`);

      // Don't wait for the job to complete - it runs asynchronously
      // The job will update Firestore when it finishes

    } catch (error) {
      console.error(`Failed to execute job for task ${taskId}:`, error);

      // Update task status to failed
      const admin = require('firebase-admin');
      if (!admin.apps.length) {
        admin.initializeApp();
      }

      await admin.firestore().collection('tasks').doc(taskId).update({
        status: 'failed',
        error: `Failed to start job: ${error.message}`,
        failedAt: new Date()
      });

      throw error;
    }
  }
);
