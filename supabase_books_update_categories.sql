-- Vellum kitap kategorileri güncelleme script'i
-- Eski kategori etiketlerini yeni yapıya uyarlamak için.
-- Supabase SQL Editor'da tek seferlik çalıştırın.

-- 'Öykü' ve 'Şiir' kategorilerini daha genel 'Diğer' altına taşı.
UPDATE books
SET category = 'Diğer'
WHERE category IN ('Öykü', 'Şiir');

