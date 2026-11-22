-- Catalog and lessons for Artura.
-- Images live in the public storage bucket "artworks": <slug>/zoom.jpg, <slug>/large.jpg, <slug>/thumb.jpg

create table public.movements (
  id text primary key,
  name text not null,
  period text,
  summary text,
  description text,
  sort_order int not null default 0
);

create table public.artworks (
  slug text primary key,
  movement_id text not null references public.movements(id),
  title text not null,
  artist text not null,
  year int,
  year_label text,
  museum text,
  kind text not null default '2d' check (kind in ('2d','sculpture')),
  zoom_width int,
  zoom_height int,
  wikidata_qid text,
  commons_page text,
  license text,
  attribution_required boolean not null default false,
  author text,
  credit text,
  image_match text,
  image_note text,
  teaser text,
  focus_x real,
  focus_y real,
  created_at timestamptz not null default now()
);
create index artworks_movement_idx on public.artworks(movement_id);

create table public.lessons (
  artwork_slug text primary key references public.artworks(slug) on delete cascade,
  language text not null default 'en',
  status text not null default 'draft' check (status in ('draft','published')),
  review_notes text,
  updated_at timestamptz not null default now()
);

-- payload holds interactive data in normalised 0..1 image coordinates:
-- {"spots":[{x,y,zoom,r,shape,title,text}]} for tour/find/explore, {"lines":[{points,closed,label,text}]} for lines
create table public.lesson_blocks (
  artwork_slug text not null references public.lessons(artwork_slug) on delete cascade,
  position int not null,
  type text not null check (type in ('text','key','fact','image','tour','find','lines','explore')),
  title text,
  body text,
  payload jsonb not null default '{}'::jsonb,
  primary key (artwork_slug, position)
);

create table public.quiz_questions (
  artwork_slug text not null references public.lessons(artwork_slug) on delete cascade,
  position int not null,
  question text not null,
  options jsonb not null,
  answer_index int not null,
  explanation text,
  primary key (artwork_slug, position)
);

create table public.true_false_facts (
  artwork_slug text not null references public.lessons(artwork_slug) on delete cascade,
  position int not null,
  statement text not null,
  is_true boolean not null,
  explanation text,
  primary key (artwork_slug, position)
);

alter table public.movements enable row level security;
alter table public.artworks enable row level security;
alter table public.lessons enable row level security;
alter table public.lesson_blocks enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.true_false_facts enable row level security;

create policy "public read" on public.movements for select to anon, authenticated using (true);
create policy "public read" on public.artworks for select to anon, authenticated using (true);
create policy "public read published" on public.lessons for select to anon, authenticated using (status = 'published');
create policy "public read published" on public.lesson_blocks for select to anon, authenticated
  using (exists (select 1 from public.lessons l where l.artwork_slug = lesson_blocks.artwork_slug and l.status = 'published'));
create policy "public read published" on public.quiz_questions for select to anon, authenticated
  using (exists (select 1 from public.lessons l where l.artwork_slug = quiz_questions.artwork_slug and l.status = 'published'));
create policy "public read published" on public.true_false_facts for select to anon, authenticated
  using (exists (select 1 from public.lessons l where l.artwork_slug = true_false_facts.artwork_slug and l.status = 'published'));

create schema if not exists private;

-- Loads one lesson file (catalog/lessons/<slug>.json) in a single call:
--   select private.upsert_lesson('<slug>', '<file content>'::jsonb);
create or replace function private.upsert_lesson(p_slug text, p jsonb)
returns text language plpgsql set search_path = '' as $$
declare n_blocks int; n_quiz int; n_facts int;
begin
  if not exists (select 1 from public.artworks where slug = p_slug) then
    raise exception 'unknown artwork %', p_slug;
  end if;
  update public.artworks set
    teaser = coalesce(p->>'teaser', teaser),
    focus_x = coalesce((p->'focus'->>0)::real, focus_x),
    focus_y = coalesce((p->'focus'->>1)::real, focus_y)
  where slug = p_slug;
  insert into public.lessons(artwork_slug, review_notes, updated_at)
  values (p_slug, p->>'review_notes', now())
  on conflict (artwork_slug) do update set review_notes = excluded.review_notes, updated_at = now();
  delete from public.lesson_blocks where artwork_slug = p_slug;
  delete from public.quiz_questions where artwork_slug = p_slug;
  delete from public.true_false_facts where artwork_slug = p_slug;
  insert into public.lesson_blocks(artwork_slug, position, type, title, body, payload)
  select p_slug, ord::int, b->>'type', b->>'title', b->>'text', b - 'type' - 'title' - 'text'
  from jsonb_array_elements(p->'lesson') with ordinality as t(b, ord);
  get diagnostics n_blocks = row_count;
  insert into public.quiz_questions(artwork_slug, position, question, options, answer_index, explanation)
  select p_slug, ord::int, q->>'question', q->'options', (q->>'answer')::int, q->>'explanation'
  from jsonb_array_elements(p->'quiz') with ordinality as t(q, ord);
  get diagnostics n_quiz = row_count;
  insert into public.true_false_facts(artwork_slug, position, statement, is_true, explanation)
  select p_slug, ord::int, f->>'text', (f->>'isTrue')::boolean, f->>'explanation'
  from jsonb_array_elements(p->'facts') with ordinality as t(f, ord);
  get diagnostics n_facts = row_count;
  return format('%s: %s blocks, %s quiz, %s facts', p_slug, n_blocks, n_quiz, n_facts);
end $$;
