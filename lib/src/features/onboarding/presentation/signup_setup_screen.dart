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
import '../../library/data/book_repository.dart'
    show bookLanguageFilterProvider;
import '../../settings/presentation/settings_screen.dart'
    show themeModeProvider;
import '../../settings/services/notification_permission_service.dart';
import 'onboarding_screen.dart' show markOnboardingCompleted;
import '../../auth/data/auth_repository.dart'
    show authRepositoryProvider, currentProfileProvider, profileByIdProvider;

class SignupSetupScreen extends ConsumerStatefulWidget {
  const SignupSetupScreen({super.key, this.sandboxMode = false});

  final bool sandboxMode;

  @override
  ConsumerState<SignupSetupScreen> createState() => _SignupSetupScreenState();
}

class _SignupSetupScreenState extends ConsumerState<SignupSetupScreen> {
  static const String _localSetupDoneKeyPrefix = 'signup_setup_completed_';
  static const String _localAgeKeyPrefix = 'user_age_';
  static const String _localAllowAdultKeyPrefix = 'allow_adult_content_';
  late final PageController _pageController;
  static const int _totalPages = 11;
  static const int _profileIntroPage = 0;
  static const int _profileAnswerPage = 1;
  static const int _birthIntroPage = 2;
  static const int _birthAnswerPage = 3;
  static const int _languageIntroPage = 4;
  static const int _languageAnswerPage = 5;
  static const int _regionIntroPage = 6;
  static const int _regionAnswerPage = 7;
  static const int _themeIntroPage = 8;
  static const int _themeAnswerPage = 9;
  static const int _notificationsPage = 10;
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
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentPage = ref
        .read(signupSetupStepProvider)
        .clamp(0, _totalPages - 1)
        .toInt();
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

      final currentLang = LocalizedApp.of(
        context,
      ).delegate.currentLocale.languageCode;
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final profile = await ref.read(currentProfileProvider.future);
        if (!mounted) return;
        final authUser = ref.read(authRepositoryProvider).currentUser;
        final suggestedUsername =
            (authUser?.userMetadata?['username'] as String?)?.trim();
        setState(() {
          // Kullanıcı yazmaya başlamışsa async prefill ile üzerine yazma.
          final usernameEmpty = _usernameController.text.trim().isEmpty;
          if (usernameEmpty &&
              profile != null &&
              profile.username.trim().isNotEmpty) {
            _usernameController.text = profile.username;
          } else if (usernameEmpty &&
              suggestedUsername != null &&
              suggestedUsername.isNotEmpty) {
            _usernameController.text = suggestedUsername;
          }
          if (_birthDateController.text.trim().isEmpty &&
              profile?.birthDate != null) {
            final date = profile!.birthDate!;
            final day = date.day.toString().padLeft(2, '0');
            final month = date.month.toString().padLeft(2, '0');
            final year = date.year.toString();
            _birthDateController.text = '$day.$month.$year';
          }
        });
      } catch (_) {
        // ignore
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _birthDateController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentPage == _profileAnswerPage && !_validateProfileStep()) {
      return;
    }
    if (_currentPage == _birthAnswerPage && !_validateBirthStep()) {
      return;
    }
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

    // Kullanıcı swipe ile ara adımları geçebilirse bile
    // bitirmede kritik doğrulamaları zorunlu tut.
    if (!_validateProfileStep()) {
      if (mounted) {
        setState(() {
          _isFinishing = false;
          _currentPage = _profileAnswerPage;
        });
        _pageController.animateToPage(
          _profileAnswerPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    if (!_validateBirthStep()) {
      if (mounted) {
        setState(() {
          _isFinishing = false;
          _currentPage = _birthAnswerPage;
        });
        _pageController.animateToPage(
          _birthAnswerPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

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
    try {
      final userId = ref.read(authRepositoryProvider).currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final birthDate = _parseBirthDate(_birthDateController.text.trim());
      final age = int.tryParse(_ageController.text.trim());
      final username = _usernameController.text.trim();

      // KRITIK: Onboarding tamamlanmadan önce Supabase'e yazım başarılı olmalı.
      await ref
          .read(authRepositoryProvider)
          .updateProfile(
            id: userId,
            username: username,
            age: age,
            birthDate: birthDate,
            signupSetupCompleted: true,
          );

      // Yazım doğrulaması: taze profile tekrar çekilip username kontrol edilir.
      final refreshed = await ref.refresh(currentProfileProvider.future);
      if (refreshed == null ||
          refreshed.username.trim().toLowerCase() != username.toLowerCase()) {
        throw StateError(
          'Kullanıcı adı kaydı doğrulanamadı. Lütfen farklı bir kullanıcı adı deneyin.',
        );
      }

      // Onboarding başarıyla DB'ye yazıldıktan SONRA local flag'leri bırak.
      final currentUserId = ref.read(authRepositoryProvider).currentUser?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('$_localSetupDoneKeyPrefix$currentUserId', true);
        final age = int.tryParse(_ageController.text.trim()) ?? 18;
        await prefs.setInt('$_localAgeKeyPrefix$currentUserId', age);
        await prefs.setBool(
          '$_localAllowAdultKeyPrefix$currentUserId',
          age >= 18,
        );
      }

      // Setup artık tamamlandı; router yeniden setup'a döndürmesin.
      ref.read(signupSetupPendingProvider.notifier).state = false;
      ref.read(signupSetupRedirectOverrideProvider.notifier).state = true;
      ref.read(signupSetupStepProvider.notifier).state = 0;

      // İsteğe bağlı: bildirim iznini akış sonunda iste.
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

      // Bu setup onboarding'in yerine geçtiği için sadece burada tamam say.
      await markOnboardingCompleted();
      if (mounted) {
        ref.read(onboardingCompletedProvider.notifier).state = true;
      }

      // Router hâlâ eski profile verisini görüp tekrar signup-setup'a dönebilir.
      // Bu yüzden profili hemen invalidate edip tazeleyelim.
      ref.invalidate(currentProfileProvider);
      final uidForInvalidate = ref.read(authRepositoryProvider).currentUser?.id;
      if (uidForInvalidate != null && uidForInvalidate.isNotEmpty) {
        ref.invalidate(profileByIdProvider(uidForInvalidate));
      }
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        final raw = e.toString().toLowerCase();
        final duplicateUsername =
            raw.contains('duplicate key') || raw.contains('username');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              duplicateUsername
                  ? 'Bu kullanıcı adı zaten kullanılıyor. Lütfen başka bir kullanıcı adı deneyin.'
                  : toUserFriendlyErrorMessage(e),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
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
      final supported =
          langCode == 'tr' || langCode == 'en' || langCode == 'de';
      await delegate.changeLocale(
        localeFromString(supported ? langCode : 'en'),
      );
      state.onLocaleChanged();
      return;
    }

    await VellumTranslatePreferences().savePreferredLocale(
      localeFromString(option),
    );
    await delegate.changeLocale(localeFromString(option));
    state.onLocaleChanged();
  }

  bool _validateProfileStep() {
    final username = _usernameController.text.trim();

    String? message;
    if (username.length < 3) {
      message = translate('onboarding.setup_profile_username_required');
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
      return false;
    }
    return true;
  }

  bool _validateBirthStep() {
    final dt = _parseBirthDate(_birthDateController.text.trim());
    final age = _calculateAge(dt);
    if (dt == null || age == null || age < 13 || age > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translate('onboarding.setup_profile_age_invalid')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    _ageController.text = age.toString();
    return true;
  }

  DateTime? _parseBirthDate(String raw) {
    final parts = raw.split('.');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    try {
      final dt = DateTime(y, m, d);
      if (dt.day != d || dt.month != m || dt.year != y) return null;
      return dt;
    } catch (_) {
      return null;
    }
  }

  int? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    final hasBirthdayPassed =
        (today.month > birthDate.month) ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hasBirthdayPassed) age--;
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final pageColor = _pageColors[_currentPage];

    return Scaffold(
      backgroundColor: pageColor,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
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
                    ageController: _ageController,
                    birthDateController: _birthDateController,
                    usernameController: _usernameController,
                    selectedLocaleOption: _selectedLocaleOption,
                    onSelectLocale: _applyLocaleOption,
                    selectedRegionCode: _selectedRegionCode,
                    onSelectRegion: (code) {
                      setState(() => _selectedRegionCode = code);
                      if (!widget.sandboxMode) {
                        ref.read(bookLanguageFilterProvider.notifier).state =
                            code;
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
          isLast
              ? translate('onboarding.setup_finish')
              : translate('onboarding.next'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
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
                      color: Colors.black.withValues(
                        alpha: isActive ? 0.9 : 0.35,
                      ),
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
    required this.ageController,
    required this.birthDateController,
    required this.usernameController,
    required this.selectedLocaleOption,
    required this.onSelectLocale,
    required this.selectedRegionCode,
    required this.onSelectRegion,
    required this.selectedThemeMode,
    required this.onSelectTheme,
  });

  final int stepIndex;
  final Color pageColor;
  final TextEditingController ageController;
  final TextEditingController birthDateController;
  final TextEditingController usernameController;

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
      case _SignupSetupScreenState._profileIntroPage:
        content = const _QuestionIntroStep(
          titleKey: 'onboarding.setup_profile_title',
          subtitleKey: 'onboarding.setup_profile_subtitle',
          animationAsset: 'assets/animation/info-1.json',
        );
        break;
      case _SignupSetupScreenState._profileAnswerPage:
        content = _UsernameSetupStep(usernameController: usernameController);
        break;
      case _SignupSetupScreenState._birthIntroPage:
        content = const _QuestionIntroStep(
          titleKey: 'onboarding.setup_birth_intro_title',
          subtitleKey: 'onboarding.setup_birth_intro_subtitle',
          animationAsset: 'assets/animation/info-2.json',
        );
        break;
      case _SignupSetupScreenState._birthAnswerPage:
        content = _BirthDateSetupStep(birthDateController: birthDateController);
        break;
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
        content = _NotificationsStep(
          onFinishPermission: () {},
          isFinishing: false,
        );
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
      (
        code: 'system',
        labelKey: 'settings.language_system',
        flagAsset: 'assets/image/flag_system.svg',
      ),
      (
        code: 'tr',
        labelKey: 'settings.language_turkish',
        flagAsset: 'assets/image/flag_tr.svg',
      ),
      (
        code: 'en',
        labelKey: 'settings.language_english',
        flagAsset: 'assets/image/flag_en.svg',
      ),
      (
        code: 'de',
        labelKey: 'settings.language_german',
        flagAsset: 'assets/image/falg_de.svg',
      ),
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
                    SvgPicture.asset(opt.flagAsset, width: 28, height: 18),
                    const SizedBox(width: 12),
                    Text(
                      translate(opt.labelKey),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: opt.code == selectedOption
                            ? Colors.white
                            : Colors.black87,
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

class _UsernameSetupStep extends StatelessWidget {
  const _UsernameSetupStep({required this.usernameController});

  final TextEditingController usernameController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Header(
          icon: Icons.badge_outlined,
          title: translate('onboarding.setup_profile_title'),
          subtitle: translate('onboarding.setup_profile_subtitle'),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              _ProfileField(
                controller: usernameController,
                label: translate('onboarding.setup_profile_username_label'),
                hint: translate('onboarding.setup_profile_username_hint'),
                keyboardType: TextInputType.text,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BirthDateSetupStep extends StatelessWidget {
  const _BirthDateSetupStep({required this.birthDateController});

  final TextEditingController birthDateController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Header(
          icon: Icons.cake_outlined,
          title: translate('onboarding.setup_birth_date_label'),
          subtitle: translate('onboarding.setup_birth_date_hint'),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _BirthDateField(controller: birthDateController),
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.done,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.16)),
        ),
      ),
      style: theme.textTheme.bodyLarge,
    );
  }
}

class _BirthDateField extends StatefulWidget {
  const _BirthDateField({required this.controller});
  final TextEditingController controller;

  @override
  State<_BirthDateField> createState() => _BirthDateFieldState();
}

class _BirthDateFieldState extends State<_BirthDateField> {
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );
    if (picked == null) return;
    final day = picked.day.toString().padLeft(2, '0');
    final month = picked.month.toString().padLeft(2, '0');
    final year = picked.year.toString();
    widget.controller.text = '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: widget.controller,
      readOnly: true,
      onTap: _pickDate,
      decoration: InputDecoration(
        labelText: translate('onboarding.setup_birth_date_label'),
        hintText: translate('onboarding.setup_birth_date_placeholder'),
        suffixIcon: const Icon(Icons.calendar_month_outlined),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.16)),
        ),
      ),
      style: theme.textTheme.bodyLarge,
    );
  }
}

class _RegionStep extends StatelessWidget {
  const _RegionStep({required this.selectedCode, required this.onSelectCode});

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
                      color: opt.code == selectedCode
                          ? Colors.white
                          : Colors.black87,
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
  bool _autoRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _autoRequested) return;
      _autoRequested = true;
      final status = await NotificationPermissionService.status;
      if (!mounted) return;
      if (!status.isGranted && !status.isPermanentlyDenied) {
        await NotificationPermissionService.request();
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _handleNotificationPermissionTap() async {
    final status = await NotificationPermissionService.status;
    if (status.isPermanentlyDenied) {
      await NotificationPermissionService.openSettings();
      if (mounted) setState(() {});
      return;
    }
    if (!status.isGranted) {
      await NotificationPermissionService.request();
      if (mounted) setState(() {});
    }
  }

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

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _handleNotificationPermissionTap,
              child: Container(
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
                            granted
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_rounded,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
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
  const _LottieOrFallback({required this.assetPath, this.fallbackIcon});

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
          child: Icon(fallbackIcon!, size: 84, color: Colors.black54),
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
    final titleLines = _buildTitleLines(words, size.width);

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
              for (final w in titleLines)
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

  List<String> _buildTitleLines(List<String> words, double screenWidth) {
    if (words.isEmpty) return const [];
    if (words.length == 1) return words;

    final compact = screenWidth < 380;
    final medium = screenWidth >= 380 && screenWidth < 520;
    final maxLineChars = compact ? 10 : (medium ? 14 : 18);
    final maxWordsPerLine = compact ? 2 : 3;

    final lines = <String>[];
    var current = <String>[];
    var currentLen = 0;

    for (final word in words) {
      final nextLen = current.isEmpty
          ? word.length
          : currentLen + 1 + word.length;
      final canAppend =
          current.length < maxWordsPerLine && nextLen <= maxLineChars;
      if (canAppend) {
        current.add(word);
        currentLen = nextLen;
      } else {
        lines.add(current.join(' '));
        current = [word];
        currentLen = word.length;
      }
    }

    if (current.isNotEmpty) {
      lines.add(current.join(' '));
    }

    return lines;
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
            color: selected ? Colors.black : Colors.white,
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
