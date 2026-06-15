import 'package:flutter/material.dart';

class StartupLoadingPage extends StatefulWidget {
  const StartupLoadingPage({super.key, this.onReady});

  final VoidCallback? onReady;

  @override
  State<StartupLoadingPage> createState() => _StartupLoadingPageState();
}

class _StartupLoadingPageState extends State<StartupLoadingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: const SizedBox.expand(),
    );
  }
}
