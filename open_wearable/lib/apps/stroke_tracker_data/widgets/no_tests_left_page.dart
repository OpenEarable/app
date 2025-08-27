import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class NoTestsLeftPage extends StatelessWidget {
  const NoTestsLeftPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text('All tests finished'),
      ),
      body: Center(
        child: Text('No more tests available, thank you for your participation!'),
      ),
    );
  }
}
