import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Small building blocks shared by the dashboard and the sensor page (design: AgriTwin Mobile UI Concept).

/// Round soft-coloured badge holding an icon, as on the design's sensor cards.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.tint,
    this.size = AppTokens.iconBadgeSize,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
      child: Icon(icon, size: AppTokens.iconInBadge, color: color),
    );
  }
}

/// "● ออนไลน์" / "● ออฟไลน์". Needs a bounded width (wrap it in Flexible inside a Row).
class StatusDotLabel extends StatelessWidget {
  const StatusDotLabel({super.key, required this.online, this.style});

  final bool online;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusDot(color: online ? AppTokens.online : AppTokens.offline),
        const SizedBox(width: AppTokens.gapTight),
        Flexible(
          child: Text(
            online ? 'ออนไลน์' : 'ออฟไลน์',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style ??
                const TextStyle(
                  fontSize: AppTokens.fontBodySmall,
                  fontWeight: FontWeight.w500,
                  color: AppTokens.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: AppTokens.statusDot,
        height: AppTokens.statusDot,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Pill-shaped segmented control (design: "24 ชม. / 7 วัน / 30 วัน").
class PillSegmented<T> extends StatelessWidget {
  const PillSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppTokens.segmentHeight,
      padding: const EdgeInsets.all(AppTokens.space1),
      decoration: BoxDecoration(
        color: AppTokens.segmentTrack,
        borderRadius: BorderRadius.circular(AppTokens.radiusSegment),
      ),
      child: Row(
        children: [
          for (final (value, label) in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: value == selected
                        ? BoxDecoration(
                            color: AppTokens.surface,
                            borderRadius: BorderRadius.circular(AppTokens.radiusSegmentThumb),
                            boxShadow: const [
                              BoxShadow(color: AppTokens.shadow, blurRadius: 3, offset: Offset(0, 1)),
                            ],
                          )
                        : null,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTokens.fontBodySmall,
                        fontWeight: value == selected ? FontWeight.w500 : FontWeight.w400,
                        color: value == selected ? AppTokens.textPrimary : AppTokens.textSecondary,
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

/// White rounded card with the design's hairline border.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space3),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTokens.radiusCard);
    final decoration = BoxDecoration(
      color: AppTokens.surface,
      borderRadius: radius,
      border: Border.all(color: AppTokens.border),
    );
    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: Padding(padding: padding, child: child));
    }
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(decoration: decoration, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Section title on the left and a short hint on the right edge, like the design's section
/// headers ("ค่าล่าสุดจาก …" / "แตะเพื่อดูกราฟ"). On narrow screens both shrink with an ellipsis and
/// the title keeps the larger share.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.hint, this.titleStyle});

  final String title;
  final String? hint;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle ?? theme.textTheme.titleMedium,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(width: AppTokens.space2),
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
            ),
          ),
        ],
      ],
    );
  }
}

/// Text style for sensor values. The design uses Inter Bold; the app keeps the platform font.
TextStyle valueStyle(double size, {Color color = AppTokens.textPrimary}) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.1,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
