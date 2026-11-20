# My Block self-hosting security checklist

## Before first public launch

- [ ] Replace all official Supabase example passwords and secrets in `/opt/my-block-supabase/.env`.
- [ ] Keep `.env`, `.env.functions`, and `/etc/on-my-block/config.json` out of Git and readable only by root/services.
- [ ] Never place `SUPABASE_SECRET_KEY` or `SUPABASE_SERVICE_ROLE_KEY` in the frontend config.
- [ ] Keep PostgreSQL, Supavisor, Studio, and Docker service ports off the public interface.
- [ ] Expose only the Nginx/tunnel path required for My Block.
- [ ] Configure the tunnel hostname and HTTPS certificate before allowing real users.
- [ ] Set the self-hosted Auth Site URL and allowed redirect URLs to the actual HTTPS hostname.
- [ ] Configure SMTP if email verification, password reset, or recovery mail is required. Without SMTP, do not claim delivery is enabled.
- [ ] Review the RLS policies in `supabase-schema.sql` after every schema change.
- [ ] Confirm the `avatars` bucket MIME and size limits match the application upload rules.
- [ ] Run `sudo nginx -t` and inspect the generated Nginx configuration.
- [ ] Run `docker compose ps` and confirm services are healthy.

## Operations

- [ ] Keep Ubuntu, Docker, Nginx, and the pinned Supabase release updated.
- [ ] Run `sudo my-block-backup` and verify files appear under `/var/backups/my-block`.
- [ ] Perform a test restore to a separate test instance before relying on backups.
- [ ] Review `docker compose logs` and `journalctl -u my-block-supabase.service` after upgrades.
- [ ] Do not run the official `reset.sh` against production; it deletes database and storage data.
- [ ] Do not modify or remove `underpunk-tunnel.service` during My Block maintenance.
