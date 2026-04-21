ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS birth_date date;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS age integer;

COMMENT ON COLUMN public.profiles.birth_date IS 'Kullanicinin dogum tarihi (signup setup)';
COMMENT ON COLUMN public.profiles.age IS 'Kullanicinin yasi (dogum tarihinden hesaplanmis)';
