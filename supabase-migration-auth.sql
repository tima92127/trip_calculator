-- Выполните один раз в SQL Editor вашего существующего проекта Supabase,
-- чтобы включить обязательный вход по email для изменения данных.
-- Чтение (просмотр расходов) остаётся открытым всем по ссылке, как раньше —
-- меняется только то, что добавлять/редактировать/удалять сможет лишь тот,
-- чей email указан здесь у одного из участников.

ALTER TABLE participants ADD COLUMN IF NOT EXISTS email TEXT UNIQUE;

-- Впишите реальные email участников поездки и выполните эти строки:
-- UPDATE participants SET email = 'имя@example.com' WHERE name = 'Тимур';
-- UPDATE participants SET email = 'имя@example.com' WHERE name = 'Наташа';
-- UPDATE participants SET email = 'имя@example.com' WHERE name = 'Андрей';
-- UPDATE participants SET email = 'имя@example.com' WHERE name = 'Рома';
-- UPDATE participants SET email = 'имя@example.com' WHERE name = 'Санёк';

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

DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY['expenses', 'personal_expenses', 'participants', 'settlements'] LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Allow all operations" ON %I', t);
        EXECUTE format('CREATE POLICY "Public read" ON %I FOR SELECT USING (true)', t);
        EXECUTE format('CREATE POLICY "Members can insert" ON %I FOR INSERT WITH CHECK (is_trip_member())', t);
        EXECUTE format('CREATE POLICY "Members can update" ON %I FOR UPDATE USING (is_trip_member()) WITH CHECK (is_trip_member())', t);
        EXECUTE format('CREATE POLICY "Members can delete" ON %I FOR DELETE USING (is_trip_member())', t);
    END LOOP;
END $$;
