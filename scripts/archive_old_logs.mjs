import admin from 'firebase-admin';

const retentionDays = Number.parseInt(process.env.LOG_RETENTION_DAYS ?? '30', 10);
const databaseUrl = process.env.FIREBASE_DATABASE_URL ?? '';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: databaseUrl || undefined,
  });
}

const db = admin.database();
const cutoff = Date.now() - retentionDays * 24 * 60 * 60 * 1000;
const sourcePaths = ['logs', 'activityLogs', 'adminLogs'];

function getCreatedAtMillis(entry) {
  const value = entry?.createdAt ?? entry?.timestamp ?? null;
  if (typeof value !== 'string') {
    return null;
  }
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? null : parsed;
}

function archivePath(sourcePath, logId, createdAtMillis) {
  const date = new Date(createdAtMillis);
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  return `archivedLogs/${sourcePath}/${year}/${month}/${logId}`;
}

async function archiveSource(sourcePath) {
  const snapshot = await db.ref(sourcePath).get();
  if (!snapshot.exists()) {
    return {archived: 0, deleted: 0};
  }
  const entries = snapshot.val() ?? {};
  const updates = {};
  let archived = 0;

  for (const [logId, value] of Object.entries(entries)) {
    const createdAtMillis = getCreatedAtMillis(value);
    if (createdAtMillis === null || createdAtMillis >= cutoff) {
      continue;
    }
    updates[archivePath(sourcePath, logId, createdAtMillis)] = value;
    updates[`${sourcePath}/${logId}`] = null;
    archived += 1;
  }

  if (archived > 0) {
    await db.ref().update(updates);
  }

  return {archived, deleted: archived};
}

const results = {};
for (const sourcePath of sourcePaths) {
  results[sourcePath] = await archiveSource(sourcePath);
}

console.log(
  JSON.stringify(
    {
      retentionDays,
      results,
    },
    null,
    2,
  ),
);
