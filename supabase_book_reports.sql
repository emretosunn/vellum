-- Kitap şikayetleri ve geliştirici kimliği.
-- Supabase SQL Editor'da çalıştırın.

-- 1) profiles tablosuna is_developer sütunu
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_developer BOOLEAN DEFAULT false;

-- 2) Kitap şikayetleri tablosu
CREATE TABLE IF NOT EXISTS book_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  reporter_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'read')),
  read_at TIMESTAMPTZ,
  read_by_user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_book_reports_created_at ON book_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_book_reports_status ON book_reports(status);

-- RLS: Herkes kendi şikayetini görebilir; developer olanlar tümünü görebilir (policy uygulama tarafında filtre ile).
ALTER TABLE book_reports ENABLE ROW LEVEL SECURITY;

-- Kullanıcı kendi şikayetini ekleyebilir
CREATE POLICY "Users can insert own report"
  ON book_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_user_id);

-- Geliştirici (profiles.is_developer = true) tüm şikayetleri okuyabilir ve güncelleyebilir
CREATE POLICY "Developers can read all reports"
  ON book_reports FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.is_developer = true
    )
  );

CREATE POLICY "Developers can update reports"
  ON book_reports FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.is_developer = true
    )
  );

-- Geliştirici olmayan sadece kendi şikayetlerini görebilir (isteğe bağlı)
CREATE POLICY "Users can read own reports"
  ON book_reports FOR SELECT
  USING (auth.uid() = reporter_user_id);
