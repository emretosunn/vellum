-- profiles tablosuna, kullanıcı ilk kez kayıt/oturum sonrası kişiselleştirme akışını
-- tamamladı mı bilgisini ekler.

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS signup_setup_completed boolean NOT NULL DEFAULT false;

