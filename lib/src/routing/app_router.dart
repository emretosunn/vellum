import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/library/presentation/all_books_screen.dart';
import '../features/library/presentation/author_profile_screen.dart';
import '../features/library/presentation/book_detail_screen.dart';
import '../features/library/presentation/home_screen.dart';
import '../features/library/presentation/reader_screen.dart';
import '../features/library/presentation/discovery_canvas_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/presentation/signup_setup_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shared/widgets/scaffold_with_nav.dart';
import '../features/shared/presentation/splash_screen.dart';
import '../features/studio/presentation/book_editor_screen.dart';
import '../features/studio/presentation/chapter_editor_screen.dart';
import '../features/studio/presentation/writer_studio_screen.dart';
import '../features/subscription/presentation/subscription_screen.dart';
import '../features/subscription/presentation/premium_upgrade_screen.dart';

final GlobalKey<NavigatorState> _homeBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'homeBranchNav');
final GlobalKey<NavigatorState> _studioBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'studioBranchNav');
final GlobalKey<NavigatorState> _discoveryBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'discoveryBranchNav');
final GlobalKey<NavigatorState> _subscriptionBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'subscriptionBranchNav');
final GlobalKey<NavigatorState> _settingsBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'settingsBranchNav');

/// GoRouter yapılandırması.
///
/// [isLoggedIn] parametresi auth durumuna göre yönlendirme yapar.
/// [onboardingCompleted] onboarding süreci tamamlandı mı kontrol eder.
GoRouter createRouter({
  bool isLoggedIn = false,
  bool onboardingCompleted = true,
  bool signupSetupPending = false,
  bool forceSignupSetup = false,
  bool signupSetupRedirectOverride = false,
}) {
  return GoRouter(
    initialLocation: '/splash',
    // Web'de OAuth callback gibi deep-link URL'leri geldiğinde
    // browser'ın mevcut URL'ini ezmeyelim.
    overridePlatformDefaultLocation: false,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isOnboarding = location == '/onboarding';
      final isLogin = location == '/login';
      final isSignupSetup = location == '/signup-setup';
      final isAuthCallback = location == '/auth-callback' ||
          location == '/auth/callback' ||
          location == '/login-callback';

      // Splash ekranı her zaman ilk açılışta bir kere gösterilsin.
      // Sonraki yönlendirmeler splash üzerinden root'a atlayacak.
      if (isSplash) return null;
      // OAuth callback sayfasını serbest bırak.
      // Burada auth state güncellenirken router yarışına girmesin.
      if (isAuthCallback) return null;

      // Signup sonrası kişiselleştirme adımı:
      // Döngüleri engellemek için setup ekranına zorlamayı yalnızca geçici
      // `signupSetupPending` bayrağı ile yapıyoruz.
      if (!signupSetupRedirectOverride &&
          signupSetupPending &&
          isLoggedIn &&
          !isSignupSetup) {
        return '/signup-setup';
      }

      // Onboarding henüz tamamlanmadıysa oraya yönlendir (signup-setup hariç)
      if (!isLoggedIn &&
          !onboardingCompleted &&
          !isOnboarding &&
          !isSignupSetup) {
        return '/onboarding';
      }
      // Onboarding tamamlandıysa oraya gitmeyi engelle
      if (onboardingCompleted && isOnboarding) {
        return isLoggedIn ? '/' : '/login';
      }
      // Oturum açıkken klasik onboarding'e geri dönmeyelim.
      // (Kullanıcının ikinci kez onboarding turuna zorlanmasını engeller.)
      if (isLoggedIn && isOnboarding) {
        return '/';
      }

      // Auth yönlendirmeleri
      if (!isLoggedIn && !isLogin && !isOnboarding && !isSignupSetup) {
        return '/login';
      }
      if (isLoggedIn && isLogin) {
        return (!signupSetupRedirectOverride && signupSetupPending)
            ? '/signup-setup'
            : '/';
      }

      return null;
    },
    routes: [
      // Splash ekranı (ilk açılışta kısa V animasyonu)
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Onboarding ekranı (ilk açılış)
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Kayıt sonrası kişiselleştirme (dil/bölge/tema/bildirim)
      GoRoute(
        path: '/signup-setup',
        name: 'signupSetup',
        builder: (context, state) => const SignupSetupScreen(),
      ),

      // OAuth provider (Google/Facebook) callback dönüşü.
      // Callback sonrası auth state güncelleneceği için Splash akışıyla devam edilir.
      GoRoute(
        path: '/auth/callback',
        name: 'authCallback',
        builder: (context, state) => const SplashScreen(),
      ),
      // iOS/Android eski redirect şemaları için geriye dönük uyumluluk.
      GoRoute(
        path: '/login-callback',
        name: 'loginCallbackLegacy',
        builder: (context, state) => const SplashScreen(),
      ),

      // Login ekranı (shell dışında)
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Kitap detay (shell dışında — tam ekran)
      GoRoute(
        path: '/book/:id',
        name: 'bookDetail',
        builder: (context, state) {
          final bookId = state.pathParameters['id'] ?? '';
          return BookDetailScreen(bookId: bookId);
        },
      ),

      // Vellum Pro yükseltme ekranı
      GoRoute(
        path: '/premium-upgrade',
        name: 'premiumUpgrade',
        builder: (context, state) => const PremiumUpgradeScreen(),
      ),

      // Tüm kitaplar (Tümünü Gör — en fazla 25)
      GoRoute(
        path: '/books',
        name: 'allBooks',
        builder: (context, state) => const AllBooksScreen(),
      ),

      // Yazar profili (shell dışında — tam ekran)
      GoRoute(
        path: '/author/:id',
        name: 'authorProfile',
        builder: (context, state) {
          final authorId = state.pathParameters['id'] ?? '';
          return AuthorProfileScreen(authorId: authorId);
        },
      ),

      // Bölüm editörü (shell dışında — tam ekran)
      GoRoute(
        path: '/editor/:bookId',
        name: 'chapterEditor',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId'] ?? '';
          final chapterId = state.uri.queryParameters['chapterId'];
          return ChapterEditorScreen(
            bookId: bookId,
            chapterId: chapterId,
          );
        },
      ),

      // Sayfa bazlı kitap editörü
      GoRoute(
        path: '/book-editor/:bookId',
        name: 'bookEditor',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId'] ?? '';
          return BookEditorScreen(bookId: bookId);
        },
      ),

      // Kitap okuyucu (query: chapter = bölüm indeksi, 0 tabanlı)
      GoRoute(
        path: '/reader/:bookId',
        name: 'reader',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId'] ?? '';
          final chapter = state.uri.queryParameters['chapter'];
          final initialChapterIndex = chapter != null ? int.tryParse(chapter) ?? 0 : 0;
          return ReaderScreen(bookId: bookId, initialChapterIndex: initialChapterIndex);
        },
      ),

      // Ana navigasyon shell'i (4 tab: Home, Stüdyo, Abonelik, Ayarlar)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNav(
            navigationShell: navigationShell,
            branchNavigatorKeys: [
              _homeBranchNavigatorKey,
              _studioBranchNavigatorKey,
              _discoveryBranchNavigatorKey,
              _subscriptionBranchNavigatorKey,
              _settingsBranchNavigatorKey,
            ],
          );
        },
        branches: [
          // Branch 0: Ana Sayfa
          StatefulShellBranch(
            navigatorKey: _homeBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Branch 1: Stüdyo
          StatefulShellBranch(
            navigatorKey: _studioBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/studio',
                name: 'studio',
                builder: (context, state) => const WriterStudioScreen(),
              ),
            ],
          ),

          // Branch 2: Abonelik
          StatefulShellBranch(
            navigatorKey: _discoveryBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/discovery-canvas',
                name: 'discoveryCanvas',
                builder: (context, state) => const DiscoveryCanvasScreen(),
              ),
            ],
          ),

          // Branch 3: Abonelik
          StatefulShellBranch(
            navigatorKey: _subscriptionBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/subscription',
                name: 'subscription',
                builder: (context, state) => const SubscriptionScreen(),
              ),
            ],
          ),

          // Branch 4: Ayarlar
          StatefulShellBranch(
            navigatorKey: _settingsBranchNavigatorKey,
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
