import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../model/meditation_analytics.dart';
import 'drawer_page.dart';

class WeeklyAnalyticsPage extends StatefulWidget implements DrawerPage {
  final MeditationAnalyticsStore analyticsStore;

  const WeeklyAnalyticsPage({
    super.key,
    required this.analyticsStore,
  });

  @override
  String get label => "Weekly Analytics";

  @override
  IconData get icon => Icons.insights_outlined;

  @override
  IconData get selectedIcon => Icons.insights;

  @override
  State<WeeklyAnalyticsPage> createState() => _WeeklyAnalyticsPageState();
}

class _WeeklyAnalyticsPageState extends State<WeeklyAnalyticsPage> {
  late DateTime _selectedWeek;

  @override
  void initState() {
    super.initState();
    _selectedWeek = MeditationAnalyticsStore.startOfWeek(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.analyticsStore,
      builder: (context, _) {
        if (widget.analyticsStore.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = widget.analyticsStore.recordsForWeek(_selectedWeek);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WeekHeader(
                weekStart: _selectedWeek,
                onPrevious: () => setState(
                  () => _selectedWeek =
                      _selectedWeek.subtract(const Duration(days: 7)),
                ),
                onNext: _canMoveToNextWeek
                    ? () => setState(
                          () => _selectedWeek =
                              _selectedWeek.add(const Duration(days: 7)),
                        )
                    : null,
              ),
              const SizedBox(height: 16),
              _SummaryGrid(records: records),
              const SizedBox(height: 16),
              _WeeklyActivityCard(
                weekStart: _selectedWeek,
                records: records,
              ),
              const SizedBox(height: 16),
              _ModeBreakdownCard(records: records),
              const SizedBox(height: 16),
              _RecentSessionsCard(records: records),
            ],
          ),
        );
      },
    );
  }

  bool get _canMoveToNextWeek => _selectedWeek.isBefore(
        MeditationAnalyticsStore.startOfWeek(DateTime.now()),
      );
}

class _WeekHeader extends StatelessWidget {
  final DateTime weekStart;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  const _WeekHeader({
    required this.weekStart,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final sameMonth = weekStart.month == weekEnd.month;
    final range = sameMonth
        ? '${DateFormat('MMM d').format(weekStart)}–${DateFormat('d, y').format(weekEnd)}'
        : '${DateFormat('MMM d').format(weekStart)}–${DateFormat('MMM d, y').format(weekEnd)}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous week',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Weekly Analytics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    range,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Next week',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final List<MeditationSessionRecord> records;

  const _SummaryGrid({required this.records});

  @override
  Widget build(BuildContext context) {
    final totalDuration = _totalDuration(records);
    final completed = records.where((record) => record.completed).length;
    final completionRate = records.isEmpty
        ? '—'
        : '${(completed / records.length * 100).round()}%';
    final activeDays = records
        .map(
          (record) => DateTime(
            record.startedAt.year,
            record.startedAt.month,
            record.startedAt.day,
          ),
        )
        .toSet()
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              width: cardWidth,
              icon: Icons.self_improvement,
              label: 'Sessions',
              value: '${records.length}',
            ),
            _MetricCard(
              width: cardWidth,
              icon: Icons.timelapse,
              label: 'Mindful time',
              value: _durationLabel(totalDuration),
            ),
            _MetricCard(
              width: cardWidth,
              icon: Icons.check_circle_outline,
              label: 'Completed',
              value: completionRate,
            ),
            _MetricCard(
              width: cardWidth,
              icon: Icons.calendar_today_outlined,
              label: 'Active days',
              value: '$activeDays / 7',
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;

  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyActivityCard extends StatelessWidget {
  final DateTime weekStart;
  final List<MeditationSessionRecord> records;

  const _WeeklyActivityCard({
    required this.weekStart,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final days = List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final dayRecords = records.where(
        (record) => _sameDay(
          record.startedAt,
          date,
        ),
      );
      return (
        date: date,
        bio: _totalDuration(
          dayRecords.where(
            (record) => record.mode == MeditationAnalyticsMode.bioAdaptive,
          ),
        ),
        timed: _totalDuration(
          dayRecords.where(
            (record) => record.mode == MeditationAnalyticsMode.timed,
          ),
        ),
      );
    });
    final maxSeconds = days
        .map((day) => day.bio.inSeconds + day.timed.inSeconds)
        .fold<int>(0, (maximum, value) => value > maximum ? value : maximum);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Combined meditation time across both regular modes',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in days)
                    Expanded(
                      child: _DailyBar(
                        date: day.date,
                        bioDuration: day.bio,
                        timedDuration: day.timed,
                        maximumSeconds: maxSeconds,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(
                  color: colors.primary,
                  label: MeditationAnalyticsMode.bioAdaptive.label,
                ),
                const SizedBox(width: 20),
                _LegendDot(
                  color: colors.tertiary,
                  label: MeditationAnalyticsMode.timed.label,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyBar extends StatelessWidget {
  final DateTime date;
  final Duration bioDuration;
  final Duration timedDuration;
  final int maximumSeconds;

  const _DailyBar({
    required this.date,
    required this.bioDuration,
    required this.timedDuration,
    required this.maximumSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final totalSeconds = bioDuration.inSeconds + timedDuration.inSeconds;
    final availableHeight = 125.0;
    final barHeight = maximumSeconds == 0
        ? 0.0
        : availableHeight * totalSeconds / maximumSeconds;

    return Tooltip(
      message: '${DateFormat('EEEE').format(date)}\n'
          '${MeditationAnalyticsMode.bioAdaptive.label}: ${_durationLabel(bioDuration)}\n'
          '${MeditationAnalyticsMode.timed.label}: ${_durationLabel(timedDuration)}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 18,
            child: totalSeconds == 0
                ? null
                : Text(
                    _shortDurationLabel(Duration(seconds: totalSeconds)),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 24,
            height: availableHeight,
            alignment: Alignment.bottomCenter,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 24,
                height: barHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (bioDuration.inSeconds > 0)
                      Expanded(
                        flex: bioDuration.inSeconds,
                        child: ColoredBox(color: colors.primary),
                      ),
                    if (timedDuration.inSeconds > 0)
                      Expanded(
                        flex: timedDuration.inSeconds,
                        child: ColoredBox(color: colors.tertiary),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(DateFormat('E').format(date).substring(0, 2)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ModeBreakdownCard extends StatelessWidget {
  final List<MeditationSessionRecord> records;

  const _ModeBreakdownCard({required this.records});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'By mode',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            for (final mode in MeditationAnalyticsMode.values) ...[
              _ModeRow(
                mode: mode,
                records: records
                    .where((record) => record.mode == mode)
                    .toList(growable: false),
              ),
              if (mode != MeditationAnalyticsMode.values.last)
                const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  final MeditationAnalyticsMode mode;
  final List<MeditationSessionRecord> records;

  const _ModeRow({required this.mode, required this.records});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isBio = mode == MeditationAnalyticsMode.bioAdaptive;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isBio ? colors.primary : colors.tertiary)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isBio ? Icons.monitor_heart_outlined : Icons.alarm_outlined,
            color: isBio ? colors.primary : colors.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            mode.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _durationLabel(_totalDuration(records)),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${records.length} ${records.length == 1 ? 'session' : 'sessions'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecentSessionsCard extends StatelessWidget {
  final List<MeditationSessionRecord> records;

  const _RecentSessionsCard({required this.records});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sessions this week',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.spa_outlined,
                        size: 40,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 10),
                      const Text('No regular meditation sessions yet'),
                      const SizedBox(height: 4),
                      Text(
                        'Biosignal-adaptive and timed sessions will appear here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (var index = 0; index < records.length; index++) ...[
                _SessionRow(record: records[index]),
                if (index < records.length - 1) const Divider(height: 1),
              ],
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final MeditationSessionRecord record;

  const _SessionRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isBio = record.mode == MeditationAnalyticsMode.bioAdaptive;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            (isBio ? colors.primary : colors.tertiary).withValues(alpha: 0.12),
        child: Icon(
          isBio ? Icons.monitor_heart_outlined : Icons.alarm_outlined,
          color: isBio ? colors.primary : colors.tertiary,
        ),
      ),
      title: Text(record.mode.label),
      subtitle: Text(
        '${DateFormat('EEE, HH:mm').format(record.startedAt)} · ${_durationLabel(record.duration)}',
      ),
      trailing: Tooltip(
        message: record.completed ? 'Completed naturally' : 'Stopped early',
        child: Icon(
          record.completed ? Icons.check_circle : Icons.stop_circle_outlined,
          color: record.completed ? Colors.green : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

Duration _totalDuration(Iterable<MeditationSessionRecord> records) {
  return records.fold(
    Duration.zero,
    (total, record) => total + record.duration,
  );
}

String _durationLabel(Duration duration) {
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60);
    return minutes == 0
        ? '${duration.inHours}h'
        : '${duration.inHours}h ${minutes}m';
  }
  if (duration.inMinutes > 0) return '${duration.inMinutes} min';
  return '${duration.inSeconds} sec';
}

String _shortDurationLabel(Duration duration) {
  if (duration.inHours > 0) return '${duration.inHours}h';
  if (duration.inMinutes > 0) return '${duration.inMinutes}m';
  return '${duration.inSeconds}s';
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
