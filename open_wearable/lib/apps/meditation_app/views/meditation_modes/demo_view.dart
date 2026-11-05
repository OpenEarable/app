import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import '../../configs/demo_mode_config.dart';
import '../../model/user_account.dart';
import '../../model/wearable_connection.dart';
import '../../model/meditation.dart';
import '../../model/bio_adaptive_session_config.dart';
import '../../model/meditation_prompt_policy.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/meditation_tile.dart';
import '../../widgets/api_warning.dart';
import 'bio_adaptive_view.dart' show BioAdaptiveView;
import 'package:provider/provider.dart';

enum Step {
  settings,
  meditation,
}

enum DemoMode {
  biosignalAdaptive(steps: [Step.settings, Step.meditation]),
  personalizedOnly(steps: [Step.settings, Step.meditation]);

  final List<Step> steps;

  const DemoMode({required this.steps});
}

abstract class DemoStepView extends StatefulWidget {
  final UserAccount userAccount;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const DemoStepView({
    super.key,
    required this.userAccount,
    required this.onBack,
    required this.onContinue,
  });
}

class DemoView extends StatefulWidget {
  final Sensor ppgSensor;
  final Sensor accelerometerSensor;
  final Sensor gyroscopeSensor;
  final SensorConfigurationProvider sensorConfigProvider;

  const DemoView({
    super.key,
    required this.ppgSensor,
    required this.accelerometerSensor,
    required this.gyroscopeSensor,
    required this.sensorConfigProvider,
  });

  @override
  State<DemoView> createState() => _DemoViewState();
}

class _DemoViewState extends State<DemoView> {
  DemoMode? _selectedMode;
  int _currentStepIndex = 0;
  late UserAccount _demoAccount;
  bool _hasDemoAccount = false;
  final ValueNotifier<Meditation?> _personalizedMeditation =
      ValueNotifier(null);

  List<Step> get _steps => _selectedMode!.steps;
  Step get _currentStep => _steps[_currentStepIndex];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasDemoAccount) {
      _createFreshDemoAccount();
      _hasDemoAccount = true;
    }
  }

  void _createFreshDemoAccount() {
    _demoAccount = UserAccount.forConferenceDemo(
      serviceConfiguration: context.read<UserAccount>(),
    );
  }

  void _selectMode(DemoMode mode) {
    // Both demo experiences speak through the earbud, and the biosignal one
    // also measures with it. Starting an attendee on either without it
    // connected leaves them waiting on something that cannot arrive.
    if (!context.read<WearableConnection>().isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The demo needs the OpenEarable connected. Reconnect it, then '
            'choose a mode again.',
          ),
        ),
      );
      return;
    }
    _discardPersonalizedMeditation();
    _createFreshDemoAccount();
    setState(() {
      _selectedMode = mode;
      _currentStepIndex = 0;
    });
  }

  void _continue() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _startPersonalizedMeditationIfNeeded();
    }
  }

  void _back() {
    if (_currentStep == Step.meditation) {
      _discardPersonalizedMeditation();
    }
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
    } else {
      setState(() {
        _selectedMode = null;
      });
    }
  }

  void _finish() {
    _discardPersonalizedMeditation();
    _createFreshDemoAccount();
    setState(() {
      _selectedMode = null;
      _currentStepIndex = 0;
    });
  }

  @override
  void dispose() {
    _discardPersonalizedMeditation();
    _personalizedMeditation.dispose();
    super.dispose();
  }

  void _startPersonalizedMeditationIfNeeded() {
    if (_selectedMode != DemoMode.personalizedOnly ||
        _currentStep != Step.meditation ||
        _personalizedMeditation.value != null) {
      return;
    }

    final meditation = Meditation(
      userAccount: _demoAccount,
      maxSegments: DemoModeConfig.meditationOnlySegmentCount,
      meditationSegmentDuration: DemoModeConfig.meditationOnlySegmentDuration,
      promptPolicy: MeditationPromptPolicy.conferenceDemo,
    );
    _personalizedMeditation.value = meditation;
    unawaited(meditation.start());
  }

  void _discardPersonalizedMeditation() {
    final meditation = _personalizedMeditation.value;
    if (meditation == null) return;
    _personalizedMeditation.value = null;
    unawaited(meditation.stop().whenComplete(meditation.dispose));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _selectedMode == null
            ? DemoSelection(onSelectMode: _selectMode)
            : _stepContent(),
      ),
    );
  }

  Widget _stepContent() {
    switch (_currentStep) {
      case Step.settings:
        return SettingsView(
          userAccount: _demoAccount,
          onBack: _back,
          onContinue: _continue,
        );
      case Step.meditation:
        if (_selectedMode == DemoMode.biosignalAdaptive) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BioAdaptiveView(
                ppgSensor: widget.ppgSensor,
                accelerometerSensor: widget.accelerometerSensor,
                gyroscopeSensor: widget.gyroscopeSensor,
                sensorConfigProvider: widget.sensorConfigProvider,
                userAccount: _demoAccount,
                sessionConfig: BioAdaptiveSessionConfig.conferenceDemo,
                // One pass through the demo: rating the session ends it,
                // matching the meditation-only mode.
                onMeditationAcknowledged: _finish,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _finish,
                child: const Text('End Demo'),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              MeditationTile(
                meditationNotifier: _personalizedMeditation,
                onMeditationComplete: (_) => _finish(),
              ),
              if (!_demoAccount.hasValidDeepseekKey) ...[
                const SizedBox(height: 16),
                APIWarning(serviceName: "Deepseek"),
              ],
              if (!_demoAccount.hasValidSelectedTtsProvider) ...[
                const SizedBox(height: 16),
                APIWarning(
                  serviceName: _demoAccount.ttsProvider.label,
                ),
              ],
            ],
          );
        }
    }
  }
}

class DemoSelection extends StatelessWidget {
  final Function(DemoMode) onSelectMode;

  const DemoSelection({super.key, required this.onSelectMode});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                "lib/apps/meditation_app/assets/ubicomp_logo.png",
                width: 40,
                height: 40,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "ACM UbiComp 2026 Demo",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        Text(
          "Welcome to EarStream! This demo lets you experience a closed-loop earable system for stress-adaptive meditation. Please choose between two demo modes to start your experience.",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => onSelectMode(DemoMode.biosignalAdaptive),
            icon: const Icon(Icons.monitor_heart_outlined),
            label: const Text('Biosignal-Adaptive Demo'),
            style: ElevatedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => onSelectMode(DemoMode.personalizedOnly),
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Personalized Meditation Only'),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DemoNavBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final bool canContinue;

  const DemoNavBar({
    super.key,
    required this.onBack,
    required this.onContinue,
    this.canContinue = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton(
          onPressed: onBack,
          child: const Text('Back'),
        ),
        ElevatedButton(
          onPressed: canContinue ? onContinue : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class SettingsView extends DemoStepView {
  const SettingsView({
    super.key,
    required super.userAccount,
    required super.onBack,
    required super.onContinue,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _random = Random();

  late Gender _voiceGender;
  late SpeakingSpeed _speakingSpeed;
  late MeditationType _meditationType;
  late MeditationEnvironment _meditationEnvironment;

  @override
  void initState() {
    super.initState();
    _voiceGender = widget.userAccount.voiceGender ?? Gender.female;
    _speakingSpeed = widget.userAccount.speakingSpeed ?? SpeakingSpeed.slow;
    _meditationType =
        widget.userAccount.meditationType ?? MeditationType.mindfulness;
    _meditationEnvironment = widget.userAccount.meditationEnvironment ??
        MeditationEnvironment.forest;
  }

  T _randomEntry<T>(List<DropdownMenuEntry<T>> entries) =>
      entries[_random.nextInt(entries.length)].value;

  void _randomiseSelection() {
    setState(() {
      _voiceGender = _randomEntry(voiceGenderOptions);
      _speakingSpeed = _randomEntry(speakingSpeedOptions);
      _meditationType = _randomEntry(meditationTypeOptions);
      _meditationEnvironment = _randomEntry(meditationEnvironmentOptions);
    });
  }

  void _savePreferences() {
    widget.userAccount.voiceGender = _voiceGender;
    widget.userAccount.speakingSpeed = _speakingSpeed;
    widget.userAccount.meditationType = _meditationType;
    widget.userAccount.meditationEnvironment = _meditationEnvironment;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.spa_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Meditation Preferences',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Please put in your preferences for your upcoming personalized meditation.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _randomiseSelection,
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Surprise me'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Voice Gender',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          VoiceGenderDropdown(
            key: ValueKey(_voiceGender),
            initialSelection: _voiceGender,
            onSelected: (value) {
              if (value != null) setState(() => _voiceGender = value);
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Speaking Speed',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SpeakingSpeedDropdown(
            key: ValueKey(_speakingSpeed),
            initialSelection: _speakingSpeed,
            onSelected: (value) {
              if (value != null) setState(() => _speakingSpeed = value);
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Meditation Type',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          MeditationTypeDropdown(
            key: ValueKey(_meditationType),
            initialSelection: _meditationType,
            onSelected: (value) {
              if (value != null) setState(() => _meditationType = value);
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Meditation Environment',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          MeditationEnvironmentDropdown(
            key: ValueKey(_meditationEnvironment),
            initialSelection: _meditationEnvironment,
            onSelected: (value) {
              if (value != null) {
                setState(() => _meditationEnvironment = value);
              }
            },
          ),
          const SizedBox(height: 24),
          DemoNavBar(
            onBack: () {
              _savePreferences();
              widget.onBack();
            },
            onContinue: () {
              _savePreferences();
              widget.onContinue();
            },
          ),
        ],
      ),
    );
  }
}
