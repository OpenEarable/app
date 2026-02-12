import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:provider/provider.dart';

import '../../../models/logger.dart';
import '../../../view_models/sensor_configuration_provider.dart';
import '../../../view_models/sensor_configuration_storage.dart';

class SaveConfigRow extends StatefulWidget {
  final String storageScope;
  final String? uniqueNameScope;
  final Set<String> reservedProfileNames;
  final Map<String, Map<String, String>> reservedProfilesByName;
  final String? defaultName;
  final VoidCallback? onSaved;

  const SaveConfigRow({
    super.key,
    required this.storageScope,
    this.uniqueNameScope,
    this.reservedProfileNames = const <String>{},
    this.reservedProfilesByName = const <String, Map<String, String>>{},
    this.defaultName,
    this.onSaved,
  });

  @override
  State<SaveConfigRow> createState() => _SaveConfigRowState();
}

class _SaveConfigRowState extends State<SaveConfigRow> {
  String _configName = '';
  bool _isSaving = false;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _configName = widget.defaultName?.trim() ?? '';
    _nameController = TextEditingController(text: _configName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PlatformTextField(
                  controller: _nameController,
                  onChanged: (value) {
                    setState(() {
                      _configName = value;
                    });
                  },
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  hintText: 'Profile name',
                ),
              ),
              const SizedBox(width: 12),
              _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : PlatformElevatedButton(
                      onPressed: _saveConfiguration,
                      child: const Text('Save Profile'),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Save current settings as a reusable profile for this device.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _saveConfiguration() async {
    final String profileName = _configName.trim();
    if (profileName.isEmpty) {
      await _showInfoDialog(
        title: 'Profile name required',
        message: 'Enter a profile name before saving.',
      );
      return;
    }
    if (_isReservedProfileName(profileName)) {
      await _showInfoDialog(
        title: 'Reserved profile name',
        message: '"$profileName" is reserved and cannot be overwritten.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final SensorConfigurationProvider provider =
          Provider.of<SensorConfigurationProvider>(context, listen: false);
      final Map<String, String> config = provider.toJson();

      final reservedDuplicate = _findReservedDuplicateSettingsProfile(
        currentConfig: config,
        profileName: profileName,
      );
      if (reservedDuplicate != null) {
        await _showInfoDialog(
          title: 'Profile already exists',
          message:
              'These settings already exist as "$reservedDuplicate". This built-in profile cannot be renamed or overwritten.',
        );
        return;
      }

      final duplicateSettingsMatch = await _findStoredDuplicateSettingsProfile(
        currentConfig: config,
        profileName: profileName,
      );
      if (duplicateSettingsMatch != null) {
        final action = await _showDuplicateSettingsDialog(
          existingProfileName: duplicateSettingsMatch.displayName,
          requestedProfileName: profileName,
        );
        if (action != _DuplicateSettingsAction.renameExisting) {
          return;
        }

        final renamed = await _renameDuplicateProfileToRequestedName(
          duplicateSettingsMatch: duplicateSettingsMatch,
          requestedProfileName: profileName,
          config: config,
        );
        if (!renamed || !mounted) {
          return;
        }
        FocusScope.of(context).unfocus();
        _showToast(
          'Renamed profile "${duplicateSettingsMatch.displayName}" to "$profileName".',
        );
        widget.onSaved?.call();
        return;
      }

      final String storageKey = SensorConfigurationStorage.buildScopedKey(
        scope: widget.storageScope,
        name: profileName,
      );

      final existingKeys =
          await SensorConfigurationStorage.listConfigurationKeys();
      final conflictingKeys = _collectConflictingKeys(
        existingKeys: existingKeys,
        storageKey: storageKey,
        profileName: profileName,
      );
      if (conflictingKeys.isNotEmpty) {
        final shouldOverwrite = await _confirmOverwrite(profileName);
        if (!shouldOverwrite) return;
        for (final conflictKey in conflictingKeys) {
          if (conflictKey == storageKey) {
            continue;
          }
          await SensorConfigurationStorage.deleteConfiguration(conflictKey);
        }
      }

      logger.d('Saving sensor profile "$profileName" to "$storageKey".');
      await SensorConfigurationStorage.saveConfiguration(storageKey, config);

      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _showToast('Saved profile "$profileName".');
      widget.onSaved?.call();
    } catch (e) {
      logger.e('Failed to save sensor profile: $e');
      if (!mounted) return;
      await _showInfoDialog(
        title: 'Save failed',
        message: 'Could not save this profile. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _confirmOverwrite(String profileName) async {
    final bool? confirmed = await showPlatformDialog<bool>(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: const Text('Overwrite profile?'),
        content: Text(
          'A profile named "$profileName" already exists for this device name.',
        ),
        actions: [
          PlatformDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PlatformDialogAction(
            child: const Text('Overwrite'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<_DuplicateSettingsAction> _showDuplicateSettingsDialog({
    required String existingProfileName,
    required String requestedProfileName,
  }) async {
    final action = await showPlatformDialog<_DuplicateSettingsAction>(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: const Text('Profile already exists'),
        content: Text(
          'A profile named "$existingProfileName" already uses these settings. Rename that existing profile to "$requestedProfileName", or cancel.',
        ),
        actions: [
          PlatformDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext)
                .pop(_DuplicateSettingsAction.cancel),
          ),
          PlatformDialogAction(
            child: const Text('Change name'),
            onPressed: () => Navigator.of(dialogContext).pop(
              _DuplicateSettingsAction.renameExisting,
            ),
          ),
        ],
      ),
    );

    return action ?? _DuplicateSettingsAction.cancel;
  }

  Future<bool> _renameDuplicateProfileToRequestedName({
    required _StoredProfileMatch duplicateSettingsMatch,
    required String requestedProfileName,
    required Map<String, String> config,
  }) async {
    final targetKey = SensorConfigurationStorage.buildScopedKey(
      scope: widget.storageScope,
      name: requestedProfileName,
    );
    final existingKeys =
        await SensorConfigurationStorage.listConfigurationKeys();
    final conflictingKeys = _collectConflictingKeys(
      existingKeys: existingKeys,
      storageKey: targetKey,
      profileName: requestedProfileName,
    );
    final conflictingWithoutSource = conflictingKeys
        .where((key) => key != duplicateSettingsMatch.key)
        .toList(growable: false);
    if (conflictingWithoutSource.isNotEmpty) {
      final shouldOverwrite = await _confirmOverwrite(requestedProfileName);
      if (!shouldOverwrite) {
        return false;
      }
      for (final key in conflictingWithoutSource) {
        await SensorConfigurationStorage.deleteConfiguration(key);
      }
    }

    await SensorConfigurationStorage.saveConfiguration(targetKey, config);
    if (duplicateSettingsMatch.key != targetKey) {
      await SensorConfigurationStorage.deleteConfiguration(
        duplicateSettingsMatch.key,
      );
    }
    return true;
  }

  List<String> _collectConflictingKeys({
    required List<String> existingKeys,
    required String storageKey,
    required String profileName,
  }) {
    final conflicts = <String>{storageKey};
    final sanitizedProfileName = SensorConfigurationStorage.sanitizeKey(
      profileName,
    );
    final normalizedSanitizedProfileName = sanitizedProfileName.toLowerCase();

    final uniqueNameScope = widget.uniqueNameScope?.trim();
    if (uniqueNameScope != null && uniqueNameScope.isNotEmpty) {
      conflicts.addAll(
        existingKeys.where(
          (key) => _isScopedNameConflict(
            key: key,
            uniqueNameScope: uniqueNameScope,
            sanitizedProfileName: sanitizedProfileName,
          ),
        ),
      );
    }

    conflicts.addAll(
      existingKeys.where(
        (key) =>
            SensorConfigurationStorage.isLegacyUnscopedKey(key) &&
            SensorConfigurationStorage.sanitizeKey(key).toLowerCase() ==
                normalizedSanitizedProfileName,
      ),
    );

    return conflicts.where(existingKeys.contains).toList(growable: false);
  }

  String? _findReservedDuplicateSettingsProfile({
    required Map<String, String> currentConfig,
    required String profileName,
  }) {
    final normalizedName = _normalizeProfileName(profileName);
    for (final entry in widget.reservedProfilesByName.entries) {
      if (_normalizeProfileName(entry.key) == normalizedName) {
        continue;
      }
      if (_mapsEqual(entry.value, currentConfig)) {
        return entry.key;
      }
    }
    return null;
  }

  Future<_StoredProfileMatch?> _findStoredDuplicateSettingsProfile({
    required Map<String, String> currentConfig,
    required String profileName,
  }) async {
    final existingKeys =
        await SensorConfigurationStorage.listConfigurationKeys();
    final normalizedName = _normalizeProfileName(profileName);
    final keysToCheck = _keysInNameFamilyOrLegacy(existingKeys);
    for (final key in keysToCheck) {
      final existingName = _profileNameFromKey(key);
      if (_normalizeProfileName(existingName) == normalizedName) {
        continue;
      }
      final savedConfig =
          await SensorConfigurationStorage.loadConfiguration(key);
      if (_mapsEqual(savedConfig, currentConfig)) {
        return _StoredProfileMatch(
          key: key,
          displayName: existingName,
        );
      }
    }
    return null;
  }

  Iterable<String> _keysInNameFamilyOrLegacy(List<String> existingKeys) {
    final uniqueNameScope = widget.uniqueNameScope?.trim();
    final nameFamilyPrefix = uniqueNameScope == null || uniqueNameScope.isEmpty
        ? null
        : SensorConfigurationStorage.scopedPrefix(uniqueNameScope);
    return existingKeys.where((key) {
      if (SensorConfigurationStorage.isLegacyUnscopedKey(key)) {
        return true;
      }
      if (nameFamilyPrefix == null) {
        return false;
      }
      return key.startsWith(nameFamilyPrefix);
    });
  }

  String _profileNameFromKey(String key) {
    if (SensorConfigurationStorage.isLegacyUnscopedKey(key)) {
      return key.replaceAll('_', ' ');
    }
    final lastSeparatorIndex = key.lastIndexOf('__');
    if (lastSeparatorIndex < 0 || lastSeparatorIndex + 2 >= key.length) {
      return key.replaceAll('_', ' ');
    }
    return key.substring(lastSeparatorIndex + 2).replaceAll('_', ' ');
  }

  String _normalizeProfileName(String value) => value.trim().toLowerCase();

  bool _mapsEqual(Map<String, String> left, Map<String, String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  bool _isScopedNameConflict({
    required String key,
    required String uniqueNameScope,
    required String sanitizedProfileName,
  }) {
    if (!SensorConfigurationStorage.keyMatchesScope(key, uniqueNameScope)) {
      return false;
    }
    if (key ==
        SensorConfigurationStorage.buildScopedKey(
          scope: uniqueNameScope,
          name: sanitizedProfileName,
        )) {
      return true;
    }

    final prefix = SensorConfigurationStorage.scopedPrefix(uniqueNameScope);
    if (!key.startsWith(prefix)) {
      return false;
    }
    final remainder = key.substring(prefix.length);
    if (!remainder.startsWith('fw_')) {
      return false;
    }
    return remainder.endsWith('__$sanitizedProfileName');
  }

  bool _isReservedProfileName(String profileName) {
    final normalized = _normalizeProfileName(profileName);
    if (normalized.isEmpty) {
      return false;
    }
    return widget.reservedProfileNames.any(
      (name) => _normalizeProfileName(name) == normalized,
    );
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
  }) async {
    await showPlatformDialog<void>(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          PlatformDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    AppToast.show(
      context,
      message: message,
      type: AppToastType.success,
      icon: Icons.check_circle_outline_rounded,
    );
  }
}

enum _DuplicateSettingsAction {
  cancel,
  renameExisting,
}

class _StoredProfileMatch {
  final String key;
  final String displayName;

  const _StoredProfileMatch({
    required this.key,
    required this.displayName,
  });
}
