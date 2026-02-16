import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/apps/posture_tracker/view_model/posture_tracker_view_model.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:provider/provider.dart';

class SettingsView extends StatefulWidget {
  final PostureTrackerViewModel _viewModel;

  const SettingsView(this._viewModel, {super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _rollAngleThresholdController;
  late final TextEditingController _pitchAngleThresholdController;
  late final TextEditingController _badPostureTimeThresholdController;
  late final TextEditingController _goodPostureTimeThresholdController;

  late final PostureTrackerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget._viewModel;
    _rollAngleThresholdController = TextEditingController(
      text: _viewModel.badPostureSettings.rollAngleThreshold.toString(),
    );
    _pitchAngleThresholdController = TextEditingController(
      text: _viewModel.badPostureSettings.pitchAngleThreshold.toString(),
    );
    _badPostureTimeThresholdController = TextEditingController(
      text: _viewModel.badPostureSettings.timeThreshold.toString(),
    );
    _goodPostureTimeThresholdController = TextEditingController(
      text: _viewModel.badPostureSettings.resetTimeThreshold.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(title: const Text('Posture Tracker Settings')),
      body: ChangeNotifierProvider<PostureTrackerViewModel>.value(
        value: _viewModel,
        builder: (context, child) => Consumer<PostureTrackerViewModel>(
          builder: (context, postureTrackerViewModel, child) =>
              _buildSettingsView(context, postureTrackerViewModel),
        ),
      ),
    );
  }

  Widget _buildSettingsView(
    BuildContext context,
    PostureTrackerViewModel postureTrackerViewModel,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = !postureTrackerViewModel.isAvailable
        ? colorScheme.error
        : postureTrackerViewModel.isTracking
            ? const Color(0xFF2F8F5B)
            : colorScheme.primary;
    final statusLabel = postureTrackerViewModel.isTracking
        ? 'Tracking'
        : postureTrackerViewModel.isAvailable
            ? 'Ready'
            : 'Unavailable';

    return ListView(
      padding: SensorPageSpacing.pagePadding,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tracker status',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Adjust reminder thresholds and calibrate your posture baseline.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _SettingsStatusChip(label: statusLabel, color: statusColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: SensorPageSpacing.sectionGap),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bad Posture Reminder',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    PlatformSwitch(
                      value:
                          postureTrackerViewModel.badPostureSettings.isActive,
                      onChanged: (value) {
                        final settings = _viewModel.badPostureSettings;
                        settings.isActive = value;
                        _viewModel.setBadPostureSettings(settings);
                      },
                    ),
                  ],
                ),
                if (postureTrackerViewModel.badPostureSettings.isActive) ...[
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    thickness: 0.6,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 10),
                  _buildNumericSettingRow(
                    context: context,
                    label: 'Roll angle threshold',
                    controller: _rollAngleThresholdController,
                    suffix: '°',
                  ),
                  const SizedBox(height: 8),
                  _buildNumericSettingRow(
                    context: context,
                    label: 'Pitch angle threshold',
                    controller: _pitchAngleThresholdController,
                    suffix: '°',
                  ),
                  const SizedBox(height: 8),
                  _buildNumericSettingRow(
                    context: context,
                    label: 'Bad posture time threshold',
                    controller: _badPostureTimeThresholdController,
                    suffix: 's',
                  ),
                  const SizedBox(height: 8),
                  _buildNumericSettingRow(
                    context: context,
                    label: 'Good posture reset threshold',
                    controller: _goodPostureTimeThresholdController,
                    suffix: 's',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: SensorPageSpacing.sectionGap),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calibration',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  postureTrackerViewModel.isTracking
                      ? 'Use your current head position as the neutral posture reference.'
                      : 'Start tracking to calibrate your neutral posture reference.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: PlatformElevatedButton(
                    onPressed: postureTrackerViewModel.isTracking
                        ? _calibrateAndClose
                        : postureTrackerViewModel.isAvailable
                            ? postureTrackerViewModel.startTracking
                            : null,
                    child: Text(
                      postureTrackerViewModel.isTracking
                          ? 'Calibrate as Main Posture'
                          : 'Start Tracking',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumericSettingRow({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required String suffix,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.end,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              _updatePostureSettings();
            },
            decoration: InputDecoration(
              isDense: true,
              suffixText: suffix,
            ),
          ),
        ),
      ],
    );
  }

  void _calibrateAndClose() {
    _viewModel.calibrate();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _updatePostureSettings() {
    final rollAngleThreshold =
        int.tryParse(_rollAngleThresholdController.text.trim());
    final pitchAngleThreshold =
        int.tryParse(_pitchAngleThresholdController.text.trim());
    final badPostureTimeThreshold =
        int.tryParse(_badPostureTimeThresholdController.text.trim());
    final goodPostureTimeThreshold =
        int.tryParse(_goodPostureTimeThresholdController.text.trim());

    if (rollAngleThreshold == null ||
        pitchAngleThreshold == null ||
        badPostureTimeThreshold == null ||
        goodPostureTimeThreshold == null) {
      return;
    }

    if (rollAngleThreshold < 0 ||
        pitchAngleThreshold < 0 ||
        badPostureTimeThreshold < 0 ||
        goodPostureTimeThreshold < 0) {
      return;
    }

    final settings = _viewModel.badPostureSettings;
    settings.rollAngleThreshold = rollAngleThreshold;
    settings.pitchAngleThreshold = pitchAngleThreshold;
    settings.timeThreshold = badPostureTimeThreshold;
    settings.resetTimeThreshold = goodPostureTimeThreshold;
    _viewModel.setBadPostureSettings(settings);
  }

  @override
  void dispose() {
    _rollAngleThresholdController.dispose();
    _pitchAngleThresholdController.dispose();
    _badPostureTimeThresholdController.dispose();
    _goodPostureTimeThresholdController.dispose();
    super.dispose();
  }
}

class _SettingsStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SettingsStatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
