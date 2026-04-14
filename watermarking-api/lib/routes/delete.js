// Delete endpoints: DELETE /original/:id, /marked/:id, /detection/:id

const express = require('express');

const { db } = require('../config');
const { authenticateFirebaseToken } = require('../auth');
const { gcsDelete } = require('../gcs');

const router = express.Router();

/// Helper to delete a detection item's GCS files (both pathMarked and extractedRef).
async function deleteDetectionGcsFiles(detData) {
  if (detData.pathMarked) {
    await gcsDelete(detData.pathMarked).catch(() => {});
  }
  // Also clean up detecting-images/ path if it differs from pathMarked
  const extractedPath = detData.extractedRef?.remotePath;
  if (extractedPath && extractedPath !== detData.pathMarked) {
    await gcsDelete(extractedPath).catch(() => {});
  }
}

/// Delete an original image + all marked versions + detection items + GCS files.
router.delete('/original/:id', authenticateFirebaseToken, async (req, res) => {
  const originalImageId = req.params.id;
  const userId = req.uid;

  try {
    const originalRef = db.collection('originalImages').doc(originalImageId);
    const originalDoc = await originalRef.get();

    if (!originalDoc.exists) {
      return res.status(404).json({ error: 'Original image not found' });
    }

    const originalData = originalDoc.data();
    if (originalData.userId !== userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Delete all marked images referencing this original
    const markedSnap = await db.collection('markedImages')
      .where('originalImageId', '==', originalImageId)
      .get();

    for (const markedDoc of markedSnap.docs) {
      const markedData = markedDoc.data();

      // Delete detection items referencing this marked image
      const detSnap = await db.collection('detectionItems')
        .where('markedImageId', '==', markedDoc.id)
        .get();
      for (const detDoc of detSnap.docs) {
        await deleteDetectionGcsFiles(detDoc.data());
        await detDoc.ref.delete();
      }

      if (markedData.path) await gcsDelete(markedData.path).catch(() => {});
      await markedDoc.ref.delete();
    }

    // Delete the original GCS file
    if (originalData.path) await gcsDelete(originalData.path).catch(() => {});

    await originalRef.delete();
    res.json({ ok: true });
  } catch (err) {
    console.error('Delete original error:', err);
    res.status(500).json({ error: err.message });
  }
});

/// Delete a marked image + related detection items + GCS files.
router.delete('/marked/:id', authenticateFirebaseToken, async (req, res) => {
  const markedImageId = req.params.id;
  const userId = req.uid;

  try {
    const markedRef = db.collection('markedImages').doc(markedImageId);
    const markedDoc = await markedRef.get();

    if (!markedDoc.exists) {
      return res.status(404).json({ error: 'Marked image not found' });
    }

    const markedData = markedDoc.data();
    if (markedData.userId !== userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Delete detection items referencing this marked image
    const detSnap = await db.collection('detectionItems')
      .where('markedImageId', '==', markedImageId)
      .get();
    for (const detDoc of detSnap.docs) {
      await deleteDetectionGcsFiles(detDoc.data());
      await detDoc.ref.delete();
    }

    // Delete the marked image GCS file
    if (markedData.path) await gcsDelete(markedData.path).catch(() => {});

    await markedRef.delete();
    res.json({ ok: true });
  } catch (err) {
    console.error('Delete marked error:', err);
    res.status(500).json({ error: err.message });
  }
});

/// Delete a detection item + GCS files.
router.delete('/detection/:id', authenticateFirebaseToken, async (req, res) => {
  const detectionItemId = req.params.id;
  const userId = req.uid;

  try {
    const detRef = db.collection('detectionItems').doc(detectionItemId);
    const detDoc = await detRef.get();

    if (!detDoc.exists) {
      return res.status(404).json({ error: 'Detection item not found' });
    }

    const detData = detDoc.data();
    if (detData.userId !== userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await deleteDetectionGcsFiles(detData);

    await detRef.delete();
    res.json({ ok: true });
  } catch (err) {
    console.error('Delete detection error:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
