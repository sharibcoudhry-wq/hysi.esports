-- HYSI ESPORTS / Stage 1 foundation
-- Apply in Supabase SQL Editor or via Supabase CLI.
-- This migration intentionally creates the schema foundation only.
-- Policies are restrictive by default; later stages add narrowly scoped policies.

create extension if not exists pgcrypto;

create type public.app_role as enum ('owner', 'moderator', 'player');
create type public.tournament_mode as enum ('solo', 'duo', 'squad');
create type public.tournament_status as enum (
  'draft', 'upcoming', 'registration_open', 'full', 'live',
  'completed', 'cancelled'
);
create type public.registration_status as enum ('confirmed', 'waitlisted', 'cancelled');
create type public.report_status as enum ('open', 'reviewing', 'resolved', 'rejected');

create sequence if not exists public.hysi_player_number_seq start 1;

create or replace function public.generate_hysi_player_id()
returns text
language sql
volatile
as $$
  select 'HYSI-' || lpad(nextval('public.hysi_player_number_seq')::text, 6, '0');
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  player_id text not null unique default public.generate_hysi_player_id(),
  username text not null unique,
  avatar_path text,
  free_fire_ign text,
  free_fire_uid text,
  bio varchar(280),
  instagram_url text,
  youtube_url text,
  discord_url text,
  is_profile_public boolean not null default true,
  show_online_status boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_length check (char_length(username) between 3 and 24)
);

create table public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'player',
  granted_by uuid references auth.users(id),
  granted_at timestamptz not null default now()
);

create table public.role_permissions (
  id bigint generated always as identity primary key,
  role public.app_role not null,
  permission_key text not null,
  unique(role, permission_key)
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  constraint season_dates check (ends_at > starts_at)
);

create table public.tournaments (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id),
  season_id uuid references public.seasons(id),
  name text not null,
  description text,
  mode public.tournament_mode not null,
  status public.tournament_status not null default 'draft',
  starts_at timestamptz not null,
  registration_opens_at timestamptz not null,
  registration_closes_at timestamptz not null,
  total_slots integer not null check (total_slots > 0),
  rules text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tournament_registration_dates check (registration_closes_at > registration_opens_at),
  constraint tournament_start_after_registration check (starts_at >= registration_closes_at)
);

create table public.tournament_registrations (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  slot_number integer,
  status public.registration_status not null default 'confirmed',
  registered_at timestamptz not null default now(),
  cancelled_at timestamptz,
  unique(tournament_id, player_id),
  unique(tournament_id, slot_number),
  constraint valid_slot_number check (slot_number is null or slot_number > 0)
);

-- Room secrets are isolated from public tournament records.
-- Encrypt room_id / room_password in application code before inserting.
create table public.private_room_credentials (
  tournament_id uuid primary key references public.tournaments(id) on delete cascade,
  room_id_ciphertext text not null,
  room_password_ciphertext text not null,
  opens_at timestamptz not null,
  instructions text,
  updated_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now()
);

create table public.tournament_messages (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  body text not null check (char_length(body) between 1 and 2000),
  is_announcement boolean not null default false,
  is_pinned boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.direct_conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.direct_conversation_members (
  conversation_id uuid not null references public.direct_conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  accepted_at timestamptz,
  last_read_at timestamptz,
  primary key(conversation_id, user_id)
);

create table public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.direct_conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  body text check (body is null or char_length(body) <= 4000),
  attachment_path text,
  created_at timestamptz not null default now(),
  constraint message_has_content check (coalesce(char_length(body), 0) > 0 or attachment_path is not null)
);

create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (sender_id <> receiver_id),
  unique(sender_id, receiver_id)
);

create table public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followed_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(follower_id, followed_id),
  check (follower_id <> followed_id)
);

create table public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table public.clans (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  tag varchar(6) not null unique,
  description text,
  owner_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.clan_members (
  clan_id uuid not null references public.clans(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  member_role text not null default 'member' check (member_role in ('leader','officer','member')),
  joined_at timestamptz not null default now(),
  primary key(clan_id, user_id)
);

create table public.squads (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid references public.clans(id) on delete set null,
  name text not null,
  captain_id uuid not null references public.profiles(id),
  recruitment_open boolean not null default false,
  requirements text,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null,
  href text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.coin_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  amount integer not null check (amount <> 0),
  reason text not null,
  reference_type text,
  reference_id uuid,
  idempotency_key text not null unique,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.daily_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  checkin_date date not null,
  coin_ledger_id uuid references public.coin_ledger(id),
  created_at timestamptz not null default now(),
  unique(user_id, checkin_date)
);

create table public.missions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  mission_type text not null,
  reward_coins integer not null default 0 check (reward_coins >= 0),
  reward_xp integer not null default 0 check (reward_xp >= 0),
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true
);

create table public.player_missions (
  user_id uuid not null references public.profiles(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete cascade,
  progress integer not null default 0 check (progress >= 0),
  completed_at timestamptz,
  claimed_at timestamptz,
  primary key(user_id, mission_id)
);

create table public.match_submissions (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id),
  submitted_by uuid not null references public.profiles(id),
  screenshot_path text not null,
  notes text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now()
);

create table public.verified_results (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id),
  player_id uuid not null references public.profiles(id),
  placement integer not null check (placement > 0),
  kills integer not null default 0 check (kills >= 0),
  points integer not null default 0 check (points >= 0),
  mvp boolean not null default false,
  verified_by uuid not null references auth.users(id),
  verified_at timestamptz not null default now(),
  unique(tournament_id, player_id)
);

create table public.leaderboard_snapshots (
  id uuid primary key default gen_random_uuid(),
  season_id uuid references public.seasons(id),
  period_type text not null check (period_type in ('weekly','monthly','season','all_time')),
  calculated_at timestamptz not null default now(),
  payload jsonb not null
);

create table public.badges (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text not null,
  icon_path text
);

create table public.player_badges (
  user_id uuid not null references public.profiles(id) on delete cascade,
  badge_id uuid not null references public.badges(id),
  awarded_by uuid references auth.users(id),
  awarded_at timestamptz not null default now(),
  primary key(user_id, badge_id)
);

create table public.certificates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  tournament_id uuid references public.tournaments(id),
  season_id uuid references public.seasons(id),
  certificate_code text not null unique,
  file_path text,
  issued_by uuid not null references auth.users(id),
  issued_at timestamptz not null default now()
);

create table public.youtube_streams (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  youtube_video_id text not null,
  scheduled_at timestamptz,
  status text not null check (status in ('upcoming','live','completed')),
  tournament_id uuid references public.tournaments(id) on delete set null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id),
  target_user_id uuid references public.profiles(id),
  target_message_id uuid,
  target_type text not null check (target_type in ('player','profile','message','clan')),
  reason text not null,
  details text,
  status public.report_status not null default 'open',
  assigned_to uuid references auth.users(id),
  resolved_by uuid references auth.users(id),
  resolution_note text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  subject text not null,
  body text not null,
  status text not null default 'open' check (status in ('open','in_progress','closed')),
  assigned_to uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.admin_audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid not null references auth.users(id),
  action text not null,
  target_type text,
  target_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Helpful indexes for common lookups.
create index profiles_username_search_idx on public.profiles using btree (lower(username));
create index tournament_status_start_idx on public.tournaments(status, starts_at);
create index registrations_player_idx on public.tournament_registrations(player_id, registered_at desc);
create index tournament_messages_recent_idx on public.tournament_messages(tournament_id, created_at desc);
create index direct_messages_recent_idx on public.direct_messages(conversation_id, created_at desc);
create index notifications_unread_idx on public.notifications(user_id, created_at desc) where read_at is null;
create index reports_queue_idx on public.reports(status, created_at desc);
create index verified_results_player_idx on public.verified_results(player_id, verified_at desc);

-- updated_at helper for tables that carry that column.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger tournaments_set_updated_at before update on public.tournaments
for each row execute function public.set_updated_at();

-- RLS enabled now. Stage-specific migrations add explicit least-privilege policies.
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','user_roles','role_permissions','seasons','tournaments',
    'tournament_registrations','private_room_credentials','tournament_messages',
    'direct_conversations','direct_conversation_members','direct_messages',
    'friend_requests','follows','user_blocks','clans','clan_members','squads',
    'notifications','coin_ledger','daily_checkins','missions','player_missions',
    'match_submissions','verified_results','leaderboard_snapshots','badges',
    'player_badges','certificates','youtube_streams','reports','support_tickets',
    'admin_audit_logs'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- No broad policies are created here. With RLS enabled and no policy, access is denied.
-- Never disable RLS to make the app "work". Add narrowly scoped policies in later stages.
