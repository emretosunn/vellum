import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/config/env.dart';
import 'src/features/onboarding/presentation/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Env.validate();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  final onboardingDone = await isOnboardingCompleted();

  runApp(
    ProviderScope(
      overrides: [
        onboardingCompletedProvider.overrideWith((ref) => onboardingDone),
      ],
      child: const VellumApp(),
    ),
  );
}
