// Keep the public-order mapping, reader route and complete course in agreement.
export function curriculumIssues(curriculum, { lessons, workshops, guides, paths }) {
  const issues = [];
  const text = value => typeof value === 'string' && value.trim();
  const safeId = value => typeof value === 'string' && /^[a-z0-9-]+$/.test(value);
  if (curriculum?.version !== 1 || !text(curriculum.title) || !text(curriculum.sourceScope) || !/^\d{4}-\d{2}-\d{2}$/.test(curriculum.reviewedAt || '')) return ['Invalid complete-course curriculum metadata'];
  if (curriculum.source?.url !== 'https://www.swiftful-thinking.com/store' || !text(curriculum.source.title)) issues.push('Curriculum needs its observed public-outline attribution');
  if (!Array.isArray(curriculum.stages) || curriculum.stages.length !== 13 || !Array.isArray(curriculum.extensions) || !curriculum.extensions.length) return [...issues, 'Curriculum needs thirteen public-order stages and further production practice'];
  const lessonIds = new Set(lessons.map(item => item.id));
  const workshopIds = new Set(workshops.map(item => item.id));
  const guideIds = new Set(guides.map(item => item.id));
  const stages = [...curriculum.stages, ...curriculum.extensions];
  const stageIds = new Set();
  const sequence = [];
  for (const [index, stage] of stages.entries()) {
    const label = `Curriculum stage ${stage.id}`;
    if (!safeId(stage.id) || stageIds.has(stage.id)) issues.push(`${label}: invalid/duplicate stage ID`);
    for (const field of ['title', 'summary', 'goal']) if (!text(stage[field])) issues.push(`${label}: missing ${field}`);
    if (!['Beginner', 'Intermediate', 'Advanced', 'Elective'].includes(stage.level)) issues.push(`${label}: unknown level`);
    if (index < 13 && !text(stage.sourceCourseTitle)) issues.push(`${label}: missing public course mapping`);
    if (!Array.isArray(stage.prerequisites)) issues.push(`${label}: missing prerequisite list`);
    for (const prerequisite of stage.prerequisites || []) if (!stageIds.has(prerequisite)) issues.push(`${label}: prerequisite stage is not earlier`);
    stageIds.add(stage.id);
    if (!Array.isArray(stage.lessons) || !stage.lessons.length || !Array.isArray(stage.workshops) || !Array.isArray(stage.guides)) { issues.push(`${label}: missing learning connections`); continue; }
    for (const id of stage.lessons) {
      if (!lessonIds.has(id) || sequence.includes(id)) issues.push(`${label}: unknown or repeated lesson ${id}`);
      sequence.push(id);
    }
    for (const id of stage.workshops) if (!workshopIds.has(id)) issues.push(`${label}: missing project workshop ${id}`);
    for (const id of stage.guides) if (!guideIds.has(id)) issues.push(`${label}: missing language guide ${id}`);
    if (!Array.isArray(stage.checkpoint) || stage.checkpoint.length < 3 || !stage.checkpoint.every(text)) issues.push(`${label}: needs explained review questions`);
  }
  if (sequence.length !== lessonIds.size || new Set(sequence).size !== lessonIds.size) issues.push('Complete curriculum must cover every numbered lesson exactly once');
  const positions = new Map(sequence.map((id, index) => [id, index]));
  for (const lesson of lessons) for (const prerequisite of lesson.prerequisites || []) {
    if (!positions.has(prerequisite) || positions.get(prerequisite) >= positions.get(lesson.id)) issues.push(`Lesson ${lesson.id}: prerequisite ${prerequisite} is not earlier in the complete course`);
  }
  const complete = paths.find(item => item.id === 'complete');
  if (!complete || JSON.stringify(complete.stages.map(({ title, summary, lessons, workshops, guides }) => ({ title, summary, lessons, workshops, guides }))) !== JSON.stringify(stages.map(({ title, summary, lessons, workshops, guides }) => ({ title, summary, lessons, workshops, guides })))) issues.push('Complete learning path differs from the curriculum mapping');
  return issues;
}
