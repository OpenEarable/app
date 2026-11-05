import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../configs/overall_config.dart';

enum MeditationAnalyticsMode {
  bioAdaptive(label: 'Biosignal-Adaptive'),
  timed(label: 'Timed');

  final String label;

  const MeditationAnalyticsMode({required this.label});
}

@immutable
class MeditationSessionRecord {
  final MeditationAnalyticsMode mode;
  final DateTime startedAt;
  final DateTime endedAt;
  final bool completed;

  const MeditationSessionRecord({
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.completed,
  });

  Duration get duration {
    final value = endedAt.difference(startedAt);
    return value.isNegative ? Duration.zero : value;
  }

  Map<String, Object> toJson() => {
        'mode': mode.name,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'completed': completed,
      };

  static MeditationSessionRecord? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      final modeName = raw['mode'] as String;
      return MeditationSessionRecord(
        mode: MeditationAnalyticsMode.values.byName(modeName),
        startedAt: DateTime.parse(raw['startedAt'] as String).toLocal(),
        endedAt: DateTime.parse(raw['endedAt'] as String).toLocal(),
        completed: raw['completed'] as bool,
      );
    } catch (_) {
      return null;
    }
  }
}

class MeditationAnalyticsStore extends ChangeNotifier {
  static const _storageKey = OverallMeditationConfig.analyticsStorageKey;
  static const _retention = OverallMeditationConfig.analyticsRetention;

  final Future<SharedPreferences> Function() _preferencesProvider;
  final List<MeditationSessionRecord> _records = [];
  Future<void>? _loadFuture;
  bool _isLoading = true;
  bool _isDisposed = false;

  MeditationAnalyticsStore({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance;

  bool get isLoading => _isLoading;
  List<MeditationSessionRecord> get records => List.unmodifiable(_records);

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    _records.clear();
    try {
      final preferences = await _preferencesProvider();
      final encoded = preferences.getString(_storageKey);
      if (encoded != null) {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          _records.addAll(
            decoded
                .map(MeditationSessionRecord.tryParse)
                .whereType<MeditationSessionRecord>(),
          );
        }
      }
    } catch (_) {
      // Analytics must never prevent meditation. Treat unavailable storage or
      // malformed local data as an empty history.
    }

    _prune(DateTime.now());
    _sortNewestFirst();
    _isLoading = false;
    _notifyListenersIfMounted();
  }

  Future<void> recordSession(MeditationSessionRecord record) async {
    await load();
    _records.add(record);
    _prune(record.endedAt);
    _sortNewestFirst();
    try {
      await _persist();
    } catch (_) {
      // Keep the in-memory result even if local persistence is unavailable.
    }
    _notifyListenersIfMounted();
  }

  Future<void> clear() async {
    await load();
    _records.clear();
    final preferences = await _preferencesProvider();
    await preferences.remove(_storageKey);
    _notifyListenersIfMounted();
  }

  List<MeditationSessionRecord> recordsForWeek(DateTime dateInWeek) {
    final start = startOfWeek(dateInWeek);
    final end = start.add(OverallMeditationConfig.analyticsWeekLength);
    return _records
        .where(
          (record) =>
              !record.startedAt.isBefore(start) &&
              record.startedAt.isBefore(end),
        )
        .toList(growable: false);
  }

  static DateTime startOfWeek(DateTime date) {
    final local = date.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  Future<void> _persist() async {
    final preferences = await _preferencesProvider();
    await preferences.setString(
      _storageKey,
      jsonEncode(_records.map((record) => record.toJson()).toList()),
    );
  }

  void _prune(DateTime now) {
    final cutoff = now.subtract(_retention);
    _records.removeWhere((record) => record.endedAt.isBefore(cutoff));
  }

  void _sortNewestFirst() {
    _records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  void _notifyListenersIfMounted() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    super.dispose();
  }
}
