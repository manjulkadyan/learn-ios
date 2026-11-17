// Requires separately provisioned firebase and @firebase/rules-unit-testing.
// Never install dependencies or start/download emulators from this file.
import { readFile } from 'node:fs/promises';
import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, collection, query, limit, getDocs, serverTimestamp } from 'firebase/firestore';
import { ref, uploadBytes, getBytes, deleteObject, updateMetadata } from 'firebase/storage';

assert.equal(process.env.FIREBASE_RULES_LAB, '1', 'Explicit local rules gate required');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8080');
assert.equal(process.env.FIREBASE_STORAGE_EMULATOR_HOST, '127.0.0.1:9199');
let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-firebase-course',
    firestore: { host: '127.0.0.1', port: 8080,
      rules: await readFile(new URL('../Rules/firestore.rules', import.meta.url), 'utf8') },
    storage: { host: '127.0.0.1', port: 9199,
      rules: await readFile(new URL('../Rules/storage.rules', import.meta.url), 'utf8') }
  });
});
beforeEach(async () => { await env.clearFirestore(); await env.clearStorage(); });
after(async () => { if (env) await env.cleanup(); });
const note = (extra = {}) => ({ ownerID: 'alice', title: 'Lantern', revision: 0,
  updatedAt: serverTimestamp(), ...extra });
const aliceDB = () => env.authenticatedContext('alice').firestore();
const aliceStorage = () => env.authenticatedContext('alice').storage();

test('owner CRUD; anonymous and cross-account requests denied', async () => {
  const own = doc(aliceDB(), 'users/alice/notes/n1');
  await assertSucceeds(setDoc(own, note()));
  await assertSucceeds(getDoc(own));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), own.path)));
  await assertFails(getDoc(doc(env.authenticatedContext('bob').firestore(), own.path)));
  await assertSucceeds(updateDoc(own, { title: 'Boat', revision: 1, updatedAt: serverTimestamp() }));
  await assertSucceeds(deleteDoc(own));
});
test('forged owner, extra keys, wrong types, invalid sizes and client time denied', async () => {
  for (const payload of [note({ ownerID: 'bob' }), note({ admin: true }),
    note({ title: 12 }), note({ title: '' }), note({ title: 'x'.repeat(121) }),
    note({ revision: 0.5 }), note({ revision: 2 }), note({ updatedAt: new Date(0) })]) {
    await assertFails(setDoc(doc(aliceDB(), 'users/alice/notes/n1'), payload));
  }
});
test('stale revision and ownership transfer denied; current revision accepted', async () => {
  const own = doc(aliceDB(), 'users/alice/notes/n1');
  await setDoc(own, note());
  await assertFails(updateDoc(own, { title: 'Wrong', revision: 0, updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(own, { ownerID: 'bob', revision: 1, updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(own, { title: 'Current', revision: 1, updatedAt: serverTimestamp() }));
});
test('list has an enforced bound and cannot cross account paths', async () => {
  const own = collection(aliceDB(), 'users/alice/notes');
  await assertSucceeds(getDocs(query(own, limit(25))));
  await assertFails(getDocs(own));
  await assertFails(getDocs(query(own, limit(26))));
  await assertFails(getDocs(query(collection(aliceDB(), 'users/bob/notes'), limit(10))));
});
test('unknown collections and token registry deny writes', async () => {
  await assertFails(setDoc(doc(aliceDB(), 'admin/a'), { admin: true }));
  await assertFails(setDoc(doc(aliceDB(), 'users/alice/tokens/device1'), { token: 'synthetic' }));
});
test('Storage ownership, immutable object, MIME, metadata and byte boundaries', async () => {
  const own = ref(aliceStorage(), 'users/alice/media/p1.jpg');
  const metadata = { contentType: 'image/jpeg', customMetadata: { ownerID: 'alice' } };
  // Synthetic bytes are not a decodable JPEG; rules evaluate declarations, not pixels.
  await assertSucceeds(uploadBytes(own, new Uint8Array([1, 2, 3]), metadata));
  await assertSucceeds(getBytes(own));
  await assertFails(getBytes(ref(env.authenticatedContext('bob').storage(), own.fullPath)));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), own.fullPath)));
  await assertFails(updateMetadata(own, { customMetadata: { ownerID: 'bob' } }));
  await assertFails(uploadBytes(own, new Uint8Array([4]), metadata));
  await assertFails(uploadBytes(ref(aliceStorage(), 'users/alice/media/bad.jpg'), new Uint8Array([1]),
    { ...metadata, contentType: 'text/plain' }));
  await assertFails(uploadBytes(ref(aliceStorage(), 'users/alice/media/forged.jpg'), new Uint8Array([1]),
    { contentType: 'image/jpeg', customMetadata: { ownerID: 'bob' } }));
  await assertFails(uploadBytes(ref(aliceStorage(), 'users/alice/media/extra.jpg'), new Uint8Array([1]),
    { contentType: 'image/jpeg', customMetadata: { ownerID: 'alice', admin: 'yes' } }));
  await assertFails(uploadBytes(ref(aliceStorage(), 'users/alice/media/zero.jpg'), new Uint8Array(), metadata));
  await assertFails(uploadBytes(ref(aliceStorage(), 'users/alice/media/big.jpg'), new Uint8Array(1_048_577), metadata));
  await assertSucceeds(uploadBytes(ref(aliceStorage(), 'users/alice/media/edge.jpg'), new Uint8Array(1_048_576), metadata));
  await assertFails(deleteObject(ref(env.authenticatedContext('bob').storage(), own.fullPath)));
  await assertSucceeds(deleteObject(own));
});
