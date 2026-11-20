# My Block

An art-directed neighborhood app for shared instants, Substack stories, meet-up voting, location sharing, battery pulse, chat, voice notes, and stickers.

## Vercel setup

Set these Vercel environment variables for Production, Preview, and Development:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (publishable/anon key; this is public at runtime in a browser)
- `APP_ORIGIN` (the exact deployed Vercel origin)

The service-role key must never be added to Vercel client variables or this repository. Keep `SUPABASE_SERVICE_ROLE_KEY` only in Supabase Edge Function secrets.

## Supabase setup

Run [supabase-schema.sql](./supabase-schema.sql) in the Supabase SQL Editor, then deploy `supabase/functions/login-with-photo/index.ts` with the Supabase CLI. Configure `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and `APP_ORIGINS` as Edge Function secrets.

## Local preview

Run a static server from the project folder, then open the displayed local URL. Supabase connection values can be entered through the setup panel when `/api/config` is unavailable.

## Ubuntu hosting with Nginx

This repository includes an Ubuntu setup script and Nginx configuration. On the Ubuntu server, run:

```bash
git clone https://github.com/itsjimba/on-my-block.git
cd on-my-block
sudo bash deploy/setup-ubuntu.sh
```

The script installs Nginx, serves the project from `/var/www/on-my-block`, and creates `/etc/on-my-block/config.json` from the public Supabase URL and publishable key you enter. Do not put a Supabase service-role key in that file or in this repository. After DNS points to the server, enable HTTPS with the Certbot commands printed by the script.
