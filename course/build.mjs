import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildCatalogue } from './inventory.mjs';
import { createHash } from 'node:crypto';
import { simpleIssues, teachingIdentity, interviewIdentity } from './teaching.mjs';

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
  if (!/^unit-\d{2}\.json$/.test(entry.file) || entry.order !== unitNumber || entry.first !== nextSession || !Number.isInteger(entry.count) || entry.count < 1 || entry.count > 14 || unitNumber <= 12 && entry.count !== 7 || !['Core', 'Deep dive', 'Swift bootcamp', 'SwiftUI bootcamp', 'Advanced practice', 'Specialist electives'].includes(entry.track)) { errors.push(`manifest unit ${unitNumber}: invalid file, order, range, count, or track`); continue; }
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
    errors.push(...simpleIssues(lesson.simple, label));
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
    const minimumWords = Number(lesson.id) >= 85 ? 1300 : 900;
    if (wordCount < minimumWords) errors.push(`${label}: only ${wordCount} teaching words; expected at least ${minimumWords}; add depth`);
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
  errors.push(...simpleIssues(guide.simple, label));
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
  if (!Array.isArray(guide.quiz) || guide.quiz.length < 3) errors.push(`${label}: add explained assessment for supplementary concepts`);
  for (const quiz of guide.quiz || []) {
    requiredString(quiz.question, `${label} question`); requiredString(quiz.explanation, `${label} explanation`);
    if (!Array.isArray(quiz.options) || quiz.options.length < 3 || !Number.isInteger(quiz.answer) || quiz.answer < 0 || quiz.answer >= quiz.options.length) errors.push(`${label}: invalid quiz`);
  }
}
const interviewQuestions = [];
const interviewBankFiles = new Set();
if (!Array.isArray(manifest?.interviewBanks) || !manifest.interviewBanks.length) errors.push('manifest.json: expected interview banks');
for (const bank of manifest?.interviewBanks || []) {
  const { file, count: expected } = bank;
  if (!/^interview-[a-z][a-z0-9-]*\.json$/.test(file || '') || interviewBankFiles.has(file) || !Number.isInteger(expected) || expected < 1) { errors.push('manifest.json: invalid or duplicate interview bank'); continue; }
  interviewBankFiles.add(file);
  try {
    const data = JSON.parse(await fs.readFile(path.join(root, 'content', file), 'utf8'));
    if (!Array.isArray(data.questions) || data.questions.length !== expected) errors.push(`${file}: expected ${expected} interview prompts`);
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
if (!Array.isArray(interviewRounds) || interviewRounds.length < 8) errors.push('Expected at least the eight original mock interview rounds');
const roundIDs = new Set();
for (const round of interviewRounds || []) {
  if (!/^[a-z0-9-]+$/.test(round.id) || roundIDs.has(round.id)) errors.push('Invalid/duplicate mock round ID');
  roundIDs.add(round.id);
  for (const key of ['title','brief','level']) requiredString(round[key], `Mock round ${round.id}.${key}`);
  if (!Number.isInteger(round.minutes) || round.minutes < 30 || round.minutes > 120) errors.push('Invalid mock round duration');
  for (const key of ['steps','evidence','questions']) if (!Array.isArray(round[key]) || round[key].length < 3) errors.push(`Mock round ${round.id}: missing ${key}`);
  for (const id of round.questions || []) if (!interviewIDs.has(id)) errors.push(`Mock round ${round.id}: unknown question ${id}`);
  const rehearsal = (round.questions || []).reduce((total, id) => total + (interviewQuestions.find(question => question.id === id)?.minutes || 0), 0);
  if (!Number.isInteger(round.setupMinutes) || round.setupMinutes < 0 || !Number.isInteger(round.debriefMinutes) || round.debriefMinutes < 5 || rehearsal + round.setupMinutes + round.debriefMinutes > round.minutes) errors.push(`Mock round ${round.id}: question, setup and debrief time must fit its advertised duration`);
}
const workshops = [];
const workshopIDs = new Set();
const artifacts = new Map();
const practiceBankFiles = new Set();
if (!Array.isArray(manifest?.practiceBanks) || !manifest.practiceBanks.length) errors.push('manifest.json: expected practice banks');
for (const file of manifest?.practiceBanks || []) {
  if (!/^practice-[a-z][a-z0-9-]*\.json$/.test(file || '') || practiceBankFiles.has(file)) { errors.push('manifest.json: invalid or duplicate practice bank'); continue; }
  practiceBankFiles.add(file);
  let content;
  try { content = JSON.parse(await fs.readFile(path.join(root, 'content', file), 'utf8')); }
  catch (error) { errors.push(`${file}: ${error.message}`); continue; }
  if (!Array.isArray(content.workshops) || !content.workshops.length) { errors.push(`${file}: expected workshops`); continue; }
  for (const workshop of content.workshops) {
    const label = `Workshop ${workshop.id}`;
    errors.push(...simpleIssues(workshop.simple, label));
    if (!/^[a-z0-9-]+$/.test(workshop.id) || workshopIDs.has(workshop.id)) errors.push(`${label}: invalid/duplicate ID`);
    workshopIDs.add(workshop.id);
    for (const key of ['title', 'summary']) requiredString(workshop[key], `${label}.${key}`);
    if (!['Host implementation', 'Native implementation', 'Tool investigation', 'Design review'].includes(workshop.kind)) errors.push(`${label}: invalid evidence kind`);
    if (!Array.isArray(workshop.sessions) || !workshop.sessions.length) errors.push(`${label}: missing lesson connections`);
    for (const id of workshop.sessions || []) if (!lessonIDs.has(id)) errors.push(`${label}: unknown lesson ${id}`);
    if (!Array.isArray(workshop.sections) || workshop.sections.length < 4) errors.push(`${label}: expected four teaching sections`);
    const sectionIDs = new Set();
    for (const section of workshop.sections || []) {
      if (!/^[a-z0-9-]+$/.test(section.id) || sectionIDs.has(section.id)) errors.push(`${label}: invalid/duplicate section ID`);
      sectionIDs.add(section.id);
      requiredString(section.title, `${label} section title`); requiredString(section.html, `${label} section HTML`);
      htmlBlocks.push({ label, html: section.html });
    }
    if (!Array.isArray(workshop.exercise?.steps) || !workshop.exercise.steps.length || !Array.isArray(workshop.exercise?.acceptance) || !workshop.exercise.acceptance.length) errors.push(`${label}: incomplete practice contract`);
    requiredString(workshop.exercise?.brief, `${label} exercise`); requiredString(workshop.exercise?.solution, `${label} worked answer`);
    htmlBlocks.push({ label, html: workshop.exercise?.solution || '' });
    if (!Array.isArray(workshop.quiz) || workshop.quiz.length < 3) errors.push(`${label}: add three explained knowledge checks`);
    for (const quiz of workshop.quiz || []) {
      requiredString(quiz.question, `${label} question`); requiredString(quiz.explanation, `${label} explanation`);
      if (!Array.isArray(quiz.options) || quiz.options.length < 3 || !Number.isInteger(quiz.answer) || quiz.answer < 0 || quiz.answer >= quiz.options.length) errors.push(`${label}: invalid quiz`);
    }
    if (!Array.isArray(workshop.references) || workshop.references.length < 2) errors.push(`${label}: add official references`);
    for (const reference of workshop.references || []) {
      requiredString(reference.label, `${label} reference`);
      try { if (new URL(reference.url).protocol !== 'https:') errors.push(`${label}: HTTPS reference required`); }
      catch { errors.push(`${label}: invalid reference`); }
    }
    if (!Array.isArray(workshop.files) || !workshop.files.length) errors.push(`${label}: missing companion artifacts`);
    for (const file of workshop.files || []) {
      requiredString(file.label, `${label} artifact label`);
      if (typeof file.path !== 'string' || !/^labs\/[A-Za-z0-9][A-Za-z0-9_./ -]*$/.test(file.path) || file.path.split('/').some(part => !part || part.startsWith('.'))) { errors.push(`${label}: unsafe artifact path`); continue; }
      try {
        const filename = await fs.realpath(path.join(root, file.path));
        const labRoot = await fs.realpath(path.join(root, 'labs'));
        if (!filename.startsWith(labRoot + path.sep)) throw new Error('Artifact escapes lab directory');
        const stats = await fs.stat(filename);
        if (!stats.isFile() || stats.size > 500_000) throw new Error('Artifact must be a bounded text file');
        const source = await fs.readFile(filename, 'utf8');
        if (source.includes('\u0000')) throw new Error('Binary artifact is not supported');
        artifacts.set(file.path, { path: file.path, source, sha256: createHash('sha256').update(source).digest('hex') });
      } catch (error) { errors.push(`${label}: ${file.path}: ${error.message}`); }
    }
    workshop.wordCount = words((workshop.sections || []).map(section => section.html).join(' ') + ' ' + (workshop.exercise?.solution || ''));
    if (workshop.wordCount < 900) errors.push(`${label}: only ${workshop.wordCount} words; add guided teaching`);
    workshops.push(workshop);
  }
}
let learningPaths;
try { learningPaths = JSON.parse(await fs.readFile(path.join(root, 'content/paths.json'), 'utf8')); }
catch (error) { errors.push(`paths.json: ${error.message}`); }
if (learningPaths?.version !== 1 || !Array.isArray(learningPaths?.paths) || learningPaths.paths.length < 6) errors.push('Expected at least the six original learning paths');
const pathIDs = new Set();
for (const learningPath of learningPaths?.paths || []) {
  if (!/^[a-z0-9-]+$/.test(learningPath.id) || pathIDs.has(learningPath.id)) errors.push('Invalid/duplicate learning path');
  pathIDs.add(learningPath.id);
  for (const key of ['title', 'summary', 'audience']) requiredString(learningPath[key], `Path ${learningPath.id}.${key}`);
  if (!Array.isArray(learningPath.evidence) || learningPath.evidence.length < 3 || !Array.isArray(learningPath.stages) || !learningPath.stages.length) errors.push(`Path ${learningPath.id}: missing stages/evidence`);
  const pathLessons = new Set();
  for (const stage of learningPath.stages || []) {
    requiredString(stage.title, `Path ${learningPath.id} stage`); requiredString(stage.summary, `Path ${learningPath.id} stage summary`);
    if (!Array.isArray(stage.lessons) || !stage.lessons.length || !Array.isArray(stage.workshops) || !Array.isArray(stage.guides)) errors.push(`Path ${learningPath.id}: invalid stage references`);
    for (const id of stage.lessons || []) { if (!lessonIDs.has(id) || pathLessons.has(id)) errors.push(`Path ${learningPath.id}: invalid/duplicate session ${id}`); pathLessons.add(id); }
    for (const id of stage.workshops || []) if (!workshopIDs.has(id)) errors.push(`Path ${learningPath.id}: missing workshop ${id}`);
    for (const id of stage.guides || []) if (!guideIDs.has(id)) errors.push(`Path ${learningPath.id}: missing guide ${id}`);
  }
}
for (const lesson of lessons) {
  if (lesson.guides !== undefined && !Array.isArray(lesson.guides)) errors.push(`${lesson.id}: guide links must be an array`);
  for (const id of lesson.guides || []) if (!guideIDs.has(id)) errors.push(`${lesson.id}: unknown guide ${id}`);
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
    if (topic.workshops !== undefined && !Array.isArray(topic.workshops)) errors.push(`Coverage ${topic.id}: workshops must be an array`);
    for (const id of topic.workshops || []) if (!workshopIDs.has(id)) errors.push(`Coverage ${topic.id}: unknown workshop ${id}`);
  }
}
try {
  const contract = JSON.parse(await fs.readFile(path.join(root, 'content/progress-contract.json'), 'utf8'));
  if (contract.version !== 1 || contract.sessions?.length !== 56) errors.push('Invalid original-progress contract');
  for (const original of contract.sessions || []) {
    const lesson = lessons.find(item => item.id === original.id);
    if (!lesson || createHash('sha256').update(JSON.stringify({ quiz: lesson.quiz, checklist: lesson.checklist })).digest('hex') !== original.sha256) errors.push(`${original.id}: original quiz/checklist storage contract changed`);
  }
} catch (error) { errors.push(`progress-contract.json: ${error.message}`); }
try {
  const contract = JSON.parse(await fs.readFile(path.join(root, 'content/progress-expansion-contract.json'), 'utf8'));
  if (contract.version !== 1 || contract.sessions?.length !== 84) errors.push('Invalid 84-session progress contract');
  for (const original of contract.sessions || []) {
    const lesson = lessons.find(item => item.id === original.id);
    if (!lesson || createHash('sha256').update(JSON.stringify({ quiz: lesson.quiz, checklist: lesson.checklist })).digest('hex') !== original.sha256) errors.push(`${original.id}: pre-expansion quiz/checklist storage contract changed`);
  }
} catch (error) { errors.push(`progress-expansion-contract.json: ${error.message}`); }
try {
  const contract = JSON.parse(await fs.readFile(path.join(root, 'content/progress-plain-contract.json'), 'utf8'));
  const items = new Map([
    ...lessons.map(item => [`lesson:${item.id}`, item]),
    ...workshops.map(item => [`workshop:${item.id}`, item]),
    ...(essentials?.guides || []).map(item => [`guide:${item.id}`, item])
  ]);
  const questions = new Map(interviewQuestions.map(item => [item.id, item]));
  if (contract.version !== 1 || !/^[a-f0-9]{40}$/.test(contract.basedOnCommit || '') || contract.entries?.length !== items.size || contract.interviews?.length !== questions.size) errors.push('Invalid plain-language teaching baseline');
  for (const original of contract.entries || []) {
    const key = `${original.kind}:${original.id}`;
    const item = items.get(key);
    if (!item || createHash('sha256').update(JSON.stringify(teachingIdentity(item))).digest('hex') !== original.sha256) errors.push(`${key}: existing quiz/checklist, section identities or code example changed`);
    items.delete(key);
  }
  for (const original of contract.interviews || []) {
    const item = questions.get(original.id);
    if (!item || createHash('sha256').update(JSON.stringify(interviewIdentity(item))).digest('hex') !== original.sha256) errors.push(`${original.id}: interview identity, timing or code example changed`);
    questions.delete(original.id);
  }
  if (items.size || questions.size) errors.push('Plain-language baseline does not cover every existing teaching and interview item');
} catch (error) { errors.push(`progress-plain-contract.json: ${error.message}`); }
if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
else {
  const catalogue = await buildCatalogue(workspace);
  const data = { version: 1, title: 'Across the Stack', generatedAt: new Date().toISOString(), units, lessons, paths: learningPaths.paths, workshops, artifacts: [...artifacts.values()], reference: reference.reference, syntax: reference.syntax, coverage, catalogue, essentials: essentials.guides, interview: { questions: interviewQuestions, rounds: interviewRounds } };
  if (!checkOnly) await fs.writeFile(path.join(root, 'data.js'), `/* Generated from course/content by build.mjs. */\nwindow.IOS_COURSE = ${JSON.stringify(data, null, 2).replace(/</g, '\\u003c')};\n`);
  console.log(`${checkOnly ? 'Validated' : 'Built'} ${lessons.length} detailed sessions, ${lessons.reduce((total, lesson) => total + lesson.wordCount, 0).toLocaleString()} lesson teaching words, ${essentials.guides.length} Swift supplementary guides, ${learningPaths.paths.length} learning paths, ${workshops.length} implementation/tool/review workshops, ${artifacts.size} offline companion source files, ${coverage.groups.flatMap(group => group.topics).length} coverage topics, ${catalogue.packages.length} remote dependency entries, ${interviewQuestions.length} interview prompts and ${interviewRounds.length} mock rounds. Repository anchors and companion paths resolve.`);
}
