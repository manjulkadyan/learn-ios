/* Interview bank, history ledger and mixed quizzes; no network or automatic essay grading. */
(() => {
  'use strict';
  function create({ course, escape: esc, toast, rerender }) {
    const model = window.IOSInterviewState;
    const questions = course.interview?.questions || [];
    const byId = new Map(questions.map(question => [question.id, question]));
    const lessons = course.lessons;
    const lessonById = new Map(lessons.map(lesson => [lesson.id, lesson]));
    const quizIndex = model.quizIndex(lessons);
    const main = document.querySelector('#main');
    const storageKey = 'across-the-stack.interviews.v1';
    let state = model.empty();
    let storageAvailable = true;
    let query = '', area = 'all', level = 'all', selectedStatus = 'all';
    let quizScope = 'all', quizCount = 20;
    let sequence = 0;
    const uid = prefix => `${prefix}-${Date.now().toString(36)}-${(++sequence).toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
    const today = () => {
      const parts = Object.fromEntries(new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Calcutta', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date()).map(part => [part.type, part.value]));
      return `${parts.year}-${parts.month}-${parts.day}`;
    };
    const label = { unattempted: 'Unattempted', unscored: 'Unscored', review: 'Needs review', confident: 'Self-confident' };
    const warning = () => storageAvailable ? '' : '<p class="storage-warning">Interview history is not being saved in this browser. Export a backup before closing.</p>';
    try {
      const stored = localStorage.getItem(storageKey);
      if (stored) state = model.normalize(JSON.parse(stored), questions, lessons);
    } catch { storageAvailable = false; }
    function save() {
      try { localStorage.setItem(storageKey, JSON.stringify(state)); }
      catch { storageAvailable = false; toast('Interview storage is unavailable. Export a backup to preserve the current ledger.'); }
    }
    function entry(id) { return state.questions[id] ||= model.blank(); }
    const options = (items, selected) => items.map(([value, text]) => `<option value="${esc(value)}" ${value === selected ? 'selected' : ''}>${esc(text)}</option>`).join('');
    const related = question => `<a href="#lesson/${question.lesson}">Session ${question.lesson}: ${esc(lessonById.get(question.lesson).title)}</a>`;
    const scoring = '<ol start="0"><li><strong>0 — Not yet:</strong> cannot explain the mechanism.</li><li><strong>1 — Vocabulary:</strong> names terms but misses the causal rule.</li><li><strong>2 — Partial:</strong> explains some behavior, with important gaps.</li><li><strong>3 — Sound:</strong> explains the mechanism and a relevant failure case.</li><li><strong>4 — Defensible:</strong> adds alternatives, tradeoffs and a credible verification plan.</li></ol><p>Scores are your self-assessment, not automatic essay grading, mentor acceptance or a staff qualification. Assess against the question-specific rubric, not answer length.</p>';
    function lessonHTML(id) {
      const items = questions.filter(question => question.lesson === id);
      if (!items.length) return '';
      return `<section class="lesson-section" id="interview-${id}"><h2>Interview rehearsal & final recap</h2><p>Explain the mechanism aloud, then defend a failure case. Draft your answer before revealing the rubric.</p><div class="interview-cards">${items.map(question => `<article class="exercise-card"><p class="eyebrow">${esc(question.level)} · ${esc(question.kind)} · ${question.minutes} MIN</p><h3>${esc(question.prompt)}</h3><p>${esc(question.scenario)}</p><a href="#interviews/${question.id}">Answer, inspect the rubric & record an attempt →</a></article>`).join('')}</div><p><a class="button secondary" href="#interviews/quiz/${id}">Take this lesson's recap quiz</a> <a href="#interviews">Open the full interview ledger →</a></p></section>`;
    }
    function renderLedger() {
      const attempts = Object.values(state.questions).reduce((sum, item) => sum + item.attempts.length, 0);
      const needsReview = questions.filter(question => model.status(state.questions[question.id]) === 'review').length;
      main.innerHTML = `${warning()}<div class="page-title"><p class="eyebrow">RETRIEVE. EXPLAIN. DEFEND. IMPROVE.</p><h1>Your interview ledger.</h1><p>${questions.length} original interview prompts, two per lesson, with Android-to-iOS comparisons, model answers, follow-ups and observable rubrics. Practice language fluency, debugging, implementation and staff-level judgment without turning reading into a qualification.</p></div><div class="stat-strip"><div class="stat-item"><strong>${questions.length}</strong><span>interview<br>prompts</span></div><div class="stat-item"><strong>${attempts}</strong><span>recorded<br>attempts</span></div><div class="stat-item"><strong>${needsReview}</strong><span>need<br>review</span></div><div class="stat-item"><strong>${state.quizzes.length}</strong><span>saved<br>quizzes</span></div></div><div class="row"><a class="button" href="#interviews/rounds">Mock interview rounds</a><a class="button secondary" href="#interviews/quiz">Mixed-topic final quiz</a><button class="button tertiary" data-export>Back up the ledger</button><button class="button tertiary" data-print>Print</button></div><div class="interview-filters"><label>Search prompts<input type="search" id="interview-query" value="${esc(query)}" placeholder="Try ARC, lifecycle, cache, variants…"></label><label>Chapter<select data-interview-filter="area">${options([['all','All chapters'], ...course.units.map(unit => [unit.id, unit.title])], area)}</select></label><label>Level<select data-interview-filter="level">${options([['all','All levels'],['Foundation','Foundation'],['Senior','Senior'],['Staff','Staff']], level)}</select></label><label>Practice state<select data-interview-filter="status">${options([['all','All questions'], ...Object.entries(label), ['due','Review date reached'],['bookmarked','Bookmarked']], selectedStatus)}</select></label></div><p id="interview-count" class="note-status" aria-live="polite"></p><div id="interview-table"></div><details class="exercise-card"><summary>How to score and maintain the ledger</summary>${scoring}<p>Attempt without hints; compare against the rubric; record a concrete next action and an optional review date. Dates are shown against Asia/Calcutta. Due dates are a manual queue, not scheduled notifications. A self-confident answer should still be tested under a changed scenario.</p><p>Answer drafts auto-save. Saved attempts are immutable history. At most 20 attempts per question and 30 finished quizzes are retained; new records are refused at the limit rather than deleting old evidence. Export before explicitly clearing history. Browser quotas can be smaller than these bounds.</p></details>${quizHistoryHTML()}`;
      filterLedger();
    }
    function filterLedger() {
      const words = query.toLowerCase().trim().split(/\s+/).filter(Boolean);
      const items = questions.filter(question => {
        const item = state.questions[question.id];
        const status = model.status(item);
        const reviewOn = item?.attempts.at(-1)?.reviewOn;
        return (area === 'all' || lessonById.get(question.lesson).unitId === area) && (level === 'all' || question.level === level) && (selectedStatus === 'all' || selectedStatus === status || selectedStatus === 'bookmarked' && item?.bookmark || selectedStatus === 'due' && reviewOn && reviewOn <= today()) && words.every(word => `${question.id} ${question.prompt} ${question.scenario} ${question.androidBridge} ${lessonById.get(question.lesson).title}`.toLowerCase().includes(word));
      });
      document.querySelector('#interview-count').textContent = `${items.length} matching questions`;
      document.querySelector('#interview-table').innerHTML = items.length ? `<div class="table-wrap"><table class="reference-table coverage-table"><caption class="sr-only">Interview prompts, latest self-assessment and review plan</caption><thead><tr><th scope="col">Prompt & lesson</th><th scope="col">Level / style</th><th scope="col">Latest assessment</th><th scope="col">Next practice</th></tr></thead><tbody>${items.map(question => {
        const item = state.questions[question.id];
        const latest = item?.attempts.at(-1);
        return `<tr><td><a href="#interviews/${question.id}"><strong>${esc(question.prompt)}</strong></a><p>${related(question)}</p></td><td>${esc(question.level)} · ${esc(question.kind)}<br>${question.minutes} min</td><td>${label[model.status(item)]}${latest?.score !== null && latest?.score !== undefined ? ` · ${latest.score}/4` : ''}<br>${item?.attempts.length || 0} attempts${item?.bookmark ? ' · ★' : ''}</td><td>${esc(latest?.reviewOn || 'No review date')}<p>${esc(latest?.nextAction || 'Record an attempt and name one improvement.')}</p></td></tr>`;
      }).join('')}</tbody></table></div>` : '<div class="empty-state"><h2>No matching question.</h2><p>Broaden your search or reset the filters.</p></div>';
    }
    function renderQuestion(question) {
      const item = entry(question.id), draft = item.draft;
      document.querySelector('#breadcrumbs').textContent = `Interview practice / Session ${question.lesson}`;
      main.innerHTML = `${warning()}<div class="lesson-title"><p class="eyebrow">${esc(question.level)} · ${esc(question.kind)} · ${question.minutes} MIN SUGGESTED</p><h1>${esc(question.prompt)}</h1><p>${esc(question.scenario)}</p><p>${related(question)}</p></div><div class="row"><a href="#interviews">← Interview ledger</a><button class="button tertiary" data-interview-action="bookmark" data-question="${question.id}" aria-pressed="${item.bookmark}">${item.bookmark ? '★ Bookmarked' : '☆ Bookmark'}</button><button class="button tertiary" data-print>Print</button></div><section class="lesson-section"><h2>Give your answer before reading ours</h2><form data-interview-attempt="${question.id}" class="interview-form"><label for="interview-response">Your explanation, pseudocode or code<textarea id="interview-response" class="note-area" data-interview-field="response" data-question="${question.id}" maxlength="${model.limits.response}" required>${esc(draft.response)}</textarea></label><p id="interview-draft-status" class="note-status">Draft saved in this browser when storage is available. An answer must be recorded to join attempt history.</p><details class="solution exercise-card"><summary>Reveal answer rubric, model answer & follow-ups</summary><h3>What a strong answer demonstrates</h3><ul>${question.rubric.map(point => `<li>${esc(point)}</li>`).join('')}</ul><div class="prose">${question.answerHTML}</div><h3>Android analogy — and its limit</h3><p>${esc(question.androidBridge)}</p><h3>Follow-up probes</h3><ol>${question.followUps.map(point => `<li>${esc(point)}</li>`).join('')}</ol><h3>Common mistakes</h3><ul>${question.pitfalls.map(point => `<li>${esc(point)}</li>`).join('')}</ul></details><details><summary>Self-assessment scale: 0–4</summary>${scoring}</details><div class="interview-filters"><label>Self-score<select data-interview-field="score" data-question="${question.id}">${options([['','Unscored'], ...[0,1,2,3,4].map(score => [String(score), String(score)])], draft.score === null ? '' : String(draft.score))}</select></label><label>Minutes spent<input type="number" min="1" max="180" step="1" value="${draft.minutes}" data-interview-field="minutes" data-question="${question.id}" required></label><label>Review again on<input type="date" value="${esc(draft.reviewOn)}" data-interview-field="reviewOn" data-question="${question.id}"></label></div><label>Feedback or evidence from your review<textarea class="note-area compact" data-interview-field="feedback" data-question="${question.id}" maxlength="${model.limits.feedback}">${esc(draft.feedback)}</textarea></label><label>One concrete next action<textarea class="note-area compact" data-interview-field="nextAction" data-question="${question.id}" maxlength="${model.limits.nextAction}">${esc(draft.nextAction)}</textarea></label><button class="button" type="submit">Record this attempt</button><p class="note-status">This records practice only. It never marks a course lesson reviewed or mentor-approved.</p></form></section><section class="lesson-section"><h2>Your attempt history</h2>${item.attempts.length ? item.attempts.slice().reverse().map(attempt => `<article class="exercise-card interview-attempt"><h3>${esc(attempt.at)} · ${attempt.score === null ? 'Unscored' : `Self-score ${attempt.score}/4`} · ${attempt.minutes} min</h3><p class="plain-answer">${esc(attempt.response)}</p><p><strong>Feedback:</strong> ${esc(attempt.feedback || 'Not recorded')}</p><p><strong>Next action:</strong> ${esc(attempt.nextAction || 'Not recorded')}</p><p><strong>Next review:</strong> ${esc(attempt.reviewOn || 'No date')}</p></article>`).join('') : '<p>No recorded attempts. Your current draft is separate from completed practice.</p>'}<button class="button tertiary" data-interview-action="clear-attempts" data-question="${question.id}" ${item.attempts.length ? '' : 'disabled'}>Clear this question’s history…</button></section>`;
    }
    function quizHistoryHTML() {
      return `<section class="lesson-section"><h2>Finished quiz ledger</h2>${state.quizzes.length ? `<div class="table-wrap"><table class="reference-table"><thead><tr><th scope="col">Completed</th><th scope="col">Scope</th><th scope="col">Score</th><th scope="col">Review</th></tr></thead><tbody>${state.quizzes.slice().reverse().map(value => {
        const score = model.grade(value, lessons);
        return `<tr><td>${esc(value.finishedAt)}</td><td>${esc(value.scope)}</td><td>${score.correct}/${score.total} · ${score.percent}%</td><td><a href="#interviews/result/${value.id}">Answers & explanations →</a></td></tr>`;
      }).join('')}</tbody></table></div>` : '<p>No finished quizzes yet. Original lesson quizzes remain available and unchanged.</p>'}<button class="button tertiary" data-interview-action="clear-quizzes" ${state.quizzes.length ? '' : 'disabled'}>Clear finished quiz history…</button></section>`;
    }
    function renderQuiz(lessonId) {
      if (lessonId && lessonById.has(lessonId)) quizScope = `lesson:${lessonId}`;
      const scopes = [['all','Whole course'], ...course.units.map(unit => [unit.id, unit.title]), ...(quizScope.startsWith('lesson:') ? [[quizScope, `Session ${quizScope.slice(7)}`]] : [])];
      main.innerHTML = `${warning()}<div class="page-title"><p class="eyebrow">A FINAL RECAP, WITH EXPLAINED ANSWERS.</p><h1>Your quiz studio.</h1><p>Build a mixed quiz from the existing ${quizIndex.size} lesson questions. No new quiz indices are inserted into your lesson progress. Scores here are saved separately and do not certify interview readiness.</p></div><div class="interview-filters"><label>Quiz scope<select data-interview-quiz-setting="scope">${options(scopes, quizScope)}</select></label><label>Questions<select data-interview-quiz-setting="count">${options([['10','10 questions'],['20','20 questions'],['30','30 questions']], String(quizCount))}</select></label></div><p class="note-status">A lesson recap contains its available questions; larger scopes sample up to the requested count without repeats. Unfinished quiz answers auto-save. Starting a replacement asks before discarding them.</p><button class="button" data-interview-action="start-quiz">Start a new quiz</button><a href="#interviews"> Back to interview ledger →</a>${state.activeQuiz ? `<form data-interview-exam class="lesson-section"><h2>Current quiz · ${esc(state.activeQuiz.scope)}</h2>${state.activeQuiz.keys.map((key, index) => {
        const question = quizIndex.get(key);
        return `<div class="quiz-card"><fieldset><legend>${index + 1}. ${esc(question.question)}</legend>${question.options.map((option, value) => `<label class="quiz-option"><input type="radio" name="exam-${key}" data-interview-exam-key="${key}" value="${value}" ${state.activeQuiz.answers[key] === value ? 'checked' : ''} required><span>${esc(option)}</span></label>`).join('')}</fieldset></div>`;
      }).join('')}<button class="button" type="submit">Finish quiz & save the result</button></form>` : ''}${quizHistoryHTML()}`;
    }
    function renderResult(id) {
      const value = state.quizzes.find(quiz => quiz.id === id);
      if (!value) { main.innerHTML = '<div class="empty-state"><h1>Quiz result not found.</h1><a href="#interviews/quiz">Open quiz studio</a></div>'; return; }
      const score = model.grade(value, lessons);
      main.innerHTML = `<div class="page-title"><h1>${score.correct} / ${score.total} correct</h1><p>${esc(value.scope)} · ${esc(value.finishedAt)} · ${score.percent}%</p><p>This measures answers to sampled questions, not implementation ability or staff-level readiness.</p><a href="#interviews/quiz">← Quiz studio</a></div>${value.keys.map((key, index) => {
        const question = quizIndex.get(key), correct = value.answers[key] === question.answer;
        return `<article class="exercise-card"><h2>${index + 1}. ${esc(question.question)}</h2><p>${correct ? 'Correct.' : 'Revisit this idea.'} Your answer: ${esc(question.options[value.answers[key]])}</p><p><strong>Expected:</strong> ${esc(question.options[question.answer])}</p><p>${esc(question.explanation)}</p><a href="#lesson/${question.lesson}/quiz">Review session ${question.lesson} →</a></article>`;
      }).join('')}`;
    }
    function renderRounds(id) {
      const rounds = course.interview?.rounds || [];
      const selected = rounds.find(round => round.id === id);
      if (id && !selected) { main.innerHTML = '<h1>Mock round not found.</h1><a href="#interviews/rounds">View rounds</a>'; return; }
      const roundHTML = round => `<article class="exercise-card"><p class="eyebrow">${round.minutes} MIN · ${esc(round.level)}</p><h2>${esc(round.title)}</h2><p>${esc(round.brief)}</p><ol>${round.steps.map(step => `<li>${esc(step)}</li>`).join('')}</ol><h3>Question seeds</h3><ol>${round.questions.map(value => `<li><a href="#interviews/${value}">${esc(byId.get(value).prompt)}</a></li>`).join('')}</ol><p class="note-status">Full individual rehearsal estimates total ${round.questions.reduce((sum, value) => sum + byId.get(value).minutes, 0)} minutes before debrief. The round is a ${round.minutes}-minute time-box: prioritize a subset or split across blocks when full answers and follow-ups exceed it.</p><h3>Debrief evidence</h3><ul>${round.evidence.map(value => `<li>${esc(value)}</li>`).join('')}</ul>${id ? '' : `<a href="#interviews/round/${round.id}">Open this round →</a>`}</article>`;
      main.innerHTML = `${warning()}<div class="page-title"><p class="eyebrow">PRACTICE AN EXPLANATION, NOT A SCRIPT.</p><h1>${selected ? esc(selected.title) : 'Mock interview rounds.'}</h1><p>Suggested agendas, not a live interviewer or an automatic timer. Use a colleague or mentor for independent challenge. Record each question attempt in its own ledger entry; review failed reasoning and evidence after the round.</p><a href="#interviews">← Interview ledger</a><button class="button tertiary" data-print>Print agenda</button></div>${(selected ? [selected] : rounds).map(roundHTML).join('')}`;
    }
    function render(id, detail) {
      document.querySelector('#breadcrumbs').textContent = 'Interview preparation / Practice ledger';
      if (!id || id === 'ledger') renderLedger();
      else if (id === 'quiz') renderQuiz(detail);
      else if (id === 'result') renderResult(detail);
      else if (id === 'rounds' || id === 'round') renderRounds(detail);
      else if (byId.has(id)) renderQuestion(byId.get(id));
      else main.innerHTML = '<div class="empty-state"><h1>Interview question not found.</h1><a href="#interviews">Open the ledger</a></div>';
    }
    function guarded(action) { try { action(); } catch (error) { toast(error.message || 'Could not update interview practice.'); } }
    function updateDraft(target) {
      if (!target.dataset?.interviewField || !byId.has(target.dataset.question)) return;
      const field = target.dataset.interviewField;
      if (!['response','score','minutes','reviewOn','feedback','nextAction'].includes(field)) return;
      const value = field === 'score' ? target.value === '' ? null : Number(target.value) : field === 'minutes' ? Number(target.value) : target.value;
      const status = document.querySelector('#interview-draft-status');
      try {
        const next = model.parseDraft({ ...entry(target.dataset.question).draft, [field]: value });
        entry(target.dataset.question).draft = next; save();
        if (status) status.textContent = storageAvailable ? 'Draft saved in this browser.' : 'Not saved to browser storage. Export a backup before closing.';
      } catch (error) { if (status) status.textContent = `${error.message} The previous valid draft is retained.`; }
    }
    document.addEventListener('input', event => {
      const target = event.target;
      if (target.id === 'interview-query') { query = target.value; filterLedger(); }
      updateDraft(target);
    });
    document.addEventListener('change', event => {
      const target = event.target;
      updateDraft(target);
      if (target.dataset?.interviewFilter) {
        const name = target.dataset.interviewFilter;
        if (name === 'area') area = target.value;
        if (name === 'level') level = target.value;
        if (name === 'status') selectedStatus = target.value;
        filterLedger();
      }
      if (target.dataset?.interviewQuizSetting === 'scope') quizScope = target.value;
      if (target.dataset?.interviewQuizSetting === 'count') quizCount = Number(target.value);
      if (target.dataset?.interviewExamKey && state.activeQuiz?.keys.includes(target.dataset.interviewExamKey)) {
        state.activeQuiz.answers[target.dataset.interviewExamKey] = Number(target.value); save();
      }
    });
    document.addEventListener('click', event => {
      const button = event.target.closest('button');
      if (!button?.dataset.interviewAction) return;
      guarded(() => {
        const action = button.dataset.interviewAction, id = button.dataset.question;
        if (action === 'bookmark' && byId.has(id)) { entry(id).bookmark = !entry(id).bookmark; save(); rerender(); }
        if (action === 'clear-attempts' && byId.has(id) && window.confirm(`Clear all saved attempts for ${id}? Its current draft stays. Export first; recovery requires your backup.`)) {
          entry(id).attempts = []; save(); rerender(); toast('This question’s recorded attempts were removed. Restore from an exported backup if needed.');
        }
        if (action === 'clear-quizzes' && window.confirm('Clear all finished interview quiz results? The unfinished quiz stays. Export first; recovery requires your backup.')) {
          state.quizzes = []; save(); rerender(); toast('Finished quiz history was removed. Restore from an exported backup if needed.');
        }
        if (action === 'start-quiz') {
          if (state.quizzes.length >= model.limits.quizzes) throw new Error('Quiz history is full. Export before explicitly clearing finished results.');
          if (state.activeQuiz && !window.confirm('Replace the unfinished quiz and its answers? Export first if you want to retain it.')) return;
          const pool = [...quizIndex.keys()].filter(key => quizScope === 'all' || quizScope.startsWith('lesson:') && quizIndex.get(key).lesson === quizScope.slice(7) || quizIndex.get(key).unitId === quizScope);
          if (!pool.length || ![10,20,30].includes(quizCount)) throw new Error('Choose a valid quiz scope and question count.');
          for (let index = pool.length - 1; index > 0; index--) { const next = Math.floor(Math.random() * (index + 1)); [pool[index], pool[next]] = [pool[next], pool[index]]; }
          const scope = quizScope === 'all' ? 'Whole course' : quizScope.startsWith('lesson:') ? `Session ${quizScope.slice(7)}` : course.units.find(unit => unit.id === quizScope).title;
          state.activeQuiz = { id: uid('quiz'), startedAt: new Date().toISOString(), scope, keys: pool.slice(0, quizCount), answers: {} };
          save(); rerender();
        }
      });
    });
    document.addEventListener('submit', event => {
      if (event.target.matches('[data-interview-attempt]')) {
        event.preventDefault();
        guarded(() => {
          const id = event.target.dataset.interviewAttempt;
          if (!byId.has(id)) throw new Error('Unknown interview question.');
          state = model.addAttempt(state, id, { ...entry(id).draft, id: uid('attempt'), at: new Date().toISOString() }, questions, lessons);
          save(); rerender(); toast('Practice attempt recorded. Course completion was not changed.');
        });
      }
      if (event.target.matches('[data-interview-exam]')) {
        event.preventDefault();
        guarded(() => {
          if (!state.activeQuiz) throw new Error('Start a quiz first.');
          if (state.quizzes.length >= model.limits.quizzes) throw new Error('Quiz history is full. Export before clearing finished results.');
          const completed = { ...state.activeQuiz, finishedAt: new Date().toISOString() };
          model.grade(completed, lessons); // Reject incomplete answers; do not save a misleading result.
          state = model.normalize({ ...state, quizzes: [...state.quizzes, completed], activeQuiz: null }, questions, lessons);
          save(); location.hash = `#interviews/result/${completed.id}`; rerender();
        });
      }
    });
    return { render, lessonHTML, exportData: () => state, allowance: () => model.allowance(questions), prepareImport: incoming => model.merge(state, incoming, questions, lessons), commit: value => { state = value; save(); }, searchEntries: questions.map(question => ({ kind: 'Interview', id: question.id, title: question.prompt, summary: question.scenario, href: `#interviews/${question.id}`, text: `${question.prompt} ${question.scenario} ${question.androidBridge}` })) };
  }
  window.IOSInterviewReader = { create };
})();
