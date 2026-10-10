import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/persian_numbers.dart';
import 'glass_card.dart';
import 'premium_badge.dart';

/// Section header used across screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.subtitle,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  /// Optional small leading icon rendered in a tinted circle.
  final IconData? icon;

  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (iconColor ?? theme.colorScheme.primary)
                    .withValues(alpha: 0.14),
              ),
              child: Icon(
                icon,
                size: 16,
                color: iconColor ?? theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AstralTextStyles.title(
                      color: theme.colorScheme.onSurface),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Icon + label + percentage card for the four home categories.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.score,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final int score;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      accent: color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            PersianNumbers.percent(score),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill chip (element / planet / date…).
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: theme.colorScheme.primary),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly empty state (product spec §44).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String emoji;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.9,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: 'Vazirmatn',
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state with retry.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.wb_twilight,
              size: 38, color: theme.colorScheme.error.withValues(alpha: 0.8)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontFamily: 'Vazirmatn',
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('تلاش دوباره'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Loading shimmer placeholder for cards.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.height = 140, this.message});

  final double height;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontFamily: 'Vazirmatn',
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

/// Locked premium section placeholder.
class LockedSection extends StatelessWidget {
  const LockedSection({
    super.key,
    required this.title,
    required this.hint,
    required this.onOpenPremium,
  });

  final String title;
  final String hint;
  final VoidCallback onOpenPremium;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      accent: AppTheme.gold,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.gold.withValues(alpha: 0.14),
            ),
            child: const Icon(Icons.lock_outline, size: 20, color: AppTheme.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AstralTextStyles.titleSmall(
                            color: theme.colorScheme.onSurface),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const PremiumBadge(),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onOpenPremium,
            child: const Text('فعال‌سازی'),
          ),
        ],
      ),
    );
  }
}
