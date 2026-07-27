-- Создайте таблицы в Supabase SQL Editor

CREATE TABLE expenses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    date DATE NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Прочее',
    payer TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    split_mode TEXT NOT NULL DEFAULT 'equal',
    participants TEXT[] NOT NULL,
    splits JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS политики (Row Level Security)
-- Для простого калькулятора поездки разрешим все операции без авторизации
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations" ON expenses
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Индекс для быстрой сортировки по дате
CREATE INDEX idx_expenses_date ON expenses(date DESC);

-- ============================================
-- Личные траты участников (не входят в общий котёл)
-- ============================================

CREATE TABLE personal_expenses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    person TEXT NOT NULL,
    date DATE NOT NULL,
    category TEXT NOT NULL DEFAULT 'Прочее',
    description TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE personal_expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations" ON personal_expenses
    FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE INDEX idx_personal_expenses_person ON personal_expenses(person);
CREATE INDEX idx_personal_expenses_date ON personal_expenses(date DESC);

-- ============================================
-- Участники поездки (редактируются из приложения)
-- ============================================

CREATE TABLE participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations" ON participants
    FOR ALL
    USING (true)
    WITH CHECK (true);

INSERT INTO participants (name, sort_order) VALUES
    ('Тимур', 0),
    ('Наташа', 1),
    ('Андрей', 2),
    ('Рома', 3),
    ('Санёк', 4);

-- ============================================
-- Взаиморасчёты: кто кому уже вернул деньги
-- ============================================

CREATE TABLE settlements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    from_person TEXT NOT NULL,
    to_person TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations" ON settlements
    FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE INDEX idx_settlements_date ON settlements(date DESC);

-- ============================================
-- Фото чека: прикладывается к расходам, созданным через "Скан чека"
-- ============================================

alter table expenses add column if not exists receipt_photos text[];

insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', true)
on conflict (id) do nothing;

drop policy if exists "Public read access on receipts" on storage.objects;
create policy "Public read access on receipts"
on storage.objects for select
using (bucket_id = 'receipts');

drop policy if exists "Anon can upload receipts" on storage.objects;
create policy "Anon can upload receipts"
on storage.objects for insert
with check (bucket_id = 'receipts');

-- ============================================
-- Realtime: мгновенные обновления у всех участников
-- (входит в бесплатный тариф Supabase)
-- ============================================

ALTER PUBLICATION supabase_realtime ADD TABLE expenses;
ALTER PUBLICATION supabase_realtime ADD TABLE personal_expenses;
ALTER PUBLICATION supabase_realtime ADD TABLE participants;
ALTER PUBLICATION supabase_realtime ADD TABLE settlements;
