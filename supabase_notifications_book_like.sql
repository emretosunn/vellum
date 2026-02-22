-- ============================================================
-- Beğeni bildirimi: book_likes INSERT olduğunda kitap sahibine
-- "X, [Kitap Adı] kitabını beğendi" bildirimi oluşturulur.
-- Supabase SQL Editor'da çalıştırın.
-- ============================================================

-- 1. notifications tablosu yoksa oluştur (uygulama zaten kullanıyor olabilir)
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  type text NOT NULL DEFAULT 'system',
  created_at timestamptz NOT NULL DEFAULT now(),
  is_read boolean NOT NULL DEFAULT false,
  ref_type text,
  ref_id uuid
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- RLS (sadece kendi bildirimlerini görsün/güncellesin)
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select_own" ON notifications;
CREATE POLICY "notifications_select_own"
ON notifications FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "notifications_update_own" ON notifications;
CREATE POLICY "notifications_update_own"
ON notifications FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "notifications_delete_own" ON notifications;
CREATE POLICY "notifications_delete_own"
ON notifications FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Service role / trigger ile ekleme yapılacağı için INSERT policy:
-- Sadece backend (SECURITY DEFINER fonksiyon) ekleyebilsin; kullanıcı kendi adına bildirim ekleyemez.
DROP POLICY IF EXISTS "notifications_insert" ON notifications;
CREATE POLICY "notifications_insert"
ON notifications FOR INSERT
TO authenticated
WITH CHECK (true);
-- Not: Trigger SECURITY DEFINER ile çalıştığı için trigger içinden insert yapılır.
-- İsterseniz INSERT'ı sadece service_role'a bırakıp policy kaldırabilirsiniz;
-- bu durumda trigger fonksiyonu SECURITY DEFINER olmalı (aşağıda öyle).

-- 2. Beğeni bildirimi trigger fonksiyonu
CREATE OR REPLACE FUNCTION notify_on_book_like()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author_id uuid;
  v_book_title text;
  v_liker_username text;
  v_prefs jsonb;
BEGIN
  -- Kitabın yazarı ve başlığını al
  SELECT b.author_id, b.title
  INTO v_author_id, v_book_title
  FROM books b
  WHERE b.id = NEW.book_id;

  -- Kitap bulunamadıysa çık
  IF v_author_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Kendi kitabına beğeni yaptıysa bildirim gönderme
  IF v_author_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  -- Yazarın bildirim tercihi: bookLike kapalıysa bildirim gönderme
  SELECT p.notification_preferences INTO v_prefs
  FROM profiles p
  WHERE p.id = v_author_id;
  IF (v_prefs->>'bookLike')::boolean IS FALSE THEN
    RETURN NEW;
  END IF;

  -- Beğeni yapan kullanıcının adını al
  SELECT COALESCE(p.username, 'Bir okur')
  INTO v_liker_username
  FROM profiles p
  WHERE p.id = NEW.user_id;

  -- Yazar için bildirim ekle
  INSERT INTO notifications (user_id, title, body, type, ref_type, ref_id, is_read)
  VALUES (
    v_author_id,
    'Kitabınız beğenildi',
    v_liker_username || ', "' || COALESCE(v_book_title, 'Kitap') || '" kitabını beğendi.',
    'bookLike',
    'book',
    NEW.book_id,
    false
  );

  RETURN NEW;
END;
$$;

-- 3. book_likes üzerinde trigger
DROP TRIGGER IF EXISTS trigger_notify_on_book_like ON book_likes;
CREATE TRIGGER trigger_notify_on_book_like
  AFTER INSERT ON book_likes
  FOR EACH ROW
  EXECUTE PROCEDURE notify_on_book_like();
