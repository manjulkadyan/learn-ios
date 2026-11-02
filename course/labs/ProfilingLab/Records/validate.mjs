import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const outcomes = new Set(['success', 'error', 'cancelled', 'timeout', 'incorrect', 'preparation-failure']);
const fields = ['id', 'variant', 'fixture', 'boundary', 'source', 'configuration', 'pressureStart',
  'pressureEnd', 'device', 'osBuild', 'revision', 'cachePolicy'];
export function percentile(samples, p) {
  if (!(p > 0 && p <= 1) || !samples.length || samples.some(x => !Number.isFinite(x) || x < 0))
    throw new Error('invalid percentile input');
  return [...samples].sort((a, b) => a - b)[Math.ceil(samples.length * p) - 1];
}
export function inspect(envelope) {
  const issues = [], groups = new Map(), ids = new Set(), ordinals = new Set();
  if (envelope?.schema !== 1 || !Array.isArray(envelope.records) || envelope.records.length === 0)
    return { decision: 'invalid_capture', issues: ['schema 1 and nonempty records required'], cohorts: [] };
  for (const r of envelope.records) {
    if (!r || fields.some(f => typeof r[f] !== 'string') || !Number.isInteger(r.ordinal) || r.ordinal < 1 ||
        !Number.isInteger(r.workers) || r.workers < 1 || r.workers > 4 || typeof r.lowPower !== 'boolean') {
      issues.push('malformed record'); continue;
    }
    if (ids.has(r.id) || ordinals.has(r.ordinal) || !r.id) issues.push(`duplicate/empty identity ${r.id}`);
    ids.add(r.id); ordinals.add(r.ordinal);
    if (!outcomes.has(r.outcome)) issues.push(`${r.id}: unknown outcome`);
    if (!['synthetic', 'device', 'simulator', 'host'].includes(r.source)) issues.push(`${r.id}: annotation required`);
    if (!['nominal', 'fair', 'serious', 'critical'].includes(r.pressureStart) ||
        !['nominal', 'fair', 'serious', 'critical'].includes(r.pressureEnd)) issues.push(`${r.id}: pressure missing`);
    if (r.pressureStart !== r.pressureEnd) issues.push(`${r.id}: pressure drift violates stable-cohort protocol`);
    if (r.outcome === 'preparation-failure') issues.push(`${r.id}: fixture preparation failed`);
    if (r.source === 'synthetic') {
      if (r.device || r.osBuild) issues.push(`${r.id}: synthetic device fields must be blank`);
    } else if (!r.device || !r.osBuild || !r.revision || !['Debug', 'Release'].includes(r.configuration)) {
      issues.push(`${r.id}: observed environment incomplete`);
    }
    if (!r.fixture || !r.variant || !r.boundary || !r.cachePolicy) issues.push(`${r.id}: contract fields missing`);
    const elapsed = r.elapsedMS ?? null, correct = r.correct ?? null;
    if (elapsed !== null && (!Number.isFinite(elapsed) || elapsed < 0)) issues.push(`${r.id}: invalid duration`);
    if (correct !== null && typeof correct !== 'boolean') issues.push(`${r.id}: invalid correctness`);
    if (r.outcome === 'success' && (elapsed === null || correct !== true)) issues.push(`${r.id}: invalid success`);
    if (r.outcome === 'incorrect' && correct !== false) issues.push(`${r.id}: incorrect must fail correctness`);
    const key = JSON.stringify([r.source, r.device, r.osBuild, r.configuration, r.fixture, r.boundary,
      r.cachePolicy, r.workers, r.lowPower, r.pressureStart, r.pressureEnd]);
    if (!groups.has(key)) groups.set(key, new Map());
    const variants = groups.get(key);
    if (!variants.has(r.variant)) variants.set(r.variant, []);
    variants.get(r.variant).push(r);
  }
  const cohorts = [...groups].map(([key, variants]) => ({ coordinates: JSON.parse(key),
    variants: [...variants].map(([variant, records]) => {
      const successes = records.filter(r => r.outcome === 'success' && r.correct === true && Number.isFinite(r.elapsedMS) && r.elapsedMS >= 0);
      const values = successes.map(r => r.elapsedMS).sort((a,b) => a-b), n = values.length;
      const counts = Object.fromEntries([...outcomes].map(o => [o, records.filter(r => r.outcome === o).length]));
      const revisions = [...new Set(records.map(r => r.revision))];
      if (revisions.length !== 1) issues.push(`${variant}: multiple revisions in one variant`);
      return { variant, attempts: records.length, counts, n, medianMS: n ? (values[Math.floor((n-1)/2)] + values[Math.floor(n/2)]) / 2 : null,
        p95MS: n ? percentile(values, .95) : null, rangeMS: n ? [values[0], values[n-1]] : null,
        failureRate: records.filter(r => ['error','timeout','incorrect'].includes(r.outcome)).length / records.length,
        rawOrder: records.map(r => r.ordinal), revisions };
    }) }));
  const incorrect = envelope.records.some(r => r?.outcome === 'incorrect' || r?.correct === false);
  const sufficient = cohorts.length === 1 && cohorts[0].variants.length === 2 && cohorts[0].variants.every(v => v.n >= 20);
  return { decision: issues.length ? 'invalid_capture' : incorrect ? 'correctness_failure' : sufficient ? 'review_required' : 'insufficient_samples',
    synthetic: envelope.records.every(r => r?.source === 'synthetic'), issues, cohorts,
    note: 'Descriptive arithmetic only. Twenty successes is a lab minimum, not statistical confidence or release approval. Preserve original order and failed attempts.' };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const report = inspect(JSON.parse(readFileSync(process.argv[2], 'utf8')));
    process.stdout.write(JSON.stringify(report, null, 2) + '\n');
    process.exitCode = report.decision === 'invalid_capture' || report.decision === 'correctness_failure' ? 2 : 0;
  } catch (error) { process.stderr.write(`invalid_capture: ${error.message}\n`); process.exitCode = 2; }
}
