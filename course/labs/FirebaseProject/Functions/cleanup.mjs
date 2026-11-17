// Separately provisioned Firebase Functions/Admin SDK source. Never part of host checks.
// No deploy command is supplied or executed by this module.
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

if (process.env.FIREBASE_FUNCTIONS_LAB !== '1') {
  throw new Error('Explicit separately provisioned Functions integration gate required');
}
const bucket = process.env.FIREBASE_COURSE_STORAGE_BUCKET;
if (!bucket) throw new Error('An explicitly reviewed Storage bucket is required');
initializeApp({ storageBucket: bucket });
const validID = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,64}$/.test(value);

export const abandonMedia = onCall({ enforceAppCheck: true, region: 'us-central1' }, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const { mediaID, commandID } = request.data ?? {};
  if (!validID(mediaID) || !validID(commandID) || !validID(request.auth.uid)) {
    throw new HttpsError('invalid-argument', 'Invalid cleanup identity.');
  }
  const uid = request.auth.uid;
  const job = getFirestore().doc(`users/${uid}/cleanupCommands/${commandID}`);
  await getFirestore().runTransaction(async transaction => {
    const old = await transaction.get(job);
    if (old.exists) {
      if (old.data().uid !== uid || old.data().mediaID !== mediaID) {
        throw new HttpsError('failed-precondition', 'Command identity already has another payload.');
      }
      return; // Same command and payload: preserve its existing state.
    }
    transaction.create(job, { uid, mediaID, status: 'pending', createdAt: FieldValue.serverTimestamp() });
  });
  return { commandID, accepted: true }; // Acceptance is not completed deletion.
});

export const performMediaCleanup = onDocumentCreated({
  document: 'users/{uid}/cleanupCommands/{command}', region: 'us-central1', retry: true
}, async event => {
  const snapshot = event.data;
  if (!snapshot) return;
  const job = snapshot.data();
  if (!validID(job.uid) || !validID(job.mediaID) || job.uid !== event.params.uid) {
    throw new Error('Invalid trusted cleanup job');
  }
  // Stable owned path; clients cannot supply an arbitrary bucket or victim UID.
  const path = `users/${job.uid}/media/${job.mediaID}.jpg`;
  // Requires an explicitly configured default Storage bucket in the server environment.
  await getStorage().bucket().file(path).delete({ ignoreNotFound: true });
  await snapshot.ref.update({ status: 'completed', completedAt: FieldValue.serverTimestamp() });
});
