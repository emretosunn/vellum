import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription_status_service.dart';
import '../presentation/subscription_plan_screen.dart';

/// Abonelik ile ilgili yardımcı servis.
class SubscriptionService {
  SubscriptionService(this._ref);

  final Ref _ref;

  /// Kullanıcının Vellum Pro olup olmadığını döndürür.
  Future<bool> isPro() {
    return _ref.read(isProProvider.future);
  }

  /// Bir özelliğe erişmeden önce Pro üyelik gerekliliğini kontrol eder.
  ///
  /// - Kullanıcı Pro ise `true` döner.
  /// - Değilse ortada cam efektli Premium modalını açar.
  Future<bool> ensurePro(BuildContext context) async {
    final pro = await isPro();
    if (pro) return true;

    if (!context.mounted) return false;

    final result = await showSubscriptionPlanModal(context);
    if (result == true) {
      _ref.invalidate(isProProvider);
      return true;
    }
    return false;
  }
}

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(ref);
});

