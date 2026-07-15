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

  return actualComparison.contains(expectedComparison) ||
      expectedComparison.contains(actualComparison);
}

String _comparisonValue(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
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
