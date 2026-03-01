import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';
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

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  final delegate = await LocalizationDelegate.create(
    fallbackLocale: 'tr',
    supportedLocales: ['tr', 'en'],
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
