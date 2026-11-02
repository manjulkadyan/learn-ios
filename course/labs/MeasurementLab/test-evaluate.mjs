import assert from 'node:assert/strict';
import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { evaluate, median, nearestRank } from './evaluate.mjs';

const fixture = name => JSON.parse(fs.readFileSync(new URL(`fixtures/${name}.json`, import.meta.url), 'utf8'));
for (const [name, status, exit] of [['pass', 'pass', 0], ['regression', 'regression', 1], ['invalid-preparation', 'invalid-preparation', 2], ['missing-data', 'missing-data', 3]]) {
  test(`synthetic ${name}: API and CLI agree`, () => {
    assert.equal(evaluate(fixture(name)).status, status);
    const run = spawnSync(process.execPath, [fileURLToPath(new URL('evaluate.mjs', import.meta.url)), fileURLToPath(new URL(`fixtures/${name}.json`, import.meta.url))], { encoding: 'utf8' });
    assert.equal(run.status, exit, run.stderr);
    assert.equal(JSON.parse(run.stdout).status, status);
  });
}

test('nearest rank, conventional median and raw order', () => {
  const values = Array.from({ length: 20 }, (_, i) => 20 - i);
  assert.equal(nearestRank(values), 19);
  assert.equal(median(values), 10.5);
  assert.equal(values[0], 20);
  assert.equal(nearestRank([]), null);
  assert.equal(median([]), null);
  assert.equal(nearestRank([7]), 7);
  assert.throws(() => nearestRank([1], 0), RangeError);
  assert.throws(() => nearestRank([Infinity]), TypeError);
  assert.throws(() => nearestRank([-1]), TypeError);
});

test('different cohort and failed correctness block performance approval', () => {
  const mismatched = fixture('pass');
  mismatched.candidate.cohort.configuration = 'Debug';
  assert.equal(evaluate(mismatched).status, 'incompatible-cohort');
  const wrong = fixture('pass');
  wrong.candidate.correctness = 'fail';
  assert.equal(evaluate(wrong).status, 'correctness-failure');
});

test('timeouts count against the denominator and cannot become slow success', () => {
  const input = fixture('pass');
  for (let i = 0; i < 2; i++) input.candidate.runs.push({ id: `timeout-${i}`, phase: 'measurement', prepared: true, outcome: 'timeout', milliseconds: null });
  const report = evaluate(input);
  assert.equal(report.status, 'regression');
  assert.equal(report.summaries.candidate.completedSamples, 20);
  assert.equal(report.summaries.candidate.attempts, 22);
  assert.equal(report.summaries.candidate.outcomes.timeout, 2);
  input.candidate.runs.at(-1).milliseconds = 999;
  assert.equal(evaluate(input).status, 'invalid-data');
});

test('small samples and absent metadata cannot pass', () => {
  const small = fixture('pass');
  small.candidate.runs.pop();
  assert.equal(evaluate(small).status, 'missing-data');
  const absent = fixture('pass');
  delete absent.candidate.cohort.fixture;
  assert.equal(evaluate(absent).status, 'missing-data');
});

test('invalid numeric samples, duplicate records and invalid policy reject', () => {
  for (const value of [NaN, Infinity, -1, '100']) {
    const input = fixture('pass');
    input.candidate.runs[1].milliseconds = value;
    assert.equal(evaluate(input).status, 'invalid-data');
  }
  const duplicate = fixture('pass');
  duplicate.candidate.runs.push({ ...duplicate.candidate.runs[1] });
  assert.equal(evaluate(duplicate).status, 'invalid-data');
  const invalidPolicy = fixture('pass');
  invalidPolicy.policy.maxFailureRate = 2;
  assert.equal(evaluate(invalidPolicy).status, 'invalid-data');
});

test('warmups must occur before measurement and match the declared count', () => {
  const relabeled = fixture('pass');
  relabeled.candidate.runs.push({ ...relabeled.candidate.runs[0], id: 'late-warmup' });
  assert.equal(evaluate(relabeled).status, 'invalid-data');
  const missing = fixture('pass');
  missing.candidate.runs.shift();
  assert.equal(evaluate(missing).status, 'invalid-preparation');
});

test('allowed preparation exclusions are counted and do not silently add samples', () => {
  const input = fixture('pass');
  input.candidate.runs.push({ id: 'prepare-failed', phase: 'measurement', prepared: false, outcome: 'not-run', milliseconds: null });
  const report = evaluate(input);
  assert.equal(report.status, 'pass');
  assert.equal(report.summaries.candidate.invalidPreparation, 1);
  assert.equal(report.summaries.candidate.attempts, 20);
  assert.equal(report.summaries.candidate.measurements, 21);
});

test('zero baseline is explicit and thresholds include equality', () => {
  const zero = fixture('pass');
  for (const version of [zero.baseline, zero.candidate]) for (const run of version.runs) run.milliseconds = 0;
  assert.equal(evaluate(zero).status, 'pass');
  for (const run of zero.candidate.runs) run.milliseconds = 1;
  const regression = evaluate(zero);
  assert.equal(regression.status, 'regression');
  assert.equal(regression.relativeIncrease, null);
  const boundary = fixture('pass');
  for (const run of boundary.baseline.runs) run.milliseconds = 100;
  for (const run of boundary.candidate.runs) run.milliseconds = 110;
  boundary.policy.maxP95Ms = 110;
  assert.equal(evaluate(boundary).status, 'pass');
});

test('bad JSON and missing file fail CLI without emitting a pass report', () => {
  for (const filename of [fileURLToPath(new URL('fixtures/diagnostics.txt', import.meta.url)), fileURLToPath(new URL('fixtures/absent.json', import.meta.url))]) {
    const run = spawnSync(process.execPath, [fileURLToPath(new URL('evaluate.mjs', import.meta.url)), filename], { encoding: 'utf8' });
    assert.equal(run.status, 6);
    assert.equal(run.stdout, '');
    assert.match(run.stderr, /Cannot read experiment/);
  }
});
