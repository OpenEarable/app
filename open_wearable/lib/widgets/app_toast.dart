import 'package:flutter/material.dart';
import 'package:open_wearable/view_models/app_banner_controller.dart';
import 'package:open_wearable/widgets/app_banner.dart';
import 'package:provider/provider.dart';

enum AppToastType {
  info,
  success,
  warning,
  error,
}

class AppToast {
  const AppToast._();

  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showInternal(
      context,
      content: Text(message),
      type: type,
      icon: icon,
      duration: duration,
    );
  }

  static void showContent(
    BuildContext context, {
    required Widget content,
    AppToastType type = AppToastType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showInternal(
      context,
      content: content,
      type: type,
      icon: icon,
      duration: duration,
    );
  }

  static void _showInternal(
    BuildContext context, {
    required Widget content,
    required AppToastType type,
    required IconData? icon,
    required Duration duration,
  }) {
    final style = _AppToastStyle.resolve(
      context: context,
      type: type,
      iconOverride: icon,
    );

    final appBannerController =
        Provider.of<AppBannerController?>(context, listen: false);
    if (appBannerController != null) {
      appBannerController.showBanner(
        (id) => AppBanner(
          key: ValueKey(id),
          content: content,
          backgroundColor: style.backgroundColor,
          foregroundColor: style.foregroundColor,
          leadingIcon: style.icon,
        ),
        duration: duration,
      );
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          elevation: 0,
          padding: EdgeInsets.zero,
          duration: duration,
          backgroundColor: Colors.transparent,
          content: AppBanner(
            content: content,
            backgroundColor: style.backgroundColor,
            foregroundColor: style.foregroundColor,
            leadingIcon: style.icon,
          ),
        ),
      );
  }
}

class _AppToastStyle {
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  const _AppToastStyle({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  static _AppToastStyle resolve({
    required BuildContext context,
    required AppToastType type,
    IconData? iconOverride,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final base = switch (type) {
      AppToastType.info => const _AppToastStyle(
          backgroundColor: Color(0xFFEDE4FF),
          foregroundColor: Color(0xFF5A2EA6),
          icon: Icons.info_outline_rounded,
        ),
      AppToastType.success => const _AppToastStyle(
          backgroundColor: Color(0xFFE8F5E9),
          foregroundColor: Color(0xFF1E6A3A),
          icon: Icons.check_circle_outline_rounded,
        ),
      AppToastType.warning => const _AppToastStyle(
          backgroundColor: Color(0xFFFFF3E0),
          foregroundColor: Color(0xFF8A4B00),
          icon: Icons.warning_amber_rounded,
        ),
      AppToastType.error => _AppToastStyle(
          backgroundColor: colorScheme.errorContainer,
          foregroundColor: colorScheme.onErrorContainer,
          icon: Icons.error_outline_rounded,
        ),
    };

    if (iconOverride == null) {
      return base;
    }

    return _AppToastStyle(
      backgroundColor: base.backgroundColor,
      foregroundColor: base.foregroundColor,
      icon: iconOverride,
    );
  }
}
