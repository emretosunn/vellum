import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:go_router/go_router.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../../../constants/app_assets.dart';
import '../../../constants/app_colors.dart';
import '../data/book_repository.dart';
import '../domain/book.dart';

final discoveryCanvasTransformProvider = StateProvider<Matrix4?>((ref) => null);

class DiscoveryCanvasScreen extends ConsumerStatefulWidget {
  const DiscoveryCanvasScreen({super.key});

  @override
  ConsumerState<DiscoveryCanvasScreen> createState() =>
      _DiscoveryCanvasScreenState();
}

class _DiscoveryCanvasScreenState extends ConsumerState<DiscoveryCanvasScreen> {
  late final TransformationController _transformationController;
  bool _initializedDefaultView = false;
  int _visibleCount = 16;
  static const int _pageSize = 25;
  final List<Book> _books = <Book>[];
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _initialError;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _loadInitialBooks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final saved = ref.read(discoveryCanvasTransformProvider);
      if (saved != null) {
        _transformationController.value = Matrix4.copy(saved);
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _storeTransform() {
    ref.read(discoveryCanvasTransformProvider.notifier).state =
        Matrix4.copy(_transformationController.value);
  }

  Future<void> _loadInitialBooks() async {
    setState(() {
      _isInitialLoading = true;
      _initialError = null;
      _books.clear();
      _hasMore = true;
      _visibleCount = 16;
    });
    await _loadMoreBooks(isInitial: true);
  }

  Future<void> _loadMoreBooks({bool isInitial = false}) async {
    if (_isLoadingMore) return;
    if (!_hasMore && !isInitial) return;

    setState(() {
      _isLoadingMore = true;
      if (isInitial) {
        _initialError = null;
      }
    });

    try {
      final batch = await ref.read(bookRepositoryProvider).getPublishedBooks(
        limit: _pageSize,
        offset: _books.length,
        sortOrder: BookSortOrder.recent,
      );

      if (!mounted) return;
      setState(() {
        _books.addAll(batch);
        _hasMore = batch.length == _pageSize;
        if (_visibleCount > _books.length) {
          _visibleCount = _books.length;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (isInitial && _books.isEmpty) {
          _initialError = error;
        }
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(translate('discovery_canvas.title')),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.88),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.50),
            ),
          ),
        ),
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : (_initialError != null && _books.isEmpty)
              ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  translate('discovery_canvas.error_load'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _loadInitialBooks,
                  child: Text(translate('common.retry')),
                ),
              ],
            ),
          ),
        )
              : LayoutBuilder(
            builder: (context, constraints) {
              final canvasWidth = constraints.maxWidth * 2.2;
              final canvasHeight = constraints.maxHeight * 2.2;
              final nodes = _buildNodes(
                _books,
                Size(canvasWidth, canvasHeight),
              );

              if (!_initializedDefaultView &&
                  ref.read(discoveryCanvasTransformProvider) == null) {
                _initializedDefaultView = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  // İlk açılışta tuvalin ortasına yakın konuma getir;
                  // kullanıcı tek kitap değil, daha zengin bir dağılım görsün.
                  _transformationController.value = Matrix4.identity()
                    ..translate(
                      -(canvasWidth - constraints.maxWidth) * 0.42,
                      -(canvasHeight - constraints.maxHeight) * 0.32,
                    );
                  _storeTransform();
                });
              }

              return Column(
                children: [
                  Expanded(
                    child: nodes.isEmpty
                        ? Center(
                            child: Text(
                              translate('discovery_canvas.empty'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : InteractiveViewer(
                            transformationController: _transformationController,
                            minScale: 0.5,
                            maxScale: 2.5,
                            constrained: false,
                            boundaryMargin: const EdgeInsets.all(300),
                            onInteractionEnd: (_) {
                              _storeTransform();
                              if (_visibleCount < nodes.length) {
                                setState(() {
                                  _visibleCount =
                                      (_visibleCount + 10).clamp(0, nodes.length);
                                });
                              }
                              final isNearRenderedEnd =
                                  _visibleCount + 8 >= nodes.length;
                              if (isNearRenderedEnd && _hasMore) {
                                _loadMoreBooks();
                              }
                            },
                            child: SizedBox(
                              width: canvasWidth,
                              height: canvasHeight,
                              child: Stack(
                                children: [
                                  for (final node
                                      in nodes.take(_visibleCount))
                                    Positioned(
                                      left: node.dx,
                                      top: node.dy,
                                      child: _CanvasBookCover(
                                        book: node.book,
                                        angle: node.angle,
                                        onTap: () async {
                                          _storeTransform();
                                          await context.push('/book/${node.book.id}');
                                          if (!mounted) return;
                                          final saved =
                                              ref.read(discoveryCanvasTransformProvider);
                                          if (saved != null) {
                                            _transformationController.value =
                                                Matrix4.copy(saved);
                                          }
                                        },
                                      ),
                                    ),
                                  if (_isLoadingMore)
                                    Positioned(
                                      right: 18,
                                      bottom: 18,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface
                                              .withValues(alpha: 0.92),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.colorScheme.shadow
                                                  .withValues(alpha: 0.16),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.all(10),
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 74),
        child: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () {
            _transformationController.value = Matrix4.identity()
              ..translate(-260.0, -180.0);
            _storeTransform();
          },
          child: const Icon(Icons.center_focus_strong_rounded),
        ),
      ),
    );
  }

  List<_BookNode> _buildNodes(List<Book> books, Size canvasSize) {
    if (books.isEmpty) return const [];
    const itemWidth = 140.0;
    const itemHeight = 205.0;
    final nodes = <_BookNode>[];
    final centerX = (canvasSize.width - itemWidth) / 2;
    final centerY = (canvasSize.height - itemHeight) / 2;
    const angleStep = 0.9;
    const radiusStep = 42.0;
    const minCenterDistance = 150.0;

    for (var i = 0; i < books.length; i++) {
      final book = books[i];
      final t = i + 1;
      var radius = radiusStep * math.sqrt(t.toDouble());
      final baseTheta = t * angleStep;
      var placed = false;
      var x = centerX;
      var y = centerY;

      for (var attempt = 0; attempt < 18; attempt++) {
        final theta = baseTheta + (attempt * 0.35);
        final jitterX = ((book.id.hashCode + attempt * 31) % 24 - 12).toDouble();
        final jitterY = ((book.title.hashCode + attempt * 17) % 20 - 10).toDouble();

        x = centerX + (radius * math.cos(theta)) + jitterX;
        y = centerY + (radius * math.sin(theta)) + jitterY;

        x = x.clamp(16.0, canvasSize.width - itemWidth - 16);
        y = y.clamp(16.0, canvasSize.height - itemHeight - 16);

        final overlaps = nodes.any((n) {
          final dx = n.dx - x;
          final dy = n.dy - y;
          return (dx * dx + dy * dy) < (minCenterDistance * minCenterDistance);
        });

        if (!overlaps) {
          placed = true;
          break;
        }

        radius += 26.0;
      }

      if (!placed) {
        radius += 60.0;
        x = (centerX + (radius * math.cos(baseTheta))).clamp(
          16.0,
          canvasSize.width - itemWidth - 16,
        );
        y = (centerY + (radius * math.sin(baseTheta))).clamp(
          16.0,
          canvasSize.height - itemHeight - 16,
        );
      }

      final angleRaw = ((book.id.hashCode >> 2) % 14) - 7;
      final angle = angleRaw / 180;
      nodes.add(_BookNode(book: book, dx: x, dy: y, angle: angle));
    }

    return nodes;
  }
}

class _CanvasBookCover extends StatelessWidget {
  const _CanvasBookCover({
    required this.book,
    required this.angle,
    required this.onTap,
  });

  final Book book;
  final double angle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Transform.rotate(
      angle: angle,
      child: GestureDetector(
        onTap: onTap,
        child: Hero(
          tag: 'book-cover-${book.id}',
          child: Container(
            width: 140,
            height: 205,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.22),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: (book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: book.coverImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Image.asset(
                        AppAssets.defaultBookCover,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      AppAssets.defaultBookCover,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookNode {
  const _BookNode({
    required this.book,
    required this.dx,
    required this.dy,
    required this.angle,
  });

  final Book book;
  final double dx;
  final double dy;
  final double angle;
}
