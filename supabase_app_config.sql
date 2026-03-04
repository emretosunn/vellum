-- =====================================================
-- Vellum: Uygulama Konfigürasyonu (Bakım + Duyuru)
-- Supabase SQL Editor'da çalıştırın.
-- =====================================================

CREATE TABLE IF NOT EXISTS app_config (
  id text PRIMARY KEY DEFAULT 'global',
  maintenance_enabled boolean NOT NULL DEFAULT false,
  maintenance_message text,
  announcement_enabled boolean NOT NULL DEFAULT false,
  announcement_title text,
  announcement_body text,
  announcement_level text NOT NULL DEFAULT 'info' CHECK (announcement_level IN ('info','success','warning')),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Tek satırlık global config için index gerekmiyor ama ileride çoğalırsa kullanılabilir.

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Herkes konfigürasyonu okuyabilsin (sadece SELECT).
CREATE POLICY "Anyone can read app_config"
ON app_config FOR SELECT
USING (true);

-- Sadece developer kullanıcılar (profiles.is_developer = true) güncelleyebilsin.
CREATE POLICY "Developers can update app_config"
ON app_config FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid() AND profiles.is_developer = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid() AND profiles.is_developer = true
  )
);

