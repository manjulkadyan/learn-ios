/* Executes app.js against a controlled DOM adapter. Not a browser/layout test. */
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const shell = await fs.readFile(path.join(root, 'index.html'), 'utf8');
const scriptNames = ['data.js', 'state.js', 'interview-state.js', 'interview.js', 'app.js'];
const scripts = await Promise.all(scriptNames.map(name => fs.readFile(path.join(root, name), 'utf8')));
const decode = text => text.replace(/<[^>]*>/g, ' ').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;/g, "'");
class Node {
  constructor(tagName = 'DIV', dataset = {}) { this.tagName = tagName; this.dataset = dataset; this.listeners = {}; this.attributes = {}; this.style = {}; this.hidden = false; this.value = ''; this.open = false; this.classes = new Set(); }
  get innerHTML() { return this.html || ''; }
  set innerHTML(value) { this.html = value; this.text = decode(value); }
  get textContent() { return this.text || ''; }
  set textContent(value) { this.text = String(value); }
  get classList() {
    return { add: (...names) => names.forEach(x => this.classes.add(x)), remove: (...names) => names.forEach(x => this.classes.delete(x)), contains: name => this.classes.has(name), toggle: (name, force) => { const on = force === undefined ? !this.classes.has(name) : force; if (on) this.classes.add(name); else this.classes.delete(name); return on; } };
  }
  setAttribute(name, value) { this.attributes[name] = String(value); }
  removeAttribute(name) { delete this.attributes[name]; }
  addEventListener(type, callback) { (this.listeners[type] ||= []).push(callback); }
  dispatch(type, event = {}) { for (const callback of this.listeners[type] || []) callback({ target: this, ...event }); }
  matches(selector) {
    return selector.split(',').some(part => {
      const match = part.trim().match(/^\[data-([\w-]+)\]$/);
      const key = match?.[1].replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
      return key ? Object.hasOwn(this.dataset, key) : part.trim().toUpperCase() === this.tagName;
    });
  }
  closest(selector) { return this.matches(selector) ? this : null; }
  querySelector(selector) { return this.childrenBySelector?.[selector] || null; }
  querySelectorAll() { return []; } // Code/table enhancement needs a real DOM and is not claimed here.
  focus() { this.focused = true; }
  scrollIntoView() { this.scrolled = true; }
  showModal() { this.open = true; }
  close() { this.open = false; }
  append() {}
  remove() {}
  before() {}
  click() { this.dispatch('click'); }
}
const persistent = new Map();
let passed = 0;
function check(value, message) { assert.ok(value, message); passed++; }
function start(protocol = 'http:', narrow = false) {
  const nodes = new Map([...shell.matchAll(/\bid="([^"]+)"/g)].map(match => [match[1], new Node()]));
  const get = id => { if (!nodes.has(id)) nodes.set(id, new Node()); return nodes.get(id); };
  const nav = [...shell.matchAll(/\bdata-nav="([^"]+)"/g)].map(match => new Node('A', { nav: match[1] }));
  const document = new Node();
  document.body = new Node('BODY');
  document.querySelector = selector => {
    if (selector.startsWith('#')) return get(selector.slice(1));
    throw new Error(`Unexpected document selector ${selector}`);
  };
  document.querySelectorAll = selector => selector === '[data-nav]' ? nav : [];
  document.getElementById = get;
  document.createElement = tag => new Node(tag.toUpperCase());
  const env = {
    document, location: { protocol, hash: '', href: protocol === 'file:' ? `file://${root}/index.html` : 'http://127.0.0.1:4173/' }, navigator: {}, URL, Blob,
    localStorage: { getItem: key => persistent.get(key) || null, setItem: (key, value) => persistent.set(key, value) },
    setTimeout: () => 1, clearTimeout() {}, requestAnimationFrame: callback => callback(), scrollTo() {}, print() {}, confirm: () => false,
    matchMedia: () => ({ matches: narrow, addEventListener() {} }),
    addEventListener(type, callback) { this.listeners[type] = callback; }, listeners: {}
  };
  env.window = env;
  vm.createContext(env);
  scripts.forEach((script, i) => vm.runInContext(script, env, { filename: scriptNames[i] }));
  const route = hash => { env.location.hash = hash; env.listeners.hashchange(); };
  const click = data => document.dispatch('click', { target: new Node('BUTTON', data) });
  return { env, get, document, route, click, html: () => get('main').innerHTML, state: () => JSON.parse(persistent.get('across-the-stack.v1') || '{}') };
}
const reader = start();
check(reader.html().includes('YOUR NEXT SESSION · 004'), 'Mentor continue session rendered');
check((reader.html().match(/class="unit-card"/g) || []).length === reader.env.IOS_COURSE.units.length, 'All manifest chapters rendered');
check(!reader.html().includes('undefined'), 'Deep-dive chapter labels and symbols are defined');
for (const lesson of reader.env.IOS_COURSE.lessons) {
  reader.route(`#lesson/${lesson.id}`);
  check(reader.html().includes(lesson.title), `Title ${lesson.id}`);
  check((reader.html().match(/class="quiz-card"/g) || []).length === lesson.quiz.length, `Quiz forms ${lesson.id}`);
  check((reader.html().match(/class="repo-link"/g) || []).length === lesson.repo.length, `Repository anchors ${lesson.id}`);
  check(reader.html().includes('Worked solution & mentor commentary') && reader.html().includes('data-note='), `Practice and notes ${lesson.id}`);
  check(reader.html().includes(`id="interview-${lesson.id}"`) && reader.html().includes(`#interviews/quiz/${lesson.id}`), `End-of-lesson interview and recap ${lesson.id}`);
  reader.route(`#lesson/${lesson.id}/${lesson.sections[0].id}`);
  check(reader.get(`s-${lesson.id}-${lesson.sections[0].id}`).scrolled, `Section route ${lesson.id}`);
}
reader.route('#lesson/001');
const note = new Node('TEXTAREA', { note: '001' });
note.value = 'A saved note. </textarea><script>not executable</script>';
reader.document.dispatch('input', { target: note });
reader.click({ bookmark: '001' });
reader.route('#lesson/001');
check(reader.html().includes('&lt;/textarea&gt;&lt;script&gt;'), 'Note rendering escapes HTML');
check(reader.state().lessons['001'].bookmark, 'Bookmark click persists');
reader.click({ reviewed: '001' });
check(!reader.state().lessons['001'].reviewed, 'Review is gated in real app handler');
const first = reader.env.IOS_COURSE.lessons[0];
for (let index = 0; index < first.quiz.length; index++) {
  const form = new Node('FORM', { lesson: '001', quiz: String(index) });
  const selected = new Node('INPUT'); selected.value = String(first.quiz[index].answer);
  const feedback = new Node();
  form.childrenBySelector = { 'input:checked': selected, '.quiz-feedback': feedback };
  reader.document.dispatch('submit', { target: form, preventDefault() {} });
  check(feedback.textContent.startsWith('Correct.'), `Explained quiz feedback ${index}`);
}
for (let index = 0; index < first.checklist.length; index++) {
  const item = new Node('INPUT', { lesson: '001', check: String(index) }); item.checked = true;
  reader.document.dispatch('change', { target: item });
}
const exercise = new Node('INPUT', { exerciseDone: '001' }); exercise.checked = true;
reader.document.dispatch('change', { target: exercise });
reader.click({ reviewed: '001' });
check(reader.state().lessons['001'].reviewed, 'Completed self-review recorded');
exercise.checked = false;
reader.document.dispatch('change', { target: exercise });
check(!reader.state().lessons['001'].reviewed, 'Unchecking exercise clears review');
reader.route('#reference');
reader.click({ category: 'Concurrency' });
check(reader.get('reference-count').textContent === '4 comparisons', 'Category filter');
const query = reader.get('reference-query'); query.id = 'reference-query'; query.value = 'weak';
reader.document.dispatch('input', { target: query });
check(reader.get('reference-count').textContent === '0 comparisons', 'Combined category and text filtering');
reader.route('#reference/weak');
check(reader.html().includes('value=""') && reader.html().includes('chip active" data-category="All"'), 'Deep-linked reference resets toolbar coherently');
check(reader.get('reference-grid').innerHTML.includes('id="ref-weak"'), 'Reference target is visible');
reader.get('top-search').dispatch('click');
check(reader.get('search-dialog').open, 'Search dialog event');
reader.get('search-input').dispatch('input', { target: { value: 'coroutine' } });
check(reader.get('search-results').innerHTML.includes('search-result'), 'Full lesson text search');
reader.route('#essentials');
check(reader.html().includes('Swift, in finer detail.') && reader.html().includes('#essentials/generic-contracts'), 'Supplementary reference landing page');
for (const guide of reader.env.IOS_COURSE.essentials) {
  const previousState = JSON.stringify(reader.state());
  reader.route(`#essentials/${guide.id}`);
  check(reader.html().includes(guide.title) && reader.html().includes(guide.exercise.brief), `Guide explanation and practice ${guide.id}`);
  check(!reader.html().includes('data-reviewed=') && JSON.stringify(reader.state()) === previousState, `Guides never mutate learner progress ${guide.id}`);
  reader.route(`#essentials/${guide.id}/${guide.sections[0].id}`);
  check(reader.get(`g-${guide.id}-${guide.sections[0].id}`).scrolled, `Guide section navigation ${guide.id}`);
  reader.route(`#essentials/${guide.id}/exercise`);
  check(reader.get(`g-${guide.id}-exercise`).scrolled, `Guide exercise navigation ${guide.id}`);
}
reader.get('search-input').dispatch('input', { target: { value: 'associatedtype' } });
check(reader.get('search-results').innerHTML.includes('#essentials/generic-contracts'), 'Supplement prose is full-text searchable');
reader.route('#essentials/missing-guide');
check(reader.html().includes('Guide not found.'), 'Unknown supplementary guide has a useful fallback');
reader.route('#notes');
check(reader.html().includes('A saved note.') && reader.html().includes('1 saved'), 'Notes and bookmarks page');
reader.route('#plan');
check(reader.html().includes('45-minute') && reader.html().includes('Your next seven sessions'), 'Daily plan explains pacing');
reader.route('#coverage');
check(reader.html().includes('The platform, mapped.') && reader.get('coverage-count').textContent === '118 matching topics', 'Coverage map renders all audited topics');
reader.click({ coverageLevel: 'further-study' });
check(reader.get('coverage-count').textContent === '10 matching topics', 'Specialist gaps are explicitly filterable');
reader.click({ coverageLevel: 'all' });
const coverageQuery = reader.get('coverage-query'); coverageQuery.id = 'coverage-query'; coverageQuery.value = 'launch';
reader.document.dispatch('input', { target: coverageQuery });
check(reader.get('coverage-groups').innerHTML.includes('Launch and first usable frame'), 'Coverage search finds deep performance topics');
reader.route('#coverage/performance-optimization');
check(reader.html().includes('value=""') && reader.get('coverage-performance-optimization').scrolled, 'Coverage area links reset filters and navigate');
check(reader.get('coverage-groups').innerHTML.includes('Session 039'), 'Coverage links to concrete deep-dive lessons');
reader.route('#libraries');
check(reader.get('library-count').textContent === '52 matching remote entries', 'Complete remote pin catalogue rendered');
reader.click({ libraryFilter: 'direct' });
check(reader.get('library-count').textContent === '23 matching remote entries', 'Direct declarations remain distinct from resolution');
reader.click({ libraryFilter: 'different' });
check(reader.get('library-table').innerHTML.includes('lib-peasy') && reader.get('library-table').innerHTML.includes('lib-swiftlintplugins'), 'Graph differences are visible');
reader.route('#libraries/sdwebimage');
check(reader.get('lib-sdwebimage').scrolled && reader.html().includes('value=""'), 'Library deep links reset filters');
const libraryQuery = reader.get('library-query'); libraryQuery.id = 'library-query'; libraryQuery.value = 'GraphQL';
reader.document.dispatch('input', { target: libraryQuery });
check(reader.get('library-table').innerHTML.includes('lib-apollo-ios'), 'Library purpose search works');
reader.get('menu-button').dispatch('click');
check(reader.get('sidebar').classes.has('open'), 'Menu opens');
reader.route('#home');
check(!reader.get('sidebar').classes.has('open'), 'Routing closes menu');
reader.get('theme-toggle').dispatch('click');
check(reader.document.body.classes.has('dark'), 'Theme event applies');
const restored = start(); restored.route('#lesson/001');
check(restored.html().includes('A saved note.') && restored.state().lessons['001'].bookmark, 'Reader restores progress on reload');
restored.route('#lesson/999');
check(restored.html().includes('Session not found.'), 'Unknown lesson has useful fallback');
const offline = start('file:'); offline.route('#lesson/001');
check(offline.html().includes('file:') && !offline.html().includes('href="source?'), 'Direct-file source link generation');
const mobile = start('http:', true);
check(mobile.get('sidebar').inert, 'Closed mobile navigation is not keyboard-focusable');
mobile.get('menu-button').dispatch('click');
check(!mobile.get('sidebar').inert, 'Open mobile navigation is interactive');
mobile.route('#home');
check(mobile.get('sidebar').inert, 'Navigation route restores closed mobile state');
reader.route('#interviews');
check(reader.html().includes('Your interview ledger.') && reader.get('interview-count').textContent === '112 matching questions', 'Full interview ledger');
for (const question of reader.env.IOS_COURSE.interview.questions) {
  reader.route(`#interviews/${question.id}`);
  check(reader.html().includes(question.answerHTML) && reader.html().includes('Common mistakes') && reader.html().includes('Follow-up probes'), `Explained interview route ${question.id}`);
}
reader.route('#interviews');
const interviewQuery = reader.get('interview-query'); interviewQuery.id = 'interview-query'; interviewQuery.value = 'ARC';
reader.document.dispatch('input', { target: interviewQuery });
check(reader.get('interview-table').innerHTML.includes('iq-004-'), 'Interview prompt filtering');
const beforeInterview = JSON.stringify(reader.state());
const firstInterview = reader.env.IOS_COURSE.interview.questions[0];
reader.route(`#interviews/${firstInterview.id}`);
check(reader.html().includes(firstInterview.prompt) && reader.html().includes('Reveal answer rubric'), 'Question and hidden answer rubric');
for (const [field, value] of [['response','My answer. </textarea><script>plain only</script>'],['score','2'],['minutes','7'],['feedback','Need an ownership diagram'],['nextAction','Explain again without hints'],['reviewOn','2026-10-30']]) {
  const input = new Node('TEXTAREA', { interviewField: field, question: firstInterview.id }); input.value = value;
  reader.document.dispatch('input', { target: input });
}
const attemptForm = new Node('FORM', { interviewAttempt: firstInterview.id });
reader.document.dispatch('submit', { target: attemptForm, preventDefault() {} });
check(reader.html().includes('&lt;script&gt;plain only&lt;/script&gt;'), 'Interview response HTML is escaped');
const ledgerState = () => JSON.parse(persistent.get('across-the-stack.interviews.v1') || '{}');
check(ledgerState().questions[firstInterview.id].attempts.length === 1 && ledgerState().questions[firstInterview.id].attempts[0].score === 2, 'Attempt history and self-score persist');
check(JSON.stringify(reader.state()) === beforeInterview, 'Interview attempt never marks a course lesson reviewed');
reader.click({ interviewAction: 'bookmark', question: firstInterview.id });
check(ledgerState().questions[firstInterview.id].bookmark, 'Interview bookmarks persist independently');
reader.click({ interviewAction: 'clear-attempts', question: firstInterview.id });
check(ledgerState().questions[firstInterview.id].attempts.length === 1, 'Declining history deletion preserves evidence');
reader.route('#interviews/rounds');
check(reader.html().includes('Mock interview rounds.') && reader.html().includes('Staff-level design'), 'Mock round agendas');
reader.route('#interviews/round/performance-investigation');
check(reader.html().includes('Performance investigation and optimization defense'), 'Specific mock round route');
reader.route('#interviews/quiz/001');
reader.click({ interviewAction: 'start-quiz' });
check(ledgerState().activeQuiz.keys.length === first.quiz.length, 'Lesson recap samples only its available questions');
reader.route('#interviews/quiz');
reader.document.dispatch('submit', { target: new Node('FORM', { interviewExam: '' }), preventDefault() {} });
check(ledgerState().quizzes.length === 0 && ledgerState().activeQuiz, 'Incomplete exam cannot create a score');
for (const key of ledgerState().activeQuiz.keys) {
  const [ , lessonId, index ] = key.split('-');
  const question = reader.env.IOS_COURSE.lessons.find(lesson => lesson.id === lessonId).quiz[Number(index)];
  const input = new Node('INPUT', { interviewExamKey: key }); input.value = String(question.answer);
  reader.document.dispatch('change', { target: input });
}
reader.document.dispatch('submit', { target: new Node('FORM', { interviewExam: '' }), preventDefault() {} });
check(ledgerState().quizzes.length === 1 && ledgerState().activeQuiz === null, 'Finished quiz saves its result and clears only the active run');
check(reader.html().includes(`${first.quiz.length} / ${first.quiz.length} correct`) && reader.html().includes('Expected:'), `Quiz result includes score and explained correct answers; route=${reader.env.location.hash}; page=${reader.html().slice(0, 300)}`);
check(JSON.stringify(reader.state()) === beforeInterview, 'Final quiz also leaves original lesson progress untouched');
const ledgerReload = start(); ledgerReload.route(`#interviews/${firstInterview.id}`);
check(ledgerReload.html().includes('Need an ownership diagram'), 'Interview history survives reader reload');
async function importBackup(payload) {
  const text = JSON.stringify(payload);
  reader.get('import-file').dispatch('change', { target: { files: [{ size: text.length * 3, text: async () => text }], value: 'selected' } });
  await Promise.resolve(); await Promise.resolve();
}
const courseBeforeImport = JSON.stringify(reader.state());
const ledgerBeforeImport = JSON.stringify(ledgerState());
const malformedCombined = { ...reader.state(), interviews: { version: 99 } };
malformedCombined.lessons['005'] = { notes: 'This must not partly import.' };
await importBackup(malformedCombined);
check(JSON.stringify(reader.state()) === courseBeforeImport && JSON.stringify(ledgerState()) === ledgerBeforeImport, 'Invalid interview backup cannot partly change lesson progress');
await importBackup(reader.state());
check(JSON.stringify(ledgerState()) === ledgerBeforeImport, 'Actual reader import accepts old lesson-only backups without losing interview work');
await importBackup({ ...reader.state(), interviews: ledgerState() });
check(ledgerState().questions[firstInterview.id].attempts.length === 1 && ledgerState().quizzes.length === 1, 'Actual combined backup merge deduplicates attempt and quiz history');
reader.route('#interviews/missing-question');
check(reader.html().includes('Interview question not found.'), 'Unknown interview route has a fallback');
console.log(`Passed ${passed} app rendering/event checks in a controlled DOM adapter. Covers ${reader.env.IOS_COURSE.lessons.length} lessons, ${reader.env.IOS_COURSE.interview.questions.length} interview routes, interview/quiz history, combined backups, section navigation, notes, review gates, coverage/library filtering, daily plan, menu/theme, and file links. This does not validate browser layout or native interactions.`);
