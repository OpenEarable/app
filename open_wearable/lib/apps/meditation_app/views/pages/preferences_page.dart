import 'package:flutter/material.dart';
import '../../configs/overall_config.dart';
import 'drawer_page.dart';
import '../../model/user_account.dart';
import '../../widgets/custom_dropdown.dart';

class PreferencesPage extends StatefulWidget implements DrawerPage {
  final UserAccount userAccount;
  final Future<void> Function()? onSaved;

  const PreferencesPage({
    super.key,
    required this.userAccount,
    this.onSaved,
  });

  @override
  String get label => "Meditation Preferences";

  @override
  IconData get icon => Icons.spa_outlined;

  @override
  IconData get selectedIcon => Icons.spa;

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _additionalPreferencesController;
  late Gender _voiceGender;
  late SpeakingSpeed _speakingSpeed;
  late MeditationType _meditationType;
  late MeditationEnvironment _meditationEnvironment;
  late double _stressThreshold;

  @override
  void initState() {
    super.initState();
    _additionalPreferencesController = TextEditingController(
      text: widget.userAccount.additionalPreferences ?? '',
    );
    _voiceGender = widget.userAccount.voiceGender ?? Gender.female;
    _speakingSpeed = widget.userAccount.speakingSpeed ?? SpeakingSpeed.slow;
    _meditationType =
        widget.userAccount.meditationType ?? MeditationType.mindfulness;
    _meditationEnvironment = widget.userAccount.meditationEnvironment ??
        MeditationEnvironment.forest;
    _stressThreshold = widget.userAccount.stressThreshold ??
        OverallMeditationConfig.defaultStressSensitivity;
  }

  @override
  void dispose() {
    _additionalPreferencesController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        widget.userAccount.voiceGender = _voiceGender;
        widget.userAccount.speakingSpeed = _speakingSpeed;
        widget.userAccount.meditationType = _meditationType;
        widget.userAccount.meditationEnvironment = _meditationEnvironment;
        widget.userAccount.additionalPreferences =
            _additionalPreferencesController.text;
        widget.userAccount.stressThreshold = _stressThreshold;
      });
      try {
        await widget.onSaved?.call();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save meditation preferences: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meditation preferences saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form before saving.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Card(
          margin: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose the meditation experience',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'These settings stay optional at startup, but they shape the generated script, ambience, and delivery once a session begins. The voice service and provider itself are managed under API Keys.',
                    style: TextStyle(color: Colors.grey[700], height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Voice Gender',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  VoiceGenderDropdown(
                    initialSelection: _voiceGender,
                    onSelected: (value) =>
                        setState(() => _voiceGender = value!),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Speaking Speed',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SpeakingSpeedDropdown(
                    initialSelection: _speakingSpeed,
                    onSelected: (value) =>
                        setState(() => _speakingSpeed = value!),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Meditation Type',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  MeditationTypeDropdown(
                    initialSelection: _meditationType,
                    onSelected: (value) =>
                        setState(() => _meditationType = value!),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Meditation Environment',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  MeditationEnvironmentDropdown(
                    initialSelection: _meditationEnvironment,
                    onSelected: (value) =>
                        setState(() => _meditationEnvironment = value!),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Additional Preferences',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _additionalPreferencesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'e.g., "Focus on gratitude" or "Include affirmations"',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Stress Detection Threshold',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How much must your heart rate increase (and HRV decrease) above baseline to be considered stressed?',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  StressThresholdDropdown(
                    initialSelection: _stressThreshold,
                    onSelected: (value) =>
                        setState(() => _stressThreshold = value!),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: _saveProfile,
                    child: const Text(
                      'Save Profile',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
