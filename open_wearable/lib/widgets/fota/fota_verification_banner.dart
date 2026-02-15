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
    final baseStyle = DefaultTextStyle.of(context).style;
    final warningColor = Theme.of(context).colorScheme.error;
    final buttonBackground = warningColor.withValues(alpha: 0.14);
    final buttonBorder = warningColor.withValues(alpha: 0.36);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Firmware upload completed successfully. Verification in progress. '
          'Do NOT reset or power off your OpenEarable.',
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _TargetLabel(
              wearableName: widget.wearableName,
              sideLabel: widget.sideLabel,
            ),
            _RemainingPill(
              remainingText: _format(remaining),
              warningColor: warningColor,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Spacer(),
            TextButton.icon(
              onPressed: widget.onDismiss,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Confirm and Close'),
              style: TextButton.styleFrom(
                foregroundColor: warningColor,
                backgroundColor: buttonBackground,
                side: BorderSide(color: buttonBorder),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TargetLabel extends StatelessWidget {
  final String wearableName;
  final String? sideLabel;

  const _TargetLabel({
    required this.wearableName,
    required this.sideLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            wearableName,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (sideLabel != null) ...[
            const SizedBox(width: 6),
            _FotaSideBadge(sideLabel: sideLabel!),
          ],
        ],
      ),
    );
  }
}

class _FotaSideBadge extends StatelessWidget {
  final String sideLabel;

  const _FotaSideBadge({
    required this.sideLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        sideLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _RemainingPill extends StatelessWidget {
  final String remainingText;
  final Color warningColor;

  const _RemainingPill({
    required this.remainingText,
    required this.warningColor,
  });

  @override
  Widget build(BuildContext context) {
    final background = warningColor.withValues(alpha: 0.12);
    final border = warningColor.withValues(alpha: 0.32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 14,
            color: warningColor,
          ),
          const SizedBox(width: 4),
          Text(
            remainingText,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: warningColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
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
      return AppBanner(
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
        backgroundColor: const Color(0xFFFFECEC),
        foregroundColor: const Color(0xFF8A1C1C),
        leadingIcon: Icons.warning_amber_rounded,
        key: bannerKey,
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
