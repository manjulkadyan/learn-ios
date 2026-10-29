import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const packagePath = process.env.IOS_COURSE_PLAYWRIGHT;
if (!packagePath) throw new Error('Set IOS_COURSE_PLAYWRIGHT to the absolute path of an installed playwright/index.mjs. No package is downloaded by this script.');
const { chromium, firefox } = await import(pathToFileURL(packagePath).href);
const errors = [];
const browserType = process.env.IOS_COURSE_BROWSER === 'firefox' ? firefox : chromium;
const browser = await browserType.launch({ headless: true, ...(process.env.IOS_COURSE_BROWSER_PATH ? { executablePath: process.env.IOS_COURSE_BROWSER_PATH } : {}) });
const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
const page = await context.newPage();
page.on('pageerror', error => errors.push(error.message));
const base = process.env.IOS_COURSE_URL || 'http://127.0.0.1:4173';
const output = process.env.IOS_COURSE_SCREENSHOTS || '/private/tmp/ios-course-preview';
await fs.mkdir(output, { recursive: true });
try {
  await page.goto(base);
  await page.locator('#course-heading').waitFor();
  const data = await page.evaluate(() => window.IOS_COURSE);
  if (await page.locator('.unit-card').count() !== data.units.length) throw new Error('Missing course units');
  await page.screenshot({ path: path.join(output, 'desktop.png'), fullPage: true });
  await page.goto(`${base}/#lesson/001`);
  await page.locator('#lesson-notes').fill('Ownership comparison: Kotlin reference versus Swift value.');
  await page.locator('[data-bookmark]').click();
  await page.reload();
  if (await page.locator('#lesson-notes').inputValue() !== 'Ownership comparison: Kotlin reference versus Swift value.') throw new Error('Notes did not persist');
  if (await page.locator('[data-bookmark]').getAttribute('aria-pressed') !== 'true') throw new Error('Bookmark did not persist');
  const first = data.lessons.find(lesson => lesson.id === '001');
  await page.locator('[data-reviewed]').click();
  if ((await page.locator('[data-reviewed]').textContent()).includes('undo')) throw new Error('Review should be gated');
  for (let i = 0; i < first.quiz.length; i++) {
    const form = page.locator(`[data-quiz="${i}"]`);
    await form.locator(`input[value="${first.quiz[i].answer}"]`).check();
    await form.locator('button').click();
    if (!(await form.locator('.quiz-feedback').textContent()).startsWith('Correct.')) throw new Error('Quiz feedback is incorrect');
  }
  for (const check of await page.locator('[data-check]').all()) await check.check();
  await page.locator('[data-exercise-done]').check();
  await page.locator('[data-reviewed]').click();
  if (!(await page.locator('[data-reviewed]').textContent()).includes('undo')) throw new Error('Review did not save');
  await page.locator('[data-reviewed]').click(); // Smoke checks leave no reviewed completion behind.
  await page.locator('details.solution summary').click();
  if (!(await page.locator('details.solution').getAttribute('open') !== null)) throw new Error('Solution did not open');
  await page.locator('#top-search').click();
  await page.locator('#search-input').fill('coroutine');
  if (!(await page.locator('.search-result').count())) throw new Error('Full-text search found no concurrency content');
  await page.locator('#close-search').click();
  await page.goto(`${base}/#reference`);
  await page.locator('#reference-query').fill('weak');
  if (!(await page.locator('.reference-card').count())) throw new Error('Reference filtering failed');
  await page.goto(`${base}/#notes`);
  if (!(await page.locator('.note-card').count())) throw new Error('Notes page lost saved note');
  await page.goto(`${base}/#coverage`);
  await page.locator('.coverage-table').first().waitFor();
  await page.locator('[data-coverage-level="further-study"]').click();
  if (!(await page.locator('.coverage-badge.further-study').count())) throw new Error('Specialist coverage boundaries missing');
  await page.goto(`${base}/#coverage/performance-optimization`);
  await page.locator('#coverage-performance-optimization').waitFor();
  await page.goto(`${base}/#libraries`);
  await page.locator('#lib-alamofire').waitFor();
  await page.locator('[data-library-filter="different"]').click();
  await page.locator('#lib-peasy').waitFor();
  for (const guide of data.essentials) {
    await page.goto(`${base}/#essentials/${guide.id}`);
    await page.locator(`#g-${guide.id}-${guide.sections[0].id}`).waitFor();
    if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2)) throw new Error(`Desktop overflow in guide ${guide.id}`);
  }
  await page.goto(`${base}/#interviews`);
  await page.locator('#interview-query').fill('ARC');
  if (!(await page.locator('#interview-table a[href^="#interviews/iq-"]').count())) throw new Error('Interview filtering failed');
  await page.goto(`${base}/#interviews/iq-001-a`);
  await page.locator('#interview-response').fill('Synthetic explanation: independent value fields, shared class references.');
  await page.locator('[data-interview-field="score"]').selectOption('2');
  await page.locator('[data-interview-attempt] button[type="submit"]').click();
  if (!(await page.locator('.interview-attempt').count())) throw new Error('Interview attempt did not persist');
  await page.reload();
  if (!(await page.locator('.interview-attempt').count())) throw new Error('Interview history lost on reload');
  await page.goto(`${base}/#interviews/quiz/001`);
  await page.locator('[data-interview-action="start-quiz"]').click();
  const quizKeys = await page.evaluate(() => JSON.parse(localStorage.getItem('across-the-stack.interviews.v1')).activeQuiz.keys);
  for (const key of quizKeys) {
    const [, lessonId, index] = key.split('-');
    const question = data.lessons.find(lesson => lesson.id === lessonId).quiz[Number(index)];
    await page.locator(`[data-interview-exam-key="${key}"][value="${question.answer}"]`).check();
  }
  await page.locator('[data-interview-exam] button[type="submit"]').click();
  await page.locator('h1').filter({ hasText: `${first.quiz.length} / ${first.quiz.length} correct` }).waitFor();
  for (const lesson of data.lessons) {
    await page.goto(`${base}/#lesson/${lesson.id}`);
    await page.locator('#lesson-notes').waitFor();
    if (await page.locator('.quiz-card').count() !== lesson.quiz.length) throw new Error(`Missing quiz in ${lesson.id}`);
    if (await page.locator('.repo-link').count() !== lesson.repo.length) throw new Error(`Missing source connections in ${lesson.id}`);
    if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2)) throw new Error(`Desktop overflow in ${lesson.id}`);
  }
  const anchor = data.lessons[0].repo[0];
  const response = await page.request.get(`${base}/source?path=${encodeURIComponent(anchor.path)}&line=${anchor.line}`);
  if (!response.ok() || !(await response.text()).includes(`id="L${anchor.line}"`)) throw new Error('Source viewer failed');
  const invalid = await page.request.get(`${base}/source?path=../../etc/passwd`);
  if (invalid.status() !== 404) throw new Error('Source viewer accepted invalid path');
  await page.goto(`${base}/#lesson/004`);
  await page.screenshot({ path: path.join(output, 'lesson.png'), fullPage: false });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(base);
  await page.screenshot({ path: path.join(output, 'mobile.png'), fullPage: true });
  await page.locator('#menu-button').click();
  if (await page.locator('#menu-button').getAttribute('aria-expanded') !== 'true') throw new Error('Mobile menu did not open');
  await page.locator('#sidebar a[href="#reference"]').click();
  if (await page.locator('#menu-button').getAttribute('aria-expanded') !== 'false') throw new Error('Mobile menu did not close');
  for (const lesson of data.lessons) {
    await page.goto(`${base}/#lesson/${lesson.id}`);
    if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2)) throw new Error(`Mobile overflow in ${lesson.id}`);
  }
  for (const route of ['coverage', 'libraries', 'interviews', 'interviews/iq-001-a', 'interviews/quiz', 'interviews/round/staff-design', ...data.essentials.map(guide => `essentials/${guide.id}`)]) {
    await page.goto(`${base}/#${route}`);
    if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2)) throw new Error(`Mobile overflow in ${route}`);
  }
  await page.locator('#menu-button').click();
  await page.locator('#theme-toggle').click();
  if (!(await page.locator('body').getAttribute('class')).includes('dark')) throw new Error('Dark theme did not apply');
  const offline = await context.newPage();
  await offline.goto(pathToFileURL(path.join(root, 'index.html')).href);
  await offline.locator('#course-heading').waitFor();
  await offline.goto(`${pathToFileURL(path.join(root, 'index.html')).href}#lesson/016`);
  await offline.locator('.quiz-card').first().waitFor();
  if (errors.length) throw new Error(`Browser errors: ${errors.join('; ')}`);
  console.log(`Passed: ${data.lessons.length} desktop and mobile lesson routes, coverage/library maps, quizzes, gated review, notes/bookmarks persistence, search/filter, mobile navigation, dark mode, offline reader, and source viewer. Screenshots: ${output}`);
} finally { await browser.close(); }
