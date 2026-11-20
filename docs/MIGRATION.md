# My Block self-hosting migration report

## Audit summary

My Block is a static single-page application. The frontend uses Supabase JS for Auth, PostgREST data access, Storage, Realtime-compatible subscriptions, and Edge Function invocation. Vercel currently provides only `/api/config`, which exposes public runtime configuration; it is not an application database.

The application schema in `supabase-schema.sql` contains profiles, blocks and memberships, invitations, locations, meetup rounds/proposals/votes, stories/comments/reactions, chat messages/songs, Spotify activity, and photo-login rate-limit state. It also contains the profile trigger, security-definer functions, indexes, grants, RLS policies, and the `avatars` Storage bucket policies.

The repository’s two Edge Functions are `create-account` and `login-with-photo`. They now accept both legacy `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` variables and the self-hosted `SUPABASE_PUBLISHABLE_KEYS` / `SUPABASE_SECRET_KEYS` dictionaries.

## Target architecture

```text
HTTPS tunnel -> Nginx 127.0.0.1:8080
                 |-- /              My Block static frontend
                 |-- /api/config    local public runtime config
                 `-- /supabase/*    Supabase API gateway on 127.0.0.1:8000
                                      |-- Auth
                                      |-- PostgREST
                                      |-- Realtime/WebSockets
                                      |-- Storage/local files
                                      |-- Edge Functions
                                      `-- PostgreSQL
```

The official Supabase self-hosted Docker release is fetched and pinned by `SUPABASE_REF` during installation instead of copying its large upstream Compose stack into this repository. My Block supplies the application migration, functions, Nginx integration, backup scripts, and systemd units around that supported stack.

## Deployment

Run `sudo bash deploy/setup-self-hosted-ubuntu.sh` on Ubuntu. It clones the app to `/var/www/on-my-block`, installs the official Supabase Docker release under `/opt/my-block-supabase`, generates keys on first install, applies the schema, installs the two functions, creates the local public config, configures Nginx on `127.0.0.1:8080`, and enables the Supabase service plus nightly backups.

The existing `underpunk-tunnel.service` is not changed. The tunnel must forward the chosen hostname to `127.0.0.1:8080`.

## Validation status

Validated from the development workspace:

- Existing schema and RLS definitions inspected.
- Existing cloud create-account endpoint returned HTTP 201 during signup testing.
- Existing block create/join RPC flow passed with two temporary accounts; temporary data was removed.
- Shell scripts passed Git Bash syntax checks.
- Git tree and upstream were synchronized before this migration stage.

Must be validated on the Ubuntu host after installation:

- Docker image pulls and all official Supabase containers becoming healthy.
- Applying the migration to the local PostgreSQL container.
- Auth/session flow against the local API gateway.
- Realtime WebSocket delivery through the tunnel.
- Storage persistence after container recreation.
- Backup restore and boot recovery.
- The existing tunnel’s public HTTPS route.

No claim is made that these host-specific checks have already passed from Windows.
