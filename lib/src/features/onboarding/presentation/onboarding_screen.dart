import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app.dart';
import '../../auth/presentation/login_screen.dart';

const _kOnboardingCompleted = 'onboarding_completed';

Future<void> markOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingCompleted, true);
}

Future<bool> isOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingCompleted) ?? false;
}

// ─── Sayfa Verileri ──────────────────────────────────

class _OnboardingPage {
  const _OnboardingPage({
    required this.imagePaths,
    required this.titleKey,
    required this.subtitleKey,
  });

  final List<String> imagePaths;
  final String titleKey;
  final String subtitleKey;
}

const _pages = [
  _OnboardingPage(
    imagePaths: ['assets/image/book.png'],
    titleKey: 'onboarding.page1.title',
    subtitleKey: 'onboarding.page1.subtitle',
  ),
  _OnboardingPage(
    imagePaths: ['assets/image/Humaaans - 3 Characters.png'],
    titleKey: 'onboarding.page2.title',
    subtitleKey: 'onboarding.page2.subtitle',
  ),
  _OnboardingPage(
    imagePaths: ['assets/image/onboarding3.png'],
    titleKey: 'onboarding.page3.title',
    subtitleKey: 'onboarding.page3.subtitle',
  ),
];

/// Glide tarzı: her sayfa farklı canlı renk
const _pageColors = [
  Color(0xFF4F46E5), // Indigo
  Color(0xFFD97706), // Amber / turuncu
  Color(0xFF0891B2), // Cyan / teal
];

// ─── OnboardingScreen ────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  static const int _totalPages = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    final page = _pageController.page ?? 0;
    if (page.floor() < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    await markOnboardingCompleted();
    if (!mounted) return;
    ref.read(onboardingCompletedProvider.notifier).state = true;
  }

  Future<void> _skip() async {
    await _completeOnboarding();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColors.first,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _totalPages,
            onPageChanged: (_) => setState(() {}),
            itemBuilder: (context, index) {
              return _PageContent(
                key: ValueKey(index),
                page: _pages[index],
                pageIndex: index,
                pageColor: _pageColors[index.clamp(0, _pageColors.length - 1)],
              );
            },
          ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _OnboardingBottomBar(
                pageController: _pageController,
                totalPages: _totalPages,
                onNext: _nextPage,
                onSkip: _skip,
                onCompleteOnboarding: _completeOnboarding,
              ),
            ),
          ],
        ),
    );
  }
}

// ─── Alt bar (Glide tarzı: büyük beyaz buton) ─────────────────────────────

class _OnboardingBottomBar extends ConsumerWidget {
  const _OnboardingBottomBar({
    required this.pageController,
    required this.totalPages,
    required this.onNext,
    required this.onSkip,
    required this.onCompleteOnboarding,
  });

  final PageController pageController;
  final int totalPages;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final Future<void> Function() onCompleteOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = theme.brightness == Brightness.dark;
    final openScreenColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7);

    return ListenableBuilder(
      listenable: pageController,
      builder: (context, _) {
        final page = (pageController.page ?? 0).clamp(0.0, (totalPages - 1).toDouble());
        final currentPage = page.floor().clamp(0, totalPages - 1);
        final isLastPage = currentPage == totalPages - 1;
        final pageColor = _pageColors[currentPage];

        final buttonChild = Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
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
              isLastPage ? translate('onboarding.start') : translate('onboarding.next'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: 0.3,
              ),
            ),
          ),
        );

        return Container(
          padding: EdgeInsets.fromLTRB(28, 16, 28, bottomPadding + 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                pageColor.withValues(alpha: 0),
                pageColor,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AnimatedOpacity(
                    opacity: isLastPage ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: TextButton(
                      onPressed: isLastPage ? null : onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.9),
                      ),
                      child: Text(
                        translate('onboarding.skip'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
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
                          color: Colors.white.withValues(alpha: isActive ? 1.0 : 0.5),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  const SizedBox(width: 60),
                ],
              ),
              const SizedBox(height: 16),
              isLastPage
                  ? OpenContainer(
                      transitionDuration: const Duration(milliseconds: 600),
                      closedColor: Colors.white,
                      openColor: openScreenColor,
                      closedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      openShape: const RoundedRectangleBorder(),
                      closedElevation: 0,
                      openElevation: 0,
                      closedBuilder: (context, openContainer) => GestureDetector(
                        onTap: () async {
                          await onCompleteOnboarding();
                          if (context.mounted) openContainer();
                        },
                        child: buttonChild,
                      ),
                      openBuilder: (context, _) => const LoginScreen(),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onNext,
                        borderRadius: BorderRadius.circular(14),
                        child: buttonChild,
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Sayfa İçeriği (tam ekran, örnek tasarım gibi) ─────────────────────────

class _PageContent extends StatelessWidget {
  const _PageContent({
    super.key,
    required this.page,
    required this.pageIndex,
    required this.pageColor,
  });

  final _OnboardingPage page;
  final int pageIndex;
  final Color pageColor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Container(
      color: pageColor,
      child: SafeArea(
        child: Column(
          children: [
            // Üst: logo + başlık + alt metin (ikonlara yakın)
            Padding(
              padding: EdgeInsets.only(
                top: size.height * 0.08,
                left: size.width * 0.06,
                right: size.width * 0.06,
                bottom: size.height * 0.006,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/image/vellum_logo.png',
                    height: size.width * 0.14,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      translate('common.app_name'),
                      style: GoogleFonts.inter(
                        fontSize: size.width * 0.075,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.018),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      translate(page.titleKey),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      style: GoogleFonts.inter(
                        fontSize: size.width * 0.105,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.008),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: size.width * 0.02),
                      child: Text(
                        translate(page.subtitleKey),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: GoogleFonts.inter(
                          fontSize: size.width * 0.052,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Görsel: kalan alanı tamamen doldur (ortada, büyük)
            Expanded(
              child: _OnboardingImage(imagePath: page.imagePaths.first),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tek görsel (tam ekrana sığacak şekilde, kalan alanı doldurur) ─────────

class _OnboardingImage extends StatelessWidget {
  const _OnboardingImage({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final size = w < h / 1.1 ? w : h / 1.1;
        return Center(
          child: SizedBox(
            width: size,
            height: size * 1.1,
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

