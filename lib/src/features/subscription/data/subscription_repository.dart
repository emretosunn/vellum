import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/profile.dart';

/// Ödeme kaydı modeli.
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.amount,
    required this.currency,
    required this.planType,
    required this.status,
    this.description,
    required this.createdAt,
  });

  final String id;
  final double amount;
  final String currency;
  final String planType;
  final String status;
  final String? description;
  final DateTime createdAt;

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'TRY',
      planType: json['plan_type'] as String,
      status: json['status'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get planLabel => planType == 'yearly' ? 'Yıllık Plan' : 'Aylık Plan';

  String get statusLabel {
    switch (status) {
      case 'completed':
        return 'Tamamlandı';
      case 'pending':
        return 'Beklemede';
      case 'failed':
        return 'Başarısız';
      case 'refunded':
        return 'İade Edildi';
      default:
        return status;
    }
  }

  String get formattedAmount {
    final symbol = currency == 'TRY' ? '₺' : currency;
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  String get formattedDate {
    final d = createdAt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}

/// Abonelik yönetim repository'si.
class SubscriptionRepository {
  SubscriptionRepository(this._client);
  final SupabaseClient _client;

  /// Kullanıcının abonelik durumunu kontrol et.
  Future<bool> checkSubscription(String userId) async {
    final data = await _client
        .from('profiles')
        .select('is_pro, sub_end_date')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return false;

    final isPro = data['is_pro'] as bool? ?? false;
    final subEndDateStr = data['sub_end_date'] as String?;

    if (!isPro) return false;
    if (subEndDateStr == null) return isPro;

    final subEndDate = DateTime.tryParse(subEndDateStr);
    if (subEndDate == null) return false;

    return subEndDate.isAfter(DateTime.now());
  }

  /// Aboneliği aktifleştir (profil güncelle).
  Future<Profile> activateSubscription({
    required String userId,
    int durationDays = 30,
    String? stripeCustomerId,
  }) async {
    final endDate = DateTime.now().add(Duration(days: durationDays));

    // is_verified_author (Pro Yazar) yalnızca geliştirici panelinden verilir; abonelikle atanmaz.
    final updates = <String, dynamic>{
      'is_pro': true,
      'sub_end_date': endDate.toIso8601String(),
      'role': 'author',
    };

    if (stripeCustomerId != null) {
      updates['stripe_customer_id'] = stripeCustomerId;
    }

    final data = await _client
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return Profile.fromJson(data);
  }

  /// Gerçek ödeme kaydı oluştur (RevenueCat satın alma sonrası).
  Future<void> recordPayment({
    required String userId,
    required String planType,
    required double amount,
    String currency = 'TRY',
    String? description,
  }) async {
    await _client.from('subscription_payments').insert({
      'user_id': userId,
      'amount': amount,
      'currency': currency,
      'plan_type': planType,
      'status': 'completed',
      'description': description ?? (planType == 'yearly'
          ? 'Vellum Pro Yıllık Plan'
          : 'Vellum Pro Aylık Plan'),
    });
  }

  /// Aboneliği iptal et.
  Future<Profile> cancelSubscription(String userId) async {
    final data = await _client
        .from('profiles')
        .update({
          'is_pro': false,
          'sub_end_date': null,
        })
        .eq('id', userId)
        .select()
        .single();

    return Profile.fromJson(data);
  }

  /// Kullanıcının ödeme geçmişini getir (en yeniden eskiye).
  Future<List<PaymentRecord>> getPaymentHistory(String userId) async {
    final data = await _client
        .from('subscription_payments')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(20);

    return (data as List)
        .map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ─── Providers ────────────────────────────────────

final subscriptionRepositoryProvider =
    Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(supabaseClientProvider));
});


/// Ödeme geçmişi provider'ı
final paymentHistoryProvider =
    FutureProvider<List<PaymentRecord>>((ref) async {
  ref.watch(currentProfileProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  return ref.read(subscriptionRepositoryProvider).getPaymentHistory(userId);
});
