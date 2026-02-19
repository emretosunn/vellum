📄 VELLUM_PROJE_PRD.md
1. ÜRÜN ÖZETİ
Vellum, yazarların bir abonelik modeliyle içerik ürettiği, okuyucuların ise (seçilen modele göre) bu içeriklere eriştiği dijital bir yayıncılık platformudur. Token karmaşası yerine, "Vellum Pro" aboneliği ile yazarlık yetkisi ve premium özellikler sunulur.

2. KULLANICI ROLLERİ VE YETKİLERİ
Okuyucu (Ücretsiz): Kitapları keşfeder, kütüphanesine ekler ve halka açık bölümleri okur.

Vellum Pro (Abone/Yazar):

Sınırsız kitap ve bölüm oluşturma.

Kitaplarını yayınlama ve yönetme.

Yazar paneli ve detaylı istatistiklere erişim.

Admin: İçerik denetimi ve abonelik yönetimi.

3. ABONELİK MODELİ (MONETİZASYON)
Yazar Aboneliği: Kitap yazmak ve yayınlamak isteyen kullanıcılar aylık veya yıllık bir ücret öder.

Ödeme Altyapısı: * Mobil: Google Play Billing & Apple In-App Purchase.

Web: Stripe veya Iyzico entegrasyonu.

Kısıtlama: Ücretsiz kullanıcılar taslak oluşturabilir ancak kitabı yayına alamazlar; yayına almak için aktif abonelik şarttır.

4. ÖZELLİK LİSTESİ
4.1. Yazma ve Düzenleme (Studio)
Zengin Metin Editörü: flutter_quill ile kalın, italik, başlık ve görsel desteği.

Bölüm Yönetimi: Bölümleri sürükle-bırak yöntemiyle sıralama.

Otomatik Kaydetme: Yazım sırasında veri kaybını önlemek için Supabase ile anlık senkronizasyon.

4.2. Okuma Deneyimi
Kişiselleştirme: Gece modu, font boyutu ve kağıt tipi seçimi.

Çevrimdışı Okuma: Okunan bölümlerin yerel veritabanına (SQLite/Hive) önbelleğe alınması.

5. TEKNİK MİMARİ (FLUTTER + SUPABASE)
5.1. Güncellenmiş Veritabanı Şeması (SQL)
SQL
-- Profiles Tablosu Güncellemesi
ALTER TABLE profiles 
ADD COLUMN is_pro boolean DEFAULT false,
ADD COLUMN sub_end_date timestamp with time zone,
ADD COLUMN stripe_customer_id text;

-- Books Tablosu (Token bağımlılığı kaldırıldı)
CREATE TABLE books (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id uuid REFERENCES profiles(id),
  title text NOT NULL,
  summary text,
  cover_url text,
  is_published boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now()
);

-- Chapters Tablosu
CREATE TABLE chapters (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  book_id uuid REFERENCES books(id) ON DELETE CASCADE,
  title text,
  content jsonb, -- Zengin metin formatı için
  order_index int,
  created_at timestamp with time zone DEFAULT now()
);
6. UYGULAMA AKIŞI (UX FLOW)
Giriş: Kullanıcı Supabase Auth ile giriş yapar.

Yazma İsteği: Kullanıcı "Yazmaya Başla" dediğinde sistem is_pro kontrolü yapar.

Paywall: Eğer abone değilse, "Vellum Pro'ya Geç" ekranı (Benefits: Kitap Yayınla, Yazar Rozeti Al vb.) gösterilir.

Abonelik: Ödeme başarılıysa is_pro alanı güncellenir ve Studio erişimi açılır.