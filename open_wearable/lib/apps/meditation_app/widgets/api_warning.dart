import 'package:flutter/material.dart';

class APIWarning extends StatelessWidget {
  final String serviceName;

  const APIWarning({
    super.key,
    required this.serviceName,
  });

  String get _message =>
      'No valid $serviceName credentials were found. Add them on the API '
      'Keys page and check the connection. EarStreAM will use its local '
      'fallback until then.';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'API Not Configured',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    _message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
