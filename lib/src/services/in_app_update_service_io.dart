import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:in_app_update/in_app_update.dart';

import '../constants/app_colors.dart';
import '../utils/user_friendly_error.dart';

/// Android'de (Google Play üzerinden yüklü uygulamada) güncelleme kontrolü yapar.
/// Hemen güncelleme mümkünse tam ekran, değilse esnek (arka planda indir + sonra yeniden başlat) kullanır.
Future<void> checkForInAppUpdate(BuildContext context) async {
  if (!Platform.isAndroid) return;

  try {
    final info = await InAppUpdate.checkForUpdate();
    if (!context.mounted) return;

    if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

    if (info.immediateUpdateAllowed == true) {
      await InAppUpdate.performImmediateUpdate();
      return;
    }

    if (info.flexibleUpdateAllowed == true) {
      await InAppUpdate.startFlexibleUpdate();
      if (!context.mounted) return;
      _showFlexibleUpdateCompleteSnackBar(context);
    }
  } catch (e) {
    if (context.mounted) _showErrorSnackBar(context, e.toString());
  }
}

void _showFlexibleUpdateCompleteSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(translate('common.update_downloaded_restart')),
      backgroundColor: AppColors.primary,
      action: SnackBarAction(
        label: translate('common.restart'),
        textColor: Colors.white,
        onPressed: () async {
          await InAppUpdate.completeFlexibleUpdate();
        },
      ),
    ),
  );
}

void _showErrorSnackBar(BuildContext context, String message) {
  // API_NOT_AVAILABLE = test/Play dışı kurulumda normal; kullanıcıyı rahatsız etmeyelim
  if (message.contains('API_NOT_AVAILABLE') || message.contains('ERROR')) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(toUserFriendlyErrorMessage(Exception(message)))),
  );
}
