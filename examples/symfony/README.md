# Symfony origin recipe

```bash
ORIGIN_STACK=symfony
SITE_PATH=/var/www/your-app
REMOTE_FILES_PATH=/var/www/your-app/
DB_DUMP_CMD='mysqldump --single-transaction --quick --lock-tables=false YOUR_DB'
# or: php bin/console doctrine:schema:update --dump-sql  # schema only — use mysqldump/pg_dump for data
```

Exclude `var/cache` and `var/log` in the rsync exclude file.
