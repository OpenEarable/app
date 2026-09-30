String? normalizeFirmwareVersion(String? value) {
  final cleaned = value?.replaceAll('\x00', '').trim();
  if (cleaned == null || cleaned.isEmpty) {
    return null;
  }
  return cleaned;
}

bool firmwareVersionsMatch(String? expected, String? actual) {
  final normalizedExpected = normalizeFirmwareVersion(expected);
  final normalizedActual = normalizeFirmwareVersion(actual);
  if (normalizedExpected == null || normalizedActual == null) {
    return false;
  }

  final expectedComparison = _comparisonValue(normalizedExpected);
  final actualComparison = _comparisonValue(normalizedActual);
  if (expectedComparison == actualComparison) {
    return true;
  }

  final expectedPrNumber = _extractPullRequestNumber(expectedComparison);
  final actualPrNumber = _extractPullRequestNumber(actualComparison);
  if (expectedPrNumber != null && actualPrNumber != null) {
    return expectedPrNumber == actualPrNumber;
  }

  final corePattern = RegExp(r'^\d+\.\d+\.\d+(?:\.\d+)?');
  final expectedCore = corePattern.firstMatch(expectedComparison)?.group(0);
  final actualCore = corePattern.firstMatch(actualComparison)?.group(0);
  if (expectedCore != null &&
      actualCore != null &&
      expectedCore != actualCore) {
    return false;
  }

  // A release may match its development/build suffix, never a partial number
  // such as 2.2.9 inside 2.2.90 or 12.2.9.
  bool containsVersion(String value, String version) => RegExp(
        '(^|[^0-9A-Za-z])${RegExp.escape(version)}(?=\$|[^0-9A-Za-z])',
      ).hasMatch(value);
  return containsVersion(actualComparison, expectedComparison) ||
      containsVersion(expectedComparison, actualComparison);
}

String _comparisonValue(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(RegExp(r'^v(?=\d+\.)'), '');
}

String? _extractPullRequestNumber(String value) {
  for (final pattern in _pullRequestPatterns) {
    final match = pattern.firstMatch(value);
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
}

final _pullRequestPatterns = <RegExp>[
  RegExp(r'(?:^|[^a-z0-9])pr\s*[-#]?\s*(\d+)(?=$|[^a-z0-9])'),
  RegExp(r'(?:^|[^a-z0-9])pull\s*request\s*#?\s*(\d+)(?=$|[^a-z0-9])'),
];
