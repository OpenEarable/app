import 'package:flutter/material.dart';

class AppBanner extends StatelessWidget {
  final Widget content;
  final Color backgroundColor;
  final Color? foregroundColor;
  final IconData? leadingIcon;

  const AppBanner({
    super.key,
    required this.content,
    this.backgroundColor = Colors.blue,
    this.foregroundColor,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedForeground = foregroundColor ?? Colors.white;
    final borderColor = resolvedForeground.withValues(alpha: 0.22);

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.11),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: resolvedForeground,
                      fontWeight: FontWeight.w600,
                    ) ??
                TextStyle(
                  color: resolvedForeground,
                  fontWeight: FontWeight.w600,
                ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leadingIcon != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      leadingIcon,
                      size: 18,
                      color: resolvedForeground,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
