-- books tablosuna dil/bölge filtresi için kolon ekler.
-- Kod eşlemesi:
-- tr  -> Türkiye
-- en  -> Amerika
-- de  -> Almanya
-- fr  -> Fransa
-- ru  -> Rusya
-- es  -> İspanya
-- other -> Diğer

ALTER TABLE public.books
ADD COLUMN IF NOT EXISTS language_code text NOT NULL DEFAULT 'tr';

-- Mevcut veriler için boş/null kalmasın diye (kolon yeni eklenmişse zaten default var)
UPDATE public.books
SET language_code = 'tr'
WHERE language_code IS NULL;

