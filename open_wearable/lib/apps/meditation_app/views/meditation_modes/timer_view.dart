import 'dart:async';
import 'package:flutter/material.dart';
import 'package:open_wearable/apps/meditation_app/model/user_account.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../configs/timed_mode_config.dart';
import '../../model/meditation.dart' show Meditation, ScheduledMeditation;
import '../../model/meditation_analytics.dart';
import '../../widgets/meditation_tile.dart';
import '../../widgets/api_warning.dart';

class TimerView extends StatefulWidget {
  final MeditationAnalyticsStore analyticsStore;

  const TimerView({
    super.key,
    required this.analyticsStore,
  });

  @override
  State<TimerView> createState() => _TimerViewState();
}

class _TimerViewState extends State<TimerView> {
  final List<ScheduledMeditation> _scheduledMeditations = [];
  Timer? _timer;
  final ValueNotifier<ScheduledMeditation?> _currentMeditation =
      ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(TimedModeConfig.schedulePollingInterval, (timer) {
      _checkMeditations();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final meditation in _scheduledMeditations) {
      meditation.dispose();
    }
    final current = _currentMeditation.value;
    if (current != null) {
      unawaited(current.stop().whenComplete(current.dispose));
    }
    _currentMeditation.dispose();
    super.dispose();
  }

  void _checkMeditations() {
    if (_currentMeditation.value != null) return;
    ScheduledMeditation? dueMeditation;
    for (final meditation in _scheduledMeditations) {
      if (meditation.isDue()) {
        dueMeditation = meditation;
        break;
      }
    }
    if (dueMeditation == null) return;

    setState(() => _scheduledMeditations.remove(dueMeditation));
    _startMeditation(dueMeditation);
  }

  void _scheduleMeditation(UserAccount userAccount, DateTime time) {
    final scheduledMeditation = ScheduledMeditation(
      userAccount: userAccount,
      scheduledTime: time,
      analyticsStore: widget.analyticsStore,
    );
    setState(() {
      _scheduledMeditations.add(scheduledMeditation);
      _scheduledMeditations
          .sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    });
  }

  void _startMeditation(ScheduledMeditation meditation) {
    _currentMeditation.value = meditation;
    unawaited(meditation.start());
  }

  void _completeMeditation(Meditation meditation) {
    if (_currentMeditation.value != meditation) return;
    _currentMeditation.value = null;
    unawaited(meditation.stop().whenComplete(meditation.dispose));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userAccount = context.read<UserAccount>();

    return ValueListenableBuilder<ScheduledMeditation?>(
      valueListenable: _currentMeditation,
      builder: (context, currentMeditation, child) {
        if (currentMeditation != null) {
          return Column(
            children: [
              if (!userAccount.hasValidDeepseekKey) ...[
                APIWarning(serviceName: "Deepseek"),
                const SizedBox(height: 16),
              ],
              if (!userAccount.hasValidSelectedTtsProvider) ...[
                APIWarning(
                  serviceName: userAccount.ttsProvider.label,
                ),
                const SizedBox(height: 16),
              ],
              MeditationTile(
                meditationNotifier: _currentMeditation,
                onMeditationComplete: _completeMeditation,
              ),
            ],
          );
        } else {
          return SingleChildScrollView(
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Timed Meditation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Schedule a meditation by delay or at a specific clock time.',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Now'),
                            onPressed: () {
                              final scheduledMeditation = ScheduledMeditation(
                                userAccount: userAccount,
                                scheduledTime: DateTime.now(),
                                analyticsStore: widget.analyticsStore,
                              );
                              _startMeditation(scheduledMeditation);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                _scheduleMeditation(
                                  userAccount,
                                  DateTime.now().add(
                                    TimedModeConfig.scheduleAfterFiveMinutes,
                                  ),
                                );
                              },
                              child: const Text('After 5 min'),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                _scheduleMeditation(
                                  userAccount,
                                  DateTime.now().add(
                                    TimedModeConfig.scheduleAfterTenMinutes,
                                  ),
                                );
                              },
                              child: const Text('After 10 min'),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                _scheduleMeditation(
                                  userAccount,
                                  DateTime.now().add(
                                    TimedModeConfig.scheduleAfterThirtyMinutes,
                                  ),
                                );
                              },
                              child: const Text('After 30 min'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (!mounted) return;
                                if (picked != null) {
                                  final now = DateTime.now();
                                  DateTime scheduledDateTime = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                  if (scheduledDateTime.isBefore(now)) {
                                    scheduledDateTime = scheduledDateTime
                                        .add(Duration(days: 1));
                                  }
                                  _scheduleMeditation(
                                    userAccount,
                                    scheduledDateTime,
                                  );
                                }
                              },
                              icon: const Icon(Icons.schedule),
                              label: const Text('Pick Time'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_scheduledMeditations.isNotEmpty)
                  ScheduledMeditationList(
                    scheduledMeditations: _scheduledMeditations,
                    onCancel: (meditation) {
                      setState(() {
                        _scheduledMeditations.remove(meditation);
                      });
                      meditation.dispose();
                    },
                  ),
              ],
            ),
          );
        }
      },
    );
  }
}

class ScheduledMeditationList extends StatelessWidget {
  final List<ScheduledMeditation> scheduledMeditations;
  final ValueChanged<ScheduledMeditation> onCancel;

  const ScheduledMeditationList({
    super.key,
    required this.scheduledMeditations,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Scheduled Meditations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: scheduledMeditations.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final meditation = scheduledMeditations[index];
                return ListTile(
                  title: Text(
                    'Scheduled at ${DateFormat('MM/dd/yyyy hh:mm').format(meditation.scheduledTime)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: () => onCancel(meditation),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
