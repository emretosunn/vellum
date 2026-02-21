-- =====================================================
-- Vellum: Token → Subscription Migration
-- Supabase SQL Editor'da çalıştırın
-- =====================================================

-- 1. Profiles tablosuna abonelik sütunları ekle
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_pro boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS sub_end_date timestamp with time zone,
ADD COLUMN IF NOT EXISTS stripe_customer_id text;

-- 2. Profiles tablosundan token_balance sütununu kaldır
ALTER TABLE profiles 
DROP COLUMN IF EXISTS token_balance;

-- 3. Books tablosundan total_earnings sütununu kaldır
ALTER TABLE books 
DROP COLUMN IF EXISTS total_earnings;

-- 4. Chapters: bağımlı RLS politikalarını kaldır, sonra sütunları sil
DROP POLICY IF EXISTS "Chapters viewable by authorized users" ON chapters;
DROP POLICY IF EXISTS "chapters_select_policy" ON chapters;

ALTER TABLE chapters 
DROP COLUMN IF EXISTS price,
DROP COLUMN IF EXISTS is_free;

-- Chapters için yeni basit RLS politikası oluştur
CREATE POLICY "Chapters are viewable by everyone"
ON chapters FOR SELECT
USING (true);

-- 5. Transactions tablosunu kaldır (artık gerekli değil)
DROP TABLE IF EXISTS transactions;

-- 6. Payouts tablosunu kaldır (artık gerekli değil)
DROP TABLE IF EXISTS payouts;

-- 7. is_pro için index oluştur (hızlı sorgu)
CREATE INDEX IF NOT EXISTS idx_profiles_is_pro 
ON profiles(is_pro) WHERE is_pro = true;

-- 8. sub_end_date için index (süresi dolan abonelikleri bulmak için)
CREATE INDEX IF NOT EXISTS idx_profiles_sub_end_date 
ON profiles(sub_end_date) WHERE sub_end_date IS NOT NULL;

-- 9. Profil düzenleme: avatar_url, bio, links sütunları ekle
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS avatar_url text,
ADD COLUMN IF NOT EXISTS bio text DEFAULT '',
ADD COLUMN IF NOT EXISTS links jsonb DEFAULT '[]'::jsonb;

-- 10. Avatarlar ve kitap kapakları için Storage bucket'ları
-- NOT: supabase_storage_buckets.sql dosyasını SQL Editor'da çalıştırın
-- (avatars + book-covers bucket'ları ve politikaları)

-- 11. Abonelik durumunu kontrol eden fonksiyon
CREATE OR REPLACE FUNCTION check_subscription(user_id uuid)
RETURNS boolean AS $$
DECLARE
  user_is_pro boolean;
  user_sub_end timestamp with time zone;
BEGIN
  SELECT is_pro, sub_end_date 
  INTO user_is_pro, user_sub_end
  FROM profiles 
  WHERE id = user_id;
  
  IF user_is_pro IS NOT TRUE THEN
    RETURN false;
  END IF;
  
  IF user_sub_end IS NULL THEN
    RETURN user_is_pro;
  END IF;
  
  RETURN user_sub_end > now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
