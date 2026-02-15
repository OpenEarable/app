import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/widgets/app_toast.dart';
import 'package:provider/provider.dart';

import '../../../models/logger.dart';
import '../../../view_models/sensor_configuration_provider.dart';
import '../../../view_models/sensor_configuration_storage.dart';

class SaveConfigRow extends StatefulWidget {
  final String storageScope;
  final String? defaultName;
  final VoidCallback? onSaved;

  const SaveConfigRow({
    super.key,
    required this.storageScope,
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

    setState(() {
      _isSaving = true;
    });

    try {
      final SensorConfigurationProvider provider =
          Provider.of<SensorConfigurationProvider>(context, listen: false);
      final Map<String, String> config = provider.toJson();
      final String storageKey = SensorConfigurationStorage.buildScopedKey(
        scope: widget.storageScope,
        name: profileName,
      );

      final existingKeys =
          await SensorConfigurationStorage.listConfigurationKeys();
      if (existingKeys.contains(storageKey)) {
        final shouldOverwrite = await _confirmOverwrite(profileName);
        if (!shouldOverwrite) return;
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
          'A profile named "$profileName" already exists for this device.',
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
