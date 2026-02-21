-- ============================================================
-- Supabase Storage: avatars ve book-covers bucket'ları
-- ============================================================
-- Bu dosyayı Supabase Dashboard > SQL Editor'da çalıştırın.
-- Böylece profil fotoğrafı ve kitap kapağı yükleyebilirsiniz.
-- ============================================================

-- 1. Bucket'ları oluştur (yoksa)
-- Not: Zaten varsa "duplicate key" hatası alırsınız, o bucket'ı atlayıp devam edin.
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('avatars', 'avatars', true),
  ('book-covers', 'book-covers', true)
ON CONFLICT (id) DO NOTHING;

-- 2. AVATARS bucket politikaları (varsa eski politikaları kaldır)
DROP POLICY IF EXISTS "Avatar dosyaları herkese açık" ON storage.objects;
DROP POLICY IF EXISTS "Kullanıcı kendi avatarını yükleyebilir" ON storage.objects;
DROP POLICY IF EXISTS "Kullanıcı kendi avatarını güncelleyebilir" ON storage.objects;

-- Herkes (anon + authenticated) avatar resimlerini okuyabilsin (public URL için)
CREATE POLICY "Avatar dosyaları herkese açık"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- Sadece giriş yapmış kullanıcı kendi klasörüne (userId/...) yükleyebilsin
CREATE POLICY "Kullanıcı kendi avatarını yükleyebilir"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Kullanıcı kendi avatar dosyasını güncelleyebilsin (upsert için)
CREATE POLICY "Kullanıcı kendi avatarını güncelleyebilir"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 3. BOOK-COVERS bucket politikaları (varsa eski politikaları kaldır)
DROP POLICY IF EXISTS "Kitap kapakları herkese açık" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated kitap kapağı yükleyebilir" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated kitap kapağı güncelleyebilir" ON storage.objects;

-- Herkes kitap kapaklarını okuyabilsin
CREATE POLICY "Kitap kapakları herkese açık"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'book-covers');

-- Giriş yapmış kullanıcılar kitap kapağı yükleyebilsin
CREATE POLICY "Authenticated kitap kapağı yükleyebilir"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'book-covers');

-- Yükleyen güncelleyebilsin (upsert için)
CREATE POLICY "Authenticated kitap kapağı güncelleyebilir"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'book-covers');
