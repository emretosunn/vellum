# Vellum Çevrimdışı Okuma Sistemi - Teknik Plan

## 1. Hedef
Kullanıcıların kitapları ve tüm bölümlerini (chapters) cihazın özel alanına indirmesini, internet yokken bölümler arası geçiş yaparak okumasını sağlamak.

## 2. Teknik Altyapı
- **Veritabanı:** `sqflite` (Kitap meta verileri ve bölüm metinleri için).
- **Dosya Depolama:** `path_provider` (Kapak görselleri için ApplicationDocumentsDirectory kullanılacak).
- **İndirme:** `dio` (Görselleri ve API verilerini senkronize çekmek için).
- **Bağlantı Kontrolü:** `connectivity_plus`.

## 3. Veritabanı Şeması (SQLite)
### Tablo: `offline_books`
- `id` (String, Primary Key)
- `title` (String)
- `author_name` (String)
- `local_cover_path` (String)
- `downloaded_at` (DateTime)

### Tablo: `offline_chapters`
- `id` (String, Primary Key)
- `book_id` (String, Foreign Key)
- `title` (String)
- `content` (Text)
- `order_index` (Integer) - Bölüm sırasını korumak için.

## 4. Güvenlik ve Gizlilik
- Dosyalar uygulamanın özel sandbox alanına kaydedilecek (Uygulama silindiğinde otomatik silinir).
- Galeri veya dosya yöneticisinden erişim olmayacak.