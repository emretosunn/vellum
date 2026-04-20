-- Profil kullanıcı adını global olarak benzersiz yapar (case-insensitive).
-- Böylece bir kullanici adi bir kez alındıktan sonra başkası alamaz.

CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_unique_lower
ON public.profiles (lower(username));
