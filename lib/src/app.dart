import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/auth/data/auth_repository.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'routing/app_router.dart';

class InkTokenApp extends ConsumerWidget {
  const InkTokenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.whenOrNull(
          data: (state) => state.session != null,
        ) ??
        false;

    final router = createRouter(isLoggedIn: isLoggedIn);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'InkToken',
      debugShowCheckedModeBanner: false,
      theme: FlexThemeData.light(
        scheme: FlexScheme.indigo,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 10,
          blendOnColors: false,
          useMaterial3Typography: true,
          useM2StyleDividerInM3: true,
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorRadius: 12,
          chipRadius: 20,
          elevatedButtonRadius: 12,
          filledButtonRadius: 12,
          outlinedButtonRadius: 12,
          textButtonRadius: 12,
          cardRadius: 16,
        ),
        useMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
      ),
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.indigo,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 13,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 20,
          useMaterial3Typography: true,
          useM2StyleDividerInM3: true,
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorRadius: 12,
          chipRadius: 20,
          elevatedButtonRadius: 12,
          filledButtonRadius: 12,
          outlinedButtonRadius: 12,
          textButtonRadius: 12,
          cardRadius: 16,
        ),
        useMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
      ),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
