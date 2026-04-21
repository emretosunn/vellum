import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../data/subscription_repository.dart';

/// Google Play abonelik satın alma servisi.
///
/// Ödeme penceresinin çıkması için:
/// - Cihazda Play Store ile giriş yapılmış olmalı (gerçek cihaz veya Play Store’lu emülatör).
/// - Uygulama Play Console’da en az “Dahili test” ile yayında olmalı.
/// - Play Console > Monetize > Abonelikler’de [aylik_premium] ve [yillik_premium]
///   ürünleri oluşturulup etkinleştirilmiş olmalı.
class SubscriptionPurchaseService {
  SubscriptionPurchaseService(this._iap, this._ref);

  final InAppPurchase _iap;
  final Ref _ref;

  static const String _monthlyId = 'aylik_premium';
  static const String _yearlyId = 'yillik_premium';

  Future<Map<String, ProductDetails>> getSubscriptionProducts() async {
    final available = await _iap.isAvailable();
    if (!available) return const {};

    final response = await _iap.queryProductDetails({_monthlyId, _yearlyId});
    if (response.error != null || response.productDetails.isEmpty) {
      return const {};
    }

    return {
      for (final p in response.productDetails) p.id: p,
    };
  }

  /// Mağaza bağlantısını ve ürün listesini önceden yükler; ilk satın alma tıklamasında gecikmeyi azaltır.
  void warmUpStore() {
    _iap.isAvailable().then((_) {
      _iap.queryProductDetails({_monthlyId, _yearlyId});
    });
  }

  Future<void> purchaseSubscription({
    required String userId,
    required bool isYearly,
  }) async {
    final available = await _iap.isAvailable();
    if (!available) {
      throw Exception(
        'Google Play mağazası kullanılamıyor. '
        'Cihazda Play Store girişi yapıldığından ve uygulama Play Console\'da (en az dahili test) yayında olduğundan emin olun.',
      );
    }

    final productId = isYearly ? _yearlyId : _monthlyId;
    final response = await _iap.queryProductDetails({productId});
    if (response.error != null) {
      throw Exception('Play yanıt hatası: ${response.error!.message}');
    }
    if (response.productDetails.isEmpty) {
      throw Exception(
        'Ürün bulunamadı: $productId. '
        'Play Console > Monetize > Abonelikler bölümünde bu kimlikle ürün oluşturup etkinleştirdiğinizden emin olun.',
      );
    }

    final product = response.productDetails.first;

    // Mevcut abonelikleri kontrol et (Android); zaten aktif abonelik varsa Play UI açılmadan bilgi ver.
    try {
      final androidAddition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final pastResponse = await androidAddition.queryPastPurchases();
      if (pastResponse.error == null && pastResponse.pastPurchases.isNotEmpty) {
        final hasActiveSubscription = pastResponse.pastPurchases.any(
          (PurchaseDetails p) => p.productID == _monthlyId || p.productID == _yearlyId,
        );
        if (hasActiveSubscription) {
          throw Exception('Zaten abonesiniz');
        }
      }
    } on Object {
      // iOS veya web; queryPastPurchases yok, atla.
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    final completer = Completer<PurchaseDetails>();
    late final StreamSubscription<List<PurchaseDetails>> sub;

    // Dinleyiciyi ÖNCE kaydet; buyNonConsumable çağrıldığında stream tetiklenir (Play Billing ile senkron).
    sub = _iap.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.productID != productId) continue;

        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          // Sadece bekleyen (yeni tamamlanan) satın almada completer doldurulur; completePurchase aşağıda çağrılır.
          // Durum pending değilse burada completePurchase çağırma; eski satın almaları tetikleme.
          if (p.pendingCompletePurchase && !completer.isCompleted) {
            completer.complete(p);
          }
        } else if (p.status == PurchaseStatus.error ||
            p.status == PurchaseStatus.canceled) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception(p.error?.message ?? 'Satın alma iptal edildi'),
            );
          }
        }
      }
    });

    try {
      // Stream dinleyicisi kayıtlı olduktan sonra Play Faturalandırma UI tetiklenir.
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      final details = await completer.future;

      final repo = _ref.read(subscriptionRepositoryProvider);
      final days = isYearly ? 365 : 30;
      final planType = isYearly ? 'yearly' : 'monthly';

      await repo.activateSubscription(
        userId: userId,
        durationDays: days,
      );

      await repo.recordPayment(
        userId: userId,
        planType: planType,
        amount: details.productID == productId ? product.rawPrice.toDouble() : 0,
        currency: product.currencyCode,
      );

      if (details.pendingCompletePurchase) {
        await _iap.completePurchase(details);
      }
    } finally {
      await sub.cancel();
    }
  }

  Future<bool> restoreSubscription({required String userId}) async {
    final available = await _iap.isAvailable();
    if (!available) {
      throw Exception('Mağaza şu anda kullanılamıyor.');
    }

    final completer = Completer<List<PurchaseDetails>>();
    late final StreamSubscription<List<PurchaseDetails>> sub;
    final restored = <PurchaseDetails>[];

    sub = _iap.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.productID != _monthlyId && p.productID != _yearlyId) continue;
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          restored.add(p);
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
        }
      }
      if (!completer.isCompleted) {
        completer.complete(List<PurchaseDetails>.from(restored));
      }
    });

    try {
      await _iap.restorePurchases();
      final restoredPurchases = await completer.future;
      if (restoredPurchases.isEmpty) return false;

      final hasYearly = restoredPurchases.any((p) => p.productID == _yearlyId);
      final days = hasYearly ? 365 : 30;
      await _ref.read(subscriptionRepositoryProvider).activateSubscription(
            userId: userId,
            durationDays: days,
          );
      return true;
    } finally {
      await sub.cancel();
    }
  }
}

final subscriptionPurchaseServiceProvider =
    Provider<SubscriptionPurchaseService>((ref) {
  return SubscriptionPurchaseService(InAppPurchase.instance, ref);
});

