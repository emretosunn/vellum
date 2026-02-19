import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_colors.dart';
import '../../../utils/responsive.dart';
import '../../../app.dart';

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
    required this.accentColor,
  });

  final String imagePath;
  final String title;
  final String subtitle;
  final Color accentColor;
}

const _pages = [
  _OnboardingPage(
    imagePath: 'assets/image/image1.png',
    title: 'Kelimelerin\ndeğeri var.',
    subtitle:
        'Modern parşömenlerin dünyasına hoş geldin.\nBurada her hikaye bir mirastır.',
    accentColor: Color(0xFFD4AF37),
  ),
  _OnboardingPage(
    imagePath: 'assets/image/image2.png',
    title: 'Eşsiz bir\nokuma deneyimi.',
    subtitle:
        'Gözü yormayan arayüz ve sana özel kütüphanenle,\nhikayelerin içinde kaybol.',
    accentColor: Color(0xFF9D97FF),
  ),
  _OnboardingPage(
    imagePath: 'assets/image/image1.png',
    title: 'Kendi dünyanı\ninşa et.',
    subtitle:
        'Vellum Pro ile hikayelerini tüm dünyaya aç.\nYayınla ve okuyucularınla bağ kur.',
    accentColor: Color(0xFFD4AF37),
  ),
];

// ─── OnboardingScreen ────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

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
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    await markOnboardingCompleted();
    if (!mounted) return;
    ref.read(onboardingCompletedProvider.notifier).state = true;
    context.go('/login');
  }

  void _skip() => _completeOnboarding();

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _nextPage();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF08081A),
                      const Color(0xFF0D0C20),
                      const Color(0xFF08081A),
                    ]
                  : [
                      const Color(0xFFFBFAFF),
                      const Color(0xFFF5F2FF),
                      const Color(0xFFFBFAFF),
                    ],
            ),
          ),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  return _PageContent(
                    key: ValueKey(index),
                    page: _pages[index],
                  );
                },
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomControls(
                  currentPage: _currentPage,
                  totalPages: _pages.length,
                  onNext: _nextPage,
                  onSkip: _skip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sayfa İçeriği ───────────────────────────────────

class _PageContent extends StatelessWidget {
  const _PageContent({
    super.key,
    required this.page,
  });

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    final size = MediaQuery.sizeOf(context);
    final imageSize = isMobile ? size.width * 0.55 : 280.0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 32 : 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            _CircularImage(
              imagePath: page.imagePath,
              size: imageSize,
              accentColor: page.accentColor,
            ),

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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  height: 1.65,
                  letterSpacing: 0.15,
                ),
              ),
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

// ─── Yuvarlak Görsel ─────────────────────────────────

class _CircularImage extends StatelessWidget {
  const _CircularImage({
    required this.imagePath,
    required this.size,
    required this.accentColor,
  });

  final String imagePath;
  final double size;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dış halka
          Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
          ),

          // Görsel
          Container(
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.25),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.2),
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

// ─── Alt Kontroller ──────────────────────────────────

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
    required this.onSkip,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  bool get _isLastPage => currentPage == totalPages - 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        28,
        20,
        28,
        bottomPadding + 32,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0x00080818),
                  const Color(0xDD080818),
                ]
              : [
                  const Color(0x00FBFAFF),
                  const Color(0xDDFBFAFF),
                ],
        ),
      ),
      child: Row(
        children: [
          // Atla
          AnimatedOpacity(
            opacity: _isLastPage ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: TextButton(
              onPressed: _isLastPage ? null : onSkip,
              style: TextButton.styleFrom(
                foregroundColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: Text(
                'Atla',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Dot indicator
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
                      : AppColors.primary.withValues(alpha: 0.18),
                ),
              );
            }),
          ),

          const Spacer(),

          // Buton
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            width: _isLastPage ? 150 : 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7C6AFF), AppColors.primaryDark],
              ),
              borderRadius:
                  BorderRadius.circular(_isLastPage ? 16 : 27),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onNext,
                borderRadius:
                    BorderRadius.circular(_isLastPage ? 16 : 27),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isLastPage
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
          ),
        ],
      ),
    );
  }
}
