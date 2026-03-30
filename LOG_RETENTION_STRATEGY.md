# ABZORA Log Retention

ABZORA now uses an archival strategy for operational logs instead of leaving them in hot paths forever.

## Sources

- `logs/`
- `activityLogs/`
- `adminLogs/`

## Archive target

Old entries are moved to:

- `archivedLogs/logs/{year}/{month}/{logId}`
- `archivedLogs/activityLogs/{year}/{month}/{logId}`
- `archivedLogs/adminLogs/{year}/{month}/{logId}`

## Retention window

Default hot retention is `30` days.

Override with:

```powershell
$env:LOG_RETENTION_DAYS="14"
```

## Script

Run:

```powershell
npm install
$env:FIREBASE_DATABASE_URL="https://abzio-d99f9-default-rtdb.firebaseio.com"
npm run logs:archive
```

The script:

1. reads live logs from RTDB
2. archives old entries by year/month
3. deletes archived entries from the hot paths

## Requirements

- Google application default credentials or another `firebase-admin` auth mechanism
- `FIREBASE_DATABASE_URL`

## Notes

- Log payloads now include `createdAt` so archival can work consistently
- recent logs remain in the hot paths for dashboard/debug access
- archived logs remain queryable for audits without bloating live reads
