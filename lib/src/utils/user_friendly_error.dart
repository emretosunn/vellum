import 'package:flutter_translate/flutter_translate.dart';

String toUserFriendlyErrorMessage(
  Object error, {
  String? fallbackKey,
}) {
  final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  final lowered = raw.toLowerCase();

  if (lowered.contains('failed host lookup') ||
      lowered.contains('socketexception') ||
      lowered.contains('no address associated with hostname') ||
      lowered.contains('network is unreachable')) {
    return translate('common.network_unavailable');
  }

  if (lowered.contains('timeout')) {
    return translate('common.request_timed_out');
  }

  if (lowered.contains('already subscribed') || lowered.contains('zaten abonesiniz')) {
    return translate('subscription.already_subscribed');
  }

  if (lowered.contains('permission') || lowered.contains('unauthorized')) {
    return translate('common.permission_denied');
  }

  if (fallbackKey != null) {
    return translate(fallbackKey);
  }
  return translate('common.error_generic_friendly');
}
