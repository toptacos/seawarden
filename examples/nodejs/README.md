# Node.js origin recipe

```bash
ORIGIN_STACK=node
SITE_PATH=/var/www/your-app
REMOTE_FILES_PATH=/var/www/your-app/
# MySQL
DB_DUMP_CMD='mysqldump --single-transaction --quick --lock-tables=false YOUR_DB'
# MongoDB
# DB_DUMP_CMD='mongodump --archive --gzip'
# PostgreSQL
# DB_DUMP_CMD='pg_dump --no-owner YOUR_DB'
```

Exclude `node_modules/` (already in default excludes). If dumps are binary archives (mongodump), adjust the header check in `seawarden-backup.sh` or set a custom verify hook.
