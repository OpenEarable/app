import '../../logger.dart';

class CommandParam<T> {
  final String name;
  final T? value;
  final bool required;

  CommandParam({
    required this.name,
    this.value,
    this.required = false,
  });
}

abstract class Command {
  final String name;
  final List<CommandParam> params;

  Command({required this.name, this.params = const []});

  T requireParam<T>(List<CommandParam> params, String paramName) {
    final param = params.firstWhere(
      (p) => p.name == paramName,
      orElse: () =>
          throw ArgumentError('Missing required parameter: $paramName'),
    );
    if (param.value == null) {
      throw ArgumentError('Parameter $paramName cannot be null');
    }
    return param.value as T;
  }

  Future<Object?> run(List<CommandParam> params) async {
    final startedAt = DateTime.now();
    logger.d(
      '[connector.command] start name=$name params=${_formatParams(params)}',
    );
    for (final param in this.params) {
      if (param.required) {
        final providedParam = params.firstWhere(
          (p) => p.name == param.name,
          orElse: () => throw ArgumentError(
            'Missing required parameter: ${param.name}',
          ),
        );
        if (providedParam.value == null) {
          throw ArgumentError('Parameter ${param.name} cannot be null');
        }
      }
    }
    try {
      final result = await execute(params);
      final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
      logger.d(
        '[connector.command] done name=$name duration_ms=$durationMs',
      );
      return result;
    } catch (error, stackTrace) {
      final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
      logger.w(
        '[connector.command] failed name=$name duration_ms=$durationMs error=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<Object?> execute(List<CommandParam> params);

  String _formatParams(List<CommandParam> params) {
    final map = <String, Object?>{};
    for (final param in params) {
      if (param.name.startsWith('__')) {
        continue;
      }
      map[param.name] = _loggableValue(param.value);
    }
    return map.toString();
  }

  Object? _loggableValue(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is List) {
      return value.map(_loggableValue).toList(growable: false);
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _loggableValue(nestedValue)),
      );
    }
    return value.runtimeType.toString();
  }
}
