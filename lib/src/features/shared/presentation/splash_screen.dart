import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';

/// Uygulama açılışında gösterilen Vellum splash ekranı.
/// Logo gösterir, kısa bekler, sonra auth/onboarding durumuna göre yönlendirir.
/// Üçüncü parti paket kullanılmıyor; GoRouter ile uyumlu ve takılma olmaz.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigateAfterDelay());
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final authState = ref.read(authStateProvider);
    final isLoggedIn = authState.when(
      data: (state) => state.session != null,
      loading: () => false,
      error: (_, __) => false,
    );
    final onboardingDone = ref.read(onboardingCompletedProvider);

    if (!onboardingDone) {
      context.go('/onboarding');
    } else {
      context.go(isLoggedIn ? '/' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : AppColors.primaryDark;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: SizedBox(
          width: 120,
          height: 120,
          child: Image.asset(
            'assets/image/vellum_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.auto_stories_rounded,
              size: 80,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }
}
