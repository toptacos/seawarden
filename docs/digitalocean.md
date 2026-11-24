# DigitalOcean vault (kit companion)

Full narrative: SeaWarden site `/digitalocean` and Project store `digitalocean-setup.md`.

Minimal:

1. Droplet 2 vCPU / 4 GB + block volume (≥ media tree + retention headroom).
2. Mount volume at `/mnt/seawarden_backups`.
3. Create SSH key used **only** for vault→origin pull; install public key on origin.
4. Install this kit; configure `/etc/seawarden/seawarden.env` from `config/seawarden.env.example`.
5. TLS for status API; point the WordPress plugin at `https://backups.YOUR_DOMAIN/api/backup-status.php`.
6. Optional 3-2-1: encrypted sync of `.sql.gz.gpg` to Spaces/S3.
