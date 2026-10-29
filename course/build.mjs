import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildCatalogue } from './inventory.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const workspace = path.resolve(root, '../..');
const checkOnly = process.argv.includes('--check');
const errors = [];
const units = [];
const lessons = [];
const htmlBlocks = [];
const requiredString = (value, name) => { if (typeof value !== 'string' || !value.trim()) errors.push(`${name}: expected nonempty string`); };
const words = text => text.replace(/<[^>]+>/g, ' ').split(/\s+/).filter(Boolean).length;
let manifest;
try { manifest = JSON.parse(await fs.readFile(path.join(root, 'content/manifest.json'), 'utf8')); }
catch (error) { errors.push(`manifest.json: ${error.message}`); }
if (manifest?.version !== 1 || !Array.isArray(manifest?.units) || !manifest.units.length) errors.push('manifest.json: expected version 1 and units');
let nextSession = 1;
for (const [unitIndex, entry] of (manifest?.units || []).entries()) {
  const unitNumber = unitIndex + 1;
  if (!/^unit-\d{2}\.json$/.test(entry.file) || entry.order !== unitNumber || entry.first !== nextSession || entry.count !== 7 || !['Core', 'Deep dive'].includes(entry.track)) { errors.push(`manifest unit ${unitNumber}: invalid file, order, range, count, or track`); continue; }
  nextSession += entry.count;
  const filename = `content/${entry.file}`;
  let content;
  try { content = JSON.parse(await fs.readFile(path.join(root, filename), 'utf8')); }
  catch (error) { errors.push(`${filename}: ${error.message}`); continue; }
  requiredString(content.unit?.id, `${filename}.unit.id`);
  requiredString(content.unit?.title, `${filename}.unit.title`);
  requiredString(content.unit?.summary, `${filename}.unit.summary`);
  if (content.unit?.order !== unitNumber) errors.push(`${filename}: incorrect unit order`);
  if (!Array.isArray(content.lessons) || content.lessons.length !== entry.count) { errors.push(`${filename}: expected ${entry.count} lessons`); continue; }
  units.push({ ...content.unit, track: entry.track });
  for (let index = 0; index < content.lessons.length; index++) {
    const lesson = content.lessons[index];
    const expectedId = String(entry.first + index).padStart(3, '0');
    const label = `${filename} session ${lesson.id}`;
    if (lesson.id !== expectedId) errors.push(`${label}: expected ID ${expectedId}`);
    for (const key of ['title', 'summary', 'level']) requiredString(lesson[key], `${label}.${key}`);
    if (!Number.isFinite(lesson.duration) || lesson.duration < 15 || lesson.duration > 180) errors.push(`${label}: invalid duration`);
    for (const key of ['prerequisites', 'objectives', 'sections', 'quiz', 'references', 'repo', 'checklist']) if (!Array.isArray(lesson[key])) errors.push(`${label}.${key}: expected array`);
    if (lesson.objectives?.length < 2 || lesson.checklist?.length < 2) errors.push(`${label}: add learning objectives and reflection checks`);
    if (lesson.sections?.length < 5) errors.push(`${label}: expected at least five teaching sections`);
    const ids = new Set();
    for (const section of lesson.sections || []) {
      if (!/^[a-z0-9-]+$/.test(section.id) || ids.has(section.id)) errors.push(`${label}: invalid or duplicate section ID ${section.id}`);
      ids.add(section.id); requiredString(section.title, `${label} section title`); requiredString(section.html, `${label} section html`);
      htmlBlocks.push({ label, html: section.html });
    }
    if (lesson.quiz?.length < 3) errors.push(`${label}: expected at least three knowledge questions`);
    for (const quiz of lesson.quiz || []) {
      requiredString(quiz.question, `${label} quiz question`); requiredString(quiz.explanation, `${label} quiz explanation`);
      if (!Array.isArray(quiz.options) || quiz.options.length < 3 || !Number.isInteger(quiz.answer) || quiz.answer < 0 || quiz.answer >= quiz.options.length) errors.push(`${label}: invalid quiz answer/options`);
    }
    if (!lesson.exercise || !Array.isArray(lesson.exercise.steps) || !Array.isArray(lesson.exercise.acceptance)) errors.push(`${label}: invalid exercise`);
    requiredString(lesson.exercise?.brief, `${label} exercise brief`); requiredString(lesson.exercise?.solution, `${label} worked solution`);
    htmlBlocks.push({ label, html: lesson.exercise?.solution || '' });
    if (lesson.references?.length < 2) errors.push(`${label}: expected official references`);
    for (const reference of lesson.references || []) {
      requiredString(reference.label, `${label} reference label`);
      try { const url = new URL(reference.url); if (url.protocol !== 'https:') errors.push(`${label}: reference must use HTTPS`); }
      catch { errors.push(`${label}: invalid reference URL ${reference.url}`); }
    }
    if (!lesson.repo?.length) errors.push(`${label}: expected repository connection`);
    for (const repo of lesson.repo || []) {
      if (typeof repo.path !== 'string' || !repo.path.startsWith('ios-client/') && !repo.path.startsWith('android-client/')) { errors.push(`${label}: invalid repository path`); continue; }
      const filename = path.resolve(workspace, repo.path);
      if (!filename.startsWith(workspace + path.sep)) { errors.push(`${label}: source path escapes workspace`); continue; }
      try {
        const source = await fs.readFile(filename, 'utf8');
        if (!Number.isInteger(repo.line) || repo.line < 1 || repo.line > source.split('\n').length) errors.push(`${label}: invalid source line ${repo.path}:${repo.line}`);
      } catch { errors.push(`${label}: missing source ${repo.path}`); }
      requiredString(repo.why, `${label} source explanation`);
    }
    const wordCount = words((lesson.sections || []).map(section => section.html).join(' ') + ' ' + (lesson.exercise?.solution || ''));
    if (wordCount < 900) errors.push(`${label}: only ${wordCount} teaching words; add depth`);
    lessons.push({ ...lesson, unitId: content.unit.id, track: entry.track, wordCount });
  }
}
const lessonIDs = new Set(lessons.map(lesson => lesson.id));
let essentials;
try { essentials = JSON.parse(await fs.readFile(path.join(root, 'content/essentials.json'), 'utf8')); }
catch (error) { errors.push(`essentials.json: ${error.message}`); }
if (!Array.isArray(essentials?.guides) || essentials.guides.length !== 3) errors.push('essentials.json: expected three supplementary guides');
const guideIDs = new Set();
for (const guide of essentials?.guides || []) {
  const label = `Swift supplement ${guide.id}`;
  if (!/^[a-z0-9-]+$/.test(guide.id) || guideIDs.has(guide.id)) errors.push(`${label}: invalid/duplicate ID`);
  guideIDs.add(guide.id);
  for (const key of ['title', 'summary']) requiredString(guide[key], `${label}.${key}`);
  if (!Array.isArray(guide.sections) || guide.sections.length < 4) errors.push(`${label}: expected at least four sections`);
  const sectionIDs = new Set();
  for (const section of guide.sections || []) {
    if (!/^[a-z0-9-]+$/.test(section.id) || sectionIDs.has(section.id)) errors.push(`${label}: invalid/duplicate section ${section.id}`);
    sectionIDs.add(section.id);
    requiredString(section.title, `${label} section title`);
    requiredString(section.html, `${label} section html`);
    htmlBlocks.push({ label, html: section.html });
  }
  if (!Array.isArray(guide.exercise?.steps) || !guide.exercise.steps.length || !Array.isArray(guide.exercise?.acceptance) || !guide.exercise.acceptance.length) errors.push(`${label}: invalid exercise`);
  requiredString(guide.exercise?.brief, `${label} exercise brief`);
  requiredString(guide.exercise?.solution, `${label} worked answer`);
  htmlBlocks.push({ label, html: guide.exercise?.solution || '' });
  if (!Array.isArray(guide.sessions) || !guide.sessions.length) errors.push(`${label}: expected lesson connections`);
  for (const id of guide.sessions || []) if (!lessonIDs.has(id)) errors.push(`${label}: unknown lesson ${id}`);
  if (!Array.isArray(guide.references) || guide.references.length < 2) errors.push(`${label}: expected official references`);
  for (const reference of guide.references || []) {
    requiredString(reference.label, `${label} reference label`);
    try { if (new URL(reference.url).protocol !== 'https:') errors.push(`${label}: references require HTTPS`); }
    catch { errors.push(`${label}: invalid reference URL`); }
  }
  guide.wordCount = words((guide.sections || []).map(section => section.html).join(' ') + ' ' + (guide.exercise?.solution || ''));
  if (guide.wordCount < 900) errors.push(`${label}: add teaching depth`);
}
const interviewQuestions = [];
for (const file of ['interview-core.json', 'interview-deep.json']) {
  try {
    const data = JSON.parse(await fs.readFile(path.join(root, 'content', file), 'utf8'));
    if (!Array.isArray(data.questions) || data.questions.length !== 56) errors.push(`${file}: expected 56 interview prompts`);
    interviewQuestions.push(...(data.questions || []));
  } catch (error) { errors.push(`${file}: ${error.message}`); }
}
const interviewIDs = new Set();
for (const question of interviewQuestions) {
  const label = `Interview ${question.id}`;
  if (!/^iq-\d{3}-[ab]$/.test(question.id) || interviewIDs.has(question.id) || question.id.slice(3, 6) !== question.lesson || !lessonIDs.has(question.lesson)) errors.push(`${label}: invalid ID/lesson`);
  interviewIDs.add(question.id);
  for (const key of ['prompt', 'scenario', 'androidBridge', 'answerHTML']) requiredString(question[key], `${label}.${key}`);
  if (!['Foundation','Senior','Staff'].includes(question.level) || !['Explain','Debug','Design','Code'].includes(question.kind)) errors.push(`${label}: invalid level/style`);
  if (!Number.isInteger(question.minutes) || question.minutes < 3 || question.minutes > 20) errors.push(`${label}: invalid practice time`);
  for (const [key, minimum] of [['rubric',4], ['followUps',2], ['pitfalls',2]]) {
    if (!Array.isArray(question[key]) || question[key].length < minimum) errors.push(`${label}: add ${key}`);
    for (const value of question[key] || []) requiredString(value, `${label}.${key}`);
  }
  if (words(question.answerHTML || '') < 100) errors.push(`${label}: add an explained model answer`);
  htmlBlocks.push({ label, html: question.answerHTML || '' });
}
for (const lesson of lessons) for (const suffix of ['a','b']) if (!interviewIDs.has(`iq-${lesson.id}-${suffix}`)) errors.push(`Missing interview prompt iq-${lesson.id}-${suffix}`);
let interviewRounds = [];
try { interviewRounds = JSON.parse(await fs.readFile(path.join(root, 'content/interview-rounds.json'), 'utf8')).rounds; }
catch (error) { errors.push(`interview-rounds.json: ${error.message}`); }
if (!Array.isArray(interviewRounds) || interviewRounds.length !== 8) errors.push('Expected eight mock interview rounds');
const roundIDs = new Set();
for (const round of interviewRounds || []) {
  if (!/^[a-z0-9-]+$/.test(round.id) || roundIDs.has(round.id)) errors.push('Invalid/duplicate mock round ID');
  roundIDs.add(round.id);
  for (const key of ['title','brief','level']) requiredString(round[key], `Mock round ${round.id}.${key}`);
  if (!Number.isInteger(round.minutes) || round.minutes < 30 || round.minutes > 120) errors.push('Invalid mock round duration');
  for (const key of ['steps','evidence','questions']) if (!Array.isArray(round[key]) || round[key].length < 3) errors.push(`Mock round ${round.id}: missing ${key}`);
  for (const id of round.questions || []) if (!interviewIDs.has(id)) errors.push(`Mock round ${round.id}: unknown question ${id}`);
}
const allowedTags = new Set('p h3 h4 ul ol li strong em code pre table thead tbody tr th td blockquote details summary a br caption'.split(' '));
const allowedAttributes = new Set(['class', 'href', 'title', 'scope', 'colspan', 'rowspan']);
for (const { label, html } of htmlBlocks) {
  const stack = [];
  for (const match of html.matchAll(/<\/?([a-z][a-z0-9]*)\b(?:[^>"']|"[^"]*"|'[^']*')*>/gi)) {
    const tag = match[1].toLowerCase();
    if (!allowedTags.has(tag)) errors.push(`${label}: unexpected HTML tag ${tag}; escape code angle brackets`);
    const closing = match[0].startsWith('</');
    if (closing) {
      if (stack.pop() !== tag) errors.push(`${label}: mismatched closing tag ${tag}`);
    } else {
      const attributes = match[0].slice(match[0].indexOf(match[1]) + match[1].length).replace(/\/?\s*>$/, '');
      let parsed = '';
      for (const attr of attributes.matchAll(/\s+([\w-]+)\s*=\s*("[^"]*"|'[^']*')/g)) {
        parsed += attr[0];
        const name = attr[1].toLowerCase();
        if (!allowedAttributes.has(name)) errors.push(`${label}: disallowed HTML attribute ${name}`);
        if (name === 'href' && !/^['"]https:\/\//i.test(attr[2])) errors.push(`${label}: prose links must use HTTPS; use repo anchors for local files`);
      }
      if (parsed.trim() !== attributes.trim()) errors.push(`${label}: malformed or unquoted HTML attributes on ${tag}`);
      if (tag !== 'br') stack.push(tag);
    }
  }
  if (stack.length) errors.push(`${label}: unclosed HTML tags ${stack.join(', ')}`);
}
let reference;
try { reference = JSON.parse(await fs.readFile(path.join(root, 'content/reference.json'), 'utf8')); }
catch (error) { errors.push(`reference.json: ${error.message}`); }
for (const lesson of lessons) for (const prerequisite of lesson.prerequisites || []) if (!lessonIDs.has(prerequisite) || Number(prerequisite) >= Number(lesson.id)) errors.push(`${lesson.id}: invalid prerequisite ${prerequisite}`);
if (!Array.isArray(reference?.reference) || !Array.isArray(reference?.syntax)) errors.push('reference.json: expected reference and syntax arrays');
const referenceIDs = new Set();
for (const item of reference?.reference || []) {
  if (!/^[a-z0-9-]+$/.test(item.id) || referenceIDs.has(item.id)) errors.push(`Reference ${item.id}: invalid/duplicate ID`);
  referenceIDs.add(item.id);
  for (const key of ['category', 'android', 'ios', 'explanation', 'boundary']) requiredString(item[key], `Reference ${item.id}.${key}`);
  if (!lessonIDs.has(item.lesson)) errors.push(`Reference ${item.id}: invalid session ${item.lesson}`);
}
for (const item of reference?.syntax || []) for (const key of ['idea', 'android', 'swift']) requiredString(item[key], `Syntax ${key}`);
if (new Set(units.map(unit => unit.id)).size !== units.length) errors.push('Duplicate unit IDs');
let coverage;
try { coverage = JSON.parse(await fs.readFile(path.join(root, 'content/coverage.json'), 'utf8')); }
catch (error) { errors.push(`coverage.json: ${error.message}`); }
if (!/^\d{4}-\d{2}-\d{2}$/.test(coverage?.auditedAt || '') || !Array.isArray(coverage?.groups) || !Array.isArray(coverage?.limitations)) errors.push('coverage.json: expected audit date, groups, limitations');
requiredString(coverage?.scope, 'Coverage scope');
const coverageIDs = new Set();
for (const group of coverage?.groups || []) {
  requiredString(group.title, 'Coverage group title');
  if (!/^[a-z0-9-]+$/.test(group.id) || coverageIDs.has(group.id)) errors.push(`Coverage group ${group.id}: invalid/duplicate ID`);
  coverageIDs.add(group.id);
  if (!Array.isArray(group.topics) || !group.topics.length) errors.push(`Coverage group ${group.id}: expected topics`);
  for (const topic of group.topics || []) {
    if (!/^[a-z0-9-]+$/.test(topic.id) || coverageIDs.has(topic.id)) errors.push(`Coverage topic ${topic.id}: invalid/duplicate ID`);
    coverageIDs.add(topic.id);
    for (const key of ['title', 'detail', 'evidence']) requiredString(topic[key], `Coverage ${topic.id}.${key}`);
    if (!['explained', 'practice', 'further-study'].includes(topic.level)) errors.push(`Coverage ${topic.id}: invalid depth`);
    if (!Array.isArray(topic.sessions) || topic.level !== 'further-study' && !topic.sessions.length) errors.push(`Coverage ${topic.id}: expected lesson connections`);
    for (const id of topic.sessions || []) if (!lessonIDs.has(id)) errors.push(`Coverage ${topic.id}: missing lesson ${id}`);
    if (topic.guides !== undefined && !Array.isArray(topic.guides)) errors.push(`Coverage ${topic.id}: guides must be an array`);
    for (const id of topic.guides || []) if (!guideIDs.has(id)) errors.push(`Coverage ${topic.id}: unknown supplementary guide ${id}`);
  }
}
if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
else {
  const catalogue = await buildCatalogue(workspace);
  const data = { version: 1, title: 'Across the Stack', generatedAt: new Date().toISOString(), units, lessons, reference: reference.reference, syntax: reference.syntax, coverage, catalogue, essentials: essentials.guides, interview: { questions: interviewQuestions, rounds: interviewRounds } };
  if (!checkOnly) await fs.writeFile(path.join(root, 'data.js'), `/* Generated from course/content by build.mjs. */\nwindow.IOS_COURSE = ${JSON.stringify(data, null, 2).replace(/</g, '\\u003c')};\n`);
  console.log(`${checkOnly ? 'Validated' : 'Built'} ${lessons.length} detailed sessions, ${lessons.reduce((total, lesson) => total + lesson.wordCount, 0).toLocaleString()} lesson teaching words, ${essentials.guides.length} Swift supplementary guides (${essentials.guides.reduce((total, guide) => total + guide.wordCount, 0).toLocaleString()} words), ${coverage.groups.flatMap(group => group.topics).length} coverage topics, ${catalogue.packages.length} remote dependency entries, ${reference.reference.length} reference comparisons, ${interviewQuestions.length} interview prompts and ${interviewRounds.length} mock rounds. All repository paths and line anchors resolve.`);
}
