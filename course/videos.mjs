// Validate external video companions without changing lesson/progress identities.
export function videoCompanionIssues(videos, curriculum) {
  const issues = [];
  const text = value => typeof value === 'string' && value.trim().length > 0;
  const youtubeURL = (value, kind) => {
    try {
      const url = new URL(value);
      if (url.protocol !== 'https:' || url.hostname !== 'www.youtube.com' || url.username || url.password || url.hash) return false;
      if (kind === 'playlist') return url.pathname === '/playlist' && /^[A-Za-z0-9_-]+$/.test(url.searchParams.get('list') || '') && [...url.searchParams.keys()].every(key => key === 'list');
      return kind === 'video' && url.pathname === '/watch' && /^[A-Za-z0-9_-]{11}$/.test(url.searchParams.get('v') || '') && [...url.searchParams.keys()].every(key => key === 'v');
    } catch { return false; }
  };
  if (videos?.version !== 1 || !text(videos.title) || !text(videos.scope) || !/^\d{4}-\d{2}-\d{2}$/.test(videos.reviewedAt || '')) return ['Invalid video companion metadata'];
  if (videos.channel?.url !== 'https://www.youtube.com/@SwiftfulThinking/courses' || !text(videos.channel?.title)) issues.push('Video companions need their public channel attribution');
  if (!text(videos.referenceVideo?.title) || !youtubeURL(videos.referenceVideo?.url, 'video')) issues.push('Video companions need a canonical reference video');
  if (!Array.isArray(videos.sources) || !videos.sources.length || !videos.sources.every(source => {
    try { const url = new URL(source.url); return text(source.title) && url.protocol === 'https:' && ['www.youtube.com', 'www.swiftful-thinking.com'].includes(url.hostname) && !url.username && !url.password; }
    catch { return false; }
  })) issues.push('Video companions need primary HTTPS source references');
  if (!Array.isArray(videos.routine) || videos.routine.length !== 6 || !videos.routine.every(step => text(step.title) && text(step.instruction))) issues.push('Video companions need six explained practice steps');
  if (!Array.isArray(videos.stages) || videos.stages.length !== curriculum.stages.length) return [...issues, 'Video companions must account for each public-outline stage'];
  const stages = new Map(curriculum.stages.map(stage => [stage.id, stage]));
  const seen = new Set();
  const resourceIDs = new Set();
  for (const companion of videos.stages) {
    const stage = stages.get(companion.stageId);
    const label = `Video stage ${companion.stageId}`;
    if (!stage || seen.has(companion.stageId)) { issues.push(`${label}: unknown or duplicate stage`); continue; }
    seen.add(companion.stageId);
    if (!text(companion.focus) || !Array.isArray(companion.resources)) { issues.push(`${label}: missing focus/resources`); continue; }
    if (!companion.resources.length && !text(companion.fallback)) issues.push(`${label}: explain an unverified/unavailable public match`);
    for (const resource of companion.resources) {
      if (!/^[a-z0-9-]+$/.test(resource.id || '') || resourceIDs.has(resource.id)) issues.push(`${label}: invalid/duplicate resource identity`);
      resourceIDs.add(resource.id);
      if (!text(resource.title) || !text(resource.watchFor) || !text(resource.reviewBasis)) issues.push(`${label}: missing title, observation prompt or review scope`);
      if (!youtubeURL(resource.url, resource.kind)) issues.push(`${label}: require a canonical HTTPS YouTube ${resource.kind} URL`);
      if (!Array.isArray(resource.lessons) || resource.kind === 'video' && !resource.lessons.length || new Set(resource.lessons || []).size !== resource.lessons?.length) issues.push(`${label}: invalid lesson matches`);
      for (const id of resource.lessons || []) if (!stage.lessons.includes(id)) issues.push(`${label}: video match is outside this stage: ${id}`);
    }
  }
  return issues;
}
