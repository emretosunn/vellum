import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// İçerik tablolarındaki değişimlerde (books/reviews/author_posts/user_blocks)
/// uygulama genelinde ilgili Riverpod provider'larını invalid etmek için sinyal üretir.
final contentRealtimeProvider = StreamProvider.autoDispose<int>((ref) {
  final client = Supabase.instance.client;
  final controller = StreamController<int>.broadcast();

  void emit() {
    if (!controller.isClosed) {
      controller.add(DateTime.now().millisecondsSinceEpoch);
    }
  }

  final channel = client
      .channel('public:content:global')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'books',
        callback: (_) => emit(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'reviews',
        callback: (_) => emit(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'author_posts',
        callback: (_) => emit(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_blocks',
        callback: (_) => emit(),
      )
      .subscribe();

  ref.onDispose(() async {
    await client.removeChannel(channel);
    await controller.close();
  });

  return controller.stream;
});
