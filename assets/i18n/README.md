# Çeviri dosyaları (i18n)

Bu klasördeki JSON dosyaları [flutter_translate](https://pub.dev/packages/flutter_translate) ile kullanılır.

## Dosya yapısı

- `tr.json` — Türkçe (varsayılan)
- `en.json` — İngilizce

Yeni dil eklemek için aynı anahtar yapısına sahip yeni bir `{locale}.json` dosyası ekleyin (örn. `de.json`) ve `main.dart` içindeki `supportedLocales` listesine ekleyin.

## Anahtar yapısı

Nested (iç içe) JSON desteklenir. Kodda nokta ile erişilir:

```json
{
  "onboarding": {
    "page1": {
      "title": "Başlık",
      "subtitle": "Alt metin"
    }
  }
}
```

```dart
translate('onboarding.page1.title');  // "Başlık"
```

## Dil değiştirme

```dart
import 'package:flutter_translate/flutter_translate.dart';

changeLocale(context, 'en');  // İngilizce
changeLocale(context, 'tr');  // Türkçe
```

Seçilen dil otomatik kaydedilir ve uygulama yeniden açıldığında geri yüklenir (ek yapılandırma ile).
