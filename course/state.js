/* Pure progress rules, shared by the browser and dependency-free tests. */
(() => {
  'use strict';
  const emptyState = () => ({ version: 1, theme: 'light', lastLesson: '004', lessons: {} });
  const blankEntry = () => ({ notes: '', bookmark: false, reviewed: false, checks: [], quizzes: {}, exerciseDone: false });
  // JSON can encode one note character as six bytes. Allow a backup of every bounded note.
  const backupLimit = lessons => Math.max(16000000, lessons.length * 600000 + 1000000);
  function ready(lesson, item) {
    return item.exerciseDone === true && lesson.checklist.every((_, i) => item.checks.includes(i)) && lesson.quiz.every((q, i) => item.quizzes[i] === q.answer);
  }
  function normalizeState(raw, lessons) {
    if (!raw || raw.version !== 1 || typeof raw.lessons !== 'object' || !raw.lessons || Array.isArray(raw.lessons)) throw new Error('This file is not a course backup.');
    const result = emptyState();
    result.theme = raw.theme === 'dark' ? 'dark' : 'light';
    if (lessons.some(lesson => lesson.id === raw.lastLesson)) result.lastLesson = raw.lastLesson;
    for (const lesson of lessons) {
      const item = raw.lessons[lesson.id];
      if (!item || typeof item !== 'object' || Array.isArray(item)) continue;
      const quizzes = {};
      lesson.quiz.forEach((question, index) => {
        const answer = item.quizzes?.[index];
        if (Number.isInteger(answer) && answer >= 0 && answer < question.options.length) quizzes[index] = answer;
      });
      const checks = Array.isArray(item.checks) ? [...new Set(item.checks.filter(x => Number.isInteger(x) && x >= 0 && x < lesson.checklist.length))] : [];
      const entry = { notes: typeof item.notes === 'string' ? item.notes.slice(0, 100000) : '', bookmark: item.bookmark === true, reviewed: false, exerciseDone: item.exerciseDone === true, checks, quizzes };
      entry.reviewed = item.reviewed === true && ready(lesson, entry);
      result.lessons[lesson.id] = entry;
    }
    return result;
  }
  function mergeState(current, incoming, lessons) {
    const result = normalizeState(current, lessons);
    const imported = normalizeState(incoming, lessons);
    if (!Object.keys(result.lessons).length) {
      result.theme = imported.theme;
      result.lastLesson = imported.lastLesson;
    }
    for (const [id, other] of Object.entries(imported.lessons)) {
      const item = result.lessons[id] || blankEntry();
      const notes = item.notes && other.notes && item.notes !== other.notes ? `${item.notes}\n\n--- Imported notes ---\n${other.notes}` : item.notes || other.notes;
      if (notes.length > 100000) throw new Error(`Session ${id} would exceed the note limit. Back up both copies and shorten the notes before merging.`);
      // Keep a validated review intact; otherwise merge partial work with local answers taking precedence.
      const preferred = item.reviewed ? item : other.reviewed ? other : {
        ...item, quizzes: { ...other.quizzes, ...item.quizzes },
        checks: [...new Set([...item.checks, ...other.checks])], exerciseDone: item.exerciseDone || other.exerciseDone
      };
      result.lessons[id] = { ...preferred, notes, bookmark: item.bookmark || other.bookmark, reviewed: item.reviewed || other.reviewed };
    }
    return normalizeState(result, lessons);
  }
  globalThis.IOSCourseState = { emptyState, blankEntry, ready, normalizeState, mergeState, backupLimit };
})();
