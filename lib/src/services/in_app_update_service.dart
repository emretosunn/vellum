import 'package:flutter/material.dart';

import 'in_app_update_service_io.dart'
    if (dart.library.html) 'in_app_update_service_stub.dart' as in_app_update_impl;

/// Uygulama içi güncelleme kontrolü (Android / Google Play).
/// Web ve iOS'ta çağrı güvenle yapılır, işlem atlanır.
Future<void> checkForInAppUpdate(BuildContext context) =>
    in_app_update_impl.checkForInAppUpdate(context);

/// Ana ekrana eklendiğinde bir kez güncelleme kontrolü yapan widget.
class InAppUpdateTrigger extends StatefulWidget {
  const InAppUpdateTrigger({super.key});

  @override
  State<InAppUpdateTrigger> createState() => _InAppUpdateTriggerState();
}

class _InAppUpdateTriggerState extends State<InAppUpdateTrigger> {
  static bool _didCheck = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_didCheck && mounted) {
        _didCheck = true;
        checkForInAppUpdate(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
