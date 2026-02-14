import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/fota/stepper_view/firmware_select.dart';
import 'package:open_wearable/widgets/fota/stepper_view/update_view.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';

class FirmwareUpdateWidget extends StatefulWidget {
  const FirmwareUpdateWidget({super.key});

  @override
  State<FirmwareUpdateWidget> createState() => _FirmwareUpdateWidgetState();
}

class _FirmwareUpdateWidgetState extends State<FirmwareUpdateWidget> {
  late FirmwareUpdateRequestProvider provider;
  bool _isUpdateRunning = false;
  bool _hasStartedUpdate = false;

  @override
  Widget build(BuildContext context) {
    provider = context.watch<FirmwareUpdateRequestProvider>();
    final request = provider.updateParameters;
    final shouldRouteBackToDevices = _hasStartedUpdate && !_isUpdateRunning;

    return PopScope(
      canPop: !_isUpdateRunning && !shouldRouteBackToDevices,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        if (_isUpdateRunning) {
          final messenger = ScaffoldMessenger.maybeOf(context);
          messenger?.hideCurrentSnackBar();
          messenger?.showSnackBar(
            const SnackBar(
              content: Text(
                'Firmware update is running. Please stay on this page until it finishes.',
              ),
            ),
          );
          return;
        }

        if (shouldRouteBackToDevices) {
          context.go('/?tab=devices');
        }
      },
      child: PlatformScaffold(
        appBar: PlatformAppBar(
          title: const Text('Firmware Update'),
        ),
        body: ListView(
          padding: SensorPageSpacing.pagePadding,
          children: [
            _UpdateStepHeader(currentStep: provider.currentStep),
            const SizedBox(height: SensorPageSpacing.sectionGap),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: _buildStepContent(context, request),
              ),
            ),
            if (provider.currentStep == 0 && request.firmware != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _isUpdateRunning = true;
                      _hasStartedUpdate = true;
                    });
                    provider.nextStep();
                  },
                  icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                  label: const Text('Start Update'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(
    BuildContext context,
    FirmwareUpdateRequest request,
  ) {
    switch (provider.currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Firmware',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose firmware to install on the selected wearable.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            const FirmwareSelect(),
          ],
        );
      case 1:
        if (request.firmware == null) {
          return Text(
            'No firmware selected. Go back and select firmware first.',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Install Firmware',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Firmware update is running. Do not close the app until it finishes.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            BlocProvider(
              create: (context) => UpdateBloc(firmwareUpdateRequest: request),
              child: UpdateStepView(
                autoStart: true,
                onUpdateRunningChanged: _handleUpdateRunningChanged,
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void dispose() {
    // Reset state after the page has been removed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.reset();
    });
    super.dispose();
  }

  void _handleUpdateRunningChanged(bool running) {
    if (!mounted) {
      return;
    }

    if (running && !_hasStartedUpdate) {
      _hasStartedUpdate = true;
    }

    if (_isUpdateRunning == running) {
      return;
    }
    setState(() {
      _isUpdateRunning = running;
    });
  }
}

class _UpdateStepHeader extends StatelessWidget {
  final int currentStep;

  const _UpdateStepHeader({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StepPill(
            index: 1,
            label: 'Select',
            isActive: currentStep == 0,
            isComplete: currentStep > 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StepPill(
            index: 2,
            label: 'Update',
            isActive: currentStep == 1,
            isComplete: false,
          ),
        ),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  final int index;
  final String label;
  final bool isActive;
  final bool isComplete;

  const _StepPill({
    required this.index,
    required this.label,
    required this.isActive,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isActive || isComplete
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final background = isActive
        ? colorScheme.primaryContainer.withValues(alpha: 0.8)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final border = isActive || isComplete
        ? colorScheme.primary.withValues(alpha: 0.45)
        : colorScheme.outlineVariant.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isComplete
                ? Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: foreground,
                  )
                : Text(
                    '$index',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
