import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/common/app_section_card.dart';
import 'package:open_wearable/apps/widgets/select_earable_view.dart';
import 'package:open_wearable/apps/widgets/app_compatibility.dart';
import 'package:provider/provider.dart';
import '../models/activity_models.dart';
import '../view_models/activity_tracker_controller.dart';
import 'activity_session_pages.dart';
import 'activity_widgets.dart';

/// Built-in mini-app entry; history and interrupted sessions work offline.
class ActivityTrackerPage extends StatefulWidget {
  const ActivityTrackerPage({super.key, this.wearable});
  final Wearable? wearable;
  @override
  State<ActivityTrackerPage> createState() => _ActivityTrackerPageState();
}

class _ActivityTrackerPageState extends State<ActivityTrackerPage> {
  bool _fitChecked = false, _starting = false;
  late ActivityTrackerController _controller;
  @override
  void initState() {
    super.initState();
    _controller = context.read<ActivityTrackerController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.wearable != null) {
        context
            .read<ActivityTrackerController>()
            .prepare(widget.wearable!.deviceId);
      }
    });
  }

  @override
  void dispose() {
    _controller.releasePreparedDevice();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<ActivityTrackerController>(
        builder: (context, c, _) {
          if (!c.isTracking && c.deviceId == null) {
            return ActivityLayout(
              title: 'Activity Tracker',
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ActivitySessionsPage(),
                    ),
                  ),
                  child: const Text('View sessions'),
                ),
                ElevatedButton(
                  onPressed: () => _chooseWearable(context),
                  child: const Text('Choose wearable'),
                ),
              ],
              children: const [
                SizedBox(height: 12),
                Text(
                  'Ready to move?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                ActivityNotice(
                  'Connect your earable',
                  'Choose a connected OpenEarable to start tracking. Your saved sessions are available at any time.',
                ),
              ],
            );
          }
          if (!c.isTracking) return _ready(c);
          if (!c.connected || c.paused) {
            return ActivityInterruptionView(controller: c);
          }
          final latest = c.sessions.where((s) => s.endedAt != null).firstOrNull;
          final lastJump = c.current!.jumps.lastOrNull;
          return ActivityLayout(
            title: 'Activity Tracker',
            appBarActions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'pause') c.pause();
                  if (value == 'finish') {
                    final session = await c.finish();
                    if (context.mounted && session != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActivitySummaryPage(session: session),
                        ),
                      );
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'pause',
                    child: Text('Pause tracking'),
                  ),
                  const PopupMenuItem(
                    value: 'finish',
                    child: Text('End session'),
                  ),
                ],
              ),
            ],
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityStudyPage(session: c.current!),
                  ),
                ),
                child: const Text('Study mode'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ActivitySessionsPage(),
                  ),
                ),
                child: const Text('View sessions'),
              ),
            ],
            children: [
              _DeviceStrip(c),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.primaryContainer
                      : const Color(0xFF835B58),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TODAY’S STEPS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        ActivityIcon('activity', color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _number(c.todaySteps),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ActivityCaption(
                      c.engine.calibrated
                          ? 'Tracking since ${activityTime(c.current!.startedAt)}'
                          : 'Stand still briefly to resume counting',
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    ActivitySignal(c.signal, color: Colors.white, height: 34),
                  ],
                ),
              ),
              if (c.storageError != null)
                ActivityNotice(
                  'Storage needs attention',
                  c.storageError!,
                  warning: true,
                ),
              if (!c.engine.calibrated)
                ActivityNotice(
                  'Stand still briefly',
                  'Keep your head relaxed while the motion signal settles.',
                ),
              if (c.mode != ActivityKind.steps)
                ActivityCard(
                  onTap: () => _openExercise(context, c),
                  child: Row(
                    children: [
                      ActivityIcon(_icon(c.mode), box: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Continue ${c.mode.label.toLowerCase()}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            ActivityCaption(
                              '${c.repetitions} confirmed repetitions',
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Start an exercise',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(child: ActivityCaption('Choose manually')),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _exerciseCard(
                      context,
                      c,
                      ActivityKind.squats,
                      'Count complete repetitions',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _exerciseCard(
                      context,
                      c,
                      ActivityKind.pushUps,
                      'Track your next set',
                    ),
                  ),
                ],
              ),
              ActivityCard(
                onTap: c.canCount && c.mode == ActivityKind.steps
                    ? () {
                        c.startExercise(ActivityKind.jumps);
                        _openExercise(context, c);
                      }
                    : null,
                child: Row(
                  children: [
                    const ActivityIcon('jump', box: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Jump test',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ActivityCaption(
                            lastJump?.heightCm != null
                                ? 'Last estimate ${lastJump!.heightCm!.toStringAsFixed(1)} cm'
                                : 'Detect jumps and estimate height',
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
              ActivityCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ActivitySummaryPage(session: latest ?? c.current!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            latest == null ? 'Current session' : 'Last workout',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          ActivityCaption(
                            latest == null
                                ? 'Your results will appear here'
                                : '${activityDate(latest.startedAt)} · ${activityTime(latest.startedAt)}',
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(latest ?? c.current!).repetitions} reps',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const ActivityCaption(
                'Tracking continues between screens while the app is in the foreground. Keep the app open during measurement.',
              ),
            ],
          );
        },
      );

  Widget _ready(ActivityTrackerController c) => ActivityLayout(
        title: 'Activity Tracker',
        appBarActions: [
          IconButton(
            tooltip: 'View sessions',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ActivitySessionsPage(),
              ),
            ),
            icon: const Icon(Icons.history),
          ),
        ],
        actions: [
          ElevatedButton(
            onPressed:
                !_starting && _fitChecked && c.connected && c.engine.calibrated
                    ? () async {
                        setState(() => _starting = true);
                        await c.start();
                        if (mounted) setState(() => _starting = false);
                      }
                    : null,
            child: Text(_starting ? 'Starting…' : 'Start tracking'),
          ),
        ],
        children: [
          const SizedBox(height: 12),
          const Text(
            'Ready to move?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            'Wear your earable securely and take a moment to get comfortable.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          ActivityCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.hearing,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.deviceName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ActivityCaption(
                            c.connected
                                ? 'Connected · motion data available'
                                : 'Connecting to motion sensors',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const ActivityBadge('Selected'),
              ],
            ),
          ),
          AppSectionCard(
            title: 'A quick check',
            child: Column(
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '1. Check the fit',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle:
                      const ActivityCaption('Wear your earable securely.'),
                  value: _fitChecked,
                  onChanged: (v) => setState(() => _fitChecked = v ?? false),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '2. Stand still briefly',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const ActivityCaption(
                    'Keep your head relaxed for 1.5 seconds.',
                  ),
                  trailing: c.engine.calibrated
                      ? const Icon(Icons.check)
                      : SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            value: c.connected
                                ? c.engine.calibrationProgress
                                : null,
                            strokeWidth: 2,
                          ),
                        ),
                ),
                const Divider(),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '3. Start tracking',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle:
                      ActivityCaption('Steps continue between exercises.'),
                ),
              ],
            ),
          ),
          ActivityNotice(
            c.engine.calibrated
                ? 'You’re ready'
                : 'Waiting for a steady signal',
            c.engine.calibrated
                ? 'Motion data is available. You can begin.'
                : c.interruption ??
                    'Stand still while the motion sensors calibrate.',
          ),
          if (c.interruption != null && !c.preparing)
            TextButton.icon(
              onPressed: c.reconnect,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry connection'),
            ),
          if (c.storageError != null)
            ActivityNotice(
              'Storage needs attention',
              c.storageError!,
              warning: true,
            ),
          const ActivityCaption(
            'This first implementation uses motion sensors. Jump height is an estimate. Tracking pauses when the app moves to the background.',
          ),
        ],
      );

  Widget _exerciseCard(
    BuildContext context,
    ActivityTrackerController c,
    ActivityKind kind,
    String detail,
  ) =>
      ActivityCard(
        onTap: c.canCount && c.mode == ActivityKind.steps
            ? () {
                c.startExercise(kind);
                _openExercise(context, c);
              }
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ActivityIcon(_icon(kind), box: true),
            const SizedBox(height: 8),
            Text(
              kind.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SizedBox(height: 34, child: ActivityCaption(detail)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Start set',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      );
}

void _openExercise(BuildContext context, ActivityTrackerController c) =>
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _ExercisePage()),
    );

void _chooseWearable(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectEarableView(
          supportedDevicePrefixes: const ['OpenEarable'],
          requiredCapabilities: [
            WearableCapabilityRequirement.capability<SensorManager>(
              label: 'sensor streaming',
            ),
            WearableCapabilityRequirement.capability<
                SensorConfigurationManager>(label: 'sensor configuration'),
          ],
          startApp: (wearable, _) async =>
              ActivityTrackerPage(wearable: wearable),
        ),
      ),
    );
String _icon(ActivityKind kind) => switch (kind) {
      ActivityKind.squats => 'squat',
      ActivityKind.pushUps => 'pushup',
      ActivityKind.jumps => 'jump',
      ActivityKind.steps => 'activity'
    };
String _number(int value) => value
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

class _DeviceStrip extends StatelessWidget {
  const _DeviceStrip(this.controller);
  final ActivityTrackerController controller;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.bluetooth, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: ActivityCaption(
                '${controller.deviceName} · ${controller.connected ? 'Connected' : 'Disconnected'}',
              ),
            ),
          ],
        ),
      );
}

class _ExercisePage extends StatelessWidget {
  const _ExercisePage();
  @override
  Widget build(BuildContext context) => Consumer<ActivityTrackerController>(
        builder: (context, c, _) {
          if (!c.isTracking || c.mode == ActivityKind.steps) {
            return ActivityLayout(
              title: 'Workout complete',
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to tracking'),
                ),
              ],
              children: const [
                ActivityNotice(
                  'Set saved',
                  'Your confirmed results are in the session.',
                ),
              ],
            );
          }
          if (!c.connected || c.paused) {
            return ActivityInterruptionView(controller: c, exercise: true);
          }
          final jumpMode = c.mode == ActivityKind.jumps;
          final last = c.current!.jumps.lastOrNull;
          return ActivityLayout(
            title: c.mode.label,
            actions: [
              OutlinedButton(onPressed: c.pause, child: const Text('Pause')),
              ElevatedButton(
                onPressed: () {
                  c.finishSet();
                  Navigator.pop(context);
                },
                child: Text(jumpMode ? 'Finish test' : 'Finish set'),
              ),
            ],
            children: [
              _DeviceStrip(c),
              ActivityCard(
                padding: 18,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      ActivityBadge(
                        !c.engine.calibrated
                            ? 'Stand still to calibrate'
                            : jumpMode
                                ? c.engine.phase
                                : 'Counting repetitions',
                      ),
                      const SizedBox(height: 12),
                      ActivityIcon(_icon(c.mode), size: 30),
                      const SizedBox(height: 8),
                      Text(
                        jumpMode
                            ? last?.heightCm?.toStringAsFixed(1) ?? '—'
                            : '${c.repetitions}',
                        style: const TextStyle(
                          fontSize: 80,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ActivityCaption(
                        jumpMode ? 'cm · estimated height' : 'repetitions',
                      ),
                      const SizedBox(height: 12),
                      if (jumpMode)
                        Text(
                          c.current!.bestHeightCm == null
                              ? 'Your next jump will appear here'
                              : 'Session best ${c.current!.bestHeightCm!.toStringAsFixed(1)} cm',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            4,
                            (i) => Container(
                              width: 38,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(
                                      alpha: i <
                                              (c.engine.phase ==
                                                      'Returning to start'
                                                  ? 3
                                                  : c.engine.phase == 'Lowering'
                                                      ? 2
                                                      : 1)
                                          ? 1
                                          : 0.16,
                                    ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ActivityCaption(
                          c.engine.phase,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!jumpMode) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ActivityMetric(
                        'Current set',
                        '${c.currentSetNumber}',
                        detail: 'Complete cycles only',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ActivityMetric(
                        'Elapsed',
                        activityDuration(c.setSeconds),
                        detail: 'Tracking active',
                      ),
                    ),
                  ],
                ),
                AppSectionCard(
                  title: 'Movement',
                  subtitle: c.engine.quality,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ActivitySignal(c.signal),
                      const SizedBox(height: 10),
                      ActivityCaption(
                        c.mode == ActivityKind.pushUps
                            ? 'Hold the start position once, then continue at your own pace. No pause is needed between repetitions. Keep your head aligned with your body.'
                            : 'Hold the start position briefly. Lower and return fully; keep your head aligned with your body.',
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const ActivityNotice(
                  'Jump straight up',
                  'Begin from a still position. Keep take-off and landing posture similar. Height uses flight time and is an estimate.',
                ),
                AppSectionCard(
                  title: 'Recent attempts',
                  child: c.current!.jumps.isEmpty
                      ? const ActivityCaption(
                          'Stand still briefly, then jump and land in place.',
                        )
                      : Column(
                          children: c.current!.jumps.reversed
                              .take(5)
                              .map(
                                (j) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'Jump ${c.current!.jumps.indexOf(j) + 1}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: ActivityCaption(
                                    j.reason ??
                                        'Good signal · flight ${j.flightSeconds.toStringAsFixed(2)} s',
                                  ),
                                  trailing: Text(
                                    j.heightCm == null
                                        ? '—'
                                        : '${j.heightCm!.toStringAsFixed(1)} cm',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ],
          );
        },
      );
}

/// Pause and disconnect states preserve counters and offer explicit recovery.
class ActivityInterruptionView extends StatelessWidget {
  const ActivityInterruptionView({
    super.key,
    required this.controller,
    this.exercise = false,
  });
  final ActivityTrackerController controller;
  final bool exercise;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final lost = !c.connected;
    return ActivityLayout(
      title: c.mode == ActivityKind.steps ? 'Activity Tracker' : c.mode.label,
      actions: [
        OutlinedButton(
          onPressed: () async {
            final session = await c.finish();
            if (context.mounted && session != null) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivitySummaryPage(session: session),
                ),
              );
            }
          },
          child: const Text('End session'),
        ),
        ElevatedButton(
          onPressed: lost
              ? () async {
                  await c.reconnect();
                  if (context.mounted && !c.connected) {
                    GoRouter.maybeOf(context)?.push('/connect-devices');
                  }
                }
              : c.resume,
          child: Text(lost ? 'Reconnect' : 'Resume'),
        ),
      ],
      children: [
        _DeviceStrip(c),
        ActivityNotice(
          lost ? 'Connection lost' : 'Take your time',
          lost
              ? 'Your confirmed results are saved. Reconnect your earable, then stand still briefly.'
              : 'Workout counting is paused. Your completed repetitions are saved.',
          warning: lost,
        ),
        ActivityCard(
          padding: 24,
          child: Column(
            children: [
              Icon(
                lost ? Icons.bluetooth_disabled : Icons.pause_circle_outline,
                size: 38,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                c.mode == ActivityKind.steps
                    ? '${c.current?.steps ?? 0}'
                    : '${c.repetitions}',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ActivityCaption(
                c.mode == ActivityKind.steps
                    ? 'confirmed session steps'
                    : 'confirmed repetitions',
              ),
              const SizedBox(height: 18),
              ActivityBadge(
                lost ? 'Tracking interrupted' : 'Paused',
                warning: lost,
              ),
            ],
          ),
        ),
        ActivityNotice(
          lost ? 'Bring your earable closer' : 'Ready when you are',
          lost
              ? c.interruption ??
                  'Check that your earable is switched on and seated securely.'
              : 'Resume to continue your current set, or finish the workout.',
        ),
      ],
    );
  }
}
