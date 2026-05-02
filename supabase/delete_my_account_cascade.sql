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

  -- profiles_username_unique_lower ile uyumlu: karsilastirma buyuk/kucuk harf duyarsiz
  if lower(btrim(coalesce(p_username, ''))) <> lower(btrim(v_username)) then
    return jsonb_build_object('ok', false, 'error', 'username_mismatch');
  end if;

  -- Kullaniciya ait / kullaniciyi referanslayan tum kayitlari temizle.
  if to_regclass('public.review_reports') is not null then
    delete from public.review_reports
    where reporter_user_id = v_uid
       or review_id in (select id from public.reviews where user_id = v_uid);
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

  -- Storage: storage.objects uzerinde dogrudan DELETE Supabase tarafindan yasaklanir.
  -- Dosyalar uygulama tarafinda Storage API ile silinir (bkz. AuthRepository).

  -- Profil + auth kullanicisi
  delete from public.profiles where id = v_uid;

  -- Auth: oturum / token / MFA (auth.users silinmeden once; aksi halde FK hatasi)
  if to_regclass('auth.refresh_tokens') is not null then
    delete from auth.refresh_tokens where user_id = v_uid::text;
  end if;
  if to_regclass('auth.mfa_challenges') is not null
     and to_regclass('auth.mfa_factors') is not null then
    delete from auth.mfa_challenges
    using auth.mfa_factors
    where auth.mfa_challenges.factor_id = auth.mfa_factors.id
      and auth.mfa_factors.user_id = v_uid;
  end if;
  if to_regclass('auth.mfa_factors') is not null then
    delete from auth.mfa_factors where user_id = v_uid;
  end if;
  if to_regclass('auth.mfa_amr_claims') is not null
     and to_regclass('auth.sessions') is not null then
    delete from auth.mfa_amr_claims where session_id in (
      select id from auth.sessions where user_id = v_uid
    );
  end if;
  if to_regclass('auth.sessions') is not null then
    delete from auth.sessions where user_id = v_uid;
  end if;
  if to_regclass('auth.flow_state') is not null then
    delete from auth.flow_state where user_id = v_uid;
  end if;
  if to_regclass('auth.oauth_authorizations') is not null then
    delete from auth.oauth_authorizations where user_id = v_uid;
  end if;
  if to_regclass('auth.oauth_consents') is not null then
    delete from auth.oauth_consents where user_id = v_uid;
  end if;
  if to_regclass('auth.webauthn_challenges') is not null then
    delete from auth.webauthn_challenges where user_id = v_uid;
  end if;
  if to_regclass('auth.webauthn_credentials') is not null then
    delete from auth.webauthn_credentials where user_id = v_uid;
  end if;
  if to_regclass('auth.one_time_tokens') is not null then
    delete from auth.one_time_tokens where user_id = v_uid;
  end if;

  delete from auth.identities where user_id = v_uid;
  delete from auth.users where id = v_uid;

  return jsonb_build_object('ok', true);
exception
  when others then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$$;

-- PostgREST SECURITY DEFINER: auth.users silmek icin fonksiyon sahibi postgres olmalı
-- (aksi halde "permission denied" veya auth.users silinmez)
alter function public.delete_my_account_cascade(text) owner to postgres;

revoke all on function public.delete_my_account_cascade(text) from public;
grant execute on function public.delete_my_account_cascade(text) to authenticated;
