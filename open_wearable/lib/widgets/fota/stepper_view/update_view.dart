import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import '../logger_screen/logger_screen.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class UpdateStepView extends StatelessWidget {
  const UpdateStepView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FirmwareUpdateRequestProvider>();
    final request = provider.updateParameters;
    return BlocBuilder<UpdateBloc, UpdateState>(
      builder: (context, state) {
        switch (state) {
          case UpdateInitial():
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _firmwareInfo(context, request.firmware!),
                PlatformElevatedButton(
                  onPressed: () {
                    context.read<UpdateBloc>().add(BeginUpdateProcess());
                  },
                  child: PlatformText('Update'),
                ),
              ],
            );
          case UpdateFirmwareStateHistory():
            return Column(
              children: [
                for (var state in state.history)
                  Row(
                    children: [
                      _stateIcon(
                        state,
                        Colors.green,
                      ),
                      PlatformText(state.stage),
                    ],
                  ),
                if (state.currentState != null)
                  Row(
                    children: [
                      const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          padding: EdgeInsets.all(4),
                        ),
                      ),
                      _currentState(state),
                    ],
                  ),
                if (state.isComplete && state.updateManager?.logger != null)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoggerScreen(
                            logger: state.updateManager!.logger,
                          ),
                        ),
                      );
                    },
                    child: PlatformText('Show Log'),
                  ),
                if (state.isComplete)
                  ElevatedButton(
                    onPressed: () {
                      BlocProvider.of<UpdateBloc>(context).add(ResetUpdate());
                      provider.reset();
                    },
                    child: PlatformText('Update Again'),
                  ),
                if (state.isComplete &&
                    state.history.last is UpdateCompleteSuccess)
                  PlatformText(
                    'Firmware upload complete.\n\n'
                    'The image has been successfully uploaded and is now being verified by the device. '
                    'The device will automatically restart once verification is complete.\n\n'
                    'This may take up to 3 minutes. Please keep the device powered on and nearby.',
                    textAlign: TextAlign.start,
                  ),
              ],
            );
          default:
            return PlatformText('Unknown state');
        }
      },
    );
  }

  Icon _stateIcon(UpdateFirmware state, Color successColor) {
    if (state is UpdateCompleteFailure) {
      return const Icon(size: 24, Icons.error_outline, color: Colors.red);
    } else {
      return Icon(size: 24, Icons.check_circle_outline, color: successColor);
    }
  }

  PlatformText _currentState(UpdateFirmwareStateHistory state) {
    final currentState = state.currentState;
    if (currentState == null) {
      return PlatformText('Unknown state');
    } else if (currentState is UpdateProgressFirmware) {
      var core = currentState.imageNumber == 0 ? "application" : "network";
      return PlatformText(
        "Uploading $core core (image ${currentState.imageNumber}) ${currentState.progress}%",
      );
    } else {
      return PlatformText(currentState.stage);
    }
  }

  Widget _firmwareInfo(BuildContext context, SelectedFirmware firmware) {
    if (firmware is LocalFirmware) {
      return _localFirmwareInfo(context, firmware);
    } else if (firmware is RemoteFirmware) {
      return _remoteFirmwareInfo(context, firmware);
    } else {
      return PlatformText('Unknown firmware type');
    }
  }

  Widget _localFirmwareInfo(BuildContext context, LocalFirmware firmware) {
    return PlatformText('Firmware: ${firmware.name}');
  }

  Widget _remoteFirmwareInfo(BuildContext context, RemoteFirmware firmware) {
    return Column(
      children: [
        PlatformText('Firmware: ${firmware.name}'),
        PlatformText('Url: ${firmware.url}'),
      ],
    );
  }
}
