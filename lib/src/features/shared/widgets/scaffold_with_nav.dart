import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_colors.dart';
import '../../../utils/responsive.dart';

class NavRetapEvent {
  const NavRetapEvent({required this.index, required this.nonce});
  final int index;
  final int nonce;
}

final navRetapEventNotifier = ValueNotifier<NavRetapEvent?>(null);

/// Responsive navigasyon shell'i.
///
/// Mobile: Glassmorphism [BottomNavigationBar]
/// Tablet/Desktop: Premium glassmorphism sidebar
class ScaffoldWithNav extends StatelessWidget {
  const ScaffoldWithNav({
    super.key,
    required this.navigationShell,
    required this.branchNavigatorKeys,
  });

  final StatefulNavigationShell navigationShell;
  final List<GlobalKey<NavigatorState>> branchNavigatorKeys;

  static List<_NavDestination> _getDestinations(BuildContext context) => [
    _NavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: translate('nav.home'),
    ),
    _NavDestination(
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note_rounded,
      label: translate('nav.studio'),
    ),
    _NavDestination(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      label: translate('nav.discovery_canvas'),
    ),
    _NavDestination(
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium_rounded,
      label: translate('nav.subscription'),
    ),
    _NavDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: translate('nav.settings'),
    ),
  ];

  void _onDestinationSelected(BuildContext context, int index) {
    final isRetap = index == navigationShell.currentIndex;
    if (index == navigationShell.currentIndex) {
      final branchNav = index >= 0 && index < branchNavigatorKeys.length
          ? branchNavigatorKeys[index].currentState
          : null;
      if (branchNav != null && branchNav.canPop()) {
        branchNav.popUntil((route) => route.isFirst);
      }
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );

    if (isRetap) {
      navRetapEventNotifier.value = NavRetapEvent(
        index: index,
        nonce: DateTime.now().microsecondsSinceEpoch,
      );
      // Aynı taba tekrar basıldığında ilgili tabın ana sayfasına dönüp
      // mümkünse içeriği en üste kaydır.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (index < 0 || index >= branchNavigatorKeys.length) return;
        final branchContext = branchNavigatorKeys[index].currentContext;
        if (branchContext == null) return;
        final primary = PrimaryScrollController.maybeOf(branchContext);
        if (primary == null || !primary.hasClients) return;
        primary.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final currentIndex = navigationShell.currentIndex;

    if (isMobile) {
      return Scaffold(
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: _GlassBottomNav(
          currentIndex: currentIndex,
          destinations: _getDestinations(context),
          onTap: (index) => _onDestinationSelected(context, index),
        ),
      );
    }

    // Tablet / Desktop: Modern glassmorphism sidebar
    return Scaffold(
      body: Row(
        children: [
          _PremiumSidebar(
            currentIndex: currentIndex,
            destinations: _getDestinations(context),
            onTap: (index) => _onDestinationSelected(context, index),
            isExpanded: context.isDesktop,
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

// ─── Premium Glassmorphism Sidebar ──────────────────

class _PremiumSidebar extends StatelessWidget {
  const _PremiumSidebar({
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
    required this.isExpanded,
  });

  final int currentIndex;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onTap;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarWidth = isExpanded ? 240.0 : 78.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: sidebarWidth,
      child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF16162A)
                  : const Color(0xFFF8F7FF),
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // ── Logo alanı
                _SidebarLogo(isExpanded: isExpanded),

                const SizedBox(height: 8),

                // ── Navigasyon öğeleri
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        ...List.generate(destinations.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _SidebarItem(
                              icon: destinations[index].icon,
                              selectedIcon:
                                  destinations[index].selectedIcon,
                              label: destinations[index].label,
                              isSelected: index == currentIndex,
                              isExpanded: isExpanded,
                              onTap: () => onTap(index),
                            ),
                          );
                        }),
                        const Spacer(),

                        // ── Alt kısım: Ayırıcı + Versiyon
                        Divider(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.06),
                          height: 1,
                        ),
                        const SizedBox(height: 12),
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.success,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.success
                                            .withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  translate('common.app_name'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white
                                            .withValues(alpha: 0.3)
                                        : Colors.black
                                            .withValues(alpha: 0.3),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success
                                        .withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

// ─── Sidebar Logo ───────────────────────────────────

class _SidebarLogo extends StatelessWidget {
  const _SidebarLogo({required this.isExpanded});

  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(
        horizontal: isExpanded ? 20 : 0,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          // Gradient ikon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primaryLight,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 14),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryLight,
                ],
              ).createShader(bounds),
              child: Text(
                translate('common.app_name'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Sidebar Nav Item ───────────────────────────────

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = widget.isSelected;
    final isHovered = _isHovered && !isActive;

    final activeColor = AppColors.primary;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.45);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 48,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isExpanded ? 14 : 0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isActive
                ? activeColor.withValues(alpha: isDark ? 0.12 : 0.1)
                : isHovered
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03))
                    : Colors.transparent,
            border: Border.all(
              color: isActive
                  ? activeColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: widget.isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              // Sol taraftaki aktif çizgi göstergesi
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 3,
                height: isActive ? 20 : 0,
                margin: EdgeInsets.only(
                  right: widget.isExpanded ? 12 : 0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: activeColor,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
              ),
              // İkon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? widget.selectedIcon : widget.icon,
                  key: ValueKey(isActive),
                  size: 22,
                  color: isActive
                      ? activeColor
                      : isHovered
                          ? (isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.black.withValues(alpha: 0.65))
                          : inactiveColor,
                ),
              ),
              if (widget.isExpanded) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? activeColor
                          : isHovered
                              ? (isDark
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Colors.black
                                      .withValues(alpha: 0.7))
                              : inactiveColor,
                      letterSpacing: 0.2,
                    ),
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Glassmorphism Bottom Nav (Mobile) ──────────────

class _GlassBottomNav extends StatelessWidget {
  const _GlassBottomNav({
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
  });

  final int currentIndex;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const centerIndex = 2;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        height: 86,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    height: 68,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(destinations.length, (index) {
                        if (index == centerIndex) {
                          return const SizedBox(width: 70);
                        }
                        final isSelected = index == currentIndex;
                        final dest = destinations[index];
                        return _GlassNavItem(
                          icon: isSelected ? dest.selectedIcon : dest.icon,
                          label: dest.label,
                          isSelected: isSelected,
                          onTap: () => onTap(index),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: _CenterFloatingNavItem(
                destination: destinations[centerIndex],
                isSelected: currentIndex == centerIndex,
                onTap: () => onTap(centerIndex),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterFloatingNavItem extends StatelessWidget {
  const _CenterFloatingNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 86,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.95),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                isSelected ? destination.selectedIcon : destination.icon,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(top: 2),
              width: isSelected ? 6 : 0,
              height: isSelected ? 6 : 0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  const _GlassNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = AppColors.primary;
    final unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
            const SizedBox(height: 4),
            // Glow dot indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isSelected ? 6 : 0,
              height: isSelected ? 6 : 0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selectedColor,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: selectedColor.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
