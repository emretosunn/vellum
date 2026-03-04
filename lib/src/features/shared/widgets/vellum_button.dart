import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';

enum VellumButtonVariant { filled, outlined, tonal }

class VellumButton extends StatelessWidget {
  const VellumButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = VellumButtonVariant.filled,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final VellumButtonVariant variant;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final enabled = onPressed != null && !isLoading;
    final radius = BorderRadius.circular(16);

    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case VellumButtonVariant.outlined:
        bg = Colors.transparent;
        fg = AppColors.primary;
        border = AppColors.primary.withValues(alpha: isDark ? 0.7 : 0.8);
        break;
      case VellumButtonVariant.tonal:
        bg = AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.12);
        fg = AppColors.primary;
        border = AppColors.primary.withValues(alpha: isDark ? 0.30 : 0.18);
        break;
      case VellumButtonVariant.filled:
        bg = AppColors.primary;
        fg = Colors.white;
        border = AppColors.primary.withValues(alpha: 0.0);
        break;
    }

    if (!enabled) {
      bg = variant == VellumButtonVariant.filled
          ? AppColors.primary.withValues(alpha: 0.45)
          : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06));
      fg = isDark
          ? Colors.white.withValues(alpha: 0.55)
          : Colors.black.withValues(alpha: 0.45);
      border = isDark
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.black.withValues(alpha: 0.10);
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(color: border, width: 1.6),
          boxShadow: variant == VellumButtonVariant.filled && enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isLoading
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: fg,
                        ),
                      )
                    : Row(
                        key: const ValueKey('content'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 20, color: fg),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: fg,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

