import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app.dart';
import '../../../localization/translate_preferences.dart';
import '../../../config/theme_preferences.dart';
import '../../../utils/user_friendly_error.dart';
import '../../library/data/book_repository.dart' show bookLanguageFilterProvider;
import '../../settings/presentation/settings_screen.dart' show themeModeProvider;
import '../../settings/services/notification_permission_service.dart';
import 'onboarding_screen.dart' show markOnboardingCompleted;
import '../../auth/data/auth_repository.dart'
    show authRepositoryProvider, currentProfileProvider;

class SignupSetupScreen extends ConsumerStatefulWidget {
  const SignupSetupScreen({
    super.key,
    this.sandboxMode = false,
  });

  final bool sandboxMode;

  @override
  ConsumerState<SignupSetupScreen> createState() => _SignupSetupScreenState();
}

class _SignupSetupScreenState extends ConsumerState<SignupSetupScreen> {
  static const String _localSetupDoneKeyPrefix = 'signup_setup_completed_';
  late final PageController _pageController;
  static const int _totalPages = 7;
  static const int _languageIntroPage = 0;
  static const int _languageAnswerPage = 1;
  static const int _regionIntroPage = 2;
  static const int _regionAnswerPage = 3;
  static const int _themeIntroPage = 4;
  static const int _themeAnswerPage = 5;
  static const int _notificationsPage = 6;
  late int _currentPage;

  // Vitrin renkleri: her adımda farklı bir canlı renk.
  static const List<Color> _pageColors = [
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.white,
  ];

  // Dil (uygulama dili) seçimi: system/tr/en
  String _selectedLocaleOption = 'system';

  // Bölge (home filtresi) seçimi: language_code == tr/en/de/fr/ru/es/other
  String? _selectedRegionCode; // null => Tümü

  ThemeMode _selectedThemeMode = ThemeMode.light;

  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    _currentPage =
        ref.read(signupSetupStepProvider).clamp(0, _totalPages - 1).toInt();
    _pageController = PageController(initialPage: _currentPage);
    _selectedThemeMode = ref.read(themeModeProvider);

    // Kullanıcı bu ekrana gelince pending bayrağını kapat ki router artık home'a zorlamasın.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(signupSetupPendingProvider.notifier).state = false;
    });

    // signupSetupRedirectOverrideProvider burada elle sıfırlanmıyor.
    // Çünkü kullanıcı "devam et" deyince bu override açık kalmalı,
    // aksi halde yönlendirme döngüsü tekrar oluşabiliyor.

    // Dil adımında, kullanıcı tercihini (system/tr/en) otomatik seçili göster.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final useSystem = await VellumTranslatePreferences.getUseSystemLocale();
      if (!mounted) return;

      final currentLang = LocalizedApp.of(context).delegate.currentLocale.languageCode;
      setState(() {
        if (useSystem) {
          _selectedLocaleOption = 'system';
        } else if (currentLang == 'tr') {
          _selectedLocaleOption = 'tr';
        } else if (currentLang == 'de') {
          _selectedLocaleOption = 'de';
        } else {
          _selectedLocaleOption = 'en';
        }
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentPage < _totalPages - 1) {
      final target = _currentPage + 1;
      // Optimistic step update: page animasyonu bitmeden yeniden build olursa dahi adım korunur.
      ref.read(signupSetupStepProvider.notifier).state = target;
      setState(() => _currentPage = target);

      _pageController.nextPage(
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);

    if (widget.sandboxMode) {
      ref.read(signupSetupStepProvider.notifier).state = 0;
      if (mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        navigator.popUntil((route) => route.isFirst);
        context.go('/settings');
        setState(() => _isFinishing = false);
      }
      return;
    }

    // Home'a giderken router redirect loop'a düşmesin diye pending'i hemen kapat.
    ref.read(signupSetupPendingProvider.notifier).state = false;
    // Kullanıcı "devam et" dediğinde, Supabase/flag güncellemesi henüz gelmemiş olsa bile
    // redirect loop'a girip tekrar bu ekrana dönmesin.
    ref.read(signupSetupRedirectOverrideProvider.notifier).state = true;
    // Akış kapandığı için step'i sıfırla (gerekirse yeniden mount edilirse eski adımda kalmasın).
    ref.read(signupSetupStepProvider.notifier).state = 0;
    try {
      // İlk tamamlamadan sonra ikinci tur setup'a düşmeyi engellemek için
      // kullanıcı bazlı local bir "tamamlandı" işareti bırak.
      final currentUserId = ref.read(authRepositoryProvider).currentUser?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('$_localSetupDoneKeyPrefix$currentUserId', true);
      }

      // En son: bildirim izni iste.
      try {
        final status = await NotificationPermissionService.status;
        if (!status.isGranted) {
          await NotificationPermissionService.request();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(toUserFriendlyErrorMessage(e)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      if (!mounted) return;

      // Bu setup onboarding'in yerine geçtiği için onboarding'i de tamam say.
      await markOnboardingCompleted();
      if (mounted) {
        ref.read(onboardingCompletedProvider.notifier).state = true;
      }

      // Supabase tarafında "setup tamamlandı" bilgisini kaydet.
      try {
        final profile = await ref.read(currentProfileProvider.future);
        if (profile != null) {
          await ref.read(authRepositoryProvider).updateProfile(
                id: profile.id,
                signupSetupCompleted: true,
              );
        }
      } catch (e) {
        // DB/migration/RLS hatası olsa bile UX bozulmasın:
        // yine de kullanıcıyı ana sayfaya gönderiyoruz.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(toUserFriendlyErrorMessage(e)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // Router hâlâ eski profile verisini görüp tekrar signup-setup'a dönebilir.
      // Bu yüzden profili hemen invalidate edip tazeleyelim.
      ref.invalidate(currentProfileProvider);

    } finally {
      if (mounted) {
        // Bölge filtresi ve tema/locale zaten seçildiği için home'a geçiyoruz.
        context.go('/');
        // Akış kapandığı için step'i sıfırla.
        ref.read(signupSetupStepProvider.notifier).state = 0;
        setState(() => _isFinishing = false);
      }
    }
  }

  // Dil (locale) seçimini uygulayıp metinlerin anında güncellenmesini sağlar.
  Future<void> _applyLocaleOption(String option) async {
    if (option == _selectedLocaleOption) return;
    setState(() => _selectedLocaleOption = option);
    if (widget.sandboxMode) return;

    final delegate = LocalizedApp.of(context).delegate;
    final state = LocalizationProvider.of(context).state;

    if (option == 'system') {
      // Sistem dili, tr/en/de dışındaysa en: fallback.
      await VellumTranslatePreferences.setUseSystemLocale(true);
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final langCode = deviceLocale.languageCode;
      final supported = langCode == 'tr' || langCode == 'en' || langCode == 'de';
      await delegate.changeLocale(localeFromString(supported ? langCode : 'en'));
      state.onLocaleChanged();
      return;
    }

    await VellumTranslatePreferences().savePreferredLocale(
      localeFromString(option),
    );
    await delegate.changeLocale(localeFromString(option));
    state.onLocaleChanged();
  }

  @override
  Widget build(BuildContext context) {
    final pageColor = _pageColors[_currentPage];

    return Scaffold(
      backgroundColor: pageColor,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _totalPages,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              ref.read(signupSetupStepProvider.notifier).state = index;
            },
            itemBuilder: (context, index) {
              return SafeArea(
                child: _SetupStep(
                  stepIndex: index,
                  pageColor: _pageColors[index],
                  selectedLocaleOption: _selectedLocaleOption,
                  onSelectLocale: _applyLocaleOption,
                  selectedRegionCode: _selectedRegionCode,
                  onSelectRegion: (code) {
                    setState(() => _selectedRegionCode = code);
                    if (!widget.sandboxMode) {
                      ref.read(bookLanguageFilterProvider.notifier).state = code;
                    }
                  },
                  selectedThemeMode: _selectedThemeMode,
                  onSelectTheme: (mode) async {
                    setState(() => _selectedThemeMode = mode);
                    if (!widget.sandboxMode) {
                      await saveThemeMode(mode);
                      if (context.mounted) {
                        ref.read(themeModeProvider.notifier).state = mode;
                      }
                    }
                  },
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom,
            child: _BottomBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              isFinishing: _isFinishing,
              onNext: _goNext,
              onFinish: _finish,
              buttonColor: pageColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
    required this.onFinish,
    required this.isFinishing,
    required this.buttonColor,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;
  final Future<void> Function() onFinish;
  final bool isFinishing;
  final Color buttonColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = currentPage == totalPages - 1;

    final buttonChild = Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          isLast ? translate('onboarding.setup_finish') : translate('onboarding.next'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.paddingOf(context).bottom + 24),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(totalPages, (i) {
                  final isActive = i == currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isActive ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.black.withValues(alpha: isActive ? 0.9 : 0.35),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 18),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: isLast
                  ? (isFinishing
                      ? null
                      : () async {
                          await onFinish();
                        })
                  : onNext,
              child: buttonChild,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.stepIndex,
    required this.pageColor,
    required this.selectedLocaleOption,
    required this.onSelectLocale,
    required this.selectedRegionCode,
    required this.onSelectRegion,
    required this.selectedThemeMode,
    required this.onSelectTheme,
  });

  final int stepIndex;
  final Color pageColor;

  final String selectedLocaleOption;
  final Future<void> Function(String option) onSelectLocale;

  final String? selectedRegionCode;
  final ValueChanged<String?> onSelectRegion;

  final ThemeMode selectedThemeMode;
  final Future<void> Function(ThemeMode mode) onSelectTheme;

  static const Map<String, String> _regionLabels = {
    'tr': 'home.language_region_tr',
    'en': 'home.language_region_en',
    'de': 'home.language_region_de',
    'fr': 'home.language_region_fr',
    'ru': 'home.language_region_ru',
    'es': 'home.language_region_es',
    'other': 'home.language_region_other',
  };

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (stepIndex) {
      case _SignupSetupScreenState._languageIntroPage:
        content = const _QuestionIntroStep(
          titleKey: 'onboarding.setup_language_title',
          subtitleKey: 'onboarding.setup_language_subtitle',
          animationAsset: 'assets/animation/dilsecim-kedi.json',
        );
        break;
      case _SignupSetupScreenState._languageAnswerPage:
        content = _LanguageStep(
          selectedOption: selectedLocaleOption,
          onSelectOption: onSelectLocale,
        );
        break;
      case _SignupSetupScreenState._regionIntroPage:
        content = const _QuestionIntroStep(
          titleKey: 'onboarding.setup_region_title',
          subtitleKey: 'onboarding.setup_region_subtitle',
          animationAsset: 'assets/animation/ulkesecim-kedi.json',
        );
        break;
      case _SignupSetupScreenState._regionAnswerPage:
        content = _RegionStep(
          selectedCode: selectedRegionCode,
          onSelectCode: onSelectRegion,
        );
        break;
      case _SignupSetupScreenState._themeIntroPage:
        content = const _QuestionIntroStep(
          titleKey: 'onboarding.setup_theme_title',
          subtitleKey: 'onboarding.setup_theme_subtitle',
          animationAsset: 'assets/animation/tema-kedi.json',
        );
        break;
      case _SignupSetupScreenState._themeAnswerPage:
        content = _ThemeStep(
          selectedThemeMode: selectedThemeMode,
          onSelectThemeMode: onSelectTheme,
        );
        break;
      case _SignupSetupScreenState._notificationsPage:
      default:
        content = _NotificationsStep(onFinishPermission: () {}, isFinishing: false);
        break;
    }

    return Container(
      color: pageColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // İçeriği biraz yukarı taşı.
                  Transform.translate(
                    offset: const Offset(0, -26),
                    child: content,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({
    required this.selectedOption,
    required this.onSelectOption,
  });

  final String selectedOption; // system/tr/en
  final Future<void> Function(String option) onSelectOption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final options = <({String code, String labelKey, String flagAsset})>[
      (code: 'system', labelKey: 'settings.language_system', flagAsset: 'assets/image/flag_system.svg'),
      (code: 'tr', labelKey: 'settings.language_turkish', flagAsset: 'assets/image/flag_tr.svg'),
      (code: 'en', labelKey: 'settings.language_english', flagAsset: 'assets/image/flag_en.svg'),
      (code: 'de', labelKey: 'settings.language_german', flagAsset: 'assets/image/falg_de.svg'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Header(
          icon: Icons.language_rounded,
          title: translate('onboarding.setup_language_title'),
          subtitle: translate('onboarding.setup_language_subtitle'),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final opt in options)
              _ChoiceCard(
                selected: opt.code == selectedOption,
                onTap: () => onSelectOption(opt.code),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      opt.flagAsset,
                      width: 28,
                      height: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      translate(opt.labelKey),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: opt.code == selectedOption ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _HelperText(
          text: translate('onboarding.setup_language_subtitle'),
          // Alt metni aynı anahtar ile gösteriyoruz, kartın altında ekstra vurgu.
        ),
      ],
    );
  }
}

class _RegionStep extends StatelessWidget {
  const _RegionStep({
    required this.selectedCode,
    required this.onSelectCode,
  });

  final String? selectedCode;
  final ValueChanged<String?> onSelectCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final options = <({String? code, String labelKey})>[
      (code: null, labelKey: 'home.language_filter_all'),
      for (final e in _SetupStep._regionLabels.entries)
        (code: e.key, labelKey: e.value),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Header(
          icon: Icons.public_rounded,
          title: translate('onboarding.setup_region_title'),
          subtitle: translate('onboarding.setup_region_subtitle'),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final opt in options)
              _ChoiceCard(
                selected: opt.code == selectedCode,
                onTap: () => onSelectCode(opt.code),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    translate(opt.labelKey),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: opt.code == selectedCode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ThemeStep extends StatelessWidget {
  const _ThemeStep({
    required this.selectedThemeMode,
    required this.onSelectThemeMode,
  });

  final ThemeMode selectedThemeMode;
  final Future<void> Function(ThemeMode mode) onSelectThemeMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = selectedThemeMode == ThemeMode.dark;

    Widget themeCard({
      required ThemeMode mode,
      required IconData icon,
      required String labelKey,
    }) {
      final selected = mode == selectedThemeMode;
      return _ChoiceCard(
        selected: selected,
        onTap: () => onSelectThemeMode(mode),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: selected ? Colors.white : Colors.black87,
            ),
            const SizedBox(height: 10),
            Text(
              translate(labelKey),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Header(
          icon: Icons.palette_rounded,
          title: translate('onboarding.setup_theme_title'),
          subtitle: translate('onboarding.setup_theme_subtitle'),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: themeCard(
                mode: ThemeMode.light,
                icon: Icons.light_mode_rounded,
                labelKey: 'settings.light',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: themeCard(
                mode: ThemeMode.dark,
                icon: Icons.dark_mode_rounded,
                labelKey: 'settings.dark',
              ),
            ),
          ],
        ),
        if (isDark) const SizedBox(height: 8),
      ],
    );
  }
}

class _NotificationsStep extends StatefulWidget {
  const _NotificationsStep({
    required this.onFinishPermission,
    required this.isFinishing,
  });

  final VoidCallback onFinishPermission;
  final bool isFinishing;

  @override
  State<_NotificationsStep> createState() => _NotificationsStepState();
}

class _NotificationsStepState extends State<_NotificationsStep> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          height: 180,
          child: _LottieOrFallback(
            assetPath: 'assets/animation/bildirim-kedi.json',
          ),
        ),
        const SizedBox(height: 8),
        _Header(
          icon: Icons.notifications_rounded,
          title: translate('onboarding.setup_notifications_title'),
          subtitle: translate('onboarding.setup_notifications_subtitle'),
        ),
        const SizedBox(height: 18),
        FutureBuilder<PermissionStatus>(
          future: NotificationPermissionService.status,
          builder: (context, snapshot) {
            final status = snapshot.data;

            final granted = status?.isGranted == true;
            final permanentlyDenied = status?.isPermanentlyDenied == true;

            final title = granted
                ? translate('settings.notifications_on')
                : permanentlyDenied
                    ? translate('settings.notifications_off')
                    : translate('settings.notifications_off_prompt');

            final body = granted
                ? translate('settings.notifications_on_body')
                : permanentlyDenied
                    ? translate('settings.notifications_off_body')
                    : translate('settings.notifications_request_body');

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          granted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                          color: Colors.black87,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (permanentlyDenied)
                    Center(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await NotificationPermissionService.openSettings();
                        },
                        icon: const Icon(Icons.settings_rounded, size: 18),
                        label: Text(translate('settings.open_settings')),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _QuestionIntroStep extends StatelessWidget {
  const _QuestionIntroStep({
    required this.titleKey,
    required this.subtitleKey,
    required this.animationAsset,
  });

  final String titleKey;
  final String subtitleKey;
  final String animationAsset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 220,
          child: _LottieOrFallback(
            assetPath: animationAsset,
            fallbackIcon: Icons.auto_awesome_rounded,
          ),
        ),
        const SizedBox(height: 12),
        _Header(
          icon: Icons.auto_awesome_rounded,
          title: translate(titleKey),
          subtitle: translate(subtitleKey),
        ),
      ],
    );
  }
}

class _LottieOrFallback extends StatelessWidget {
  const _LottieOrFallback({
    required this.assetPath,
    this.fallbackIcon,
  });

  final String assetPath;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      assetPath,
      fit: BoxFit.contain,
      repeat: true,
      errorBuilder: (context, error, stackTrace) {
        if (fallbackIcon == null) {
          return const SizedBox.shrink();
        }
        return Center(
          child: Icon(
            fallbackIcon!,
            size: 84,
            color: Colors.black54,
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final titleSize = size.width * 0.105;
    final subtitleSize = size.width * 0.045;

    final words = title
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 2),
        // Başlığı kelime kelime alt alta gösteriyoruz.
        // Böylece onboarding/giriş akışı gibi daha "duolingo" bir his veriyor.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final w in words)
                Text(
                  w,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    height: 1.05,
                    color: Colors.black,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 3,
            style: GoogleFonts.inter(
              fontSize: subtitleSize,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final radius = 22.0;
    final selectedBorder = theme.colorScheme.primary.withValues(alpha: 0.75);
    final unselectedBorder = Colors.black.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.28),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minWidth: 160, minHeight: 64),
          decoration: BoxDecoration(
            color: selected
                ? Colors.black
                : Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? selectedBorder : unselectedBorder,
              width: selected ? 1.2 : 1.0,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HelperText extends StatelessWidget {
  const _HelperText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: Colors.black54,
        height: 1.3,
      ),
    );
  }
}

