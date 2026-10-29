/* Dependency-free, offline course reader. Content is produced by build.mjs. */
(() => {
  'use strict';
  const course = window.IOS_COURSE;
  const main = document.querySelector('#main');
  if (!course || !Array.isArray(course.lessons) || !course.lessons.length) {
    main.innerHTML = '<div class="empty-state"><h1>Build the course first.</h1><p>Run <code>node ios-learning/course/build.mjs</code> from the workspace, then reload this page.</p></div>';
    return;
  }
  const lessons = [...course.lessons].sort((a, b) => Number(a.id) - Number(b.id));
  const byId = new Map(lessons.map(lesson => [lesson.id, lesson]));
  const storageKey = 'across-the-stack.v1';
  let storageAvailable = true;
  const { emptyState, blankEntry, ready, mergeState, backupLimit } = window.IOSCourseState;
  const normalizeState = raw => window.IOSCourseState.normalizeState(raw, lessons);
  let state = emptyState();
  const escape = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
  try {
    const stored = localStorage.getItem(storageKey);
    if (stored) state = normalizeState(JSON.parse(stored));
  } catch { storageAvailable = false; }
  function save() {
    try { localStorage.setItem(storageKey, JSON.stringify(state)); }
    catch { storageAvailable = false; toast('Browser storage is unavailable. Export a backup to keep your work.'); }
  }
  function entry(id) {
    if (!state.lessons[id]) state.lessons[id] = blankEntry();
    return state.lessons[id];
  }
  let toastTimer;
  function toast(message) {
    const target = document.querySelector('#toast');
    target.textContent = message;
    target.classList.add('visible');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => target.classList.remove('visible'), 3500);
  }
  function applyTheme() {
    document.body.classList.toggle('dark', state.theme === 'dark');
    document.querySelector('#theme-toggle span').textContent = state.theme === 'dark' ? 'Light reading mode' : 'Dark reading mode';
  }
  function renderSidebar() {
    const count = lessons.filter(lesson => state.lessons[lesson.id]?.reviewed).length;
    document.querySelector('#lesson-total').textContent = `${lessons.length} sessions`;
    document.querySelector('#progress-label').textContent = `${count} / ${lessons.length}`;
    document.querySelector('#progress-fill').style.width = `${count / lessons.length * 100}%`;
    const progress = document.querySelector('#course-progress');
    progress.setAttribute('aria-valuemax', lessons.length);
    progress.setAttribute('aria-valuenow', count);
    const current = (location.hash.match(/^#lesson\/(\d{3})/) || [])[1];
    document.querySelector('#curriculum-nav').innerHTML = course.units.map(unit => {
      const items = lessons.filter(lesson => lesson.unitId === unit.id);
      const open = items.some(lesson => lesson.id === current) || (!current && unit.order === 1);
      return `<details ${open ? 'open' : ''}><summary><span class="unit-number">${String(unit.order).padStart(2, '0')}</span>${escape(unit.title)}</summary>${items.map(lesson => `<a class="lesson-nav-link ${lesson.id === current ? 'active' : ''} ${state.lessons[lesson.id]?.reviewed ? 'is-reviewed' : ''}" href="#lesson/${lesson.id}" ${lesson.id === current ? 'aria-current="page"' : ''}><span>${state.lessons[lesson.id]?.reviewed ? '✓' : lesson.id}</span><span>${escape(lesson.title)}</span></a>`).join('')}</details>`;
    }).join('');
    const page = location.hash.slice(1).split('/')[0] || 'home';
    document.querySelectorAll('[data-nav]').forEach(link => {
      const active = link.dataset.nav === page;
      link.classList.toggle('active', active);
      if (active) link.setAttribute('aria-current', 'page'); else link.removeAttribute('aria-current');
    });
  }
  const storageWarning = () => storageAvailable ? '' : '<p class="storage-warning">Your browser is not saving local progress. Use “Back up your progress” to keep notes and answers before closing this page.</p>';
  const interviews = window.IOSInterviewReader.create({ course, escape, toast, rerender: () => render() });
  function continueLesson() {
    const last = byId.get(state.lastLesson);
    if (last && !state.lessons[last.id]?.reviewed) return last;
    return lessons.find(lesson => !state.lessons[lesson.id]?.reviewed) || lessons[0];
  }
  function renderHome() {
    const next = continueLesson();
    const unit = course.units.find(item => item.id === next.unitId);
    const count = lessons.filter(lesson => state.lessons[lesson.id]?.reviewed).length;
    main.innerHTML = `${storageWarning()}<section class="hero"><div><p class="eyebrow">A NEW PLATFORM. A FAMILIAR FOUNDATION.</p><h1>Android experience.<br><em>iOS understanding.</em></h1><p class="lead">A thoughtful course for the engineer you already are. Learn the language, trace real features, and build the judgment to deliver confidently on iOS.</p></div><div class="hero-illustration" aria-hidden="true"><span class="orb-label left">KOTLIN</span><span class="bridge-symbol">a / i</span><span class="orb-label right">SWIFT</span></div></section>
    <div class="stat-strip"><div class="stat-item"><strong>${lessons.length}</strong><span>in-depth<br>sessions</span></div><div class="stat-item"><strong>${course.units.length}</strong><span>learning<br>chapters</span></div><div class="stat-item"><strong>45</strong><span>minutes<br>a day</span></div><p class="stat-note">Real code. Clear analogies.<br>Room to ask why.</p></div>
    <section class="continue-card"><div><p class="eyebrow">YOUR NEXT SESSION · ${next.id} / ${lessons.length}</p><h2>${escape(next.title)}</h2><p>${escape(next.summary)}</p></div><a class="button" href="#lesson/${next.id}">Open session <span aria-hidden="true">↗</span></a></section>
    <section aria-labelledby="course-heading"><div class="section-heading"><div><h2 id="course-heading">Your path across the stack</h2><p>Core foundations followed by platform, tooling, UI, and optimization deep dives. <a href="#coverage">Inspect the coverage map →</a></p></div><span class="small-label">${count} sessions self-reviewed</span></div><div class="unit-grid">${course.units.map((item, i) => {
      const items = lessons.filter(lesson => lesson.unitId === item.id);
      return `<article class="unit-card"><div class="unit-card-head"><span class="unit-number">${escape(item.track || 'Core').toUpperCase()} · ${String(i + 1).padStart(2, '0')}</span><span class="unit-symbol" aria-hidden="true">${['{ }', '◫', '⇄', '↗', '▦', '◷', '⌘', '◎'][i % 8]}</span></div><h3>${escape(item.title)}</h3><p>${escape(item.summary)}</p><ul class="unit-lessons">${items.map(lesson => `<li><a href="#lesson/${lesson.id}"><span>${lesson.id}</span><span>${escape(lesson.title)}</span></a></li>`).join('')}</ul><div class="unit-card-footer"><span>${items.length} sessions · explanations + practice</span><a href="#lesson/${items[0].id}">Explore chapter →</a></div></article>`;
    }).join('')}</div></section>
    <aside class="mentor-note"><div class="mark" aria-hidden="true">“</div><div><h3>Experience transfers. Assumptions need examination.</h3><p>Your Android background is the starting point for every lesson. We’ll explain the differences carefully, including the small ones that become production bugs. Staff readiness develops through repeated delivery, judgment, and impact. Your browser progress records your own review; it does not certify mastery.</p></div></aside>`;
    document.querySelector('#breadcrumbs').textContent = `Learning desk / ${unit.title}`;
  }
  function sectionId(lesson, section) { return `s-${lesson.id}-${section.id}`; }
  function sourceURL(item) {
    if (location.protocol === 'file:') return `${new URL(`../../${item.path}`, location.href).href}#L${item.line || 1}`;
    return `source?path=${encodeURIComponent(item.path)}&line=${item.line || 1}#L${item.line || 1}`;
  }
  function quizHTML(lesson, item, index) {
    const selected = entry(lesson.id).quizzes[index];
    return `<form class="quiz-card" data-quiz="${index}" data-lesson="${lesson.id}"><fieldset><legend>${index + 1}. ${escape(item.question)}</legend>${item.options.map((option, answer) => `<label class="quiz-option"><input type="radio" name="quiz-${lesson.id}-${index}" value="${answer}" ${selected === answer ? 'checked' : ''} required><span>${escape(option)}</span></label>`).join('')}</fieldset><button class="button secondary" type="submit">Check my reasoning</button><div class="quiz-feedback ${selected !== undefined && selected !== item.answer ? 'incorrect' : ''}" ${selected === undefined ? 'hidden' : ''} aria-live="polite">${selected === undefined ? '' : `${selected === item.answer ? 'Correct. ' : 'Revisit this idea. '}${escape(item.explanation)}`}</div></form>`;
  }
  function renderLesson(lesson, section) {
    const item = entry(lesson.id);
    state.lastLesson = lesson.id;
    save();
    const unit = course.units.find(x => x.id === lesson.unitId);
    document.querySelector('#breadcrumbs').textContent = `${unit.title} / Session ${lesson.id}`;
    const index = lessons.indexOf(lesson);
    main.innerHTML = `${storageWarning()}<div class="lesson-top"><div class="lesson-meta"><span class="pill">${escape(lesson.level)}</span><span>SESSION ${lesson.id}</span><span>·</span><span>${lesson.duration} MIN</span></div><div class="row"><button class="button tertiary" data-bookmark="${lesson.id}" aria-pressed="${item.bookmark}">${item.bookmark ? '★ Bookmarked' : '☆ Bookmark'}</button><button class="button tertiary" data-print>Print</button></div></div>
    <div class="lesson-title"><h1>${escape(lesson.title)}</h1><p>${escape(lesson.summary)}</p><p class="note-status">${lesson.duration} minutes estimated for the full explanation, tracing, and practice. Split this into about ${Math.ceil(lesson.duration / 45)} daily blocks of 45 minutes; labs may take longer.</p></div>
    <div class="lesson-layout"><article class="lesson-article"><div class="objectives"><h2>By the end of this session</h2><ul>${lesson.objectives.map(objective => `<li>${escape(objective)}</li>`).join('')}</ul>${lesson.prerequisites.length ? `<p class="note-status">Builds on ${lesson.prerequisites.map(id => `<a href="#lesson/${id}">session ${id}</a>`).join(', ')}. You can browse ahead; keep unfinished practice on your list.</p>` : ''}</div>
    ${lesson.sections.map(block => `<section class="lesson-section" id="${sectionId(lesson, block)}"><h2>${escape(block.title)}</h2><div class="prose">${block.html}</div></section>`).join('')}
    <section class="lesson-section" id="repo-${lesson.id}"><h2>Follow the idea into your codebase</h2><div class="repo-grid">${lesson.repo.map(repo => `<a class="repo-link" href="${escape(sourceURL(repo))}" target="_blank" rel="noopener"><strong>${escape(repo.label)} ↗</strong><code>${escape(repo.path)}:${repo.line || 1}</code><p>${escape(repo.why)}</p></a>`).join('')}</div><p class="note-status">Source anchors were checked when the course was built. Local checkout changes may move line numbers.</p></section>
    <section class="lesson-section" id="quiz-${lesson.id}"><h2>Check your understanding</h2><p class="muted">Choose an answer, then read the reasoning. Getting it wrong is a useful signal.</p>${lesson.quiz.map((quiz, i) => quizHTML(lesson, quiz, i)).join('')}</section>
    <section class="lesson-section" id="exercise-${lesson.id}"><h2>Make the idea your own</h2><div class="exercise-card"><p>${escape(lesson.exercise.brief)}</p><h3>Your task</h3><ol>${lesson.exercise.steps.map(step => `<li>${escape(step)}</li>`).join('')}</ol><h3>What good work demonstrates</h3><ul>${lesson.exercise.acceptance.map(criterion => `<li>${escape(criterion)}</li>`).join('')}</ul><details class="solution"><summary>Worked solution & mentor commentary</summary><div class="prose">${lesson.exercise.solution}</div></details></div></section>
    <section class="lesson-section" id="review-${lesson.id}"><h2>Reflection & review</h2><div class="checklist">${lesson.checklist.map((check, i) => `<label><input type="checkbox" data-check="${i}" data-lesson="${lesson.id}" ${item.checks.includes(i) ? 'checked' : ''}><span>${escape(check)}</span></label>`).join('')}<label><input type="checkbox" data-exercise-done="${lesson.id}" ${item.exerciseDone ? 'checked' : ''}><span>I attempted the exercise and compared my reasoning with the worked solution.</span></label></div><div class="review-actions"><button class="button" data-reviewed="${lesson.id}">${item.reviewed ? '✓ Reviewed · undo' : 'Mark session reviewed'}</button><span class="review-note">Review requires the quiz, reflection checklist, and exercise. This records your self-assessment.</span></div></section>
    <section class="lesson-section" id="notes-${lesson.id}"><h2>Your notes</h2><label class="sr-only" for="lesson-notes">Notes for session ${lesson.id}</label><textarea id="lesson-notes" class="note-area" data-note="${lesson.id}" maxlength="100000" placeholder="What clicked? What would you ask a reviewer? Keep a small example or a question for your mentor.">${escape(item.notes)}</textarea><p class="note-status" id="note-status">Saved in this browser only. Export a backup to keep a portable copy.</p></section>
    <section class="lesson-section" id="sources-${lesson.id}"><h2>Keep these references nearby</h2><div class="reference-links">${lesson.references.map(source => `<a href="${escape(source.url)}" target="_blank" rel="noopener">${escape(source.label)} <span aria-hidden="true">↗</span></a>`).join('')}</div><p class="note-status">Official references open online. The course text, practice, and notes work offline. Snippets explain a concept; framework snippets need a matching iOS target.</p></section>
    ${interviews.lessonHTML(lesson.id)}
    <nav class="lesson-pagination" aria-label="Adjacent sessions">${index > 0 ? `<a href="#lesson/${lessons[index - 1].id}"><small>← PREVIOUS SESSION</small>${escape(lessons[index - 1].title)}</a>` : ''}${index < lessons.length - 1 ? `<a href="#lesson/${lessons[index + 1].id}"><small>NEXT SESSION →</small>${escape(lessons[index + 1].title)}</a>` : '<a href="#home"><small>BACK TO YOUR DESK →</small>Reflect on your portfolio</a>'}</nav></article>
    <aside class="lesson-toc" aria-label="On this page"><p>IN THIS SESSION</p>${lesson.sections.map(block => `<a href="#lesson/${lesson.id}/${block.id}">${escape(block.title)}</a>`).join('')}<a href="#lesson/${lesson.id}/repo">Project connections</a><a href="#lesson/${lesson.id}/quiz">Knowledge check</a><a href="#lesson/${lesson.id}/exercise">Practice & worked answer</a><a href="#lesson/${lesson.id}/review">Reflection</a><a href="#lesson/${lesson.id}/notes">Your notes</a><a href="#lesson/${lesson.id}/sources">Official references</a><a href="#lesson/${lesson.id}/interview">Interview rehearsal & recap</a></aside></div>`;
    enhanceContent();
    if (section) {
      const id = lesson.sections.some(block => block.id === section) ? `s-${lesson.id}-${section}` : `${section}-${lesson.id}`;
      requestAnimationFrame(() => document.getElementById(id)?.scrollIntoView());
    }
  }
  function enhanceContent() {
    main.querySelectorAll('.prose pre').forEach(pre => {
      const code = pre.querySelector('code');
      if (!code) return;
      const language = (code.className.match(/language-([\w-]+)/) || [])[1] || 'example';
      const caption = document.createElement('span');
      caption.className = 'code-caption'; caption.textContent = language;
      const copy = document.createElement('button');
      copy.className = 'copy-code'; copy.textContent = 'Copy'; copy.type = 'button';
      copy.addEventListener('click', () => copyText(code.textContent, copy));
      pre.append(caption, copy);
    });
    main.querySelectorAll('.prose table').forEach(table => {
      const wrapper = document.createElement('div'); wrapper.className = 'table-wrap';
      table.before(wrapper); wrapper.append(table);
    });
    main.querySelectorAll('.prose a[href^="http"]').forEach(link => { link.target = '_blank'; link.rel = 'noopener'; });
  }
  async function copyText(text, button) {
    try {
      if (navigator.clipboard?.writeText) await navigator.clipboard.writeText(text);
      else {
        const temp = document.createElement('textarea'); temp.value = text; document.body.append(temp); temp.select();
        const copied = document.execCommand('copy'); temp.remove(); if (!copied) throw new Error('Copy unavailable');
      }
      button.textContent = 'Copied'; setTimeout(() => button.textContent = 'Copy', 1800);
    } catch { toast('Select the code and copy it with your keyboard.'); }
  }
  function renderPlan() {
    document.querySelector('#breadcrumbs').textContent = 'Your daily rhythm';
    const next = continueLesson();
    main.innerHTML = `${storageWarning()}<div class="page-title"><p class="eyebrow">SMALL SESSIONS. LASTING UNDERSTANDING.</p><h1>A rhythm you can sustain.</h1><p>Use learning sessions rather than calendar deadlines. Missed days add no catch-up debt. Start where you last left off, and spend extra time on ideas that change your assumptions.</p></div><div class="plan-grid">${[{min:5,title:'Recall',text:'Explain one idea from yesterday without looking.'},{min:10,title:'Understand',text:'Read the reasoning and compare it with Android.'},{min:10,title:'Trace',text:'Follow the idea into a real repository file.'},{min:15,title:'Practice',text:'Attempt the exercise before revealing its answer.'},{min:5,title:'Reflect',text:'Answer the quiz, add a note, explain a tradeoff.'}].map(step => `<div class="plan-step"><strong>${step.min}<small>MIN</small></strong><h3>${step.title}</h3><p>${step.text}</p></div>`).join('')}</div>
    <aside class="mentor-note"><div class="mark" aria-hidden="true">↗</div><div><h3>A session is a topic, not a one-day deadline.</h3><p>Detailed session estimates include explanation, tracing, and practice. Keep a 45-minute daily habit and split longer lessons across several days. On a reading day, use the practice block to predict the example; on the next day, implement it. There are ${lessons.filter(item => item.track !== 'Deep dive').length} core sessions and ${lessons.filter(item => item.track === 'Deep dive').length} deep dives, followed by repeated delivery and mentorship—not a calendar deadline or guaranteed staff title.</p></div></aside>
    <section class="continue-card" style="margin-top:24px"><div><p class="eyebrow">CONTINUE WHEN YOU ARE READY</p><h2>Session ${next.id}: ${escape(next.title)}</h2><p>Your existing mentor log had sessions 001–004 delivered, with exercises still pending. Nothing was marked complete automatically.</p></div><a class="button" href="#lesson/${next.id}">Start reading ↗</a></section>
    <div class="section-heading"><div><h2>Your next seven sessions</h2><p>Reading ahead is welcome. Demonstrate understanding before treating a skill as mastered.</p></div></div><div class="reading-route">${lessons.slice(Math.max(0, lessons.indexOf(next)), Math.max(0, lessons.indexOf(next)) + 7).map(lesson => `<div class="route-row"><span>SESSION ${lesson.id}</span><a href="#lesson/${lesson.id}">${escape(lesson.title)}</a><span>${lesson.duration} min</span></div>`).join('')}</div>
    <div class="unit-grid"><article class="unit-card"><h3>Spaced recall</h3><p>After roughly one, three, and seven completed sessions, recall a previous concept. Trace ownership again after ARC. Revisit cancellation after actor isolation. Rebuild a small model without consulting the answer.</p></article><article class="unit-card"><h3>Evidence over attendance</h3><p>Keep a test, explanation, measured investigation, or design decision from each chapter. Build a portfolio of independent contributions. A reviewed checkbox describes your own learning, not a staff title or mentor approval.</p></article></div>
    <aside class="mentor-note"><div class="mark" aria-hidden="true">↗</div><div><h3>Daily delivery and this reader are separate.</h3><p>This website provides your local learning plan. The recurring automation is still unactivated because its controls were unavailable in the earlier sessions. This page does not schedule reminders or synchronize with the Markdown mentor log.</p></div></aside>`;
  }
  function renderEssentials(id, section) {
    document.querySelector('#breadcrumbs').textContent = 'Swift details / Supplementary reference';
    const guides = course.essentials || [];
    const guide = guides.find(item => item.id === id);
    if (!id) {
      main.innerHTML = `${storageWarning()}<div class="page-title"><p class="eyebrow">THE SMALL DISTINCTIONS THAT CHANGE A CONTRACT.</p><h1>Swift, in finer detail.</h1><p>Use these supplements alongside the numbered lessons. Initialization, generic types and callback lifetimes deserve more than a Kotlin-to-Swift keyword substitution. These references do not add completed sessions or alter your existing progress.</p></div><div class="unit-grid">${guides.map(item => `<article class="unit-card"><h2>${escape(item.title)}</h2><p>${escape(item.summary)}</p><a href="#essentials/${item.id}">Read the detailed guide →</a></article>`).join('')}</div>`;
      return;
    }
    if (!guide) { main.innerHTML = '<div class="empty-state"><h1>Guide not found.</h1><a href="#essentials">Return to Swift details</a></div>'; return; }
    main.innerHTML = `${storageWarning()}<div class="lesson-title"><p class="eyebrow">SUPPLEMENTARY SWIFT REFERENCE</p><h1>${escape(guide.title)}</h1><p>${escape(guide.summary)}</p><p class="note-status">Read alongside ${guide.sessions.map(value => `<a href="#lesson/${value}">session ${value}</a>`).join(', ')}. Save your reasoning in a related session's notes; this guide has no separate completion checkbox.</p></div><div class="lesson-layout"><article class="lesson-article">${guide.sections.map(block => `<section class="lesson-section" id="g-${guide.id}-${block.id}"><h2>${escape(block.title)}</h2><div class="prose">${block.html}</div></section>`).join('')}<section class="lesson-section" id="g-${guide.id}-exercise"><h2>Practice the distinction</h2><div class="exercise-card"><p>${escape(guide.exercise.brief)}</p><h3>Your task</h3><ol>${guide.exercise.steps.map(step => `<li>${escape(step)}</li>`).join('')}</ol><h3>Acceptance evidence</h3><ul>${guide.exercise.acceptance.map(item => `<li>${escape(item)}</li>`).join('')}</ul><details class="solution"><summary>Worked solution & mentor commentary</summary><div class="prose">${guide.exercise.solution}</div></details></div></section><section class="lesson-section" id="g-${guide.id}-sources"><h2>Official references</h2><div class="reference-links">${guide.references.map(reference => `<a href="${escape(reference.url)}" target="_blank" rel="noopener">${escape(reference.label)} ↗</a>`).join('')}</div><p class="note-status">Online references need a connection. Standalone and framework-specific example requirements are identified in the text.</p></section><p><a href="#essentials">← All Swift details</a></p></article><aside class="lesson-toc" aria-label="On this guide"><p>IN THIS GUIDE</p>${guide.sections.map(block => `<a href="#essentials/${guide.id}/${block.id}">${escape(block.title)}</a>`).join('')}<a href="#essentials/${guide.id}/exercise">Practice & worked answer</a><a href="#essentials/${guide.id}/sources">Official references</a></aside></div>`;
    enhanceContent();
    if (section) requestAnimationFrame(() => document.getElementById(`g-${guide.id}-${section}`)?.scrollIntoView());
  }
  let referenceCategory = 'All';
  let coverageQuery = '';
  let coverageLevel = 'all';
  let libraryQuery = '';
  let libraryFilter = 'all';
  const coverageLabels = { explained: 'Explained', practice: 'Explanation + practice', 'further-study': 'Further study' };
  function renderCoverage(groupId) {
    document.querySelector('#breadcrumbs').textContent = 'Curriculum coverage audit';
    const audit = course.coverage;
    if (!audit) { main.innerHTML = '<div class="empty-state"><h1>Coverage audit is being expanded.</h1><p>Reload after building the updated course bundle.</p></div>'; return; }
    const topics = audit.groups.flatMap(group => group.topics);
    main.innerHTML = `${storageWarning()}<div class="page-title"><p class="eyebrow">BREADTH YOU CAN INSPECT. DEPTH YOU CAN PRACTICE.</p><h1>The platform, mapped.</h1><p>${escape(audit.scope)}</p><p class="note-status">Audited ${escape(audit.auditedAt)} · ${topics.length} topics · ${topics.filter(topic => topic.level === 'further-study').length} specialist branches. These labels describe teaching material, not your personal mastery.</p></div>
    <div class="coverage-legend"><p><strong>Explained:</strong> taught, but the named topic has no dedicated task.</p><p><strong>Explanation + practice:</strong> a guided exercise or lab is provided; execution and mentor acceptance remain yours.</p><p><strong>Further study:</strong> not fully taught here. A specialist extension is needed before claiming competence.</p></div>
    <div class="filter-toolbar"><label class="sr-only" for="coverage-query">Search the coverage map</label><input id="coverage-query" type="search" value="${escape(coverageQuery)}" placeholder="Find launch, variants, UIKit, library, camera…">${[['all','All topics'],['practice','With practice'],['explained','Explanation'],['further-study','Further study']].map(([level,label]) => `<button class="chip ${coverageLevel === level ? 'active' : ''}" data-coverage-level="${level}" aria-pressed="${coverageLevel === level}">${label}</button>`).join('')}</div>
    <nav class="coverage-nav" aria-label="Coverage areas">${audit.groups.map(group => `<a href="#coverage/${group.id}">${escape(group.title)}</a>`).join('')}</nav><p id="coverage-count" class="note-status"></p><div id="coverage-groups"></div>
    <aside class="mentor-note"><div class="mark" aria-hidden="true">↗</div><div><h3>What this audit cannot promise</h3><ul>${audit.limitations.map(item => `<li>${escape(item)}</li>`).join('')}</ul></div></aside>`;
    filterCoverage();
    if (groupId) requestAnimationFrame(() => document.getElementById(`coverage-${groupId}`)?.scrollIntoView());
  }
  function filterCoverage() {
    const words = coverageQuery.toLowerCase().trim().split(/\s+/).filter(Boolean);
    let count = 0;
    const groups = course.coverage.groups.map(group => {
      const topics = group.topics.filter(topic => (coverageLevel === 'all' || topic.level === coverageLevel) && words.every(word => `${group.title} ${topic.title} ${topic.detail} ${topic.evidence}`.toLowerCase().includes(word)));
      count += topics.length;
      if (!topics.length) return '';
      return `<section class="coverage-group" id="coverage-${group.id}"><h2>${escape(group.title)}</h2><p>${escape(group.summary)}</p><div class="table-wrap"><table class="reference-table coverage-table"><caption class="sr-only">${escape(group.title)} topic depth and practice evidence</caption><thead><tr><th scope="col">Topic & boundaries</th><th scope="col">Depth</th><th scope="col">Study here</th><th scope="col">Evidence to produce</th></tr></thead><tbody>${topics.map(topic => `<tr><td><strong>${escape(topic.title)}</strong><p>${escape(topic.detail)}</p></td><td><span class="coverage-badge ${topic.level}">${coverageLabels[topic.level]}</span></td><td>${topic.sessions.length ? topic.sessions.map(id => `<a href="#lesson/${id}">Session ${id}</a>`).join('<br>') : 'Separate learning branch'}${(topic.guides || []).map(id => `<p><a href="#essentials/${id}">Swift detail guide →</a></p>`).join('')}</td><td>${escape(topic.evidence)}</td></tr>`).join('')}</tbody></table></div></section>`;
    }).join('');
    document.querySelector('#coverage-count').textContent = `${count} matching topic${count === 1 ? '' : 's'}`;
    document.querySelector('#coverage-groups').innerHTML = groups || '<div class="empty-state"><h2>No matching topic.</h2><p>Try a broader term or choose All topics.</p></div>';
  }
  function renderLibraries(id) {
    document.querySelector('#breadcrumbs').textContent = 'Libraries and resolved dependency graphs';
    const catalogue = course.catalogue;
    if (!catalogue) { main.innerHTML = '<div class="empty-state"><h1>Dependency catalogue is being built.</h1><p>Reload after rebuilding the course.</p></div>'; return; }
    main.innerHTML = `${storageWarning()}<div class="page-title"><p class="eyebrow">KNOW WHAT IS IN THE GRAPH. ASK WHAT OWNS IT.</p><h1>Libraries, without guesswork.</h1><p>${escape(catalogue.scope)}</p><p class="note-status">${catalogue.packages.length} remote entries · ${catalogue.packages.filter(item => item.requirement).length} direct Tuist declarations · snapshot ${escape(catalogue.auditedAt)}. Pins describe this checkout, not the latest versions or an upgrade recommendation.</p></div>
    <aside class="mentor-note"><div class="mark" aria-hidden="true">↗</div><div><h3>A pin is evidence of resolution, not runtime use.</h3><p>Direct means declared in the top-level Tuist manifest. A row without that declaration may be transitive, tooling-related, required elsewhere, or legacy-only. A package's purpose is not proof that every product is linked or every feature invokes it. Follow <a href="#lesson/044">session 044</a> for package/linkage contracts and <a href="#lesson/045">session 045</a> for the active landscape.</p></div></aside>
    <div class="filter-toolbar"><label class="sr-only" for="library-query">Search dependency inventory</label><input id="library-query" type="search" value="${escape(libraryQuery)}" placeholder="Find Alamofire, image, GraphQL, reactive, testing…">${[['all','All pins'],['direct','Direct Tuist'],['different','Graph differences']].map(([value,label]) => `<button class="chip ${libraryFilter === value ? 'active' : ''}" data-library-filter="${value}">${label}</button>`).join('')}</div><p id="library-count" class="note-status"></p><div id="library-table"></div>
    <section class="lesson-section"><h2>What to inspect before changing a library</h2><ol class="library-checks"><li>Find the product and importing target—not only the package name.</li><li>Identify its owner, callbacks, data handling and stopping conditions.</li><li>Read minimum OS, Swift/compiler, architecture and binary-linkage requirements.</li><li>Inspect behavior tests, privacy resources, licenses and transitive changes.</li><li>Use a bounded upgrade/migration plan with explicit compatibility and recovery evidence.</li></ol><div class="reference-links">${catalogue.sources.map(source => `<a href="${escape(sourceURL(source))}" target="_blank" rel="noopener">${escape(source.path)} ↗</a>`).join('')}</div></section>`;
    filterLibraries();
    if (id) requestAnimationFrame(() => document.getElementById(`lib-${id}`)?.scrollIntoView());
  }
  function graphDifference(item) {
    return item.graphs.length !== 2 || new Set(item.graphs.map(graph => `${graph.version || ''}|${graph.branch || ''}|${graph.revision}`)).size !== 1;
  }
  function filterLibraries() {
    const words = libraryQuery.toLowerCase().trim().split(/\s+/).filter(Boolean);
    const filtered = course.catalogue.packages.filter(item => (libraryFilter === 'all' || libraryFilter === 'direct' && item.requirement || libraryFilter === 'different' && graphDifference(item)) && words.every(word => `${item.id} ${item.category} ${item.purpose} ${item.graphs.map(graph => `${graph.name} ${graph.version || graph.branch || ''}`).join(' ')}`.toLowerCase().includes(word)));
    document.querySelector('#library-count').textContent = `${filtered.length} matching remote entr${filtered.length === 1 ? 'y' : 'ies'}`;
    document.querySelector('#library-table').innerHTML = filtered.length ? `<div class="table-wrap"><table class="reference-table coverage-table"><caption class="sr-only">Remote dependency purposes, requirements and graph pins</caption><thead><tr><th scope="col">Package and purpose</th><th scope="col">Top-level Tuist requirement</th><th scope="col">Resolved graph evidence</th></tr></thead><tbody>${filtered.map(item => `<tr id="lib-${item.id}"><td><a href="${escape(item.url)}" target="_blank" rel="noopener"><strong>${escape(item.id)} ↗</strong></a><p>${escape(item.category)} · ${escape(item.purpose)}</p></td><td>${item.requirement ? `<a href="${escape(sourceURL(item.requirement))}" target="_blank" rel="noopener">${escape(item.requirement.kind)} ${escape(item.requirement.value)}</a>` : 'No direct top-level declaration'}${graphDifference(item) ? '<p>Graph presence or pin differs; investigate before changing.</p>' : ''}</td><td>${item.graphs.map(graph => `<p><a href="${escape(sourceURL(graph))}" target="_blank" rel="noopener"><strong>${escape(graph.name)}</strong>: ${escape(graph.version || (graph.branch ? `branch ${graph.branch}` : 'revision'))}</a><br><code>${escape(graph.revision.slice(0,12))}</code></p>`).join('')}</td></tr>`).join('')}</tbody></table></div>` : '<div class="empty-state"><h2>No matching dependency.</h2><p>Try a broader term. System frameworks and local/vendor dependencies are explained in the lessons rather than represented as remote pins here.</p></div>';
  }
  let referenceQuery = '';
  function renderReference() {
    document.querySelector('#breadcrumbs').textContent = 'Reference library';
    const categories = ['All', ...new Set(course.reference.map(item => item.category))];
    main.innerHTML = `${storageWarning()}<div class="page-title"><p class="eyebrow">FAMILIAR IDEAS. IMPORTANT DIFFERENCES.</p><h1>Your cross-platform field guide.</h1><p>Quick comparisons for the moment you think, “What is the iOS equivalent?” Each entry names the boundary of the analogy and points you to a deeper lesson.</p></div><div class="filter-toolbar"><label class="sr-only" for="reference-query">Filter reference entries</label><input id="reference-query" type="search" placeholder="Find an Android or iOS concept…" value="${escape(referenceQuery)}">${categories.map(category => `<button class="chip ${category === referenceCategory ? 'active' : ''}" data-category="${escape(category)}">${escape(category)}</button>`).join('')}</div><div id="reference-count" class="note-status"></div><div class="reference-grid" id="reference-grid"></div>
    <section class="lesson-section" style="margin-top:40px"><h2>Syntax, side by side</h2><div class="table-wrap syntax-table"><table class="reference-table"><thead><tr><th>Idea</th><th>Kotlin / Java</th><th>Swift</th></tr></thead><tbody>${course.syntax.map(row => `<tr><td>${escape(row.idea)}</td><td><code>${escape(row.android)}</code></td><td><code>${escape(row.swift)}</code></td></tr>`).join('')}</tbody></table></div></section>`;
    filterReferences();
  }
  function filterReferences() {
    const filtered = course.reference.filter(item => (referenceCategory === 'All' || item.category === referenceCategory) && `${item.android} ${item.ios} ${item.explanation} ${item.boundary}`.toLowerCase().includes(referenceQuery.toLowerCase()));
    document.querySelector('#reference-count').textContent = `${filtered.length} comparison${filtered.length === 1 ? '' : 's'}`;
    document.querySelector('#reference-grid').innerHTML = filtered.length ? filtered.map(item => `<article class="reference-card" id="ref-${item.id}"><p class="eyebrow">${escape(item.category)} · ANDROID → iOS</p><h2>${escape(item.android)}</h2><p class="equivalent">${escape(item.ios)}</p><p>${escape(item.explanation)}</p><p class="boundary"><strong>Where the analogy breaks:</strong> ${escape(item.boundary)}</p><a href="#lesson/${item.lesson}">Explore in session ${item.lesson} →</a></article>`).join('') : '<div class="empty-state"><h2>No exact match yet.</h2><p>Try a broader term such as state, task, or storage. The course search also looks inside every explanation.</p></div>';
  }
  function renderNotes() {
    document.querySelector('#breadcrumbs').textContent = 'Notes & bookmarks';
    const bookmarks = lessons.filter(lesson => state.lessons[lesson.id]?.bookmark);
    const notes = lessons.filter(lesson => state.lessons[lesson.id]?.notes?.trim());
    main.innerHTML = `${storageWarning()}<div class="page-title"><p class="eyebrow">MAKE THIS LIBRARY YOUR OWN.</p><h1>Thoughts worth keeping.</h1><p>Capture questions, examples, and decisions in any session. Notes and progress stay in this browser. Export them before switching browsers, changing the local address, or clearing website data.</p></div>
    <div class="section-heading"><h2>Bookmarked sessions</h2><span class="small-label">${bookmarks.length} saved</span></div>${bookmarks.length ? `<div class="reading-route">${bookmarks.map(lesson => `<div class="route-row"><span>SESSION ${lesson.id}</span><a href="#lesson/${lesson.id}">${escape(lesson.title)}</a><span>★</span></div>`).join('')}</div>` : '<div class="empty-state"><h2>A reference shelf, chosen by you.</h2><p>Bookmark a session to find it quickly here.</p></div>'}
    <div class="section-heading" style="margin-top:32px"><h2>Your session notes</h2><span class="small-label">${notes.length} entries</span></div>${notes.length ? notes.map(lesson => `<article class="note-card"><h2>${lesson.id} · ${escape(lesson.title)}</h2><p>${escape(state.lessons[lesson.id].notes)}</p><a href="#lesson/${lesson.id}/notes">Continue your notes →</a></article>`).join('') : '<div class="empty-state"><h2>Leave a trail of understanding.</h2><p>Try writing the ownership graph, a cancellation question, or the reason behind a design choice.</p></div>'}
    <section class="backup-panel" aria-label="Portable progress"><button class="button" data-export>Export notes & progress</button><button class="button secondary" data-import>Import a backup</button><p>Imports merge notes and reviewed sessions into this browser; they do not erase other sessions. Only known lesson IDs and plain-text notes are accepted. Markdown mentor progress is kept separately.</p></section>`;
  }
  function exportState() {
    const blob = new Blob([JSON.stringify({ ...state, interviews: interviews.exportData(), exportedAt: new Date().toISOString() }, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a'); link.href = url; link.download = 'across-the-stack-progress.json'; document.body.append(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    toast('Your progress backup is ready.');
  }
  async function importState(file) {
    if (!file) return;
    try {
      const maxBytes = backupLimit(lessons) + interviews.allowance();
      if (file.size > maxBytes) throw new Error(`Choose a backup smaller than ${Math.ceil(maxBytes / 1000000)} MB.`);
      const raw = JSON.parse(await file.text());
      const nextLessons = mergeState(state, raw, lessons);
      const nextInterviews = interviews.prepareImport(raw.interviews);
      state = nextLessons;
      interviews.commit(nextInterviews);
      save(); render(); toast('Backup merged. Lesson work and interview history were preserved.');
    } catch (error) { toast(error.message || 'Could not read that backup.'); }
  }
  function plain(html) { const temp = document.createElement('div'); temp.innerHTML = html; return temp.textContent || ''; }
  const searchIndex = lessons.map(lesson => ({ kind: 'Session', id: lesson.id, title: lesson.title, summary: lesson.summary, href: `#lesson/${lesson.id}`, text: `${lesson.id} ${lesson.title} ${lesson.summary} ${lesson.objectives.join(' ')} ${lesson.sections.map(block => `${block.title} ${plain(block.html)}`).join(' ')} ${lesson.exercise.brief} ${plain(lesson.exercise.solution)}` })).concat(course.reference.map(item => ({ kind: 'Reference', id: item.id, title: `${item.android} → ${item.ios}`, summary: item.explanation, href: `#reference/${item.id}`, text: `${item.android} ${item.ios} ${item.explanation} ${item.boundary}` })));
  searchIndex.push(...(course.catalogue?.packages || []).map(item => ({ kind: 'Library', id: item.id, title: item.id, summary: item.purpose, href: `#libraries/${item.id}`, text: `${item.id} ${item.category} ${item.purpose}` })));
  searchIndex.push(...(course.essentials || []).map(item => ({ kind: 'Swift detail', id: item.id, title: item.title, summary: item.summary, href: `#essentials/${item.id}`, text: `${item.title} ${item.summary} ${item.sections.map(block => `${block.title} ${plain(block.html)}`).join(' ')} ${item.exercise.brief} ${plain(item.exercise.solution)}` })));
  searchIndex.push(...interviews.searchEntries);
  function search(query) {
    const words = query.toLowerCase().trim().split(/\s+/).filter(Boolean);
    const results = !words.length ? searchIndex.filter(item => item.kind === 'Session').slice(0, 5) : searchIndex.filter(item => words.every(word => item.text.toLowerCase().includes(word))).sort((a, b) => Number(words.every(word => b.title.toLowerCase().includes(word))) - Number(words.every(word => a.title.toLowerCase().includes(word)))).slice(0, 18);
    document.querySelector('#search-results').innerHTML = results.length ? results.map(item => {
      let snippet = item.summary;
      if (words.length && !words.every(word => `${item.title} ${item.summary}`.toLowerCase().includes(word))) {
        const start = Math.max(0, item.text.toLowerCase().indexOf(words[0]) - 60);
        snippet = `${start ? '…' : ''}${item.text.slice(start, start + 200)}…`;
      }
      return `<a class="search-result" href="${escape(item.href)}"><small>${escape(item.kind.toUpperCase())}${item.kind === 'Session' ? ` ${item.id}` : ''}</small><strong>${escape(item.title)}</strong><p>${escape(snippet)}</p></a>`;
    }).join('') : '<div class="empty-state"><h2>No results.</h2><p>Try a single concept or its Android name.</p></div>';
  }
  const dialog = document.querySelector('#search-dialog');
  const mobileNavigation = window.matchMedia('(max-width: 850px)');
  function openSearch() { if (!dialog.open) dialog.showModal(); search(document.querySelector('#search-input').value); document.querySelector('#search-input').focus(); }
  function closeMenu() {
    const sidebar = document.querySelector('#sidebar');
    if (mobileNavigation.matches && document.activeElement && sidebar.contains(document.activeElement)) document.querySelector('#menu-button').focus();
    sidebar.classList.remove('open'); sidebar.inert = mobileNavigation.matches;
    document.querySelector('#mobile-scrim').hidden = true;
    document.querySelector('#menu-button').setAttribute('aria-expanded', 'false');
  }
  mobileNavigation.addEventListener('change', closeMenu);
  let lastRouteLesson = null;
  function render() {
    const [page = 'home', id, section] = location.hash.slice(1).split('/');
    const sameLessonSection = page === 'lesson' && lastRouteLesson === id && section;
    if (page === 'lesson' && byId.has(id)) { renderLesson(byId.get(id), section); lastRouteLesson = id; }
    else if (page === 'reference') {
      if (id) { referenceCategory = 'All'; referenceQuery = ''; }
      renderReference(); lastRouteLesson = null;
      if (id) requestAnimationFrame(() => document.getElementById(`ref-${id}`)?.scrollIntoView());
    } else if (page === 'coverage') { if (id) { coverageQuery = ''; coverageLevel = 'all'; } renderCoverage(id); lastRouteLesson = null; }
    else if (page === 'essentials') { renderEssentials(id, section); lastRouteLesson = null; }
    else if (page === 'libraries') { if (id) { libraryQuery = ''; libraryFilter = 'all'; } renderLibraries(id); lastRouteLesson = null; }
    else if (page === 'interviews') { interviews.render(id, section); enhanceContent(); lastRouteLesson = null; }
    else if (page === 'notes') { renderNotes(); lastRouteLesson = null; }
    else if (page === 'plan') { renderPlan(); lastRouteLesson = null; }
    else if (page === 'lesson') { main.innerHTML = '<div class="empty-state"><h1>Session not found.</h1><p><a href="#home">Return to the course</a>.</p></div>'; lastRouteLesson = null; }
    else { renderHome(); lastRouteLesson = null; }
    renderSidebar(); closeMenu();
    const sectionAnchor = (page === 'lesson' || page === 'essentials') && section;
    if (!sectionAnchor && !sameLessonSection) { window.scrollTo(0, 0); main.focus({ preventScroll: true }); }
    const title = page === 'lesson' && byId.has(id) ? byId.get(id).title : page === 'essentials' && id ? course.essentials?.find(item => item.id === id)?.title || 'Swift details' : ({home:'Learning desk',plan:'Your daily rhythm',reference:'Reference library',essentials:'Swift details',coverage:'Curriculum coverage',libraries:'Libraries and pins',interviews:'Interview practice & ledger',notes:'Notes & bookmarks'}[page] || 'Learning desk');
    document.title = `${title} · Across the Stack`;
  }
  document.addEventListener('click', event => {
    const button = event.target.closest('button');
    if (!button) return;
    if (button.matches('[data-bookmark]')) { const item = entry(button.dataset.bookmark); item.bookmark = !item.bookmark; save(); button.setAttribute('aria-pressed', item.bookmark); button.textContent = item.bookmark ? '★ Bookmarked' : '☆ Bookmark'; toast(item.bookmark ? 'Added to your reference shelf.' : 'Bookmark removed.'); }
    if (button.matches('[data-print]')) { main.querySelectorAll('details.solution').forEach(item => item.open = true); window.print(); }
    if (button.matches('[data-export]')) exportState();
    if (button.matches('[data-import]')) document.querySelector('#import-file').click();
    if (button.matches('[data-category]')) { referenceCategory = button.dataset.category; main.querySelectorAll('[data-category]').forEach(chip => chip.classList.toggle('active', chip === button)); filterReferences(); }
    if (button.matches('[data-coverage-level]')) { coverageLevel = button.dataset.coverageLevel; main.querySelectorAll('[data-coverage-level]').forEach(chip => { const active = chip === button; chip.classList.toggle('active', active); chip.setAttribute('aria-pressed', active); }); filterCoverage(); }
    if (button.matches('[data-library-filter]')) { libraryFilter = button.dataset.libraryFilter; main.querySelectorAll('[data-library-filter]').forEach(chip => chip.classList.toggle('active', chip === button)); filterLibraries(); }
    if (button.matches('[data-reviewed]')) {
      const lesson = byId.get(button.dataset.reviewed); const item = entry(lesson.id);
      if (item.reviewed) item.reviewed = false;
      else if (!ready(lesson, item)) { toast('Complete the quiz, reflection checklist, and exercise before marking reviewed.'); return; }
      else item.reviewed = true;
      save(); renderSidebar(); button.textContent = item.reviewed ? '✓ Reviewed · undo' : 'Mark session reviewed'; toast(item.reviewed ? 'Session self-reviewed. Keep your exercise evidence.' : 'Session review undone.');
    }
  });
  document.addEventListener('submit', event => {
    const form = event.target.closest('[data-quiz]');
    if (!form) return;
    event.preventDefault();
    const index = Number(form.dataset.quiz); const lesson = byId.get(form.dataset.lesson); const selected = form.querySelector('input:checked'); if (!selected) return;
    const answer = Number(selected.value); const item = entry(lesson.id); item.quizzes[index] = answer; if (answer !== lesson.quiz[index].answer) item.reviewed = false;
    save(); renderSidebar(); const feedback = form.querySelector('.quiz-feedback'); const correct = answer === lesson.quiz[index].answer;
    feedback.hidden = false; feedback.classList.toggle('incorrect', !correct); feedback.textContent = `${correct ? 'Correct. ' : 'Revisit this idea. '}${lesson.quiz[index].explanation}`;
    const reviewed = main.querySelector('[data-reviewed]'); if (reviewed) reviewed.textContent = item.reviewed ? '✓ Reviewed · undo' : 'Mark session reviewed';
  });
  document.addEventListener('change', event => {
    const target = event.target;
    if (target.matches('[data-check]')) { const item = entry(target.dataset.lesson); const index = Number(target.dataset.check); item.checks = target.checked ? [...new Set([...item.checks, index])] : item.checks.filter(x => x !== index); if (!target.checked) item.reviewed = false; save(); renderSidebar(); }
    if (target.matches('[data-exercise-done]')) { const item = entry(target.dataset.exerciseDone); item.exerciseDone = target.checked; if (!target.checked) item.reviewed = false; save(); renderSidebar(); }
    if (target.matches('[data-check], [data-exercise-done]')) { const id = target.dataset.lesson || target.dataset.exerciseDone; const reviewed = main.querySelector('[data-reviewed]'); if (reviewed) reviewed.textContent = entry(id).reviewed ? '✓ Reviewed · undo' : 'Mark session reviewed'; }
  });
  document.addEventListener('input', event => {
    if (event.target.matches('[data-note]')) { entry(event.target.dataset.note).notes = event.target.value.slice(0, 100000); save(); const status = document.querySelector('#note-status'); status.textContent = storageAvailable ? 'Saved in this browser. Export a backup for a portable copy.' : 'Not saved to browser storage. Export a backup before closing.'; }
    if (event.target.id === 'reference-query') { referenceQuery = event.target.value; filterReferences(); }
    if (event.target.id === 'coverage-query') { coverageQuery = event.target.value; filterCoverage(); }
    if (event.target.id === 'library-query') { libraryQuery = event.target.value; filterLibraries(); }
  });
  document.querySelector('#search-trigger').addEventListener('click', openSearch);
  document.querySelector('#top-search').addEventListener('click', openSearch);
  document.querySelector('#close-search').addEventListener('click', () => dialog.close());
  document.querySelector('#search-input').addEventListener('input', event => search(event.target.value));
  document.querySelector('#search-results').addEventListener('click', event => { if (event.target.closest('a')) dialog.close(); });
  dialog.addEventListener('click', event => { if (event.target === dialog) { const box = dialog.getBoundingClientRect(); if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) dialog.close(); } });
  document.querySelector('#theme-toggle').addEventListener('click', () => { state.theme = state.theme === 'dark' ? 'light' : 'dark'; save(); applyTheme(); });
  document.querySelector('#menu-button').addEventListener('click', () => {
    const sidebar = document.querySelector('#sidebar');
    const open = sidebar.classList.toggle('open'); sidebar.inert = mobileNavigation.matches && !open;
    document.querySelector('#mobile-scrim').hidden = !open;
    document.querySelector('#menu-button').setAttribute('aria-expanded', open);
    if (open) sidebar.querySelector('a')?.focus();
  });
  document.querySelector('#mobile-scrim').addEventListener('click', closeMenu);
  document.querySelector('#export-footer').addEventListener('click', exportState);
  document.querySelector('#import-file').addEventListener('change', event => { importState(event.target.files[0]); event.target.value = ''; });
  document.addEventListener('keydown', event => { if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') { event.preventDefault(); openSearch(); } if (event.key === 'Escape') closeMenu(); });
  window.addEventListener('hashchange', render);
  applyTheme(); render();
})();
