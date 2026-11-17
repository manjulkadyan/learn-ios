// Optional RTDB rules suite. Requires a separately provisioned local RTDB emulator.
import { readFile } from 'node:fs/promises';
import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { ref, set, get, remove, serverTimestamp } from 'firebase/database';

assert.equal(process.env.FIREBASE_PRESENCE_LAB, '1');
assert.equal(process.env.FIREBASE_DATABASE_EMULATOR_HOST, '127.0.0.1:9000');
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-firebase-course',
    database: { host: '127.0.0.1', port: 9000,
      rules: await readFile(new URL('../Rules/database.rules.json', import.meta.url), 'utf8') } });
});
beforeEach(async () => { await env.clearDatabase(); });
after(async () => { if (env) await env.cleanup(); });
const own = () => ref(env.authenticatedContext('alice').database(), 'presence/alice/device1');
const state = () => ({ online: true, lastChanged: serverTimestamp() });

test('owner publishes and removes private connection state', async () => {
  await assertSucceeds(set(own(), state()));
  await assertSucceeds(get(own()));
  await assertSucceeds(remove(own()));
});
test('anonymous and foreign account cannot read or write Alice presence', async () => {
  await set(own(), state());
  for (const context of [env.unauthenticatedContext(), env.authenticatedContext('bob')]) {
    const victim = ref(context.database(), 'presence/alice/device1');
    await assertFails(get(victim));
    await assertFails(set(victim, state()));
    await assertFails(remove(victim));
  }
});
test('invalid shape, stale client time and false online are denied', async () => {
  for (const payload of [{ online: true }, { online: true, lastChanged: 0 },
    { online: false, lastChanged: serverTimestamp() },
    { ...state(), admin: true }, { online: 'yes', lastChanged: serverTimestamp() }]) {
    await assertFails(set(own(), payload));
  }
});
