// Separately provisioned Firebase Functions/Admin SDK source. Never part of host checks.
// No deploy command is supplied or executed by this module.
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { validID, validGeneration, cleanupTarget, deleteOriginalGeneration } from './cleanup-policy.mjs';

if (process.env.FIREBASE_FUNCTIONS_LAB !== '1') {
  throw new Error('Explicit separately provisioned Functions integration gate required');
}
const bucket = process.env.FIREBASE_COURSE_STORAGE_BUCKET;
if (!bucket) throw new Error('An explicitly reviewed Storage bucket is required');
initializeApp({ storageBucket: bucket });

export const abandonMedia = onCall({ enforceAppCheck: true, region: 'us-central1' }, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const { mediaID, generation, commandID } = request.data ?? {};
  if (!validID(mediaID) || !validGeneration(generation) || !validID(commandID) || !validID(request.auth.uid)) {
    throw new HttpsError('invalid-argument', 'Invalid cleanup identity.');
  }
  const uid = request.auth.uid;
  const job = getFirestore().doc(`users/${uid}/cleanupCommands/${commandID}`);
  await getFirestore().runTransaction(async transaction => {
    const old = await transaction.get(job);
    if (old.exists) {
      if (old.data().uid !== uid || old.data().mediaID !== mediaID || old.data().generation !== generation) {
        throw new HttpsError('failed-precondition', 'Command identity already has another payload.');
      }
      return; // Same command and payload: preserve its existing state.
    }
    transaction.create(job, { uid, mediaID, generation, status: 'pending', createdAt: FieldValue.serverTimestamp() });
  });
  return { commandID, accepted: true }; // Acceptance is not completed deletion.
});

export const performMediaCleanup = onDocumentCreated({
  document: 'users/{uid}/cleanupCommands/{command}', region: 'us-central1', retry: true
}, async event => {
  const snapshot = event.data;
  if (!snapshot) return;
  const job = snapshot.data();
  const target = cleanupTarget(job, event.params.uid);
  // A redelivered event retains its original generation even after the path is recreated.
  const outcome = await deleteOriginalGeneration(getStorage().bucket().file(target.path), target.generation);
  await snapshot.ref.update({ status: 'completed', outcome, completedAt: FieldValue.serverTimestamp() });
});
