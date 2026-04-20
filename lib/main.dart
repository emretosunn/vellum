import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/config/env.dart';
import 'src/config/theme_preferences.dart';
import 'src/features/onboarding/presentation/onboarding_screen.dart';
import 'src/features/settings/presentation/settings_screen.dart';
import 'src/localization/translate_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Env.validate();

  await Hive.initFlutter();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  await VellumTranslatePreferences.ensureInitialLocale(
    supportedLocales: ['tr', 'en', 'de'],
    fallbackLocale: 'en',
  );

  final delegate = await LocalizationDelegate.create(
    // Sistem dili tr veya en değilse varsayılan olarak İngilizceye düş.
    fallbackLocale: 'en',
    supportedLocales: ['tr', 'en', 'de'],
    basePath: 'assets/i18n/',
    preferences: VellumTranslatePreferences(),
  );

  final onboardingDone = await isOnboardingCompleted();
  final savedThemeMode = await loadThemeMode();

  runApp(
    LocalizedApp(
      delegate,
      ProviderScope(
        overrides: [
          onboardingCompletedProvider.overrideWith((ref) => onboardingDone),
          themeModeProvider.overrideWith((ref) => savedThemeMode),
        ],
        child: const VellumApp(),
      ),
    ),
  );
}
