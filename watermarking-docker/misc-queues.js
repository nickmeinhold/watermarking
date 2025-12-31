// misc-queues.js
// ==============
// Miscellaneous task processing for Firestore-based queue

var firebaseAdminSingleton = require('./firebase-admin-singleton');
var db = firebaseAdminSingleton.getFirestore();


var storageHelper = require('./storage-helper');

module.exports = {
  /**
   * Get a serving URL for an image and update Firestore
   * Uses direct Storage URL instead of App Engine serving URL
   */
  processServingUrlTask: async function (data) {
    console.log(`Getting public URL for: ${data.path}`);

    var urlString = storageHelper.getPublicUrl(data.path);
    console.log('Got public URL:', urlString);

    // Update the original image document
    await db.collection('originalImages').doc(data.imageId).update({
      servingUrl: urlString
    });

    console.log('Updated original image with serving URL');
  },


  /**
   * Delete a marked image (file and database entry)
   */
  processDeleteMarkedImageTask: async function (data) {
    console.log(`Processing delete request for marked image: ${data.markedImageId}`);

    const markedDocRef = db.collection('markedImages').doc(data.markedImageId);
    const markedDoc = await markedDocRef.get();

    if (!markedDoc.exists) {
      console.log('Marked image document not found, maybe already deleted.');
      return;
    }

    const markedData = markedDoc.data();
    const gcsPath = markedData.path; // Assuming 'path' field stores the GCS path (e.g. 'marked-images/...')

    if (gcsPath) {
      try {
        await storageHelper.deleteFile(gcsPath);
      } catch (e) {
        console.error('Failed to delete file from storage, but proceeding to delete DB entry:', e);
      }
    } else {
      console.log('No GCS path found in marked image document.');
    }

    await markedDocRef.delete();
    console.log(`Deleted marked image document ${data.markedImageId}`);
  },

  /**
   * Delete a detection item (file and database entry)
   */
  processDeleteDetectionItemTask: async function (data) {
    console.log(`Processing delete request for detection item: ${data.detectionItemId}`);

    const detectionDocRef = db.collection('detectionItems').doc(data.detectionItemId);
    const detectionDoc = await detectionDocRef.get();

    if (!detectionDoc.exists) {
      console.log('Detection item document not found, maybe already deleted.');
      return;
    }

    const detectionData = detectionDoc.data();
    const gcsPath = detectionData.pathMarked; // Path to the detecting image in GCS

    if (gcsPath) {
      try {
        await storageHelper.deleteFile(gcsPath);
      } catch (e) {
        console.error('Failed to delete file from storage, but proceeding to delete DB entry:', e);
      }
    } else {
      console.log('No GCS path found in detection item document.');
    }

    await detectionDocRef.delete();
    console.log(`Deleted detection item document ${data.detectionItemId}`);

    // Clean up the detecting status document if it matches this detection
    const detectingDocRef = db.collection('detecting').doc(data.userId);
    const detectingDoc = await detectingDocRef.get();
    if (detectingDoc.exists) {
      const detectingData = detectingDoc.data();
      if (detectingData.itemId === data.detectionItemId || !detectingData.isDetecting) {
        await detectingDocRef.delete();
        console.log(`Deleted detecting status document for user ${data.userId}`);
      }
    }
  }
};
