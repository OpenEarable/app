import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icon assets exported from the approved Figma design.
class ActivityIcon extends StatelessWidget {
  const ActivityIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color,
    this.box = false,
  });
  final String name;
  final double size;
  final Color? color;
  final bool box;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = SvgPicture.asset(
      'lib/apps/activity_tracker/assets/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color ?? scheme.primary, BlendMode.srcIn),
    );
    return box
        ? Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: icon,
          )
        : icon;
  }
}

/// Figma's 18 px card, inheriting light/dark surfaces from the host theme.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = 14,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double padding;
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: EdgeInsets.all(padding), child: child),
        ),
      );
}

class ActivityMetric extends StatelessWidget {
  const ActivityMetric(this.label, this.value, {super.key, this.detail});
  final String label, value;
  final String? detail;
  @override
  Widget build(BuildContext context) => ActivityCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ActivityCaption(label),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              ActivityCaption(detail!),
            ],
          ],
        ),
      );
}

class ActivityCaption extends StatelessWidget {
  const ActivityCaption(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
      );
}

class ActivityBadge extends StatelessWidget {
  const ActivityBadge(this.label, {super.key, this.warning = false});
  final String label;
  final bool warning;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning
        ? scheme.error
        : Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF81C784)
            : const Color(0xFF2E7D32);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '•  $label',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ActivityNotice extends StatelessWidget {
  const ActivityNotice(
    this.title,
    this.message, {
    super.key,
    this.warning = false,
  });
  final String title, message;
  final bool warning;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning ? scheme.error : scheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                warning ? Icons.info_outline : Icons.check,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ActivityCaption(message, color: color),
        ],
      ),
    );
  }
}

/// Live signal, deliberately empty until real samples have arrived.
class ActivitySignal extends StatelessWidget {
  const ActivitySignal(this.values, {super.key, this.color, this.height = 44});
  final List<double> values;
  final Color? color;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SignalPainter(
            values,
            color ?? Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}

class _SignalPainter extends CustomPainter {
  _SignalPainter(this.values, this.color);
  final List<double> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
    if (values.length < 2) return;
    final scale =
        math.max(2, values.fold<double>(0, (p, v) => math.max(p, v.abs())));
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height / 2 - values[i] / scale * size.height * 0.4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      paint
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SignalPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

/// Scrollable phone layout with actions anchored above the system safe area.
class ActivityLayout extends StatelessWidget {
  const ActivityLayout({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.appBarActions,
  });
  final String title;
  final List<Widget> children, actions;
  final List<Widget>? appBarActions;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          actions: appBarActions,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: PageStorageKey('activity-$title'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(10),
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      children[i],
                    ],
                  ],
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          flex: i == actions.length - 1 ? 3 : 2,
                          child: actions[i],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
}

String activityDuration(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
String activityTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
String activityDate(DateTime time) =>
    '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
