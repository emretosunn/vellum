# Yapılacaklar Listesi (Step-by-Step)

### Aşama 1: Bağımlılıklar ve Local Database
- [ ] `sqflite`, `path_provider`, `dio` ve `connectivity_plus` paketlerini pubspec.yaml'a ekle.
- [ ] `LocalDatabaseService` oluştur. SQLite tablolarını (offline_books ve offline_chapters) başlat.

### Aşama 2: İndirme Servisi (Download Manager)
- [ ] `OfflineManager` sınıfını oluştur.
- [ ] `downloadBook(Book book)` fonksiyonunu yaz:
    1. Kitap kapak görselini `dio` ile indir ve yerel bir yola kaydet.
    2. Supabase'den kitaba ait tüm bölümleri (chapters) çek.
    3. Kitabı ve tüm bölümleri SQLite veritabanına kaydet.

### Aşama 3: Okuma Ekranı (Reader View) Güncellemesi
- [ ] Okuma ekranına internet kontrolü ekle.
- [ ] Eğer internet yoksa veya kitap indirilmişse, veriyi Supabase yerine SQLite (`offline_chapters` tablosu) üzerinden getir.
- [ ] Bölüm geçişlerini (Önceki/Sonraki) SQLite'daki `order_index` değerine göre çalıştır.

### Aşama 4: UI ve Temizlik
- [ ] Kitap kartlarına "İndirildi" ikonu ekle.
- [ ] İndirilen bir kitabı silme fonksiyonu ekle (Dosya ve DB kaydını temizle).