import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class LocalRecorderDialogs {
  static Future<bool> askOverwriteConfirmation(
    BuildContext context,
    String dirPath,
  ) async {
    return await showPlatformDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: PlatformText('Directory not empty'),
            content: PlatformText(
                '"$dirPath" already contains files or folders.\n\n'
                'New sensor files will be added; existing files with the same '
                'names will be overwritten. Continue anyway?'),
            actions: [
              PlatformTextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: PlatformText('Cancel'),
              ),
              PlatformTextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: PlatformText('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  static Future<void> showErrorDialog(
    BuildContext context,
    String message,
  ) async {
    await showPlatformDialog(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: PlatformText('Error'),
        content: PlatformText(message),
        actions: [
          PlatformDialogAction(
            child: PlatformText('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
