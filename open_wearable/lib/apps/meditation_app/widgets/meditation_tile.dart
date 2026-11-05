import 'dart:async';

import 'package:flutter/material.dart';
import '../model/meditation.dart';
import 'emojis.dart';

enum MoodRating {
  veryRelaxed(
    label: "Serene",
    emoji: AppEmojis.veryRelaxed,
  ),
  relaxed(
    label: "Relaxed",
    emoji: AppEmojis.relaxed,
  ),
  neutral(
    label: "Neutral",
    emoji: AppEmojis.neutral,
  ),
  stressed(
    label: "Stressed",
    emoji: AppEmojis.stressed,
  );

  final String label;
  final String emoji;

  const MoodRating({
    required this.label,
    required this.emoji,
  });
}

class MeditationTile extends StatelessWidget {
  final ValueNotifier<Meditation?> meditationNotifier;
  final ValueChanged<Meditation>? onMeditationComplete;

  /// Fires when the attendee acknowledges a *finished* session by choosing a
  /// mood. Deliberately separate from dismissing a failure card, which is not
  /// the end of a successful run.
  final VoidCallback? onMoodSelected;

  const MeditationTile({
    super.key,
    required this.meditationNotifier,
    this.onMeditationComplete,
    this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: meditationNotifier,
      builder: (context, meditationOrNull, child) {
        final meditation = meditationOrNull;
        if (meditation == null) {
          return const SizedBox.shrink();
        }

        // Listen to phase directly (not just meditation.phase.value) so the
        // tile actually rebuilds when the session transitions to finished,
        // instead of getting stuck on whatever phase it first rendered.
        return ValueListenableBuilder<MeditationPhase>(
          valueListenable: meditation.phase,
          builder: (context, phase, child) {
            if (phase == MeditationPhase.finished) {
              return _FinishedMoodCheck(
                isBiosignalAdaptive: meditation is BiometricMeditation,
                onMoodSelected: () {
                  _complete(meditation);
                  onMoodSelected?.call();
                },
              );
            }
            if (phase == MeditationPhase.failed) {
              return _FailedMeditation(
                title: meditation.failureTitle ?? 'Meditation interrupted',
                message: meditation.failureMessage ??
                    'The meditation could not continue.',
                onDismissed: () => _complete(meditation),
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: meditation.isPaused,
                    builder: (context, isPaused, child) {
                      return ElevatedButton.icon(
                        onPressed: () {
                          isPaused ? meditation.resume() : meditation.pause();
                        },
                        icon: isPaused
                            ? const Icon(Icons.play_arrow)
                            : const Icon(Icons.pause),
                        label: isPaused
                            ? const Text("Resume")
                            : const Text("Pause"),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _complete(meditation),
                    icon: const Icon(Icons.stop),
                    label: const Text("Stop"),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _complete(Meditation meditation) {
    final callback = onMeditationComplete;
    if (callback != null) {
      callback(meditation);
    } else {
      unawaited(meditation.stop());
    }
  }
}

class _FailedMeditation extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onDismissed;

  const _FailedMeditation({
    required this.title,
    required this.message,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  title == 'Voice service interrupted'
                      ? Icons.cloud_off_outlined
                      : Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDismissed,
                child: const Text('Dismiss'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishedMoodCheck extends StatelessWidget {
  final bool isBiosignalAdaptive;
  final VoidCallback? onMoodSelected;

  const _FinishedMoodCheck({
    required this.isBiosignalAdaptive,
    this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.celebration,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Great job!',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              isBiosignalAdaptive
                  ? 'Your stress response has eased. Well done completing your meditation session!'
                  : 'Well done completing your meditation session!',
              style:
                  Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            Text(
              'How do you feel right now?',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final mood in MoodRating.values)
                  Flexible(child: _buildMoodButton(mood)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodButton(MoodRating mood) {
    return InkWell(
      onTap: () {
        // Mood currently acknowledges the completion card; weekly analytics
        // deliberately tracks session timing/completion rather than mood.
        onMoodSelected?.call();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(mood.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                mood.label,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
