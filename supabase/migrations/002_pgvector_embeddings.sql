-- Phase 4: pgvector for semantic search
-- Run after 001_notes_schema.sql
-- Requires pgvector extension (enable in Supabase Dashboard → Database → Extensions if needed)

-- Enable pgvector (Supabase: Database → Extensions → enable "vector" if needed)
create extension if not exists vector;

-- Embeddings table: one row per note
create table if not exists public.note_embeddings (
  note_id uuid primary key references public.notes(id) on delete cascade,
  embedding vector(1536) not null,
  content_hash text,
  created_at timestamptz not null default now()
);

-- Index for cosine similarity search
create index if not exists note_embeddings_embedding_idx 
  on public.note_embeddings 
  using ivfflat (embedding vector_cosine_ops)
  with (lists = 100);

-- RLS: users can only access embeddings for their own notes
alter table public.note_embeddings enable row level security;

create policy "Users can manage own note embeddings"
  on public.note_embeddings
  for all
  using (
    note_id in (select id from public.notes where user_id = auth.uid())
  )
  with check (
    note_id in (select id from public.notes where user_id = auth.uid())
  );

-- RPC: Upsert embedding for a note
create or replace function public.upsert_note_embedding(
  p_note_id uuid,
  p_embedding float[],
  p_content_hash text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.note_embeddings (note_id, embedding, content_hash)
  values (p_note_id, p_embedding::vector, p_content_hash)
  on conflict (note_id) do update set
    embedding = excluded.embedding,
    content_hash = excluded.content_hash;
end;
$$;

-- RPC: Semantic search by embedding (cosine similarity)
create or replace function public.search_notes_by_embedding(
  p_embedding float[],
  p_match_count int default 5,
  p_match_threshold float default 0.5
)
returns table (note_id uuid, similarity float)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select 
    ne.note_id,
    1 - (ne.embedding <=> p_embedding::vector) as similarity
  from public.note_embeddings ne
  join public.notes n on n.id = ne.note_id
  where n.user_id = auth.uid()
    and (1 - (ne.embedding <=> p_embedding::vector)) >= p_match_threshold
  order by ne.embedding <=> p_embedding::vector
  limit p_match_count;
end;
$$;
