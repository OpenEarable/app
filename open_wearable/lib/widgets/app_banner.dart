import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/app_banner_controller.dart';

class AppBanner extends StatelessWidget {
  final Widget content;
  final Color backgroundColor;

  const AppBanner({
    super.key,
    required this.content,
    this.backgroundColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          elevation: 3,
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 40, 16),
            child: content,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            padding: const EdgeInsets.all(0),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            splashRadius: 18,
            icon: const Icon(Icons.close, size: 20, color: Colors.white),
            onPressed: () {
              final controller =
                  Provider.of<AppBannerController>(context, listen: false);
              controller.hideBanner(this);
            },
          ),
        ),
      ],
    );
  }
}
