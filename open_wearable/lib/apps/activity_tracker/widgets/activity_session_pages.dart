import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_wearable/widgets/common/app_section_card.dart';
import '../models/activity_models.dart';
import '../view_models/activity_tracker_controller.dart';
import 'activity_widgets.dart';

/// Stored workouts and the currently running session.
class ActivitySessionsPage extends StatelessWidget {
  const ActivitySessionsPage({super.key});
  @override
  Widget build(BuildContext context) => Consumer<ActivityTrackerController>(
        builder: (context, c, _) => ActivityLayout(
          title: 'Sessions',
          children: [
            if (c.sessions.isEmpty)
              const ActivityNotice(
                'No sessions yet',
                'Start tracking to save your steps, exercise sets and jump attempts.',
              ),
            for (final s in c.sessions)
              ActivityCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivitySummaryPage(session: s),
                  ),
                ),
                child: Row(
                  children: [
                    const ActivityIcon('activity', box: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${activityDate(s.startedAt)} · ${activityTime(s.startedAt)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          ActivityCaption(
                            '${s.steps} steps · ${s.repetitions} reps · ${s.jumps.length} jumps',
                          ),
                          if (s.endedAt == null || s.interrupted)
                            ActivityCaption(
                              s.interrupted
                                  ? 'Recovered after interruption'
                                  : 'Session in progress',
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
          ],
        ),
      );
}

/// Saved metrics and exports, using only confirmed algorithm events.
class ActivitySummaryPage extends StatelessWidget {
  const ActivitySummaryPage({super.key, required this.session});
  final ActivitySession session;
  @override
  Widget build(BuildContext context) => Consumer<ActivityTrackerController>(
        builder: (context, c, _) {
          final live = identical(c.current, session);
          final duration = (session.endedAt ?? DateTime.now())
              .difference(session.startedAt)
              .inSeconds;
          final validJumps =
              session.jumps.where((j) => j.heightCm != null).length;
          return ActivityLayout(
            title: 'Session summary',
            actions: [
              OutlinedButton(
                onPressed: () => exportActivitySession(context, session),
                child: const Text('Export'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(live ? 'Back to tracking' : 'Done'),
              ),
            ],
            children: [
              Row(
                children: [
                  ActivityBadge(
                    live
                        ? 'Session in progress'
                        : session.interrupted
                            ? 'Session recovered'
                            : 'Session saved',
                    warning: session.interrupted,
                  ),
                ],
              ),
              Text(
                '${activityDate(session.startedAt)}, ${activityTime(session.startedAt)} · ${activityDuration(duration)}',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              ActivityCaption(session.deviceName),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ActivityMetric(
                      'Steps',
                      '${session.steps}',
                      detail: 'During this session',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActivityMetric(
                      'Repetitions',
                      '${session.repetitions}',
                      detail: '${session.sets.length} completed sets',
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ActivityMetric(
                      'Jumps',
                      '${session.jumps.length}',
                      detail: '$validJumps valid height estimates',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActivityMetric(
                      'Best estimate',
                      session.bestHeightCm == null
                          ? '—'
                          : '${session.bestHeightCm!.toStringAsFixed(1)} cm',
                      detail: 'Flight-time estimate',
                    ),
                  ),
                ],
              ),
              AppSectionCard(
                title: 'Your workout',
                child: session.sets.isEmpty
                    ? const ActivityCaption('No completed exercise sets.')
                    : Column(
                        children: [
                          for (var i = 0; i < session.sets.length; i++)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                session.sets[i].kind.label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: ActivityCaption(
                                'Set ${i + 1} · ${activityDuration(session.sets[i].seconds)}',
                              ),
                              trailing: Text(
                                '${session.sets[i].repetitions} reps',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              if (session.jumps.isNotEmpty)
                AppSectionCard(
                  title: 'Jump attempts',
                  child: Column(
                    children: [
                      for (var i = 0; i < session.jumps.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Jump ${i + 1}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: ActivityCaption(
                            session.jumps[i].reason ?? 'Good signal',
                          ),
                          trailing: Text(
                            session.jumps[i].heightCm == null
                                ? '—'
                                : '${session.jumps[i].heightCm!.toStringAsFixed(1)} cm',
                          ),
                        ),
                    ],
                  ),
                ),
              if (session.interrupted)
                const ActivityNotice(
                  'Confirmed results recovered',
                  'The previous session ended unexpectedly. Incomplete movements were discarded.',
                ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityStudyPage(session: session),
                  ),
                ),
                icon: const Icon(Icons.science_outlined),
                label: Text(
                  'Study mode · ${session.trials.length} reference trials',
                ),
              ),
              if (live)
                OutlinedButton(
                  onPressed: () async {
                    await c.finish();
                  },
                  child: const Text('End and save session'),
                ),
              if (c.storageError != null)
                ActivityNotice(
                  'Storage needs attention',
                  c.storageError!,
                  warning: true,
                ),
            ],
          );
        },
      );
}

/// Reference-based evaluation for participants, speeds and execution styles.
/// Sources refer to recorded sets, individual jump attempts or session steps.
class ActivityStudyPage extends StatefulWidget {
  const ActivityStudyPage({super.key, required this.session});
  final ActivitySession session;
  @override
  State<ActivityStudyPage> createState() => _ActivityStudyPageState();
}

class _ActivityStudyPageState extends State<ActivityStudyPage> {
  final _participant = TextEditingController();
  final _pattern = TextEditingController();
  final _source = TextEditingController(text: 'Annotated video');
  final _reference = TextEditingController();
  final _height = TextEditingController();
  ActivityKind _kind = ActivityKind.steps;
  int _record = 0;
  bool _triedSaving = false;
  late final ActivitySession _captured =
      ActivitySession.fromJson(widget.session.toJson());
  final DateTime _capturedAt = DateTime.now();
  @override
  void dispose() {
    for (final c in [_participant, _pattern, _source, _reference, _height]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final sets = _captured.sets.where((s) => s.kind == _kind).toList();
    final recordCount = _kind == ActivityKind.steps
        ? 1
        : _kind == ActivityKind.jumps
            ? _captured.jumps.length
            : sets.length;
    final hasRecord = _record < recordCount;
    final detected = !hasRecord
        ? null
        : _kind == ActivityKind.steps
            ? _captured.steps
            : _kind == ActivityKind.jumps
                ? 1
                : sets[_record].repetitions;
    final estimate = _kind == ActivityKind.jumps && hasRecord
        ? _captured.jumps[_record].heightCm
        : null;
    final reference = int.tryParse(_reference.text);
    final referenceHeight = double.tryParse(_height.text.replaceAll(',', '.'));
    final valid = hasRecord &&
        _participant.text.trim().isNotEmpty &&
        _pattern.text.trim().isNotEmpty &&
        _source.text.trim().isNotEmpty &&
        reference != null &&
        reference >= 0 &&
        (_height.text.isEmpty ||
            (referenceHeight != null &&
                referenceHeight.isFinite &&
                referenceHeight > 0));
    final error =
        reference == null || detected == null ? null : detected - reference;
    final heightTrials =
        session.trials.where((t) => t.heightErrorCm != null).toList();
    return ActivityLayout(
      title: 'Validation session',
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        ElevatedButton(
          onPressed: () => exportActivitySession(context, session),
          child: const Text('Export trials'),
        ),
      ],
      children: [
        const Row(children: [ActivityBadge('Study mode')]),
        const ActivityCaption(
          'Results are captured when this screen opens. Each reference must cover the same interval.',
        ),
        const Text(
          'Compare against a reference',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        TextField(
          controller: _participant,
          decoration: const InputDecoration(
            labelText: 'Participant ID',
            hintText: 'e.g. P01',
          ),
          onChanged: (_) => setState(() {}),
        ),
        TextField(
          controller: _pattern,
          decoration: const InputDecoration(
            labelText: 'Movement pattern / trial',
            hintText: 'e.g. Slow pace · trial 1',
          ),
          onChanged: (_) => setState(() {}),
        ),
        ActivityCard(
          child: Column(
            children: [
              DropdownButtonFormField<ActivityKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Activity'),
                items: ActivityKind.values
                    .map(
                      (k) => DropdownMenuItem(value: k, child: Text(k.label)),
                    )
                    .toList(),
                onChanged: (k) => setState(() {
                  _kind = k!;
                  _record = 0;
                  _reference.clear();
                  _height.clear();
                }),
              ),
              const SizedBox(height: 12),
              if (hasRecord)
                DropdownButtonFormField<int>(
                  key: ValueKey('${_kind.name}$_record'),
                  initialValue: _record,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Detected result'),
                  items: List.generate(
                    recordCount,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(
                        _kind == ActivityKind.steps
                            ? 'Entire session · ${session.steps} steps'
                            : _kind == ActivityKind.jumps
                                ? 'Jump ${i + 1}'
                                : 'Set ${i + 1} · ${sets[i].repetitions} reps',
                      ),
                    ),
                  ),
                  onChanged: (i) => setState(() => _record = i!),
                )
              else
                const ActivityCaption('Complete a set or a jump test first.'),
              const SizedBox(height: 12),
              TextField(
                controller: _source,
                decoration:
                    const InputDecoration(labelText: 'Reference source'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ActivityMetric(
                'Detected',
                detected?.toString() ?? '—',
                detail: _kind == ActivityKind.jumps
                    ? 'Jump attempt'
                    : 'Confirmed count',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ActivityCard(
                child: TextField(
                  controller: _reference,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Reference count',
                    errorText:
                        _triedSaving && (reference == null || reference < 0)
                            ? 'Enter a count ≥ 0'
                            : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ],
        ),
        if (_kind == ActivityKind.jumps)
          TextField(
            controller: _height,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Reference height (cm)',
              hintText: 'Measured independently',
            ),
            onChanged: (_) => setState(() {}),
          ),
        AppSectionCard(
          title: 'Trial comparison',
          child: Column(
            children: [
              _ComparisonRow(
                'Count error',
                'Detected − reference',
                error == null ? '—' : '${error > 0 ? '+' : ''}$error',
              ),
              if (reference != null && reference > 0 && error != null)
                _ComparisonRow(
                  'Absolute percentage error',
                  'Relative to the reference',
                  '${(error.abs() / reference * 100).toStringAsFixed(1)}%',
                ),
              if (_kind == ActivityKind.jumps) ...[
                _ComparisonRow(
                  'Jump estimate',
                  'Flight-time estimate',
                  estimate == null
                      ? 'Unavailable'
                      : '${estimate.toStringAsFixed(1)} cm',
                ),
                _ComparisonRow(
                  'Height difference',
                  'Estimate − reference',
                  estimate != null && referenceHeight != null
                      ? '${(estimate - referenceHeight).toStringAsFixed(1)} cm'
                      : '—',
                ),
              ],
            ],
          ),
        ),
        const ActivityNotice(
          'Reference needed',
          'Use independently annotated counts and measurements. Compare separate trials across users, speeds and execution styles. Choose Steps for negative controls such as head movements.',
        ),
        if (_triedSaving && !valid)
          const ActivityCaption(
            'Enter a participant, movement pattern, reference source and valid reference values.',
          ),
        ElevatedButton(
          onPressed: () {
            setState(() => _triedSaving = true);
            if (!valid) return;
            context.read<ActivityTrackerController>().addTrial(
                  session,
                  ValidationTrial(
                    participant: _participant.text.trim(),
                    pattern: _pattern.text.trim(),
                    referenceSource: _source.text.trim(),
                    resultLabel: _kind == ActivityKind.steps
                        ? 'Session steps'
                        : '${_kind == ActivityKind.jumps ? 'Jump' : 'Set'} ${_record + 1}',
                    capturedAt: _capturedAt,
                    kind: _kind,
                    detected: detected!,
                    reference: reference,
                    estimatedHeightCm: estimate,
                    referenceHeightCm: referenceHeight,
                  ),
                );
            setState(() {
              _reference.clear();
              _height.clear();
              _triedSaving = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reference trial saved')),
            );
          },
          child: const Text('Save reference trial'),
        ),
        if (session.trials.isNotEmpty)
          AppSectionCard(
            title: '${session.trials.length} saved reference trials',
            subtitle: '${heightTrials.length} paired height estimates',
            child: Column(
              children: [
                for (final kind in ActivityKind.values)
                  if (session.trials.any((t) => t.kind == kind))
                    _ComparisonRow(
                      '${kind.label} · count MAE',
                      'Mean absolute error across saved trials',
                      (session.trials.where((t) => t.kind == kind).fold<double>(
                                    0,
                                    (n, t) => n + t.countError.abs(),
                                  ) /
                              session.trials
                                  .where((t) => t.kind == kind)
                                  .length)
                          .toStringAsFixed(2),
                    ),
                if (heightTrials.isNotEmpty)
                  _ComparisonRow(
                    'Height MAE',
                    'Paired estimates only',
                    '${(heightTrials.fold<double>(0, (n, t) => n + t.heightErrorCm!.abs()) / heightTrials.length).toStringAsFixed(1)} cm',
                  ),
                for (final t in session.trials.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${t.participant} · ${t.kind.label}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: ActivityCaption(
                      '${t.pattern} · ${t.detected}/${t.reference} detected/reference',
                    ),
                    trailing:
                        Text('${t.countError > 0 ? '+' : ''}${t.countError}'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow(this.title, this.detail, this.value);
  final String title, detail, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ActivityCaption(detail),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      );
}

/// Shares local exports only after an explicit Export action.
Future<void> exportActivitySession(
  BuildContext context,
  ActivitySession session,
) async {
  final controller = context.read<ActivityTrackerController>();
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    final paths = await controller.storage.export(session);
    await SharePlus.instance.share(
      ShareParams(
        title: 'Activity Tracker session',
        files: paths.map(XFile.new).toList(),
        sharePositionOrigin: origin,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export could not be created: $e')),
      );
    }
  }
}
