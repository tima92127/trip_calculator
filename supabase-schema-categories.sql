-- Миграция: редактируемые категории расходов (вместо захардкоженного списка).
-- Примените в Supabase SQL Editor один раз, если проект уже был создан
-- до появления этой функции.

create table if not exists categories (
    id uuid default gen_random_uuid() primary key,
    name text not null unique,
    sort_order integer not null default 0,
    created_at timestamptz default now()
);

alter table categories enable row level security;

drop policy if exists "Allow all operations" on categories;
create policy "Allow all operations" on categories
    for all
    using (true)
    with check (true);

insert into categories (name, sort_order)
select * from (values
    ('Жильё', 0),
    ('Транспорт', 1),
    ('Еда', 2),
    ('Развлечения', 3),
    ('Прочее', 4)
) as seed(name, sort_order)
where not exists (select 1 from categories);

do $$ begin
    alter publication supabase_realtime add table categories;
exception
    when duplicate_object then null;
end $$;
