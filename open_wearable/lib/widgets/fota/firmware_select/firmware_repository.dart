import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum FirmwareSource { stable, beta }

class FirmwareEntry {
  final RemoteFirmware firmware;
  final FirmwareSource source;

  FirmwareEntry({
    required this.firmware,
    required this.source,
  });

  bool get isBeta => source == FirmwareSource.beta;
  bool get isStable => source == FirmwareSource.stable;
}

class UnifiedFirmwareRepository {
  final FirmwareImageRepository _stableRepository = FirmwareImageRepository();

  List<FirmwareEntry>? _cachedStable;
  List<FirmwareEntry>? _cachedBeta;
  DateTime? _lastFetchTime;

  static const _cacheDuration = Duration(minutes: 15);

  /// Fetch stable releases
  Future<List<FirmwareEntry>> getStableFirmwares({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedStable != null && !_isCacheExpired()) {
      return _cachedStable!;
    }

    final firmwares = await _stableRepository.getFirmwareImages();
    _cachedStable = firmwares
        .map(
          (fw) => FirmwareEntry(
            firmware: fw,
            source: FirmwareSource.stable,
          ),
        )
        .toList();
    _lastFetchTime = DateTime.now();
    return _cachedStable!;
  }

  /// Fetch beta (PR build) releases
  Future<List<FirmwareEntry>> getBetaFirmwares({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedBeta != null && !_isCacheExpired()) {
      return _cachedBeta!;
    }

    //TODO: change to OpenEarable repo when available
    const owner = 'o-bagge';

    const repo = 'open-earable-2';
    const prereleaseTag = 'pr-builds';

    try {
      final releaseResponse = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$owner/$repo/releases/tags/$prereleaseTag',
        ),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (releaseResponse.statusCode != 200) {
        return [];
      }

      final releaseJson =
          jsonDecode(releaseResponse.body) as Map<String, dynamic>;
      final assets =
          (releaseJson['assets'] as List<dynamic>).cast<Map<String, dynamic>>();

      final fotaAssets = assets.where((asset) {
        final name = asset['name'] as String? ?? '';
        return name.endsWith('fota.zip');
      }).toList();

      final Map<int, Map<String, dynamic>> prMap = {};

      for (final asset in fotaAssets) {
        final name = asset['name'] as String;
        final match = RegExp(r'^pr-(\d+)-(.+?)-openearable_v2_fota\.zip$')
            .firstMatch(name);

        if (match != null) {
          final prNumber = int.parse(match.group(1)!);
          final prTitle = match.group(2)!.replaceAll('_', ' ');

          prMap[prNumber] = {
            'asset': asset,
            'title': prTitle,
            'prNumber': prNumber,
          };
        }
      }

      final result = <FirmwareEntry>[];

      for (final entry in prMap.entries) {
        final prNumber = entry.key;
        final assetData = entry.value;

        //Commented out because GitHub API rate limits are exceeded quickly
        /*
        final prResponse = await http.get(
          Uri.parse(
              'https://api.github.com/repos/$owner/$repo/pulls/$prNumber'),
          headers: {'Accept': 'application/vnd.github.v3+json'},
        );

        if (prResponse.statusCode == 200) {
          final prJson = jsonDecode(prResponse.body) as Map<String, dynamic>;
          final prTitle = prJson['title'] as String;
          final prSha = prJson['head']['sha'] as String;
          final asset = assetData['asset'] as Map<String, dynamic>;

          result.add(FirmwareEntry(
            firmware: RemoteFirmware(
              name: prTitle,
              url: asset['browser_download_url'] as String,
              version: prSha.substring(0, 7),
              type: FirmwareType.multiImage,
            ),
            source: FirmwareSource.beta,
          ));
        } else {
          */
        final asset = assetData['asset'] as Map<String, dynamic>;
        result.add(
          FirmwareEntry(
            firmware: RemoteFirmware(
              name: assetData['title']
                  as String, // Already sanitized from filename
              url: asset['browser_download_url'] as String,
              version: 'PR #$prNumber',
              type: FirmwareType.multiImage,
            ),
            source: FirmwareSource.beta,
          ),
        );
      }

      result.sort((a, b) {
        final aNum =
            int.tryParse(a.firmware.version.replaceAll(RegExp(r'[^\d]'), '')) ??
                0;
        final bNum =
            int.tryParse(b.firmware.version.replaceAll(RegExp(r'[^\d]'), '')) ??
                0;
        return bNum.compareTo(aNum);
      });

      _cachedBeta = result;
      return _cachedBeta!;
    } catch (e) {
      print('Error fetching beta firmwares: $e');
      return [];
    }
  }

  bool _isCacheExpired() {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > _cacheDuration;
  }

  /// Fetch all firmwares (stable + beta)
  Future<List<FirmwareEntry>> getAllFirmwares({
    bool includeBeta = false,
  }) async {
    final stable = await getStableFirmwares();
    if (!includeBeta) {
      return stable;
    }
    final beta = await getBetaFirmwares();
    return [...stable, ...beta];
  }

  void clearCache() {
    _cachedStable = null;
    _cachedBeta = null;
    _lastFetchTime = null;
  }
}
