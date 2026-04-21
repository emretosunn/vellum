import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/auth/data/auth_repository.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/settings/data/app_config_repository.dart';
import 'routing/app_router.dart';
import 'features/shared/presentation/maintenance_screen.dart';

/// Reaktif onboarding durumu — main.dart'ta başlangıç değeri atanır,
/// onboarding tamamlanınca true'ya çekilir.
final onboardingCompletedProvider = StateProvider<bool>((ref) => false);

/// Signup sonrası kişiselleştirme ekranı gösterilsin diye yapılan geçici bayrak.
/// Auth oturumu çok hızlı açılınca router'ın `/login` -> `'/'` redirect'i yarışı oluşabiliyor.
/// Bu bayrak sayesinde kullanıcı direkt `'/signup-setup'`a gönderilir.
final signupSetupPendingProvider = StateProvider<bool>((ref) => false);

/// Kullanıcı signup-setup ekranında "bitir" dediğinde,
/// Supabase'te flag henüz güncellenememiş olsa bile home'a geçsin diye
/// bu tur redirect'i engeller.
final signupSetupRedirectOverrideProvider = StateProvider<bool>((ref) => false);

/// Signup-setup akışında hangi adımdayız? (Dil/tema değişimi sırasında widget yeniden
/// oluşturulursa bile adımı kaybetmemek için state'i burada tutuyoruz.)
final signupSetupStepProvider = StateProvider<int>((ref) => 0);

class VellumApp extends ConsumerWidget {
  const VellumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.whenOrNull(
          data: (state) => state.session != null,
        ) ??
        false;

    final onboardingDone = ref.watch(onboardingCompletedProvider);
    final signupSetupPending = ref.watch(signupSetupPendingProvider);
    final signupSetupRedirectOverride =
        ref.watch(signupSetupRedirectOverrideProvider);
    final appConfigAsync = ref.watch(appConfigProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    final forceSignupSetup =
        profileAsync.valueOrNull?.signupSetupCompleted == false;

    final router = createRouter(
      isLoggedIn: isLoggedIn,
      onboardingCompleted: onboardingDone,
      signupSetupPending: signupSetupPending,
      forceSignupSetup: forceSignupSetup,
      signupSetupRedirectOverride: signupSetupRedirectOverride,
    );
    final themeMode = ref.watch(themeModeProvider);
    final localizationDelegate = LocalizedApp.of(context).delegate;

    return LocalizationProvider(
      state: LocalizationProvider.of(context).state,
      child: MaterialApp.router(
      title: translate('common.app_name'),
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
      builder: (context, child) {
        final content = appConfigAsync.when(
          loading: () => child ?? const SizedBox.shrink(),
          error: (_, __) => child ?? const SizedBox.shrink(),
          data: (config) {
            final isDeveloper =
                profileAsync.valueOrNull?.isDeveloper == true;

            if (config.maintenanceEnabled && !isDeveloper) {
              return MaintenanceScreen(message: config.maintenanceMessage);
            }
            return child ?? const SizedBox.shrink();
          },
        );
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            final focus = FocusManager.instance.primaryFocus;
            if (focus != null && !focus.hasPrimaryFocus) {
              focus.unfocus();
            }
          },
          child: content,
        );
      },
      localizationsDelegates: [
        localizationDelegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: localizationDelegate.supportedLocales,
      locale: localizationDelegate.currentLocale,
      ),
    );
  }
}
