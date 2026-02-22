-- ============================================================
-- Kitaplar: Görüntülenme sayısı ve Beğeni sistemi
-- Supabase SQL Editor'da çalıştırın.
-- ============================================================

-- 1. Books tablosuna view_count ekle
ALTER TABLE books
  ADD COLUMN IF NOT EXISTS view_count integer NOT NULL DEFAULT 0;

-- 2. Beğeniler için book_likes tablosu (bir kullanıcı bir kitabı bir kez beğenir)
CREATE TABLE IF NOT EXISTS book_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id uuid NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(book_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_book_likes_book_id ON book_likes(book_id);
CREATE INDEX IF NOT EXISTS idx_book_likes_user_id ON book_likes(user_id);

-- RLS
ALTER TABLE book_likes ENABLE ROW LEVEL SECURITY;

-- Politikaları varsa kaldır, sonra yeniden oluştur (script tekrar çalıştırılabilir)
DROP POLICY IF EXISTS "book_likes_select" ON book_likes;
DROP POLICY IF EXISTS "book_likes_insert" ON book_likes;
DROP POLICY IF EXISTS "book_likes_delete" ON book_likes;

-- Herkes beğeni sayısını görebilir (SELECT)
CREATE POLICY "book_likes_select"
ON book_likes FOR SELECT
TO public
USING (true);

-- Sadece giriş yapmış kullanıcı kendi beğenisini ekleyebilir
CREATE POLICY "book_likes_insert"
ON book_likes FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Sadece kendi beğenisini silebilir (beğeniyi kaldırma)
CREATE POLICY "book_likes_delete"
ON book_likes FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- 3. Görüntülenme sayısı artırma (kitap detay açıldığında çağrılır)
CREATE OR REPLACE FUNCTION increment_book_view(book_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE books SET view_count = COALESCE(view_count, 0) + 1 WHERE id = book_id;
$$;
