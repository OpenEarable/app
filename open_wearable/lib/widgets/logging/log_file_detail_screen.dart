import 'dart:io';

import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    // Read the file only once; FutureBuilder will reuse this future.
    _contentFuture = widget.file.readAsString();
  }

  @override
  Widget build(BuildContext context) {
    final fileName =
        widget.file.path.split(Platform.pathSeparator).last;

    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
      ),
      body: FutureBuilder<String>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
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

          // Scrollbars + both directions scrolling, no line wrapping.
          final verticalController = ScrollController();
          final horizontalController = ScrollController();

          return Scrollbar(
            controller: verticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: verticalController,
              padding: const EdgeInsets.all(12),
              child: Scrollbar(
                controller: horizontalController,
                thumbVisibility: true,
                notificationPredicate: (notif) =>
                    notif.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: horizontalController,
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
