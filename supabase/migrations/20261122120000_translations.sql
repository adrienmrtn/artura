-- Translations of the catalog (fr, it, es, de). English stays in the base tables.
-- Same row shapes as the English tables, with a language column: the app reads either set with the same code.

create table public.movement_translations (
  movement_id text not null references public.movements(id) on delete cascade,
  language text not null check (language in ('fr','it','es','de')),
  name text not null,
  period text,
  summary text,
  description text,
  primary key (movement_id, language)
);

create table public.artwork_translations (
  artwork_slug text not null references public.artworks(slug) on delete cascade,
  language text not null check (language in ('fr','it','es','de')),
  title text not null,
  artist text not null,
  year_label text,
  museum text,
  teaser text,
  primary key (artwork_slug, language)
);
create index artwork_translations_language_idx on public.artwork_translations(language);

create table public.lesson_translations (
  artwork_slug text not null references public.lessons(artwork_slug) on delete cascade,
  language text not null check (language in ('fr','it','es','de')),
  status text not null default 'draft' check (status in ('draft','published')),
  updated_at timestamptz not null default now(),
  primary key (artwork_slug, language)
);
create index lesson_translations_language_idx on public.lesson_translations(language);

create table public.lesson_block_translations (
  artwork_slug text not null,
  language text not null,
  position int not null,
  type text not null check (type in ('text','key','fact','image','tour','find','lines','explore')),
  title text,
  body text,
  payload jsonb not null default '{}'::jsonb,
  primary key (artwork_slug, language, position),
  foreign key (artwork_slug, language) references public.lesson_translations(artwork_slug, language) on delete cascade
);

create table public.quiz_question_translations (
  artwork_slug text not null,
  language text not null,
  position int not null,
  question text not null,
  options jsonb not null,
  answer_index int not null,
  explanation text,
  primary key (artwork_slug, language, position),
  foreign key (artwork_slug, language) references public.lesson_translations(artwork_slug, language) on delete cascade
);

create table public.true_false_fact_translations (
  artwork_slug text not null,
  language text not null,
  position int not null,
  statement text not null,
  is_true boolean not null,
  explanation text,
  primary key (artwork_slug, language, position),
  foreign key (artwork_slug, language) references public.lesson_translations(artwork_slug, language) on delete cascade
);

alter table public.movement_translations enable row level security;
alter table public.artwork_translations enable row level security;
alter table public.lesson_translations enable row level security;
alter table public.lesson_block_translations enable row level security;
alter table public.quiz_question_translations enable row level security;
alter table public.true_false_fact_translations enable row level security;

grant select on public.movement_translations, public.artwork_translations, public.lesson_translations,
  public.lesson_block_translations, public.quiz_question_translations, public.true_false_fact_translations
  to anon, authenticated;

create policy "public read" on public.movement_translations for select to anon, authenticated using (true);
create policy "public read" on public.artwork_translations for select to anon, authenticated using (true);
create policy "public read published" on public.lesson_translations for select to anon, authenticated using (status = 'published');
create policy "public read published" on public.lesson_block_translations for select to anon, authenticated
  using (exists (select 1 from public.lesson_translations l where l.artwork_slug = lesson_block_translations.artwork_slug
                 and l.language = lesson_block_translations.language and l.status = 'published'));
create policy "public read published" on public.quiz_question_translations for select to anon, authenticated
  using (exists (select 1 from public.lesson_translations l where l.artwork_slug = quiz_question_translations.artwork_slug
                 and l.language = quiz_question_translations.language and l.status = 'published'));
create policy "public read published" on public.true_false_fact_translations for select to anon, authenticated
  using (exists (select 1 from public.lesson_translations l where l.artwork_slug = true_false_fact_translations.artwork_slug
                 and l.language = true_false_fact_translations.language and l.status = 'published'));

-- Loads one translated lesson (catalog/translations/build/<lang>/<slug>.json, same format as an English
-- lesson file, plus "meta": {title, artist, year_label, museum}):
--   select private.upsert_lesson_translation('<slug>', '<lang>', '<file content>'::jsonb);
create or replace function private.upsert_lesson_translation(p_slug text, p_lang text, p jsonb)
returns text language plpgsql set search_path = '' as $$
declare n_blocks int; n_quiz int; n_facts int;
begin
  if not exists (select 1 from public.lessons where artwork_slug = p_slug) then
    raise exception 'unknown lesson %', p_slug;
  end if;
  insert into public.artwork_translations(artwork_slug, language, title, artist, year_label, museum, teaser)
  values (p_slug, p_lang, p->'meta'->>'title', p->'meta'->>'artist', p->'meta'->>'year_label', p->'meta'->>'museum', p->>'teaser')
  on conflict (artwork_slug, language) do update set title = excluded.title, artist = excluded.artist,
    year_label = excluded.year_label, museum = excluded.museum, teaser = excluded.teaser;
  insert into public.lesson_translations(artwork_slug, language, status, updated_at)
  values (p_slug, p_lang, 'published', now())
  on conflict (artwork_slug, language) do update set updated_at = now();
  delete from public.lesson_block_translations where artwork_slug = p_slug and language = p_lang;
  delete from public.quiz_question_translations where artwork_slug = p_slug and language = p_lang;
  delete from public.true_false_fact_translations where artwork_slug = p_slug and language = p_lang;
  insert into public.lesson_block_translations(artwork_slug, language, position, type, title, body, payload)
  select p_slug, p_lang, ord::int, b->>'type', b->>'title', b->>'text', b - 'type' - 'title' - 'text'
  from jsonb_array_elements(p->'lesson') with ordinality as t(b, ord);
  get diagnostics n_blocks = row_count;
  insert into public.quiz_question_translations(artwork_slug, language, position, question, options, answer_index, explanation)
  select p_slug, p_lang, ord::int, q->>'question', q->'options', (q->>'answer')::int, q->>'explanation'
  from jsonb_array_elements(p->'quiz') with ordinality as t(q, ord);
  get diagnostics n_quiz = row_count;
  insert into public.true_false_fact_translations(artwork_slug, language, position, statement, is_true, explanation)
  select p_slug, p_lang, ord::int, f->>'text', (f->>'isTrue')::boolean, f->>'explanation'
  from jsonb_array_elements(p->'facts') with ordinality as t(f, ord);
  get diagnostics n_facts = row_count;
  return format('%s/%s: %s blocks, %s quiz, %s facts', p_slug, p_lang, n_blocks, n_quiz, n_facts);
end $$;

-- Loads the movements of one language: {"<movement id>": {name, period, summary, description}}
create or replace function private.upsert_movement_translations(p_lang text, p jsonb)
returns int language plpgsql set search_path = '' as $$
declare n int;
begin
  insert into public.movement_translations(movement_id, language, name, period, summary, description)
  select key, p_lang, value->>'name', value->>'period', value->>'summary', value->>'description'
  from jsonb_each(p)
  on conflict (movement_id, language) do update set name = excluded.name, period = excluded.period,
    summary = excluded.summary, description = excluded.description;
  get diagnostics n = row_count;
  return n;
end $$;
