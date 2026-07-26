-- Выполните один раз в SQL Editor вашего существующего проекта Supabase,
-- чтобы включить обязательный вход по email для изменения данных.
-- Чтение (просмотр расходов) остаётся открытым всем по ссылке, как раньше —
-- меняется только то, что добавлять/редактировать/удалять сможет лишь тот,
-- чей email указан здесь у одного из участников.

ALTER TABLE participants ADD COLUMN IF NOT EXISTS email TEXT UNIQUE;

-- Email можно не знать заранее — каждый привяжет свою почту сам кнопкой
-- "Это я" на вкладке "Люди" после входа. Но если хотите прописать сразу:
-- UPDATE participants SET email = 'имя@example.com' WHERE name = 'Тимур';

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

-- Позволяет вошедшему по email самому "занять" ещё не привязанного участника
-- (кнопка "Это я" в приложении) — не нужно заранее знать email всех и вручную
-- прописывать их через UPDATE выше.
CREATE POLICY "Claim own email" ON participants
    FOR UPDATE
    USING (email IS NULL)
    WITH CHECK (email = auth.jwt() ->> 'email');
