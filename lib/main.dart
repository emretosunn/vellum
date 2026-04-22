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

  try {
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
  } catch (e) {
    runApp(_StartupErrorApp(error: e.toString()));
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF111214),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Uygulama başlatılamadı',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Muhtemel neden: .env.json değerleri build aşamasında geçirilmedi.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const SelectableText(
                    'Doğru komut:\nflutter build ipa --release --dart-define-from-file=.env.json',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    error,
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
