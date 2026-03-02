import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import '../fota/stepper_view/update_view.dart';
import '../fota/stepper_view/firmware_select.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class FirmwareUpdateWidget extends StatefulWidget {
  const FirmwareUpdateWidget({super.key});

  @override
  State<FirmwareUpdateWidget> createState() => _FirmwareUpdateWidget();
}

class _FirmwareUpdateWidget extends State<FirmwareUpdateWidget> {
  late FirmwareUpdateRequestProvider provider;

  @override
  Widget build(BuildContext context) {
    provider = context.watch<FirmwareUpdateRequestProvider>();
    return PlatformScaffold(
      appBar: PlatformAppBar(title: PlatformText("Update Firmware")),
      body: Material(type: MaterialType.transparency, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    return Stepper(
      connectorColor: WidgetStateProperty.resolveWith<Color>(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.green;
          }
          return Colors.grey;
        },
      ),
      currentStep: provider.currentStep,
      onStepContinue: () {
        setState(() {
          provider.nextStep();
        });
      },
      onStepCancel: () {
        setState(() {
          provider.previousStep();
        });
      },
      controlsBuilder: _controlBuilder,
      steps: [
        Step(
          state:
              provider.currentStep > 0 ? StepState.complete : StepState.indexed,
          title: PlatformText('Select Firmware'),
          content: Center(
            child: FirmwareSelect(),
          ),
          isActive: provider.currentStep >= 0,
        ),
        Step(
          state:
              provider.currentStep > 1 ? StepState.complete : StepState.indexed,
          title: PlatformText('Update'),
          content: PlatformText('Update'),
          isActive: provider.currentStep >= 1,
        ),
      ],
    );
  }

  Widget _controlBuilder(BuildContext context, ControlsDetails details) {
    final provider = context.watch<FirmwareUpdateRequestProvider>();
    FirmwareUpdateRequest parameters = provider.updateParameters;
    switch (provider.currentStep) {
      case 0:
        if (parameters.firmware == null) {
          return Container();
        }
        return Row(
          children: [
            PlatformElevatedButton(
              onPressed: details.onStepContinue,
              child: PlatformText('Next'),
            ),
          ],
        );
      case 1:
        return BlocProvider(
          create: (context) => UpdateBloc(firmwareUpdateRequest: parameters),
          child: UpdateStepView(),
        );
      default:
        throw Exception('Unknown step');
    }
  }

  @override
  void dispose() {
    // Reset the state when this widget is disposed (e.g. popped)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.reset();
    });
    super.dispose();
  }
}
