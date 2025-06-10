import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
                ElevatedButton(
                  onPressed: () {
                    context.read<UpdateBloc>().add(BeginUpdateProcess());
                  },
                  child: Text('Update'),
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
                      Text(state.stage),
                    ],
                  ),
                if (state.currentState != null)
                  Row(
                    children: [
                      const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, padding: EdgeInsets.all(4))),
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
                                    )));
                      },
                      child: Text('Show Log')),
                if (state.isComplete)
                  ElevatedButton(
                    onPressed: () {
                      BlocProvider.of<UpdateBloc>(context).add(ResetUpdate());
                      provider.reset();
                    },
                    child: Text('Update Again'),
                  ),
              ],
            );
          default:
            return Text('Unknown state');
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

  Text _currentState(UpdateFirmwareStateHistory state) {
    final currentState = state.currentState;
    if (currentState == null) {
      return Text('Unknown state');
    } else if (currentState is UpdateProgressFirmware) {
      return Text("Uploading ${currentState.progress}%");
    } else {
      return Text(currentState.stage);
    }
  }

  Widget _firmwareInfo(BuildContext context, SelectedFirmware firmware) {
    if (firmware is LocalFirmware) {
      return _localFirmwareInfo(context, firmware);
    } else if (firmware is RemoteFirmware) {
      return _remoteFirmwareInfo(context, firmware);
    } else {
      return Text('Unknown firmware type');
    }
  }

  Widget _localFirmwareInfo(BuildContext context, LocalFirmware firmware) {
    return Text('Firmware: ${firmware.name}');
  }

  Widget _remoteFirmwareInfo(BuildContext context, RemoteFirmware firmware) {
    return Column(
      children: [
        Text('Firmware: ${firmware.name}'),
        Text('Url: ${firmware.url}'),
      ],
    );
  }
}
