// Check one author's source files without requiring other authors to finish.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { simpleIssues, teachingIdentity, interviewIdentity } from './teaching.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const contentRoot = path.join(root, 'content');
const manifest = JSON.parse(await fs.readFile(path.join(contentRoot, 'manifest.json'), 'utf8'));
const contract = JSON.parse(await fs.readFile(path.join(contentRoot, 'progress-plain-contract.json'), 'utf8'));
const requested = process.argv.slice(2);
const files = requested.length ? requested.map(file => path.basename(file)) : [...manifest.units.map(unit => unit.file), ...manifest.practiceBanks, 'essentials.json', ...manifest.interviewBanks.map(bank => bank.file)];
const known = new Set([...manifest.units.map(unit => unit.file), ...manifest.practiceBanks, 'essentials.json', ...manifest.interviewBanks.map(bank => bank.file)]);
const baseline = new Map(contract.entries.map(item => [`${item.kind}:${item.id}`, item.sha256]));
const interviews = new Map(contract.interviews.map(item => [item.id, item.sha256]));
const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const words = html => html.replace(/<[^>]+>/g, ' ').split(/\s+/).filter(Boolean).length;
const stories = new Set();
const errors = [];
let teachingCount = 0;
let interviewCount = 0;
for (const file of files) {
  if (!known.has(file)) { errors.push(`Not a registered teaching source: ${file}`); continue; }
  const data = JSON.parse(await fs.readFile(path.join(contentRoot, file), 'utf8'));
  const kind = data.lessons ? 'lesson' : data.workshops ? 'workshop' : data.guides ? 'guide' : null;
  if (kind) {
    const entries = data.lessons || data.workshops || data.guides;
    for (const item of entries) {
      const label = `${file}:${item.id}`;
      errors.push(...simpleIssues(item.simple, label));
      if (hash(teachingIdentity(item)) !== baseline.get(`${kind}:${item.id}`)) errors.push(`${label}: original quiz/checklist, section identities or verified code changed`);
      const count = words(item.sections.map(section => section.html).join(' ') + ' ' + item.exercise.solution);
      if (count < (kind === 'lesson' && Number(item.id) >= 85 ? 1300 : 900)) errors.push(`${label}: technical teaching depth fell below the existing floor`);
      if (item.simple?.story) {
        if (stories.has(item.simple.story)) errors.push(`${label}: duplicated story; explain this specific concept`);
        stories.add(item.simple.story);
      }
      teachingCount++;
    }
  } else if (data.questions) {
    for (const item of data.questions) {
      if (hash(interviewIdentity(item)) !== interviews.get(item.id)) errors.push(`${file}:${item.id}: interview identity, timing or code changed`);
      if (words(item.answerHTML) < 100) errors.push(`${file}:${item.id}: answer lost its required depth`);
      interviewCount++;
    }
  } else errors.push(`${file}: unsupported teaching structure`);
}
if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
else console.log(`Passed source review for ${files.length} files: ${teachingCount} distinct stories/examples/illustrations, ${interviewCount} interview identities; original assessments, section links and code blocks preserved.`);
