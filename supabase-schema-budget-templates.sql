-- Миграция: личный бюджет участника (сравнение ожиданий с реальностью
-- на вкладке «Личное») + шаблоны быстрых трат (готовые кнопки в форме
-- добавления расхода). Примените в Supabase SQL Editor один раз.

alter table participants add column if not exists budget numeric;

create table if not exists expense_templates (
    id uuid default gen_random_uuid() primary key,
    trip_id uuid not null references trips(id) on delete cascade,
    label text not null,
    category text not null,
    sort_order integer not null default 0,
    created_at timestamptz default now(),
    unique (trip_id, label)
);

alter table expense_templates enable row level security;

drop policy if exists "Allow all operations" on expense_templates;
create policy "Allow all operations" on expense_templates
    for all
    using (true)
    with check (true);

create index if not exists idx_expense_templates_trip_id on expense_templates(trip_id);

-- Несколько шаблонов по умолчанию для каждой уже существующей поездки,
-- если у неё ещё нет ни одного шаблона.
insert into expense_templates (trip_id, label, category, sort_order)
select t.id, seed.label, seed.category, seed.sort_order
from trips t
cross join (values
    ('Такси', 'Транспорт', 0),
    ('Кафе', 'Еда', 1),
    ('Жильё', 'Жильё', 2)
) as seed(label, category, sort_order)
where not exists (select 1 from expense_templates et where et.trip_id = t.id)
  and exists (select 1 from categories c where c.trip_id = t.id and c.name = seed.category);

do $$ begin
    alter publication supabase_realtime add table expense_templates;
exception
    when duplicate_object then null;
end $$;
