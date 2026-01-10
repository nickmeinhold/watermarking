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
   * Delete an original image and all its marked versions
   */
  processDeleteOriginalImageTask: async function (data) {
    console.log(`Processing delete request for original image: ${data.originalImageId}`);

    const originalDocRef = db.collection('originalImages').doc(data.originalImageId);
    const originalDoc = await originalDocRef.get();

    if (!originalDoc.exists) {
      console.log('Original image document not found, maybe already deleted.');
      return;
    }

    const originalData = originalDoc.data();
    const gcsPath = originalData.path;

    // Delete all marked images that reference this original
    const markedImages = await db.collection('markedImages')
      .where('originalImageId', '==', data.originalImageId)
      .get();

    for (const markedDoc of markedImages.docs) {
      const markedData = markedDoc.data();
      if (markedData.path) {
        try {
          await storageHelper.deleteFile(markedData.path);
        } catch (e) {
          console.error(`Failed to delete marked image file ${markedData.path}:`, e);
        }
      }
      await markedDoc.ref.delete();
      console.log(`Deleted marked image ${markedDoc.id}`);
    }

    // Delete the original image file
    if (gcsPath) {
      try {
        await storageHelper.deleteFile(gcsPath);
      } catch (e) {
        console.error('Failed to delete original image file from storage:', e);
      }
    }

    await originalDocRef.delete();
    console.log(`Deleted original image document ${data.originalImageId}`);
  },

  /**
   * Delete a marked image (file, database entry, and related detection items)
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
    const gcsPath = markedData.path;

    // Delete all detection items that reference this marked image
    const detectionItems = await db.collection('detectionItems')
      .where('markedImageId', '==', data.markedImageId)
      .get();

    for (const detectionDoc of detectionItems.docs) {
      const detectionData = detectionDoc.data();
      // Delete the extracted/detected image file
      if (detectionData.pathMarked) {
        try {
          await storageHelper.deleteFile(detectionData.pathMarked);
        } catch (e) {
          console.error(`Failed to delete detection image file ${detectionData.pathMarked}:`, e);
        }
      }
      await detectionDoc.ref.delete();
      console.log(`Deleted detection item ${detectionDoc.id}`);
    }

    // Delete the marked image file
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
