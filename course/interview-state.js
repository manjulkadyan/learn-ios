/* Bounded, plain-text interview history. Independent from lesson completion. */
(() => {
  'use strict';
  const limits = Object.freeze({ attempts: 20, quizzes: 30, response: 5000, feedback: 2000, nextAction: 500 });
  const empty = () => ({ version: 1, questions: {}, quizzes: [], activeQuiz: null });
  const blankDraft = () => ({ response: '', feedback: '', nextAction: '', reviewOn: '', minutes: 5, score: null });
  const blank = () => ({ bookmark: false, draft: blankDraft(), attempts: [] });
  const object = value => value && typeof value === 'object' && !Array.isArray(value);
  const text = (value, max, label) => {
    if (value === undefined) return '';
    if (typeof value !== 'string' || value.length > max) throw new Error(`${label} must be plain text of at most ${max} characters.`);
    return value;
  };
  const validDate = value => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
    const parsed = new Date(`${value}T00:00:00.000Z`);
    return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
  };
  const timestamp = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value) && Number.isFinite(new Date(value).getTime()) && new Date(value).toISOString() === value;
  function draft(raw = {}) {
    if (!object(raw)) throw new Error('Invalid interview draft.');
    const score = raw.score === undefined || raw.score === null || raw.score === '' ? null : raw.score;
    if (score !== null && (!Number.isInteger(score) || score < 0 || score > 4)) throw new Error('Interview score must be 0–4 or unscored.');
    const minutes = raw.minutes === undefined ? 5 : raw.minutes;
    if (!Number.isInteger(minutes) || minutes < 1 || minutes > 180) throw new Error('Practice time must be 1–180 whole minutes.');
    const reviewOn = raw.reviewOn || '';
    if (typeof reviewOn !== 'string' || reviewOn && !validDate(reviewOn)) throw new Error('Use a valid calendar date for next review.');
    return { response: text(raw.response, limits.response, 'Answer'), feedback: text(raw.feedback, limits.feedback, 'Feedback'), nextAction: text(raw.nextAction, limits.nextAction, 'Next action'), reviewOn, minutes, score };
  }
  function quizIndex(lessons) {
    return new Map(lessons.flatMap(lesson => lesson.quiz.map((question, index) => [`q-${lesson.id}-${index}`, { ...question, lesson: lesson.id, unitId: lesson.unitId }])));
  }
  function quiz(raw, index, finished) {
    if (!object(raw) || !/^quiz-[a-z0-9-]+$/.test(raw.id) || !timestamp(raw.startedAt)) throw new Error('Invalid quiz record.');
    if (finished && !timestamp(raw.finishedAt)) throw new Error('Invalid quiz completion timestamp.');
    if (finished && raw.finishedAt < raw.startedAt) throw new Error('Quiz cannot finish before it starts.');
    if (!Array.isArray(raw.keys) || raw.keys.length < 1 || raw.keys.length > 30 || new Set(raw.keys).size !== raw.keys.length || raw.keys.some(key => !index.has(key))) throw new Error('Quiz contains unknown or duplicate questions.');
    if (!object(raw.answers)) throw new Error('Invalid quiz answers.');
    const answers = {};
    for (const key of raw.keys) {
      const value = raw.answers[key];
      if (value === undefined && !finished) continue;
      if (!Number.isInteger(value) || value < 0 || value >= index.get(key).options.length) throw new Error('Quiz answer is out of range or missing.');
      answers[key] = value;
    }
    return { id: raw.id, startedAt: raw.startedAt, ...(finished ? { finishedAt: raw.finishedAt } : {}), scope: text(raw.scope, 100, 'Quiz scope'), keys: [...raw.keys], answers };
  }
  function normalize(raw, questions, lessons) {
    if (!object(raw) || raw.version !== 1 || !object(raw.questions) || !Array.isArray(raw.quizzes)) throw new Error('Invalid interview ledger backup.');
    const result = empty();
    for (const question of questions) {
      const item = raw.questions[question.id];
      if (item === undefined) continue;
      if (!object(item) || !Array.isArray(item.attempts) || item.attempts.length > limits.attempts) throw new Error('Invalid or oversized interview history.');
      const ids = new Set();
      const attempts = item.attempts.map(attempt => {
        if (!object(attempt) || !/^attempt-[a-z0-9-]+$/.test(attempt.id) || !timestamp(attempt.at) || ids.has(attempt.id)) throw new Error('Invalid or duplicate interview attempt.');
        ids.add(attempt.id);
        const value = draft(attempt);
        if (!value.response.trim()) throw new Error('A recorded interview attempt needs an answer.');
        return { id: attempt.id, at: attempt.at, ...value };
      }).sort((a, b) => a.at.localeCompare(b.at) || a.id.localeCompare(b.id));
      result.questions[question.id] = { bookmark: item.bookmark === true, draft: draft(item.draft), attempts };
    }
    if (raw.quizzes.length > limits.quizzes) throw new Error('Quiz history is full. Export and explicitly clear history before adding more.');
    const index = quizIndex(lessons);
    const ids = new Set();
    result.quizzes = raw.quizzes.map(value => {
      const parsed = quiz(value, index, true);
      if (ids.has(parsed.id)) throw new Error('Duplicate quiz record.');
      ids.add(parsed.id); return parsed;
    }).sort((a, b) => a.finishedAt.localeCompare(b.finishedAt) || a.id.localeCompare(b.id));
    if (raw.activeQuiz) {
      result.activeQuiz = quiz(raw.activeQuiz, index, false);
      if (ids.has(result.activeQuiz.id)) throw new Error('Active quiz was already completed.');
    }
    return result;
  }
  function addAttempt(state, questionId, value, questions, lessons) {
    if (!questions.some(question => question.id === questionId)) throw new Error('Unknown interview question.');
    const result = normalize(state, questions, lessons);
    const item = result.questions[questionId] || blank();
    if (item.attempts.length >= limits.attempts) throw new Error('This question has 20 attempts. Export before explicitly clearing its history.');
    item.attempts.push(value);
    item.draft = blankDraft();
    result.questions[questionId] = item;
    return normalize(result, questions, lessons);
  }
  function merge(current, incoming, questions, lessons) {
    const result = normalize(current, questions, lessons);
    if (incoming === undefined) return result; // Older lesson-only backups are still valid.
    const other = normalize(incoming, questions, lessons);
    for (const [id, item] of Object.entries(other.questions)) {
      const local = result.questions[id] || blank();
      const attempts = new Map(local.attempts.map(attempt => [attempt.id, attempt]));
      for (const attempt of item.attempts) {
        if (attempts.has(attempt.id) && JSON.stringify(attempts.get(attempt.id)) !== JSON.stringify(attempt)) throw new Error('Conflicting attempt IDs: no history was overwritten.');
        attempts.set(attempt.id, attempt);
      }
      const localHasDraft = JSON.stringify(local.draft) !== JSON.stringify(blankDraft());
      const importedHasDraft = JSON.stringify(item.draft) !== JSON.stringify(blankDraft());
      if (localHasDraft && importedHasDraft && JSON.stringify(local.draft) !== JSON.stringify(item.draft)) throw new Error(`Question ${id} has conflicting drafts. Export both copies before resolving them.`);
      result.questions[id] = { bookmark: local.bookmark || item.bookmark, draft: localHasDraft ? local.draft : item.draft, attempts: [...attempts.values()] };
    }
    const quizzes = new Map(result.quizzes.map(value => [value.id, value]));
    for (const value of other.quizzes) {
      if (quizzes.has(value.id) && JSON.stringify(quizzes.get(value.id)) !== JSON.stringify(value)) throw new Error('Conflicting quiz IDs: no results were overwritten.');
      quizzes.set(value.id, value);
    }
    result.quizzes = [...quizzes.values()];
    if (result.activeQuiz && other.activeQuiz && JSON.stringify(result.activeQuiz) !== JSON.stringify(other.activeQuiz)) throw new Error('Conflicting unfinished quizzes. Export both copies before resolving them.');
    result.activeQuiz ||= other.activeQuiz;
    if (result.activeQuiz && quizzes.has(result.activeQuiz.id)) {
      const completed = quizzes.get(result.activeQuiz.id);
      if (JSON.stringify(result.activeQuiz.keys) !== JSON.stringify(completed.keys) || Object.entries(result.activeQuiz.answers).some(([key, answer]) => completed.answers[key] !== answer)) throw new Error('Unfinished quiz conflicts with its saved result.');
      result.activeQuiz = null;
    }
    return normalize(result, questions, lessons);
  }
  function status(item) {
    const latest = item?.attempts?.at(-1);
    return !latest ? 'unattempted' : latest.score === null ? 'unscored' : latest.score < 3 ? 'review' : 'confident';
  }
  function grade(value, lessons) {
    const index = quizIndex(lessons);
    const parsed = quiz(value, index, true);
    const correct = parsed.keys.filter(key => parsed.answers[key] === index.get(key).answer).length;
    return { correct, total: parsed.keys.length, percent: Math.round(100 * correct / parsed.keys.length) };
  }
  const allowance = questions => Math.max(2000000, questions.length * ((limits.attempts + 1) * (limits.response + limits.feedback + limits.nextAction + 300)) * 6 + 2000000);
  globalThis.IOSInterviewState = { limits, empty, blank, blankDraft, parseDraft: draft, normalize, addAttempt, merge, status, grade, quizIndex, allowance, validDate };
})();
