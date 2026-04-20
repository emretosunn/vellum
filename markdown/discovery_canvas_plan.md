# Vellum Keşfet (Discovery Canvas) Mimari Planı

## 1. Amaç
Kullanıcıların statik listeler yerine, devasa bir tuval üzerinde sağa, sola, yukarı ve aşağı serbestçe hareket ederek kitap kapaklarını keşfetmesini sağlamak.

## 2. Teknik Bileşenler
- **Ana Widget:** `InteractiveViewer` (Kaydırma ve zoom yönetimi için).
- **Kontrolcü:** `TransformationController` (Tuval üzerindeki konumu/koordinatı saklamak için).
- **Düzen (Layout):** Devasa bir `Stack` içinde rastgele veya grid düzeninde yerleştirilmiş `Positioned` kitap kapakları.
- **Geçiş Efekti:** `Hero` animasyonu (Kapak fotoğrafı detay sayfasına uçarak geçer).

## 3. UI Standartları
- **Tuval Boyutu:** Ekran boyutunun en az 3-4 katı genişlikte ve yükseklikte bir `SizedBox`.
- **Kapak Tasarımı:** Hafif gölgeli (`BoxShadow`), köşeleri yuvarlatılmış ve yüksek kaliteli görseller.
- **Üst Bar:** Şeffaf (Blur efektli) bir `AppBar`, geri dönme butonu ve "Keşfet" başlığı.

## 4. Akış ve State Yönetimi
1. Sayfa açıldığında Supabase'den kitap listesi çekilir.
2. Kitaplar tuval üzerine dağıtılır.
3. Bir kitaba tıklandığında `TransformationController.value` bir değişkende saklanır.
4. Detay sayfasından geri dönüldüğünde bu değer `initState` içinde tekrar atanarak kullanıcının aynı koordinata dönmesi sağlanır.

# Vellum Keşfet (Discovery Canvas) Mimari Planı - V2

## 1. Değişmez Kurallar (Hard Rules)
- **Renk Uyumu:** Kesinlikle harici renk tanımlanmayacak. `Theme.of(context)` veya projedeki mevcut `AppColors` sınıfı kullanılacak. Arka plan ve kart gölgeleri Vellum'un ana renk kodlarına sadık kalacak.
- **Yerelleştirme (i18n):** Sayfadaki tüm metinler (Başlıklar, hata mesajları, butonlar) sistemdeki mevcut çeviri dosyalarından çekilecek. Hard-coded String yasaktır.
- **Performans:** Tuval üzerindeki görseller için `cached_network_image` kullanılmalı ve bellek yönetimi için düşük çözünürlüklü önizlemeler tercih edilmeli.

## 2. Teknik Bileşenler
- **Ana Widget:** `InteractiveViewer`.
- **Durum Yönetimi:** `TransformationController` ile koordinat takibi.
- **Geçiş:** `Hero` animasyonu (Kapakların detay sayfasına akışı).

## 3. Akış Mantığı
1. Sayfa yüklendiğinde mevcut dile göre başlıklar yüklenir.
2. Supabase'den kitaplar çekilirken Vellum'un kurumsal yükleme (loading) animasyonu gösterilir.
3. Tuval koordinatları `SharedPreferences` veya geçici bir `State` içinde tutulur; geri dönüşte aynı noktaya odaklanır.