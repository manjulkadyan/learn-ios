import { pathToFileURL } from 'node:url';
export function synthetic() {
  // Invented arithmetic fixtures ONLY. Blank device/OS fields prevent fake hardware attribution.
  return { schema: 1, records: Array.from({length: 40}, (_, i) => ({
    id: `synthetic-${i+1}`, ordinal: i+1, variant: i % 2 ? 'indexed-thumb' : 'linear-thumb',
    fixture: 'rows-6000-unique1500-square2048-v1', boundary: 'worker-entry-to-model-ready',
    source: 'synthetic', configuration: 'Release', outcome: 'success',
    elapsedMS: 80 + Math.floor(i/2) + (i % 2 ? -10 : 0), correct: true,
    pressureStart: 'nominal', pressureEnd: 'nominal', device: '', osBuild: '',
    revision: i % 2 ? 'synthetic-candidate' : 'synthetic-baseline',
    cachePolicy: 'synthetic-no-actual-cache', workers: 1, lowPower: false
  })) };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href)
  process.stdout.write(JSON.stringify(synthetic(), null, 2) + '\n');
