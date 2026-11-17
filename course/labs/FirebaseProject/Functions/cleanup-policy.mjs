// Pure policy/orchestration only. Importing this module initializes no Firebase SDK.
export const validID = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,64}$/.test(value);
export const validGeneration = value => typeof value === 'string'
  && /^[1-9][0-9]{0,19}$/.test(value) && BigInt(value) <= 18446744073709551615n;

export function cleanupTarget(job, uid) {
  if (!validID(uid) || job?.uid !== uid || !validID(job.mediaID) || !validGeneration(job.generation)) {
    throw new Error('Invalid generation-bound cleanup job');
  }
  return { path: `users/${uid}/media/${job.mediaID}.jpg`, generation: job.generation };
}

export async function deleteOriginalGeneration(file, generation) {
  if (!validGeneration(generation)) throw new Error('A canonical generation string is required');
  try {
    // Keep the exact decimal string. Number(generation) can silently target another version.
    await file.delete({ ifGenerationMatch: generation });
    return 'deletedOriginal';
  } catch (error) {
    if (error?.code === 404) return 'alreadyAbsent';
    if (error?.code === 412) return 'replacementPreserved';
    throw error; // A transient/provider failure remains retryable, not completed.
  }
}
