import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pro abonelik durumu için tek doğru kaynak: Supabase `profiles.is_pro`.
/// RevenueCat kaldırıldığı için sadece Supabase üzerinden kontrol yapılır.
final isProProvider = FutureProvider<bool>((ref) async {
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;

    final data = await client
        .from('profiles')
        .select('is_pro, sub_end_date')
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return false;

    final isPro = data['is_pro'] as bool? ?? false;
    if (!isPro) return false;

    final endStr = data['sub_end_date'] as String?;
    if (endStr == null) return true;

    return DateTime.tryParse(endStr)?.isAfter(DateTime.now()) ?? false;
  } catch (_) {
    return false;
  }
});

