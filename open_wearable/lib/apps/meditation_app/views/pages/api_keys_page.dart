import 'dart:async';

import 'package:flutter/material.dart';
import '../../model/meditation_service_settings_store.dart';
import '../../model/user_account.dart';
import '../../model/service_connection_manager.dart';
import 'drawer_page.dart';
import '../../widgets/status_field.dart';
import '../../widgets/secret_field.dart';
import '../../widgets/custom_dropdown.dart';

class ApiKeysPage extends StatefulWidget implements DrawerPage {
  final UserAccount userAccount;
  final MeditationServiceSettingsStore? settingsStore;

  const ApiKeysPage({
    super.key,
    required this.userAccount,
    this.settingsStore,
  });

  @override
  String get label => "API Keys";

  @override
  IconData get icon => Icons.key_outlined;

  @override
  IconData get selectedIcon => Icons.key;

  @override
  State<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends State<ApiKeysPage> {
  late final DeepseekManager _deepseekManager;
  late final ElevenLabsManager _elevenLabsManager;
  late final TencentTtsManager _tencentManager;
  late final MeditationServiceSettingsStore _settingsStore;

  @override
  void initState() {
    super.initState();
    _settingsStore = widget.settingsStore ?? MeditationServiceSettingsStore();
    _deepseekManager = DeepseekManager(userAccount: widget.userAccount);
    _elevenLabsManager = ElevenLabsManager(userAccount: widget.userAccount);
    _tencentManager = TencentTtsManager(userAccount: widget.userAccount);
    _deepseekManager.addListener(_serviceStateChanged);
    _elevenLabsManager.addListener(_serviceStateChanged);
    _tencentManager.addListener(_serviceStateChanged);
  }

  void _serviceStateChanged() {
    if (!mounted) return;
    setState(() {});
    _saveSettings();
  }

  void _saveSettings() {
    unawaited(_settingsStore.save(widget.userAccount));
  }

  @override
  void dispose() {
    _deepseekManager.removeListener(_serviceStateChanged);
    _elevenLabsManager.removeListener(_serviceStateChanged);
    _tencentManager.removeListener(_serviceStateChanged);
    _deepseekManager.dispose();
    _elevenLabsManager.dispose();
    _tencentManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elevenLabsVoices = widget.userAccount.availableElevenLabsVoices;
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Voice & Service Configuration',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose which cloud voice service EarStreAM should use. Your '
                'selection and credentials are saved on this device; API '
                'secrets are kept in encrypted platform storage.',
                style: TextStyle(color: Colors.grey[700], height: 1.4),
              ),
              if (!widget.userAccount.allowsCloudProcessing) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.phonelink_lock_outlined),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Local-only meditation is active. Credentials can '
                          'still be stored here, but connection checks and '
                          'cloud services remain disabled until you allow '
                          'cloud processing in Privacy & Data.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'TTS Provider',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TtsProviderDropdown(
                key: ValueKey(widget.userAccount.ttsProvider),
                initialSelection: widget.userAccount.ttsProvider,
                onSelected: (value) {
                  if (value == null) return;
                  setState(() => widget.userAccount.ttsProvider = value);
                  _saveSettings();
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Default Voice',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Select whether the default voice configured in the app should be male or female.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              VoiceGenderDropdown(
                key: ValueKey(widget.userAccount.voiceGender),
                initialSelection:
                    widget.userAccount.voiceGender ?? Gender.female,
                onSelected: (value) {
                  if (value == null) return;
                  setState(() => widget.userAccount.voiceGender = value);
                  _tencentManager.markUnverified();
                },
              ),
              if (widget.userAccount.ttsProvider ==
                      TtsProviderOption.elevenLabs &&
                  widget.userAccount.hasValidElevenLabsKey &&
                  elevenLabsVoices != null &&
                  elevenLabsVoices.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'ElevenLabs Voice',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ElevenLabsVoiceDropdown(
                  key: ValueKey(widget.userAccount.elevenLabsVoiceId),
                  voices: elevenLabsVoices,
                  initialSelection: widget.userAccount.elevenLabsVoiceId,
                  onSelected: (value) {
                    setState(() {
                      widget.userAccount.elevenLabsVoiceId = value;
                    });
                    _saveSettings();
                  },
                ),
              ],
              const SizedBox(height: 24),
              StatusField(
                connectionManager: _deepseekManager,
                neighbourWidget: SecretField(
                  title: "Deepseek API Key",
                  description:
                      "Provide a Deepseek API key to enable personalized session generation. It is saved securely on this device.",
                  onChanged: (value) {
                    widget.userAccount.deepseekApiKey = value;
                    _deepseekManager.markUnverified();
                  },
                  initialValue: widget.userAccount.deepseekApiKey ?? '',
                ),
              ),
              const SizedBox(height: 24),
              StatusField(
                connectionManager: _elevenLabsManager,
                neighbourWidget: SecretField(
                  title: "ElevenLabs API Key",
                  description:
                      "Provide an ElevenLabs API key to enable voice synthesis. It is saved securely on this device.",
                  onChanged: (value) {
                    widget.userAccount.elevenLabsApiKey = value;
                    _elevenLabsManager.markUnverified();
                  },
                  initialValue: widget.userAccount.elevenLabsApiKey ?? '',
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Tencent processing region',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TencentTtsRegionDropdown(
                key: ValueKey(widget.userAccount.tencentTtsRegion),
                initialSelection: widget.userAccount.tencentTtsRegion,
                onSelected: (value) {
                  if (value == null) return;
                  setState(() {
                    widget.userAccount.tencentTtsRegion = value;
                  });
                  _tencentManager.markUnverified();
                },
              ),
              const SizedBox(height: 8),
              Text(
                widget.userAccount.tencentTtsRegion ==
                        TencentTtsRegion.internationalSingapore
                    ? 'Uses Tencent Cloud International with TTS processing in Singapore. Select this for international accounts and EU demos.'
                    : 'Uses Tencent Cloud mainland with TTS processing in Guangzhou. This requires TTS activated on a mainland China account.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SecretField(
                title: 'Tencent SecretId',
                description:
                    'Enter the SecretId from the Tencent Cloud API key pair.',
                onChanged: (value) {
                  widget.userAccount.tencentSecretId = value;
                  _tencentManager.markUnverified();
                },
                initialValue: widget.userAccount.tencentSecretId ?? '',
              ),
              const SizedBox(height: 12),
              StatusField(
                connectionManager: _tencentManager,
                neighbourWidget: SecretField(
                  title: 'Tencent SecretKey',
                  description:
                      'Enter the SecretKey paired with the Tencent SecretId.',
                  onChanged: (value) {
                    widget.userAccount.tencentSecretKey = value;
                    _tencentManager.markUnverified();
                  },
                  initialValue: widget.userAccount.tencentSecretKey ?? '',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
