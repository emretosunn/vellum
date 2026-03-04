import 'package:hive/hive.dart';

/// Hive kutu adı.
const String offlineBooksBoxName = 'offline_books';

/// Çevrimdışı okunabilecek kitap verisi.
class OfflineBook {
  OfflineBook({
    required this.bookId,
    required this.title,
    required this.authorName,
    required this.coverImage,
    required this.chapters,
  });

  final String bookId;
  final String title;
  final String authorName;

  /// Kapak görseli (URL veya base64).
  final String coverImage;

  /// Bölüm içerikleri (sadece metin).
  final List<String> chapters;
}

/// [OfflineBook] için manuel Hive adapter.
class OfflineBookAdapter extends TypeAdapter<OfflineBook> {
  @override
  final int typeId = 1;

  @override
  OfflineBook read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return OfflineBook(
      bookId: fields[0] as String,
      title: fields[1] as String,
      authorName: fields[2] as String,
      coverImage: fields[3] as String,
      chapters: (fields[4] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, OfflineBook obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.bookId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.authorName)
      ..writeByte(3)
      ..write(obj.coverImage)
      ..writeByte(4)
      ..write(obj.chapters);
  }
}


