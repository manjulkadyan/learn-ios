// Synthetic object store: these tests do NOT import or execute Firebase/GCS SDKs.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validGeneration, cleanupTarget, deleteOriginalGeneration } from './cleanup-policy.mjs';

function syntheticFile(initial) {
  let current = initial;
  const calls = [];
  return {
    calls,
    get current() { return current; },
    recreate(generation) { current = { generation, body: 'replacement' }; },
    async delete(options) {
      calls.push(options);
      assert.equal(typeof options.ifGenerationMatch, 'string');
      if (!current) throw Object.assign(new Error('not found'), { code: 404 });
      if (options.ifGenerationMatch !== current.generation) {
        throw Object.assign(new Error('precondition failed'), { code: 412 });
      }
      current = null;
    }
  };
}
const original = '9007199254740992';
const replacement = '9007199254740993';

test('owned job derives one path and preserves exact generation digits', () => {
  assert.deepEqual(cleanupTarget({ uid: 'alice', mediaID: 'p1', generation: original }, 'alice'),
    { path: 'users/alice/media/p1.jpg', generation: original });
  assert.throws(() => cleanupTarget({ uid: 'bob', mediaID: 'p1', generation: original }, 'alice'));
  assert.throws(() => cleanupTarget({ uid: 'alice', mediaID: '../bob', generation: original }, 'alice'));
});
test('generation accepts exact uint64 strings and rejects coerced/invalid identities', () => {
  for (const value of ['1', original, replacement, '18446744073709551615']) assert.equal(validGeneration(value), true);
  for (const value of [9007199254740992, 1, 1n, null, undefined, '0', '01', '-1', '1.0', '1e3',
    ' 1', '18446744073709551616', '9'.repeat(21)]) assert.equal(validGeneration(value), false);
});
test('original deletion succeeds with an exact precondition', async () => {
  const file = syntheticFile({ generation: original, body: 'original' });
  assert.equal(await deleteOriginalGeneration(file, original), 'deletedOriginal');
  assert.equal(file.current, null);
  assert.deepEqual(file.calls, [{ ifGenerationMatch: original }]);
});
test('lost progress acknowledgement retries an absent original safely', async () => {
  const file = syntheticFile({ generation: original, body: 'original' });
  await deleteOriginalGeneration(file, original);
  // Simulate a crash before writing completed; the same pending intent is replayed.
  assert.equal(await deleteOriginalGeneration(file, original), 'alreadyAbsent');
  assert.equal(file.current, null);
});
test('recreated path survives redelivery of the original cleanup event', async () => {
  const file = syntheticFile({ generation: original, body: 'original' });
  await deleteOriginalGeneration(file, original);
  file.recreate(replacement);
  assert.equal(await deleteOriginalGeneration(file, original), 'replacementPreserved');
  assert.deepEqual(file.current, { generation: replacement, body: 'replacement' });
  assert.equal(file.calls[1].ifGenerationMatch, original);
});
test('replacement between scheduling and deletion also survives', async () => {
  const file = syntheticFile({ generation: original, body: 'original' });
  const target = cleanupTarget({ uid: 'alice', mediaID: 'p1', generation: original }, 'alice');
  file.recreate(replacement);
  assert.equal(await deleteOriginalGeneration(file, target.generation), 'replacementPreserved');
  assert.equal(file.current.generation, replacement);
});
test('invalid numeric generation cannot issue a deletion', async () => {
  const file = syntheticFile({ generation: original, body: 'original' });
  await assert.rejects(deleteOriginalGeneration(file, 9007199254740992));
  assert.equal(file.calls.length, 0);
  assert.equal(file.current.generation, original);
});
test('service failure propagates so progress cannot be marked completed', async () => {
  const failure = Object.assign(new Error('synthetic unavailable'), { code: 503 });
  const file = { async delete() { throw failure; } };
  await assert.rejects(deleteOriginalGeneration(file, original), error => error === failure);
});
