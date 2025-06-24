// lib/apps/stroke_tracker/view/widgets/test_feedback_panel.dart

import 'package:flutter/material.dart';
import '../models/test_feedback.dart';

class TestFeedbackPanel extends StatelessWidget {
  final List<TestFeedback> feedbackList;
  final void Function(int) onRetry;
  const TestFeedbackPanel({
    Key? key,
    required this.feedbackList,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "Test Results",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: feedbackList.length,
            itemBuilder: (_, i) {
              final fb = feedbackList[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(fb.icon, size: 28, color: Colors.blueAccent),
                  title: Text(fb.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text("Result: ${fb.result}",
                      style: const TextStyle(color: Colors.green)),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Retry ${fb.name}?'),
                          content: Text('Are you sure you want to retry the ${fb.name.toLowerCase()}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
                            TextButton(onPressed: () => Navigator.of(ctx).pop(true),  child: const Text('Yes')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        onRetry(i);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
