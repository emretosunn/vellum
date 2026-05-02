-- Hesap silme: kullanicinin tum iliskili verilerini temizler ve auth.users kaydini siler.
-- Cagri: select public.delete_my_account_cascade('kullanici_adi');
-- Not: Kullanici adi dogrulamasi function icinde yapilir.

create or replace function public.delete_my_account_cascade(p_username text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_username text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;

  select username
  into v_username
  from public.profiles
  where id = v_uid;

  if v_username is null then
    return jsonb_build_object('ok', false, 'error', 'profile_not_found');
  end if;

  if btrim(coalesce(p_username, '')) <> btrim(v_username) then
    return jsonb_build_object('ok', false, 'error', 'username_mismatch');
  end if;

  -- Kullaniciya ait / kullaniciyi referanslayan tum kayitlari temizle.
  if to_regclass('public.review_reports') is not null then
    delete from public.review_reports
    where reporter_user_id = v_uid;
  end if;

  if to_regclass('public.book_reports') is not null then
    delete from public.book_reports
    where reporter_user_id = v_uid
       or book_id in (select id from public.books where author_id = v_uid);
  end if;

  if to_regclass('public.user_blocks') is not null then
    delete from public.user_blocks
    where user_id = v_uid
       or blocked_user_id = v_uid;
  end if;

  if to_regclass('public.user_follows') is not null then
    delete from public.user_follows
    where follower_id = v_uid
       or following_id = v_uid;
  end if;

  if to_regclass('public.notifications') is not null then
    delete from public.notifications
    where user_id = v_uid;
  end if;

  if to_regclass('public.user_read_books') is not null then
    delete from public.user_read_books
    where user_id = v_uid;
  end if;

  if to_regclass('public.book_likes') is not null then
    delete from public.book_likes
    where user_id = v_uid
       or book_id in (select id from public.books where author_id = v_uid);
  end if;

  if to_regclass('public.reviews') is not null then
    delete from public.reviews
    where user_id = v_uid
       or book_id in (select id from public.books where author_id = v_uid);
  end if;

  if to_regclass('public.author_posts') is not null then
    delete from public.author_posts
    where author_id = v_uid;
  end if;

  if to_regclass('public.chapters') is not null then
    delete from public.chapters
    where book_id in (select id from public.books where author_id = v_uid);
  end if;

  if to_regclass('public.books') is not null then
    delete from public.books
    where author_id = v_uid;
  end if;

  if to_regclass('public.subscription_payments') is not null then
    delete from public.subscription_payments
    where user_id = v_uid;
  end if;

  if to_regclass('public.account_deletion_requests') is not null then
    delete from public.account_deletion_requests
    where user_id = v_uid;
  end if;

  -- Tum bucketlarda kullanicinin storage.objects kaydi (aksi halde auth.users silinmez)
  delete from storage.objects where owner = v_uid;

  -- Profil + auth kullanicisi
  delete from public.profiles where id = v_uid;

  -- Auth: kullanici (identities cogunlukla users silinince cascade olur)
  delete from auth.identities where user_id = v_uid;
  delete from auth.users where id = v_uid;

  return jsonb_build_object('ok', true);
exception
  when others then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$$;

-- PostgREST SECURITY DEFINER: auth / storage silmek icin fonksiyon sahibi postgres olmalı
-- (aksi halde "permission denied" veya auth.users silinmez)
alter function public.delete_my_account_cascade(text) owner to postgres;

revoke all on function public.delete_my_account_cascade(text) from public;
grant execute on function public.delete_my_account_cascade(text) to authenticated;
