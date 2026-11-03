// Shared authoring checks for the plain-text story and illustration layer.
export function teachingIdentity(item) {
  return {
    quiz: item.quiz,
    checklist: item.checklist ?? null,
    sectionIds: item.sections.map(section => section.id),
    codeBlocks: [...item.sections.map(section => section.html), item.exercise.solution].flatMap(html => html.match(/<pre\b[^>]*>[\s\S]*?<\/pre>/gi) || [])
  };
}

export function interviewIdentity(item) {
  return { lesson: item.lesson, kind: item.kind, level: item.level, minutes: item.minutes, codeBlocks: item.answerHTML.match(/<pre\b[^>]*>[\s\S]*?<\/pre>/gi) || [] };
}

export function simpleIssues(simple, label) {
  const errors = [];
  const object = value => value && typeof value === 'object' && !Array.isArray(value);
  const text = (value, name, limit) => {
    if (typeof value !== 'string' || !value.trim() || value.length > limit) errors.push(`${label}.${name}: expected short, nonempty plain text`);
  };
  if (!object(simple)) return [`${label}: missing simple story, example, picture and vocabulary`];
  text(simple.story, 'simple.story', 1800);
  text(simple.meaning, 'simple.meaning', 1500);
  text(simple.remember, 'simple.remember', 600);
  text(simple.boundary, 'simple.boundary', 1500);
  if (!object(simple.example)) errors.push(`${label}: missing before/change/after example`);
  else for (const key of ['before', 'change', 'after']) text(simple.example[key], `simple.example.${key}`, 1200);
  if (!object(simple.picture)) errors.push(`${label}: missing illustration`);
  else {
    if (!['flow', 'comparison', 'timeline'].includes(simple.picture.kind)) errors.push(`${label}: illustration must be a flow, comparison or timeline`);
    text(simple.picture.caption, 'simple.picture.caption', 700);
    if (!Array.isArray(simple.picture.items) || simple.picture.items.length < 3 || simple.picture.items.length > 5) errors.push(`${label}: illustration needs 3–5 explained parts`);
    else for (const [index, item] of simple.picture.items.entries()) {
      text(item?.label, `simple.picture.items[${index}].label`, 120);
      text(item?.text, `simple.picture.items[${index}].text`, 700);
    }
  }
  if (!Array.isArray(simple.words) || simple.words.length < 3 || simple.words.length > 7) errors.push(`${label}: define 3–7 new words`);
  else {
    const terms = new Set();
    for (const [index, word] of simple.words.entries()) {
      text(word?.term, `simple.words[${index}].term`, 160);
      text(word?.meaning, `simple.words[${index}].meaning`, 700);
      const term = typeof word?.term === 'string' ? word.term.trim().toLowerCase() : '';
      if (terms.has(term)) errors.push(`${label}: repeated vocabulary term ${term}`);
      terms.add(term);
    }
  }
  return errors;
}
