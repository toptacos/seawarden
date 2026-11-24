# Laravel origin recipe

Set in `/etc/seawarden/seawarden.env`:

```bash
ORIGIN_STACK=laravel
SITE_PATH=/var/www/your-app
REMOTE_FILES_PATH=/var/www/your-app/
DB_DUMP_CMD='cd /var/www/your-app && php artisan db:show >/dev/null && mysqldump --single-transaction --quick --lock-tables=false "$DB_DATABASE"'
```

Prefer a dedicated read-only DB user on the origin. For PostgreSQL:

```bash
DB_DUMP_CMD='pg_dump --no-owner --format=plain "$DATABASE_URL"'
```

Rsync the whole app or narrow to `storage/` + `.env.example` + `composer.lock` as your threat model requires. Exclude `storage/framework/cache` via `config/rsync-excludes.txt`.
