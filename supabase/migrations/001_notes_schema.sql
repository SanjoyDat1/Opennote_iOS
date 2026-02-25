-- OpenNote Clinical: Notes table and Row Level Security
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)

-- Notes table
create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Untitled Note',
  blocks_payload jsonb not null default '[]',
  updated_at timestamptz not null default now()
);

-- Index for efficient user lookups
create index if not exists notes_user_id_idx on public.notes(user_id);
create index if not exists notes_updated_at_idx on public.notes(updated_at desc);

-- Enable Row Level Security (RLS)
alter table public.notes enable row level security;

-- Policy: Users can only access their own notes
create policy "Users can view own notes"
  on public.notes for select
  using (auth.uid() = user_id);

create policy "Users can insert own notes"
  on public.notes for insert
  with check (auth.uid() = user_id);

create policy "Users can update own notes"
  on public.notes for update
  using (auth.uid() = user_id);

create policy "Users can delete own notes"
  on public.notes for delete
  using (auth.uid() = user_id);
