-- Миграция: разделение на поездки (сессии) — изолированные наборы
-- участников/категорий/расходов/личных трат/расчётов.
-- Примените в Supabase SQL Editor один раз, если проект уже был создан
-- до появления этой функции.

create table if not exists trips (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    sort_order integer not null default 0,
    created_at timestamptz default now()
);

alter table trips enable row level security;

drop policy if exists "Allow all operations" on trips;
create policy "Allow all operations" on trips
    for all
    using (true)
    with check (true);

-- Создаём дефолтную поездку и переносим в неё все существующие данные,
-- если миграция ещё не применялась (столбца trip_id раньше не было).
do $$
declare
    default_trip_id uuid;
begin
    if not exists (select 1 from information_schema.columns
                    where table_name = 'expenses' and column_name = 'trip_id') then

        insert into trips (name, sort_order) values ('Поездка', 0)
        returning id into default_trip_id;

        alter table expenses add column trip_id uuid;
        alter table personal_expenses add column trip_id uuid;
        alter table participants add column trip_id uuid;
        alter table categories add column trip_id uuid;
        alter table settlements add column trip_id uuid;

        update expenses set trip_id = default_trip_id;
        update personal_expenses set trip_id = default_trip_id;
        update participants set trip_id = default_trip_id;
        update categories set trip_id = default_trip_id;
        update settlements set trip_id = default_trip_id;
    end if;
end $$;

alter table expenses alter column trip_id set not null;
alter table personal_expenses alter column trip_id set not null;
alter table participants alter column trip_id set not null;
alter table categories alter column trip_id set not null;
alter table settlements alter column trip_id set not null;

do $$ begin
    alter table expenses add constraint expenses_trip_id_fkey
        foreign key (trip_id) references trips(id) on delete cascade;
exception when duplicate_object then null; end $$;

do $$ begin
    alter table personal_expenses add constraint personal_expenses_trip_id_fkey
        foreign key (trip_id) references trips(id) on delete cascade;
exception when duplicate_object then null; end $$;

do $$ begin
    alter table participants add constraint participants_trip_id_fkey
        foreign key (trip_id) references trips(id) on delete cascade;
exception when duplicate_object then null; end $$;

do $$ begin
    alter table categories add constraint categories_trip_id_fkey
        foreign key (trip_id) references trips(id) on delete cascade;
exception when duplicate_object then null; end $$;

do $$ begin
    alter table settlements add constraint settlements_trip_id_fkey
        foreign key (trip_id) references trips(id) on delete cascade;
exception when duplicate_object then null; end $$;

create index if not exists idx_expenses_trip_id on expenses(trip_id);
create index if not exists idx_personal_expenses_trip_id on personal_expenses(trip_id);
create index if not exists idx_participants_trip_id on participants(trip_id);
create index if not exists idx_categories_trip_id on categories(trip_id);
create index if not exists idx_settlements_trip_id on settlements(trip_id);

-- Имя участника/категории теперь уникально в рамках поездки, а не глобально.
alter table participants drop constraint if exists participants_name_key;
do $$ begin
    alter table participants add constraint participants_trip_name_key unique (trip_id, name);
exception when duplicate_object then null; end $$;

alter table categories drop constraint if exists categories_name_key;
do $$ begin
    alter table categories add constraint categories_trip_name_key unique (trip_id, name);
exception when duplicate_object then null; end $$;

do $$ begin
    alter publication supabase_realtime add table trips;
exception
    when duplicate_object then null;
end $$;
