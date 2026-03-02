import 'dart:async';
import 'package:flutter/material.dart';
import 'package:open_wearable/widgets/app_banner.dart';
import 'package:provider/provider.dart';

import '../../view_models/app_banner_controller.dart';

class FotaVerificationBanner extends StatefulWidget {
  final Duration duration;
  const FotaVerificationBanner({
    super.key,
    this.duration = const Duration(minutes: 3),
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
    remaining = widget.duration;

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      setState(() {
        if (remaining.inSeconds > 0) {
          remaining -= const Duration(seconds: 1);
        } else {
          t.cancel();
          // auto-hide when done
          ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        }
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white) ?? const TextStyle(color: Colors.white);

    return Text.rich(
      TextSpan(
      style: baseStyle,
      children: [
        TextSpan(text: "Firmware verification in progress.\n"),
        TextSpan(
        text: "Do NOT reset your OpenEarable.\n",
        style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ),
        TextSpan(text: "Remaining: ${_format(remaining)}"),
      ],
      ),
    );
  }
}

void showFotaVerificationBanner(BuildContext context) {
  final controller = Provider.of<AppBannerController>(context, listen: false);
  controller.showBanner((id) => AppBanner(
      content: FotaVerificationBanner(key: ValueKey(id)),
      backgroundColor: Colors.orange,
      key: ValueKey(id),
    ),
    duration: Duration(minutes: 3),
  );
}
