import 'package:animations/animations.dart';
import 'package:concentric_transition/concentric_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_colors.dart';
import '../../../utils/responsive.dart';
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
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });

  final String imagePath;
  final String title;
  final String subtitle;
}

const _pages = [
  _OnboardingPage(
    imagePath: 'assets/image/image1.png',
    title: 'Kelimelerin\ndeğeri var.',
    subtitle:
        'Modern parşömenlerin dünyasına hoş geldin.\nBurada her hikaye bir mirastır.',
  ),
  _OnboardingPage(
    imagePath: 'assets/image/image2.png',
    title: 'Eşsiz bir\nokuma deneyimi.',
    subtitle:
        'Gözü yormayan arayüz ve sana özel kütüphanenle,\nhikayelerin içinde kaybol.',
  ),
  _OnboardingPage(
    imagePath: 'assets/image/image1.png',
    title: 'Kendi dünyanı\ninşa et.',
    subtitle:
        'Vellum Pro ile hikayelerini tüm dünyaya aç.\nYayınla ve okuyucularınla bağ kur.',
  ),
];

/// Minimalist mor tonlar (koyu tema)
const _pageColors = [
  Color(0xFF0D0C20),
  Color(0xFF12102A),
  Color(0xFF0D0C20),
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
      body: Stack(
          children: [
            ConcentricPageView(
              pageController: _pageController,
              itemCount: _totalPages,
              colors: _pageColors,
              radius: 36,
              verticalPosition: 0.88,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOutCubic,
              onChange: (_) => setState(() {}),
              nextButtonBuilder: (_) => const SizedBox.shrink(),
              itemBuilder: (index) {
                return _PageContent(
                  key: ValueKey(index),
                  page: _pages[index],
                  pageIndex: index,
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ConcentricBottomBar(
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

// ─── Alt bar (butondan yayılan dalga bu noktadan başlar) ─────────────────

class _ConcentricBottomBar extends ConsumerWidget {
  const _ConcentricBottomBar({
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

        final buttonChild = AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          width: isLastPage ? 150 : 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
              ],
            ),
            borderRadius: BorderRadius.circular(isLastPage ? 16 : 27),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLastPage ? null : onNext,
              borderRadius: BorderRadius.circular(isLastPage ? 16 : 27),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isLastPage
                      ? Text(
                          'Başlayalım',
                          key: const ValueKey('start'),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_forward_rounded,
                          key: ValueKey('arrow'),
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
            ),
          ),
        );

        return Container(
          padding: EdgeInsets.fromLTRB(28, 20, 28, bottomPadding + 32),
          child: Row(
            children: [
              AnimatedOpacity(
                opacity: isLastPage ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: TextButton(
                  onPressed: isLastPage ? null : onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text(
                    'Atla',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(totalPages, (i) {
                  final isActive = i == currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: isActive ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.25),
                    ),
                  );
                }),
              ),
              const Spacer(),
              isLastPage
                  ? OpenContainer(
                      transitionDuration: const Duration(milliseconds: 600),
                      closedColor: AppColors.primary,
                      openColor: openScreenColor,
                      closedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      openShape: const RoundedRectangleBorder(),
                      closedElevation: 4,
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
                  : buttonChild,
            ],
          ),
        );
      },
    );
  }
}

// ─── Sayfa İçeriği (animasyonsuz; sadece sayfa geçişi ve buton animasyonlu) ─

class _PageContent extends StatelessWidget {
  const _PageContent({
    super.key,
    required this.page,
    required this.pageIndex,
  });

  final _OnboardingPage page;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    final size = MediaQuery.sizeOf(context);
    final imageSize = isMobile ? size.width * 0.55 : 280.0;

    return Container(
      color: _pageColors[pageIndex.clamp(0, _pageColors.length - 1)],
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 32 : 64),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              _CircularImage(imagePath: page.imagePath, size: imageSize),
              SizedBox(height: isMobile ? 44 : 52),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  textStyle: (isMobile
                          ? theme.textTheme.headlineMedium
                          : theme.textTheme.headlineLarge)
                      ?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.15,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Text(
                  page.subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.65,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Yuvarlak Görsel (minimalist mor vurgu) ─────────────────────────────

class _CircularImage extends StatelessWidget {
  const _CircularImage({
    required this.imagePath,
    required this.size,
  });

  final String imagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
          ),
          Container(
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(imagePath, fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }
}
