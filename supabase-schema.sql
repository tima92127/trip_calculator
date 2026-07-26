-- Создайте таблицы в Supabase SQL Editor

-- ============================================
-- Участники поездки (редактируются из приложения)
-- ============================================

CREATE TABLE participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    email TEXT UNIQUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO participants (name, sort_order) VALUES
    ('Тимур', 0),
    ('Наташа', 1),
    ('Андрей', 2),
    ('Рома', 3),
    ('Санёк', 4);

-- Email можно не знать заранее — каждый привяжет свою почту сам кнопкой
-- "Это я" на вкладке "Люди" после входа. Но если хотите прописать сразу:
-- UPDATE participants SET email = 'имя@example.com' WHERE name = 'Тимур';

-- Проверяет, что текущий вход (email из JWT) принадлежит участнику поездки.
-- SECURITY DEFINER нужен, чтобы функция могла прочитать participants в обход RLS
-- (иначе при проверке политики на самой таблице participants возникла бы рекурсия).
CREATE OR REPLACE FUNCTION is_trip_member()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM participants
        WHERE email = auth.jwt() ->> 'email'
    );
$$;

-- RLS политики: читать может кто угодно по ссылке, а добавлять/менять/удалять —
-- только тот, кто вошёл под email, указанным здесь у одного из участников.
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read" ON participants FOR SELECT USING (true);
CREATE POLICY "Members can insert" ON participants FOR INSERT WITH CHECK (is_trip_member());
CREATE POLICY "Members can update" ON participants FOR UPDATE USING (is_trip_member()) WITH CHECK (is_trip_member());
CREATE POLICY "Members can delete" ON participants FOR DELETE USING (is_trip_member());

-- Позволяет вошедшему по email самому "занять" ещё не привязанного участника
-- (кнопка "Это я" в приложении) — не нужно заранее знать email всех и вручную
-- прописывать их через UPDATE.
CREATE POLICY "Claim own email" ON participants
    FOR UPDATE
    USING (email IS NULL)
    WITH CHECK (email = auth.jwt() ->> 'email');

-- ============================================
-- Расходы общего котла
-- ============================================

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

ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read" ON expenses FOR SELECT USING (true);
CREATE POLICY "Members can insert" ON expenses FOR INSERT WITH CHECK (is_trip_member());
CREATE POLICY "Members can update" ON expenses FOR UPDATE USING (is_trip_member()) WITH CHECK (is_trip_member());
CREATE POLICY "Members can delete" ON expenses FOR DELETE USING (is_trip_member());

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

CREATE POLICY "Public read" ON personal_expenses FOR SELECT USING (true);
CREATE POLICY "Members can insert" ON personal_expenses FOR INSERT WITH CHECK (is_trip_member());
CREATE POLICY "Members can update" ON personal_expenses FOR UPDATE USING (is_trip_member()) WITH CHECK (is_trip_member());
CREATE POLICY "Members can delete" ON personal_expenses FOR DELETE USING (is_trip_member());

CREATE INDEX idx_personal_expenses_person ON personal_expenses(person);
CREATE INDEX idx_personal_expenses_date ON personal_expenses(date DESC);

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

CREATE POLICY "Public read" ON settlements FOR SELECT USING (true);
CREATE POLICY "Members can insert" ON settlements FOR INSERT WITH CHECK (is_trip_member());
CREATE POLICY "Members can update" ON settlements FOR UPDATE USING (is_trip_member()) WITH CHECK (is_trip_member());
CREATE POLICY "Members can delete" ON settlements FOR DELETE USING (is_trip_member());

CREATE INDEX idx_settlements_date ON settlements(date DESC);

-- ============================================
-- Realtime: мгновенные обновления у всех участников
-- (входит в бесплатный тариф Supabase)
-- ============================================

ALTER PUBLICATION supabase_realtime ADD TABLE expenses;
ALTER PUBLICATION supabase_realtime ADD TABLE personal_expenses;
ALTER PUBLICATION supabase_realtime ADD TABLE participants;
ALTER PUBLICATION supabase_realtime ADD TABLE settlements;
