part of '../sensor_chart.dart';

class _AxisChannelChip extends StatelessWidget {
  final String axisName;
  final String statusLabel;
  final Color dotColor;
  final Color labelColor;
  final Color backgroundColor;
  final Color borderColor;
  final bool dottedBorder;
  final bool compact;
  final VoidCallback? onTap;

  const _AxisChannelChip({
    required this.axisName,
    required this.statusLabel,
    required this.dotColor,
    required this.labelColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.dottedBorder,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = compact ? 28.0 : 30.0;
    final fontSize = compact ? 10.5 : 11.5;
    final separatorColor = labelColor.withValues(alpha: 0.28);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: CustomPaint(
          foregroundPainter: dottedBorder
              ? _DottedPillBorderPainter(color: borderColor)
              : null,
          child: Container(
            height: height,
            padding: const EdgeInsets.fromLTRB(8, 0, 5, 0),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: dottedBorder ? null : Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  axisName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 1,
                  height: compact ? 12 : 14,
                  color: separatorColor,
                ),
                const SizedBox(width: 5),
                Text(
                  statusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: labelColor.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 9.8 : 10.8,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: compact ? 15 : 16,
                    color: labelColor.withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AxisHeaderChannelPill extends StatelessWidget {
  final String axisName;
  final Color axisColor;

  const _AxisHeaderChannelPill({
    required this.axisName,
    required this.axisColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: axisColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: axisColor.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: axisColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              axisName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: axisColor.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedPillBorderPainter extends CustomPainter {
  final Color color;

  const _DottedPillBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const dotRadius = 0.85;
    const gap = 3.0;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(dotRadius),
      Radius.circular(size.height / 2),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0;
          distance < metric.length;
          distance += (dotRadius * 2) + gap) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, dotRadius, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedPillBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
