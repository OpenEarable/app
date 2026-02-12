import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_wearable/apps/posture_tracker/model/bad_posture_reminder.dart';
import 'package:open_wearable/apps/posture_tracker/view/posture_roll_view.dart';
import 'package:open_wearable/apps/posture_tracker/view/settings_view.dart';
import 'package:open_wearable/apps/posture_tracker/view_model/posture_tracker_view_model.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:provider/provider.dart';

class PostureTrackerView extends StatefulWidget {
  final AttitudeTracker _tracker;

  const PostureTrackerView(this._tracker, {super.key});

  @override
  State<PostureTrackerView> createState() => _PostureTrackerViewState();
}

class _PostureTrackerViewState extends State<PostureTrackerView> {
  static const Color _goodPostureColor = Color(0xFF2F8F5B);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PostureTrackerViewModel>(
      create: (context) => PostureTrackerViewModel(
        widget._tracker,
        BadPostureReminder(attitudeTracker: widget._tracker),
      ),
      builder: (context, child) => Consumer<PostureTrackerViewModel>(
        builder: (context, postureTrackerViewModel, child) => PlatformScaffold(
          appBar: PlatformAppBar(
            title: const Text('Posture Tracker'),
            trailingActions: [
              PlatformIconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    platformPageRoute<void>(
                      context: context,
                      builder: (context) =>
                          SettingsView(postureTrackerViewModel),
                    ),
                  );
                },
              ),
            ],
          ),
          body: _buildContentView(context, postureTrackerViewModel),
        ),
      ),
    );
  }

  Widget _buildContentView(
    BuildContext context,
    PostureTrackerViewModel postureTrackerViewModel,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isGoodPosture = _isGoodPosture(postureTrackerViewModel);
    final status = _trackingStatus(
      isAvailable: postureTrackerViewModel.isAvailable,
      isTracking: postureTrackerViewModel.isTracking,
      isGoodPosture: isGoodPosture,
    );
    final rollWithinThreshold = _isWithinThreshold(
      value: postureTrackerViewModel.attitude.roll,
      thresholdDegrees: postureTrackerViewModel
          .badPostureSettings.rollAngleThreshold
          .toDouble(),
    );
    final pitchWithinThreshold = _isWithinThreshold(
      value: postureTrackerViewModel.attitude.pitch,
      thresholdDegrees: postureTrackerViewModel
          .badPostureSettings.pitchAngleThreshold
          .toDouble(),
    );
    final infoText = postureTrackerViewModel.isTracking
        ? 'Live feedback for head tilt and neck alignment.'
        : 'Start tracking for live posture feedback. Calibration is optional.';

    return Padding(
      padding: SensorPageSpacing.pagePadding,
      child: Column(
        children: [
          Card(
            color: postureTrackerViewModel.isTracking && isGoodPosture
                ? _goodPostureColor.withValues(alpha: 0.12)
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Live Posture Feedback',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      _TrackingStatusChip(
                        label: status.label,
                        color: status.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    infoText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AngleMetricPill(
                        label: 'Roll',
                        valueRadians: postureTrackerViewModel.attitude.roll,
                        accentColor: postureTrackerViewModel.isTracking
                            ? (rollWithinThreshold
                                ? _goodPostureColor
                                : colorScheme.error)
                            : colorScheme.primary,
                      ),
                      _AngleMetricPill(
                        label: 'Pitch',
                        valueRadians: postureTrackerViewModel.attitude.pitch,
                        accentColor: postureTrackerViewModel.isTracking
                            ? (pitchWithinThreshold
                                ? _goodPostureColor
                                : colorScheme.error)
                            : colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SensorPageSpacing.sectionGap),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Head Posture',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (!postureTrackerViewModel.isAvailable) ...[
                      const SizedBox(height: 4),
                      Text(
                        'No compatible OpenEarable connected.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const headGap = 8.0;
                          const headChromeHeight = 52.0;
                          final headSpecs =
                              _createHeadSpecs(postureTrackerViewModel);
                          final viewWidth = min(constraints.maxWidth, 300.0);
                          final perHeadHeight =
                              (constraints.maxHeight - headGap) / 2;
                          final previewByHeight =
                              perHeadHeight - headChromeHeight;
                          final previewByWidth = viewWidth - 20;
                          final previewSize =
                              min(previewByHeight, previewByWidth)
                                  .clamp(72.0, 200.0);

                          return Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: viewWidth,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: _buildHeadView(
                                        context,
                                        headSpecs[0],
                                        previewSize: previewSize,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: headGap),
                                  Expanded(
                                    child: Center(
                                      child: _buildHeadView(
                                        context,
                                        headSpecs[1],
                                        previewSize: previewSize,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: SensorPageSpacing.sectionGap),
          SafeArea(
            top: false,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: PlatformElevatedButton(
                        onPressed: postureTrackerViewModel.isAvailable
                            ? () {
                                if (postureTrackerViewModel.isTracking) {
                                  postureTrackerViewModel.stopTracking();
                                  return;
                                }
                                postureTrackerViewModel.startTracking();
                              }
                            : null,
                        color: postureTrackerViewModel.isTracking
                            ? colorScheme.error
                            : null,
                        child: Text(
                          postureTrackerViewModel.isTracking
                              ? 'Stop Tracking'
                              : 'Start Tracking',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: PlatformTextButton(
                        onPressed: postureTrackerViewModel.isTracking
                            ? postureTrackerViewModel.calibrate
                            : null,
                        child: const Text('Calibrate (Optional)'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadView(
    BuildContext context,
    _HeadPreviewSpec spec, {
    required double previewSize,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final withinThreshold = _isWithinThreshold(
      value: spec.roll,
      thresholdDegrees: spec.angleThreshold,
    );
    final accentColor = withinThreshold ? _goodPostureColor : colorScheme.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              spec.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        PostureRollView(
          roll: spec.roll,
          angleThreshold: _degreesToRadians(spec.angleThreshold),
          headAssetPath: spec.headAssetPath,
          neckAssetPath: spec.neckAssetPath,
          headAlignment: spec.headAlignment,
          visualSize: previewSize,
          goodColor: _goodPostureColor,
          badColor: colorScheme.error,
        ),
      ],
    );
  }

  List<_HeadPreviewSpec> _createHeadSpecs(
    PostureTrackerViewModel postureTrackerViewModel,
  ) {
    return [
      _HeadPreviewSpec(
        label: 'Side-to-Side Tilt',
        headAssetPath: 'lib/apps/posture_tracker/assets/Head_Front.png',
        neckAssetPath: 'lib/apps/posture_tracker/assets/Neck_Front.png',
        headAlignment: Alignment.center.add(const Alignment(0, 0.3)),
        roll: postureTrackerViewModel.attitude.roll,
        angleThreshold: postureTrackerViewModel
            .badPostureSettings.rollAngleThreshold
            .toDouble(),
      ),
      _HeadPreviewSpec(
        label: 'Forward/Backward Tilt',
        headAssetPath: 'lib/apps/posture_tracker/assets/Head_Side.png',
        neckAssetPath: 'lib/apps/posture_tracker/assets/Neck_Side.png',
        headAlignment: Alignment.center.add(const Alignment(0, 0.3)),
        roll: -postureTrackerViewModel.attitude.pitch,
        angleThreshold: postureTrackerViewModel
            .badPostureSettings.pitchAngleThreshold
            .toDouble(),
      ),
    ];
  }

  bool _isGoodPosture(PostureTrackerViewModel postureTrackerViewModel) {
    final rollWithinThreshold = _isWithinThreshold(
      value: postureTrackerViewModel.attitude.roll,
      thresholdDegrees: postureTrackerViewModel
          .badPostureSettings.rollAngleThreshold
          .toDouble(),
    );
    final pitchWithinThreshold = _isWithinThreshold(
      value: postureTrackerViewModel.attitude.pitch,
      thresholdDegrees: postureTrackerViewModel
          .badPostureSettings.pitchAngleThreshold
          .toDouble(),
    );
    return rollWithinThreshold && pitchWithinThreshold;
  }

  bool _isWithinThreshold({
    required double value,
    required double thresholdDegrees,
  }) {
    return value.abs() <= _degreesToRadians(thresholdDegrees).abs();
  }

  double _degreesToRadians(double value) {
    return value * pi / 180;
  }

  ({String label, Color color}) _trackingStatus({
    required bool isAvailable,
    required bool isTracking,
    required bool isGoodPosture,
  }) {
    if (!isAvailable) {
      return (label: 'Unavailable', color: Theme.of(context).colorScheme.error);
    }
    if (!isTracking) {
      return (label: 'Ready', color: Theme.of(context).colorScheme.primary);
    }
    if (isGoodPosture) {
      return (label: 'Good Posture', color: _goodPostureColor);
    }
    return (
      label: 'Adjust Posture',
      color: Theme.of(context).colorScheme.error
    );
  }
}

class _HeadPreviewSpec {
  final String label;
  final String headAssetPath;
  final String neckAssetPath;
  final AlignmentGeometry headAlignment;
  final double roll;
  final double angleThreshold;

  const _HeadPreviewSpec({
    required this.label,
    required this.headAssetPath,
    required this.neckAssetPath,
    required this.headAlignment,
    required this.roll,
    required this.angleThreshold,
  });
}

class _TrackingStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TrackingStatusChip({
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

class _AngleMetricPill extends StatelessWidget {
  final String label;
  final double valueRadians;
  final Color accentColor;

  const _AngleMetricPill({
    required this.label,
    required this.valueRadians,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final value = (valueRadians * 180 / pi).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value°',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accentColor.withValues(alpha: 0.95),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
