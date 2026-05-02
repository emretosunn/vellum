# App Store Resubmit Checklist (Vellum)

Bu dosya, Apple reject sebeplerini tekrar almamak icin son kontrol listesidir.

## 1) Guideline 4 - Design (Auth UX)

- [ ] TestFlight build'de Google girisi uygulama ici web akista aciliyor.
- [ ] TestFlight build'de Facebook girisi uygulama ici web akista aciliyor.
- [ ] TestFlight build'de Apple girisi uygulama ici web akista aciliyor.
- [ ] Login sonrasi `vellum://auth/callback` ile uygulamaya geri donus sorunsuz.

## 2) Guideline 2.1(b) - IAP Completeness

- [ ] App Store Connect > Agreements: Paid Apps Agreement aktif.
- [ ] Product ID'ler dogru:
  - [ ] `vellum_monthly`
  - [ ] `annual_vellum`
- [ ] Her iki urun icin fiyat bolgeleri aktif.
- [ ] iPad sandbox testte urunler paywall ekraninda yukleniyor.
- [ ] Satin alma sonrasi Pro yetki guncelleniyor.
- [ ] Restore Purchases sonrasi yetki geri geliyor.

## 3) Guideline 3.1.2(c) - Subscription Metadata

- [ ] App Description veya EULA alaninda Terms of Use linki var.
- [ ] Privacy Policy alani fonksiyonel URL iceriyor.
- [ ] In-app ekranda Terms/Privacy tiklanabilir durumda.

## 4) Guideline 2.3.2 - Promotional Image

- [ ] IAP promotional image app icon ile ayni degil.
- [ ] Gorsel IAP teklifini acikca temsil ediyor.

## 5) Review Notes (Gonderim oncesi)

Review Notes icine asagidaki bilgileri ekle:

1. Test account bilgisi (gerekliyse)
2. Login akislari:
   - Google/Facebook/Apple in-app web auth kullanir
3. IAP test adimlari:
   - Subscription page ac
   - Monthly/Yearly urunleri gor
   - Purchase
   - Restore Purchases
4. Account deletion:
   - Settings > Delete Account
   - Fallback: `vexorabyte@gmail.com`

