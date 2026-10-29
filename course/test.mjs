/* Real state and HTTP-handler checks. No browser, port, or dependencies needed. */
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import { handleRequest } from './serve.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const context = vm.createContext({ window: {} });
for (const filename of ['data.js', 'state.js']) vm.runInContext(await fs.readFile(path.join(root, filename), 'utf8'), context, { filename });
const course = context.window.IOS_COURSE;
const lessons = course.lessons;
const { emptyState, blankEntry, ready, normalizeState, mergeState, backupLimit } = context.IOSCourseState;
const first = lessons[0];
let checks = 0;
function check(condition, message) { assert.ok(condition, message); checks++; }
const manifest = JSON.parse(await fs.readFile(path.join(root, 'content/manifest.json'), 'utf8'));
check(lessons.length === manifest.units.reduce((total, unit) => total + unit.count, 0) && course.units.length === manifest.units.length, 'Complete manifest curriculum');
check(lessons.filter(item => item.track === 'Core').length === 28 && lessons.filter(item => item.track === 'Deep dive').length === 28, 'Stable core and expanded deep-dive tracks');
check(course.coverage.groups.length === 14 && course.coverage.groups.flatMap(group => group.topics).length >= 118, 'Auditable coverage breadth');
check(course.catalogue.packages.length === 52 && course.catalogue.packages.filter(item => item.requirement).length === 23, 'Both checked-in remote pin graphs and direct declarations inventoried');
check(course.catalogue.packages.find(item => item.id === 'peasy').graphs.length === 1, 'Legacy-only dependency is not called universally active');
for (const entry of manifest.units) {
  const content = JSON.parse(await fs.readFile(path.join(root, 'content', entry.file), 'utf8'));
  for (const original of content.lessons) {
    const { unitId, wordCount, track, ...bundled } = lessons.find(lesson => lesson.id === original.id);
    assert.deepEqual(JSON.parse(JSON.stringify(bundled)), original); checks++;
  }
}
check(course.essentials.length === 3, 'Initialization, generics and callback ownership have supplementary guides');
check(course.interview.questions.length === 112 && course.interview.rounds.length === 8, 'Two interview prompts per lesson and eight mock rounds');
check(lessons.every(lesson => course.interview.questions.filter(question => question.lesson === lesson.id).length === 2), 'No numbered lesson lacks interview rehearsal');
for (const guide of course.essentials) {
  check(guide.sections.length >= 4 && guide.wordCount >= 900 && guide.references.length >= 2, `Supplement depth ${guide.id}`);
  check(guide.sessions.every(id => lessons.some(lesson => lesson.id === id)), `Supplement lesson connections ${guide.id}`);
}
for (const item of course.catalogue.packages) for (const graph of item.graphs) {
  const source = await fs.readFile(path.resolve(root, '../..', graph.path), 'utf8');
  check(source.split('\n')[graph.line - 1].includes(`"${item.id}"`), `Pin identity anchor ${item.id} in ${graph.name}`);
}
check(backupLimit(lessons) > lessons.length * 600000, 'A complete valid backup fits the import limit');
check(emptyState().lastLesson === '004', 'Delivered mentor lesson is preserved');
check(Object.keys(emptyState().lessons).length === 0, 'No automatic completions');
const complete = { ...blankEntry(), exerciseDone: true, checks: first.checklist.map((_, i) => i), quizzes: Object.fromEntries(first.quiz.map((q, i) => [i, q.answer])), reviewed: true };
check(ready(first, complete), 'Complete self-review is eligible');
check(!ready(first, { ...complete, exerciseDone: false }), 'Exercise gates review');
check(!ready(first, { ...complete, checks: [] }), 'Reflection gates review');
check(!ready(first, { ...complete, quizzes: {} }), 'Knowledge check gates review');
const backup = item => ({ ...emptyState(), lessons: { [first.id]: item } });
check(normalizeState(backup(complete), lessons).lessons[first.id].reviewed, 'Valid review round-trip');
const duplicate = normalizeState(backup({ ...complete, checks: first.checklist.map(() => 0) }), lessons).lessons[first.id];
check(!duplicate.reviewed && duplicate.checks.length === 1, 'Duplicate checks cannot forge review');
const forged = normalizeState(backup({ ...complete, quizzes: { 0: 999 }, notes: 42 }), lessons).lessons[first.id];
check(!forged.reviewed && forged.notes === '' && !Object.keys(forged.quizzes).length, 'Invalid answers and note types rejected');
for (const raw of [null, [], { version: 2, lessons: {} }, { version: 1, lessons: [] }]) {
  assert.throws(() => normalizeState(raw, lessons)); checks++;
}
const unknown = normalizeState({ ...emptyState(), theme: 'script', lastLesson: '999', lessons: { '999': complete } }, lessons);
check(unknown.theme === 'light' && unknown.lastLesson === '004' && !Object.keys(unknown.lessons).length, 'Unknown fields cannot create sessions');
const partial = { ...blankEntry(), notes: '<script>plain text only</script>', checks: [0], quizzes: { 0: first.quiz[0].answer }, bookmark: true };
const imported = mergeState(emptyState(), backup(partial), lessons).lessons[first.id];
check(imported.notes === partial.notes && imported.bookmark && imported.quizzes[0] === first.quiz[0].answer && imported.checks.includes(0), 'Partial progress imports into empty reader');
check(!imported.reviewed, 'Partial import never silently marks reviewed');
const restored = mergeState(emptyState(), { ...backup(partial), theme: 'dark', lastLesson: '009' }, lessons);
check(restored.theme === 'dark' && restored.lastLesson === '009', 'Fresh reader restores theme and reading position');
assert.throws(() => mergeState(backup({ ...partial, notes: 'x'.repeat(100000) }), backup({ ...partial, notes: 'y' }), lessons)); checks++;
const local = { ...blankEntry(), notes: 'Local note', quizzes: { 1: first.quiz[1].answer } };
const merged = mergeState(backup(local), backup(partial), lessons).lessons[first.id];
check(merged.notes.includes('Local note') && merged.notes.includes(partial.notes), 'Both sets of notes preserved');
check(Object.keys(merged.quizzes).length === 2, 'Partial quiz progress merged');
const reviewed = mergeState(backup(local), backup(complete), lessons).lessons[first.id];
check(reviewed.reviewed && ready(first, reviewed), 'Validated imported review stays internally consistent');
const longNote = normalizeState(backup({ ...partial, notes: 'a'.repeat(100001) }), lessons).lessons[first.id];
check(longNote.notes.length === 100000, 'Notes are bounded');
const legacy = { ...emptyState(), lastLesson: '028', lessons: { '001': complete, '028': { ...blankEntry(), notes: 'Original core note', bookmark: true } } };
const expanded = normalizeState(legacy, lessons);
check(expanded.lessons['001'].reviewed && expanded.lessons['028'].notes === 'Original core note' && expanded.lastLesson === '028', 'Original 28-session progress survives expansion');
check(!expanded.lessons['029'] && !expanded.lessons['056'], 'New sessions are not automatically reviewed or initialized');
check(!normalizeState({ ...legacy, lessons: { ...legacy.lessons, 'initialization-access': complete } }, lessons).lessons['initialization-access'], 'Supplement IDs cannot create numbered-session progress');

async function request(url, method = 'GET') {
  const response = { headers: {}, status: 200, body: '' };
  const res = {
    setHeader(name, value) { response.headers[name.toLowerCase()] = value; },
    writeHead(status, headers = {}) { response.status = status; for (const [key, value] of Object.entries(headers)) this.setHeader(key, value); },
    end(body = '') { response.body = String(body); }
  };
  await handleRequest({ url, method }, res);
  return response;
}
for (const asset of ['/', '/index.html', '/styles.css', '/data.js', '/state.js', '/interview-state.js', '/interview.js', '/app.js', '/README.md']) {
  const response = await request(asset);
  check(response.status === 200 && response.body.length > 0, `Asset ${asset} renders`);
  check(response.headers['x-content-type-options'] === 'nosniff' && response.headers['content-security-policy'].includes("object-src 'none'"), `Asset ${asset} security headers`);
  check((await request(asset, 'HEAD')).body === '', `HEAD ${asset} is bodyless`);
}
const anchors = new Map(lessons.flatMap(lesson => lesson.repo).map(item => [item.path, item]));
for (const source of course.catalogue.sources) anchors.set(source.path, source);
for (const item of anchors.values()) {
  const response = await request(`/source?path=${encodeURIComponent(item.path)}&line=${item.line}`);
  check(response.status === 200 && response.body.includes(`id="L${item.line}"`), `Source ${item.path}:${item.line}`);
  check(response.headers['content-security-policy'].includes("default-src 'none'"), 'Source viewer has no script access');
}
for (const url of ['/source?path=../../etc/passwd', '/source?path=ios-client/../../etc/passwd', '/source?path=ios-client/.git/config', '/../../etc/passwd', '/%2e%2e%2fapp.js', '/%ZZ', '/content/unit-01.json', '/serve.mjs', '/source?path=ios-client/unknown.swift']) {
  check((await request(url)).status === 404, `Denied ${url}`);
}
check((await request('/', 'POST')).status === 405, 'Server is read-only');
const shell = await fs.readFile(path.join(root, 'index.html'), 'utf8');
const app = await fs.readFile(path.join(root, 'app.js'), 'utf8');
const elementIds = new Set([...shell.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]));
const generatedIds = new Set(['note-status', 'reference-count', 'reference-grid', 'search-results', 'coverage-count', 'coverage-groups', 'library-count', 'library-table']);
for (const [, id] of app.matchAll(/document\.querySelector\('#([\w-]+)'\)/g)) check(elementIds.has(id) || generatedIds.has(id), `Element #${id} exists`);
for (const [, asset] of shell.matchAll(/(?:src|href)="((?:app|state|data|interview|interview-state)\.js|styles\.css)"/g)) check((await fs.stat(path.join(root, asset))).isFile(), `Script/style ${asset} exists`);
console.log(`Passed ${checks} dependency-free checks: progress validation/merge, all course assets, ${anchors.size} source viewers, path containment, read-only requests, and reader element wiring. These are not browser or visual tests.`);
