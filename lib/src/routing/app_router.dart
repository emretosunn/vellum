import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/library/presentation/book_detail_screen.dart';
import '../features/library/presentation/home_screen.dart';
import '../features/library/presentation/reader_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shared/widgets/scaffold_with_nav.dart';
import '../features/studio/presentation/book_editor_screen.dart';
import '../features/studio/presentation/chapter_editor_screen.dart';
import '../features/studio/presentation/writer_studio_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';

/// GoRouter yapılandırması.
///
/// [isLoggedIn] parametresi auth durumuna göre yönlendirme yapar.
GoRouter createRouter({bool isLoggedIn = false}) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !loggingIn) return '/login';
      if (isLoggedIn && loggingIn) return '/';

      return null;
    },
    routes: [
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

      // Kitap okuyucu
      GoRoute(
        path: '/reader/:bookId',
        name: 'reader',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId'] ?? '';
          return ReaderScreen(bookId: bookId);
        },
      ),

      // Ana navigasyon shell'i (4 tab: Home, Stüdyo, Cüzdan, Ayarlar)
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

          // Branch 2: Cüzdan
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                name: 'wallet',
                builder: (context, state) => const WalletScreen(),
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
