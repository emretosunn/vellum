-- Kitap filtreleme ve içerik uyarıları için books tablosuna yeni sütunlar.
-- Supabase SQL Editor'da çalıştırın.

ALTER TABLE books
  ADD COLUMN IF NOT EXISTS category TEXT,
  ADD COLUMN IF NOT EXISTS is_adult_18 BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS content_warnings TEXT[] DEFAULT '{}';

-- İsteğe bağlı: kategoriye göre indeks (filtreleme performansı)
CREATE INDEX IF NOT EXISTS idx_books_category ON books(category) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS idx_books_is_adult_18 ON books(is_adult_18) WHERE status = 'published';
