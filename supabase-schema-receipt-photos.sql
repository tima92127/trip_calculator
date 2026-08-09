-- Миграция: фото чека к расходам, созданным через "Скан чека".
-- Примените в Supabase SQL Editor один раз, если проект уже был создан
-- до появления этой функции (для новых проектов это уже не нужно, если
-- дата создания schema после добавления этого файла).

alter table expenses add column if not exists receipt_photos text[];
alter table personal_expenses add column if not exists receipt_photos text[];

insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', true)
on conflict (id) do nothing;

-- Bucket публичный на чтение и открытый на запись анонимным ключом —
-- как и все таблицы в этом проекте (см. supabase-schema.sql: везде
-- "FOR ALL USING (true)"), приложение не использует авторизацию.
drop policy if exists "Public read access on receipts" on storage.objects;
create policy "Public read access on receipts"
on storage.objects for select
using (bucket_id = 'receipts');

drop policy if exists "Anon can upload receipts" on storage.objects;
create policy "Anon can upload receipts"
on storage.objects for insert
with check (bucket_id = 'receipts');
