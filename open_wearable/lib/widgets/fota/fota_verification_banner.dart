import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_wearable/widgets/app_banner.dart';
import 'package:provider/provider.dart';

import '../../view_models/app_banner_controller.dart';

final Map<String, Key> _activeFotaVerificationBannerKeys = {};
final Map<String, DateTime> _fotaVerificationDeadlinesById = {};

class FotaVerificationBanner extends StatefulWidget {
  final DateTime deadline;
  final String wearableName;
  final String? sideLabel;
  final VoidCallback onDismiss;

  const FotaVerificationBanner({
    super.key,
    required this.deadline,
    required this.wearableName,
    this.sideLabel,
    required this.onDismiss,
  });

  @override
  State<FotaVerificationBanner> createState() => _FotaVerificationBannerState();
}

class _FotaVerificationBannerState extends State<FotaVerificationBanner> {
  late Duration remaining;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    remaining = _remainingFromDeadline(widget.deadline);

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        return;
      }

      final nextRemaining = _remainingFromDeadline(widget.deadline);
      if (nextRemaining.inSeconds <= 0) {
        t.cancel();
        widget.onDismiss();
        return;
      }

      setState(() {
        remaining = nextRemaining;
      });
    });
  }

  Duration _remainingFromDeadline(DateTime deadline) {
    final difference = deadline.difference(DateTime.now());
    if (difference.isNegative) {
      return Duration.zero;
    }
    return difference;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    const successBackground = Color(0xFFE8F5E9);
    const successForeground = Color(0xFF1E6A3A);
    const warningBackground = Color(0xFFFFECEC);
    const warningForeground = Color(0xFF8A1C1C);
    final successTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: successForeground,
          fontWeight: FontWeight.w700,
        );
    final warningTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: warningForeground,
          fontWeight: FontWeight.w700,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBanner(
          backgroundColor: successBackground,
          foregroundColor: successForeground,
          leadingIcon: Icons.verified_rounded,
          content: Text.rich(
            TextSpan(
              style: successTextStyle,
              children: [
                const TextSpan(
                  text: 'Firmware upload completed successfully for ',
                ),
                TextSpan(text: widget.wearableName),
                if (widget.sideLabel != null) const TextSpan(text: ' '),
                if (widget.sideLabel != null)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: _FotaSideBadge(
                      sideLabel: widget.sideLabel!,
                      accentColor: successForeground,
                    ),
                  ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
        AppBanner(
          backgroundColor: warningBackground,
          foregroundColor: warningForeground,
          leadingIcon: Icons.warning_amber_rounded,
          content: Text(
            'Verification in progress, do not reset or power off the device: ${_format(remaining)}.',
            softWrap: true,
            style: warningTextStyle,
          ),
        ),
      ],
    );
  }
}

class _FotaSideBadge extends StatelessWidget {
  final String sideLabel;
  final Color accentColor;

  const _FotaSideBadge({
    required this.sideLabel,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = accentColor;
    final background = foreground.withValues(alpha: 0.16);
    final border = foreground.withValues(alpha: 0.34);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        sideLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _FotaStackedBanner extends AppBanner {
  const _FotaStackedBanner({
    super.key,
    required super.content,
  });

  @override
  Widget build(BuildContext context) {
    return content;
  }
}

void showFotaVerificationBanner(
  BuildContext context, {
  required String verificationId,
  required String wearableName,
  String? sideLabel,
  Duration duration = const Duration(minutes: 3),
}) {
  final controller = Provider.of<AppBannerController>(context, listen: false);
  _pruneMissingFotaVerificationBannerKeys(controller);

  final activeKey = _activeFotaVerificationBannerKeys[verificationId];
  if (activeKey != null) {
    final alreadyVisible = controller.activeBanners.any(
      (banner) => banner.key == activeKey,
    );
    if (alreadyVisible) {
      return;
    }
  }
  _activeFotaVerificationBannerKeys.remove(verificationId);
  final deadline = _fotaVerificationDeadlinesById.putIfAbsent(
    verificationId,
    () => DateTime.now().add(duration),
  );

  controller.showBanner(
    (id) {
      final bannerKey =
          ValueKey('fota_verification_banner_${verificationId}_$id');
      _activeFotaVerificationBannerKeys[verificationId] = bannerKey;
      return _FotaStackedBanner(
        key: bannerKey,
        content: FotaVerificationBanner(
          key: ValueKey('fota_verification_$verificationId'),
          deadline: deadline,
          wearableName: wearableName,
          sideLabel: sideLabel,
          onDismiss: () => _dismissFotaVerificationBanner(
            controller: controller,
            verificationId: verificationId,
            key: bannerKey,
          ),
        ),
      );
    },
  );
}

void dismissFotaVerificationBannerById(
  BuildContext context,
  String verificationId,
) {
  final controller = Provider.of<AppBannerController>(context, listen: false);
  _pruneMissingFotaVerificationBannerKeys(controller);

  final key = _activeFotaVerificationBannerKeys.remove(verificationId);
  if (key == null) {
    return;
  }

  controller.hideBannerByKey(key);
  _fotaVerificationDeadlinesById.remove(verificationId);
}

void dismissFotaVerificationBanner(BuildContext context) {
  final controller = Provider.of<AppBannerController>(context, listen: false);
  _pruneMissingFotaVerificationBannerKeys(controller);

  final keys = _activeFotaVerificationBannerKeys.values.toList();
  for (final key in keys) {
    controller.hideBannerByKey(key);
  }
  _activeFotaVerificationBannerKeys.clear();
  _fotaVerificationDeadlinesById.clear();
}

void _dismissFotaVerificationBanner({
  required AppBannerController controller,
  required String verificationId,
  required Key key,
}) {
  controller.hideBannerByKey(key);
  final activeKey = _activeFotaVerificationBannerKeys[verificationId];
  if (activeKey == key) {
    _activeFotaVerificationBannerKeys.remove(verificationId);
  }
  _fotaVerificationDeadlinesById.remove(verificationId);
}

void _pruneMissingFotaVerificationBannerKeys(AppBannerController controller) {
  final activeKeys = controller.activeBanners
      .map((banner) => banner.key)
      .whereType<Key>()
      .toSet();
  _activeFotaVerificationBannerKeys.removeWhere(
    (_, key) => !activeKeys.contains(key),
  );
  _fotaVerificationDeadlinesById.removeWhere(
    (verificationId, _) =>
        !_activeFotaVerificationBannerKeys.containsKey(verificationId),
  );
}
