import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class LogFileDetailScreen extends StatefulWidget {
  const LogFileDetailScreen({
    super.key,
    required this.file,
  });

  final File file;

  @override
  State<LogFileDetailScreen> createState() => _LogFileDetailScreenState();
}

class _LogFileDetailScreenState extends State<LogFileDetailScreen> {
  late final Future<String> _contentFuture;
  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    // Read the file only once; FutureBuilder will reuse this future.
    _contentFuture = widget.file.readAsString();
    _verticalController = ScrollController();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.path.split(Platform.pathSeparator).last;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(fileName),
      ),
      body: FutureBuilder<String>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: PlatformCircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to read file:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final content = snapshot.data ?? '';

          if (content.isEmpty) {
            return const Center(
              child: Text('File is empty.'),
            );
          }

          return Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _verticalController,
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                notificationPredicate: (notif) =>
                    notif.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    content,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
