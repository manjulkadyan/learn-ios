import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

// This is a deterministic policy evaluator, not a measurement collector.
// All supplied fixture records are invented teaching data.
export function nearestRank(values, percentile = 0.95) {
  if (!Number.isFinite(percentile) || percentile <= 0 || percentile > 1) {
    throw new RangeError('Percentile must be finite and in (0, 1]');
  }
  if (!Array.isArray(values) || values.some(v => !Number.isFinite(v) || v < 0)) {
    throw new TypeError('Samples must be finite nonnegative numbers');
  }
  if (!values.length) return null;
  const ordered = [...values].sort((a, b) => a - b);
  return ordered[Math.ceil(percentile * ordered.length) - 1];
}

export function median(values) {
  nearestRank(values); // Validate without mutating the original observation order.
  if (!values.length) return null;
  const ordered = [...values].sort((a, b) => a - b);
  const middle = Math.floor(ordered.length / 2);
  return ordered.length % 2 ? ordered[middle] : (ordered[middle - 1] + ordered[middle]) / 2;
}

const cohortKeys = ['device', 'os', 'toolchain', 'configuration', 'fixture', 'preparation', 'cache', 'instrumentation', 'metric'];
const outcomes = ['completed', 'failure', 'timeout', 'cancelled'];
const nonempty = value => typeof value === 'string' && value.trim().length > 0;

export function evaluate(input) {
  const result = (status, reasons, details = {}) => ({ status, reasons, ...details });
  if (!input || typeof input !== 'object' || Array.isArray(input) || input.schemaVersion !== 1) {
    return result('invalid-data', ['Expected a schemaVersion 1 experiment object']);
  }
  if (!nonempty(input.provenance) || !input.metric || !input.policy || !input.baseline || !input.candidate) {
    return result('missing-data', ['Provenance, metric, policy, baseline and candidate are required']);
  }
  const metric = input.metric;
  if (![metric.id, metric.start, metric.end].every(nonempty) || metric.unit !== 'ms' || metric.direction !== 'lower') {
    return result('invalid-data', ['This evaluator supports explicit lower-is-better millisecond boundaries only']);
  }
  const policy = input.policy;
  if (!Number.isInteger(policy.minSamples) || policy.minSamples < 1 ||
      !Number.isInteger(policy.warmupCount) || policy.warmupCount < 0 ||
      !Number.isFinite(policy.maxP95Ms) || policy.maxP95Ms < 0 ||
      !Number.isFinite(policy.maxRelativeIncrease) || policy.maxRelativeIncrease < 0 ||
      !['maxFailureRate', 'maxFailureRateIncrease', 'maxPreparationFailureRate'].every(key =>
        Number.isFinite(policy[key]) && policy[key] >= 0 && policy[key] <= 1) ||
      !nonempty(policy.owner)) {
    return result('invalid-data', ['Policy needs an owner, valid counts, budgets and rates']);
  }
  for (const name of ['baseline', 'candidate']) {
    const version = input[name];
    if (!nonempty(version.revision) || !version.cohort ||
        cohortKeys.some(key => !nonempty(version.cohort[key])) ||
        !nonempty(version.correctness) || !Array.isArray(version.runs)) {
      return result('missing-data', [`${name}: revision, complete cohort, correctness and runs are required`]);
    }
  }
  const changed = cohortKeys.filter(key => input.baseline.cohort[key] !== input.candidate.cohort[key]);
  if (changed.length) return result('incompatible-cohort', changed.map(key => `Different ${key}`));
  if (input.baseline.cohort.metric !== metric.id) {
    return result('invalid-data', ['Cohort metric must identify the declared operation']);
  }
  if (input.baseline.correctness !== 'pass' || input.candidate.correctness !== 'pass') {
    return result('correctness-failure', ['Both independent correctness contracts must pass before timing']);
  }

  const summaries = {};
  for (const name of ['baseline', 'candidate']) {
    const runs = input[name].runs;
    const ids = new Set();
    let warmups = 0;
    let measurements = 0;
    let invalidPreparation = 0;
    let attempts = 0;
    const counts = Object.fromEntries(outcomes.map(outcome => [outcome, 0]));
    const samples = [];
    for (const run of runs) {
      if (!run || !nonempty(run.id) || !['warmup', 'measurement'].includes(run.phase) || typeof run.prepared !== 'boolean') {
        return result('invalid-data', [`${name}: every run needs id, declared phase and preparation state`]);
      }
      if (ids.has(run.id)) return result('invalid-data', [`${name}: duplicate run ${run.id}`]);
      ids.add(run.id);
      if (!run.prepared) {
        if (run.outcome !== 'not-run' || run.milliseconds !== null) {
          return result('invalid-data', [`${name}/${run.id}: failed preparation is not a completed or timed operation`]);
        }
      } else {
        if (!outcomes.includes(run.outcome)) return result('invalid-data', [`${name}/${run.id}: unknown outcome`]);
        if (run.outcome === 'completed') {
          if (run.milliseconds === undefined || run.milliseconds === null) {
            return result('missing-data', [`${name}/${run.id}: completed operation has no duration`]);
          }
          if (!Number.isFinite(run.milliseconds) || run.milliseconds < 0) {
            return result('invalid-data', [`${name}/${run.id}: duration must be finite and nonnegative`]);
          }
        } else if (run.milliseconds !== null) {
          return result('invalid-data', [`${name}/${run.id}: unfinished/failed outcomes must not enter completed latency`]);
        }
      }
      if (run.phase === 'warmup') {
        warmups += 1;
        if (!run.prepared || run.outcome !== 'completed') {
          return result('invalid-preparation', [`${name}/${run.id}: declared warmup did not complete`]);
        }
        if (measurements > 0) return result('invalid-data', [`${name}: warmup cannot be relabeled after measurements begin`]);
        continue;
      }
      measurements += 1;
      if (!run.prepared) { invalidPreparation += 1; continue; }
      attempts += 1;
      counts[run.outcome] += 1;
      if (run.outcome === 'completed') samples.push(run.milliseconds);
    }
    summaries[name] = {
      totalRecords: runs.length, warmups, measurements, invalidPreparation, attempts,
      outcomes: counts, completedSamples: samples.length,
      preparationFailureRate: measurements ? invalidPreparation / measurements : null,
      failureRate: attempts ? (attempts - counts.completed) / attempts : null,
      medianMs: median(samples), p95Ms: nearestRank(samples),
      minMs: samples.length ? Math.min(...samples) : null,
      maxMs: samples.length ? Math.max(...samples) : null
    };
  }
  const preparationProblems = [];
  const dataProblems = [];
  for (const name of ['baseline', 'candidate']) {
    const summary = summaries[name];
    if (summary.warmups !== policy.warmupCount) preparationProblems.push(`${name}: warmup count differs from declared policy`);
    if (summary.preparationFailureRate !== null && summary.preparationFailureRate > policy.maxPreparationFailureRate) {
      preparationProblems.push(`${name}: preparation failure rate exceeds policy`);
    }
    if (summary.completedSamples < policy.minSamples) dataProblems.push(`${name}: fewer than ${policy.minSamples} completed samples`);
  }
  const details = { provenance: input.provenance, metric, owner: policy.owner, summaries };
  if (preparationProblems.length) return result('invalid-preparation', [...preparationProblems, ...dataProblems], details);
  if (dataProblems.length) return result('missing-data', dataProblems, details);
  const baseline = summaries.baseline;
  const candidate = summaries.candidate;
  const relativeIncrease = baseline.p95Ms === 0 ? null : (candidate.p95Ms - baseline.p95Ms) / baseline.p95Ms;
  const regressions = [];
  if (candidate.p95Ms > policy.maxP95Ms) regressions.push('Candidate p95 exceeds absolute budget');
  if (baseline.p95Ms === 0 ? candidate.p95Ms > 0 : relativeIncrease > policy.maxRelativeIncrease) {
    regressions.push('Candidate p95 exceeds allowed increase against baseline');
  }
  if (candidate.failureRate > policy.maxFailureRate) regressions.push('Candidate failure rate exceeds absolute budget');
  if (candidate.failureRate - baseline.failureRate > policy.maxFailureRateIncrease) {
    regressions.push('Candidate failure rate increases beyond policy');
  }
  return result(regressions.length ? 'regression' : 'pass', regressions, { ...details, relativeIncrease });
}

export const exitCodes = Object.freeze({ pass: 0, regression: 1, 'invalid-preparation': 2, 'missing-data': 3, 'incompatible-cohort': 4, 'correctness-failure': 5, 'invalid-data': 6 });

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const filename = process.argv[2];
  if (!filename || process.argv.length !== 3) {
    process.stderr.write('Usage: node labs/MeasurementLab/evaluate.mjs <experiment.json>\n');
    process.exitCode = 6;
  } else {
    try {
      const report = evaluate(JSON.parse(fs.readFileSync(filename, 'utf8')));
      process.stdout.write(JSON.stringify(report, null, 2) + '\n');
      process.exitCode = exitCodes[report.status];
    } catch (error) {
      process.stderr.write(`Cannot read experiment: ${error.message}\n`);
      process.exitCode = 6;
    }
  }
}
