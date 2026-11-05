import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/user_account.dart';
import 'drawer_page.dart';

class PrivacyDataPage extends StatefulWidget implements DrawerPage {
  final UserAccount userAccount;
  final bool requireChoice;
  final Future<void> Function(bool enabled) onCloudChoice;
  final Future<void> Function() onDeleteAll;

  const PrivacyDataPage({
    super.key,
    required this.userAccount,
    required this.onCloudChoice,
    required this.onDeleteAll,
    this.requireChoice = false,
  });

  @override
  String get label => 'Privacy & Data';

  @override
  IconData get icon => Icons.privacy_tip_outlined;

  @override
  IconData get selectedIcon => Icons.privacy_tip;

  @override
  State<PrivacyDataPage> createState() => _PrivacyDataPageState();
}

class _PrivacyDataPageState extends State<PrivacyDataPage> {
  static final _deepSeekPrivacy = Uri.parse(
    'https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html',
  );
  static final _elevenLabsPrivacy =
      Uri.parse('https://elevenlabs.io/privacy-policy');
  static final _tencentPrivacy = Uri.parse(
    'https://www.tencentcloud.com/document/product/301/17345',
  );

  bool _savingChoice = false;
  bool _deleting = false;

  Future<void> _setCloudChoice(bool enabled) async {
    if (_savingChoice) return;
    setState(() => _savingChoice = true);
    try {
      await widget.onCloudChoice(enabled);
      if (!mounted || widget.requireChoice) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Cloud personalization enabled.'
                : 'Local-only meditation enabled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save the privacy choice: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingChoice = false);
    }
  }

  Future<void> _openPolicy(Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the privacy policy.')),
      );
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete meditation data?'),
        content: const Text(
          'This removes the EarStreAM profile, meditation preferences, API '
          'credentials, cloud choice, measured baseline, and weekly analytics '
          'from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || _deleting) return;

    setState(() => _deleting = true);
    try {
      await widget.onDeleteAll();
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete all meditation data: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consent = widget.userAccount.cloudProcessingConsent;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.requireChoice
              ? 'Choose how EarStreAM processes data'
              : 'Privacy & Data',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You can use meditation entirely on this device, or explicitly '
          'allow cloud personalization. You can change this choice later.',
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 20),
        _ChoiceCard(
          key: const Key('cloud-personalization-choice'),
          title: 'Cloud personalization',
          icon: Icons.cloud_outlined,
          selected: consent == true,
          description:
              'DeepSeek receives your meditation profile and preferences. In '
              'biosignal-adaptive sessions it also receives heart rate and '
              'HRV (RMSSD) readings after segments. The selected ElevenLabs '
              'or Tencent service receives the generated narration, which '
              'may contain personalized information.',
          buttonLabel: consent == true ? 'Selected' : 'Allow cloud processing',
          enabled: !_savingChoice && consent != true,
          onPressed: () => _setCloudChoice(true),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          key: const Key('local-only-choice'),
          title: 'Local only',
          icon: Icons.phonelink_lock_outlined,
          selected: consent == false,
          description:
              'Uses pre-written meditation guidance, on-device speech, and '
              'bundled ambience. No meditation profile, preferences, heart '
              'rate, HRV, or narration is sent to DeepSeek, ElevenLabs, or '
              'Tencent. Configured credentials remain stored but unused.',
          buttonLabel: consent == false ? 'Selected' : 'Use local only',
          enabled: !_savingChoice && consent != false,
          onPressed: () => _setCloudChoice(false),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What stays on this device',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your profile, preferences, cloud choice, weekly analytics, '
                  'and service configuration are stored locally. API secrets '
                  'use the operating system\'s protected credential storage. '
                  'EarStreAM does not automatically upload weekly analytics or '
                  'diagnostic traces.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Third-party services',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cloud requests are handled under each provider\'s terms and '
                  'privacy policy. Processing may occur outside your country, '
                  'and use of your own API account may incur charges.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _openPolicy(_deepSeekPrivacy),
                      child: const Text('DeepSeek policy'),
                    ),
                    TextButton(
                      onPressed: () => _openPolicy(_elevenLabsPrivacy),
                      child: const Text('ElevenLabs policy'),
                    ),
                    TextButton(
                      onPressed: () => _openPolicy(_tencentPrivacy),
                      child: const Text('Tencent policy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wellness, not medical care',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Stress detection is a research and wellness feature. It is '
                  'not a medical diagnosis and should not be used for medical '
                  'decisions or emergencies.',
                ),
              ],
            ),
          ),
        ),
        if (!widget.requireChoice) ...[
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _deleting ? null : _confirmDeleteAll,
            icon: _deleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: const Text('Delete all EarStreAM data'),
          ),
        ],
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final String description;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback onPressed;

  const _ChoiceCard({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.description,
    required this.buttonLabel,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: selected ? colors.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (selected) const Icon(Icons.check_circle),
              ],
            ),
            const SizedBox(height: 10),
            Text(description),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: enabled ? onPressed : null,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
