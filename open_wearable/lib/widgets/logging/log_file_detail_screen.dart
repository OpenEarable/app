import 'dart:io';

import 'package:flutter/material.dart';

class LogFileDetailScreen extends StatelessWidget {
  const LogFileDetailScreen({
    super.key,
    required this.file,
  });

  final File file;

  @override
  Widget build(BuildContext context) {
    final fileName = file.path.split(Platform.pathSeparator).last;

    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
      ),
      body: FutureBuilder<String>(
        future: file.readAsString(),
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

          return Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
