# HYSI ESPORTS — Stage 1 Foundation

**Tagline:** PLAY TOGETHER. RISE TOGETHER.  
**Scope:** Free Fire esports + player community + AI assistant.

This is the first development stage, not a claim that the complete platform is already production-ready. The homepage and project foundation are present; authentication, tournament operations, chat, payments (not planned), AI and admin actions are added in later stages.

## Stack
- Next.js App Router + React + TypeScript
- Tailwind CSS
- Supabase Auth / PostgreSQL / Storage / Realtime
- OpenAI API (server-side only, later stage)
- Vercel deployment

## Requirements
- Node.js 20.9+
- npm
- A Supabase project for backend stages

## Run locally
```bash
npm install
cp .env.example .env.local
npm run dev
```
Open http://localhost:3000.

The Stage 1 homepage runs without Supabase credentials. Supabase client helpers throw a clear error if called before environment variables are configured.

## Database foundation
1. Create a Supabase project.
2. Open **SQL Editor** in the Supabase dashboard.
3. Run `supabase/migrations/0001_foundation.sql`.
4. Keep RLS enabled. This migration intentionally creates no permissive policies; later stages add policies feature by feature.
5. Configure Auth providers only when implementing Stage 3.

## Environment variables
Copy `.env.example` to `.env.local`.
- `NEXT_PUBLIC_SUPABASE_URL`: Supabase project URL.
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`: Supabase publishable/anon key. Safe for browser use when RLS is correctly configured.
- `SUPABASE_SERVICE_ROLE_KEY`: server-only secret; never expose it to browser code.
- `OPENAI_API_KEY`: server-only key for HYSI AI.
- `OWNER_BOOTSTRAP_SECRET`: controlled owner provisioning secret, used only by a protected server workflow in a later stage.
- `APP_ACTION_SECRET`: long random server secret for signed actions.

Do not commit `.env.local`.

## Current routes
- `/` — branded entry page
- `/player` — clearly marked upcoming player portal
- `/admin` — clearly marked restricted admin placeholder; grants no privileges

## Stage 1 files
See `docs/ARCHITECTURE.md` for the planned module boundaries and security model.

## Important security design
- Public signup will always create a `player`, never an `owner`.
- Admin authorization will be checked on the server and in database policies.
- Room credentials are isolated in `private_room_credentials`; encrypt values before storing them.
- Coin changes will use an append-only ledger and idempotency keys.
- RLS is enabled on all application tables. No broad allow-all policies are included.

## Verification
```bash
npm run typecheck
npm run build
```
A successful Stage 1 build verifies the scaffold only. It does not certify later-stage functionality or a deployed system.
