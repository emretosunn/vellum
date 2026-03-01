import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _selectedLocaleKey = 'selected_locale';
const String _useSystemLocaleKey = 'use_system_locale';

/// Dil tercihini SharedPreferences ile kaydeder ve geri yükler.
/// "Sistem dili" seçiliyse [getPreferredLocale] null döner; uygulama cihaz dilini kullanır.
class VellumTranslatePreferences implements ITranslatePreferences {
  VellumTranslatePreferences._();
  static final VellumTranslatePreferences _instance =
      VellumTranslatePreferences._();
  factory VellumTranslatePreferences() => _instance;

  @override
  Future<Locale?> getPreferredLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final useSystem = prefs.getBool(_useSystemLocaleKey) ?? false;
    if (useSystem) return null;

    final saved = prefs.getString(_selectedLocaleKey);
    if (saved == null || saved.isEmpty) return null;
    return localeFromString(saved);
  }

  @override
  Future savePreferredLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedLocaleKey, localeToString(locale));
    await prefs.setBool(_useSystemLocaleKey, false);
  }

  /// Kullanıcı "Sistem dili" seçtiğinde çağrılır. Sonraki açılışta cihaz dili kullanılır.
  static Future<void> setUseSystemLocale(bool useSystem) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useSystemLocaleKey, useSystem);
  }

  /// "Sistem dili" seçili mi?
  static Future<bool> getUseSystemLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useSystemLocaleKey) ?? false;
  }
}
