# SeaWarden

Self-hosted **pull** backup vault: stream databases off your origin over SSH, hardlink file snapshots with `rsync --link-dest`, encrypt dumps at rest, publish status JSON for an admin UI.

Marketing + docs: [seawarden.topta.co](https://seawarden.topta.co) (TopTacos monorepo SPA).  
This repository is the **downloadable kit** (scripts, status API, WordPress plugin, stack adapters).

## Quick start

1. Provision a vault VPS + block volume ([docs/digitalocean.md](docs/digitalocean.md)).
2. Copy `config/seawarden.env.example` → `/etc/seawarden/seawarden.env` and fill placeholders.
3. Install scripts:

```bash
sudo install -m 0755 scripts/seawarden-backup.sh /usr/local/bin/seawarden-backup
sudo install -m 0755 scripts/seawarden-restore.sh /usr/local/bin/seawarden-restore
sudo mkdir -p /mnt/seawarden_backups/{backups,status,locks}
```

4. Cron (stagger envs):

```cron
5 * * * *  /usr/local/bin/seawarden-backup production >> /var/log/seawarden-production.log 2>&1
```

5. Expose `status-api/` over HTTPS; install `wordpress/seawarden-backup-status`.

## Layout

| Path | Role |
|---|---|
| `scripts/seawarden-backup.sh` | Hourly pull pipeline |
| `scripts/seawarden-restore.sh` | Documented restore helpers |
| `status-api/` | PHP status + download endpoints |
| `wordpress/seawarden-backup-status/` | Admin dashboard plugin |
| `examples/` | Laravel / Symfony / Node dump + rsync recipes |
| `config/` | Env + rsync excludes |
| `benchmarks/` | Fixture timings + verifier |
| `tests/` | Smoke tests (no live SSH) |

## Tests

```bash
./tests/run.sh
```

## License

GPL-2.0-or-later for the WordPress plugin; MIT for scripts and examples unless noted.
