import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/library/presentation/all_books_screen.dart';
import '../features/library/presentation/author_profile_screen.dart';
import '../features/library/presentation/book_detail_screen.dart';
import '../features/library/presentation/home_screen.dart';
import '../features/library/presentation/reader_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shared/widgets/scaffold_with_nav.dart';
import '../features/shared/presentation/splash_screen.dart';
import '../features/studio/presentation/book_editor_screen.dart';
import '../features/studio/presentation/chapter_editor_screen.dart';
import '../features/studio/presentation/writer_studio_screen.dart';
import '../features/subscription/presentation/subscription_screen.dart';
import '../features/subscription/presentation/premium_upgrade_screen.dart';

/// GoRouter yapılandırması.
///
/// [isLoggedIn] parametresi auth durumuna göre yönlendirme yapar.
/// [onboardingCompleted] onboarding süreci tamamlandı mı kontrol eder.
GoRouter createRouter({
  bool isLoggedIn = false,
  bool onboardingCompleted = true,
}) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isOnboarding = location == '/onboarding';
      final isLogin = location == '/login';

      // Splash ekranı her zaman ilk açılışta bir kere gösterilsin.
      // Sonraki yönlendirmeler splash üzerinden root'a atlayacak.
      if (isSplash) return null;

      // Onboarding henüz tamamlanmadıysa oraya yönlendir
      if (!onboardingCompleted && !isOnboarding) return '/onboarding';
      // Onboarding tamamlandıysa oraya gitmeyi engelle
      if (onboardingCompleted && isOnboarding) {
        return isLoggedIn ? '/' : '/login';
      }

      // Auth yönlendirmeleri
      if (!isLoggedIn && !isLogin && !isOnboarding) return '/login';
      if (isLoggedIn && isLogin) return '/';

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
          return ScaffoldWithNav(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Ana Sayfa
          StatefulShellBranch(
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
            routes: [
              GoRoute(
                path: '/subscription',
                name: 'subscription',
                builder: (context, state) => const SubscriptionScreen(),
              ),
            ],
          ),

          // Branch 3: Ayarlar
          StatefulShellBranch(
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
