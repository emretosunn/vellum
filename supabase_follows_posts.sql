-- ============================================================
-- Yazar takip (user_follows) ve metin paylaşımı (author_posts)
-- Supabase SQL Editor'da çalıştırın.
-- ============================================================

-- 1. Takip tablosu: follower_id → following_id (yazar)
CREATE TABLE IF NOT EXISTS user_follows (
  follower_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, following_id),
  CONSTRAINT no_self_follow CHECK (follower_id != following_id)
);

CREATE INDEX IF NOT EXISTS idx_user_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_user_follows_following ON user_follows(following_id);

ALTER TABLE user_follows ENABLE ROW LEVEL SECURITY;

-- Takip: kendi takip listeni okuyabilir; takip et / takipten çık kendin yapabilirsin
DROP POLICY IF EXISTS "user_follows_select_own" ON user_follows;
CREATE POLICY "user_follows_select_own"
  ON user_follows FOR SELECT TO authenticated
  USING (auth.uid() = follower_id OR auth.uid() = following_id);

DROP POLICY IF EXISTS "user_follows_insert_own" ON user_follows;
CREATE POLICY "user_follows_insert_own"
  ON user_follows FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = follower_id);

DROP POLICY IF EXISTS "user_follows_delete_own" ON user_follows;
CREATE POLICY "user_follows_delete_own"
  ON user_follows FOR DELETE TO authenticated
  USING (auth.uid() = follower_id);

-- 2. Yazar paylaşımları (sadece metin, Twitter benzeri)
CREATE TABLE IF NOT EXISTS author_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_author_posts_author_id ON author_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_author_posts_created_at ON author_posts(created_at DESC);

ALTER TABLE author_posts ENABLE ROW LEVEL SECURITY;

-- Herkes yayınlanmış postları okuyabilir (içerik sadece metin)
DROP POLICY IF EXISTS "author_posts_select" ON author_posts;
CREATE POLICY "author_posts_select"
  ON author_posts FOR SELECT TO authenticated
  USING (true);

-- Sadece kendi postunu ekleyebilir
DROP POLICY IF EXISTS "author_posts_insert_own" ON author_posts;
CREATE POLICY "author_posts_insert_own"
  ON author_posts FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = author_id);

-- Sadece kendi postunu silebilir (opsiyonel: güncelleme eklenebilir)
DROP POLICY IF EXISTS "author_posts_delete_own" ON author_posts;
CREATE POLICY "author_posts_delete_own"
  ON author_posts FOR DELETE TO authenticated
  USING (auth.uid() = author_id);
