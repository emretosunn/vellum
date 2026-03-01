-- =====================================================
-- Vellum: Okunan Kitaplar (user_read_books)
-- Kullanıcının bitirdiği kitapları saklar.
-- Supabase SQL Editor'da çalıştırın.
-- =====================================================

-- 1. Tablo oluştur
CREATE TABLE IF NOT EXISTS user_read_books (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  book_id uuid NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  completed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, book_id)
);

-- 2. Index (kullanıcıya göre sıralı liste)
CREATE INDEX IF NOT EXISTS idx_user_read_books_user_completed
ON user_read_books(user_id, completed_at DESC);

-- 3. RLS etkinleştir
ALTER TABLE user_read_books ENABLE ROW LEVEL SECURITY;

-- 4. Politikalar: Kullanıcı sadece kendi kayıtlarını görebilir/ekleyebilir
CREATE POLICY "Users can view own read books"
ON user_read_books FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own read books"
ON user_read_books FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Upsert için (aynı kitap tekrar bitirildiğinde)
CREATE POLICY "Users can update own read books"
ON user_read_books FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
