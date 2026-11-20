-- Canonical application migration.
-- Run from the repository root with psql, or use deploy/setup-self-hosted-ubuntu.sh.
-- Keeping the existing schema file as the source preserves the deployed schema exactly.
\ir ../../supabase-schema.sql
