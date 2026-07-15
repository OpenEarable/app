import 'dart:convert';
import 'dart:io';

import 'package:open_earable_flutter/open_earable_flutter.dart';

typedef PullRequestTitleFetcher = Future<Map<int, String>> Function(
  Set<int> pullRequestNumbers,
);

class BetaFirmwareTitleResolver {
  final PullRequestTitleFetcher _fetchTitles;

  BetaFirmwareTitleResolver({
    PullRequestTitleFetcher? fetchTitles,
  }) : _fetchTitles = fetchTitles ?? fetchGitHubPullRequestTitles;

  Future<List<FirmwareEntry>> resolve(List<FirmwareEntry> entries) async {
    final pullRequestNumbers = <int>{
      for (final entry in entries)
        if (entry.isBeta) ...[
          if (_pullRequestNumberFor(entry.firmware) case final number?) number,
        ],
    };

    if (pullRequestNumbers.isEmpty) {
      return entries;
    }

    final titles = await _fetchTitlesSafely(pullRequestNumbers);
    if (titles.isEmpty) {
      return entries;
    }

    return [
      for (final entry in entries) _entryWithResolvedTitle(entry, titles),
    ];
  }

  Future<Map<int, String>> _fetchTitlesSafely(
    Set<int> pullRequestNumbers,
  ) async {
    try {
      return await _fetchTitles(pullRequestNumbers);
    } catch (_) {
      return const {};
    }
  }

  FirmwareEntry _entryWithResolvedTitle(
    FirmwareEntry entry,
    Map<int, String> titles,
  ) {
    if (!entry.isBeta) {
      return entry;
    }

    final pullRequestNumber = _pullRequestNumberFor(entry.firmware);
    final title = titles[pullRequestNumber]?.trim();
    if (title == null || title.isEmpty || title == entry.firmware.name) {
      return entry;
    }

    final firmware = entry.firmware;
    return FirmwareEntry(
      firmware: RemoteFirmware(
        name: title,
        version: firmware.version,
        url: firmware.url,
        type: firmware.type,
      ),
      source: entry.source,
    );
  }
}

Future<Map<int, String>> fetchGitHubPullRequestTitles(
  Set<int> pullRequestNumbers,
) async {
  if (pullRequestNumbers.isEmpty) {
    return const {};
  }

  final client = HttpClient();
  try {
    final entries = await Future.wait(
      pullRequestNumbers.map(
        (number) => _fetchGitHubPullRequestTitle(client, number),
      ),
    );
    return {
      for (final entry in entries)
        if (entry != null) entry.key: entry.value,
    };
  } finally {
    client.close(force: true);
  }
}

Future<MapEntry<int, String>?> _fetchGitHubPullRequestTitle(
  HttpClient client,
  int pullRequestNumber,
) async {
  try {
    final request = await client.getUrl(
      Uri.https(
        'api.github.com',
        '/repos/OpenEarable/open-earable-2/pulls/$pullRequestNumber',
      ),
    );
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    request.headers.set(HttpHeaders.userAgentHeader, 'OpenWearable');

    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return null;
    }

    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body) as Map<String, dynamic>;
    final title = (json['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      return null;
    }

    return MapEntry(pullRequestNumber, title);
  } catch (_) {
    return null;
  }
}

int? _pullRequestNumberFor(RemoteFirmware firmware) {
  return _pullRequestNumberFrom(firmware.version) ??
      _pullRequestNumberFrom(firmware.url) ??
      _pullRequestNumberFrom(firmware.name);
}

int? _pullRequestNumberFrom(String value) {
  final match = RegExp(
    r'(?:^|[^a-z0-9])pr\s*[-#]?\s*(\d+)(?=$|[^a-z0-9])',
    caseSensitive: false,
  ).firstMatch(value);
  return int.tryParse(match?.group(1) ?? '');
}
