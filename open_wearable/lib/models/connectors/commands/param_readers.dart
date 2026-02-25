import 'command.dart';

String requireStringParam(List<CommandParam> params, String name) {
  final Object? value = params.firstWhere((p) => p.name == name).value;
  if (value is String) {
    return value;
  }
  throw FormatException('Expected "$name" to be a string.');
}

int requireIntParam(List<CommandParam> params, String name) {
  final Object? value = params.firstWhere((p) => p.name == name).value;
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final int? parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  throw FormatException('Expected "$name" to be an integer.');
}

bool? readOptionalBoolParam(List<CommandParam> params, String name) {
  final CommandParam? param = params.where((p) => p.name == name).firstOrNull;
  if (param == null || param.value == null) {
    return null;
  }
  if (param.value is bool) {
    return param.value as bool;
  }
  throw FormatException('Expected "$name" to be a boolean.');
}

Map<String, dynamic> readOptionalMapParam(
  List<CommandParam> params,
  String name,
) {
  final CommandParam? param = params.where((p) => p.name == name).firstOrNull;
  final Object? value = param?.value;
  if (value == null) {
    return <String, dynamic>{};
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value
        .map((key, dynamic mapValue) => MapEntry(key.toString(), mapValue));
  }
  throw FormatException('Expected "$name" to be an object.');
}

List<String> readOptionalStringListParam(
  List<CommandParam> params,
  String name,
) {
  final CommandParam? param = params.where((p) => p.name == name).firstOrNull;
  final Object? value = param?.value;
  if (value == null) {
    return <String>[];
  }
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  throw FormatException('Expected "$name" to be a list.');
}

Object? requireParam(List<CommandParam> params, String name) {
  return params.firstWhere((p) => p.name == name).value;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
