import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:open_earable/apps/rythm_runner/bloc/simple_event_bus.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_bloc.dart';
import 'package:open_earable/apps/rythm_runner/bloc/spotify/spotify_settings.dart';
import 'package:open_earable/apps/rythm_runner/bloc/tracker/tracker_run_data.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:scidart/numdart.dart';
import 'package:scidart/scidart.dart';

import 'tracker_threshold_config.dart';

part 'tracker_event.dart';
part 'tracker_state.dart';

class TrackerBloc extends Bloc<TrackerEvent, TrackerState> {
  final OpenEarable _openEarable;
  StreamSubscription? _imuSubscription;
  Timer? _timer;

  final TrackerThresholdConfig defaultConfig =
      TrackerThresholdConfig(xThreshold: 13, zThreshold: 13, xzThreshold: 21);

  TrackerBloc(this._openEarable)
      : super(TrackerIdleState(
            config: TrackerThresholdConfig(
                xThreshold: 13, zThreshold: 13, xzThreshold: 21))) {
    SimpleEventBus().stream.listen((event) {
      if (event is CancelTracking) {
        if (!this.isClosed) {
          add(CancelTracking());
        }
      }
    });

    on<StartTracking>((event, emit) {
      emit(TrackerIdleState(config: state.config));
      _timer?.cancel();
      if (_openEarable.bleManager.connected) {
        _timer = Timer.periodic(Duration(seconds: 1), (timer) {
          add(TrackingTick());
        });

        SimpleEventBus().sendEvent(
            PlaySpotifySong(mediaKey: SpotifySettingsData.TICKING_PLAYLIST));

        List<double> _xAxisValues = [];
        List<double> _zAxisValues = [];
        _imuSubscription =
            _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
          double ax = data["ACC"]["X"];
          double az = data["ACC"]["Z"];
          _xAxisValues.add(ax);
          _zAxisValues.add(az);

          bool isPeakX = false;
          bool isPeakZ = false;

          if (_xAxisValues.length >= 3) {
            isPeakX = _detectPeak(
                _xAxisValues[_xAxisValues.length - 2],
                _xAxisValues[_xAxisValues.length - 1],
                _xAxisValues[_xAxisValues.length - 3],
                state.config.xThreshold);
          }
          if (_zAxisValues.length >= 3) {
            isPeakZ = _detectPeak(
                _zAxisValues[_zAxisValues.length - 2],
                _zAxisValues[_zAxisValues.length - 1],
                _zAxisValues[_zAxisValues.length - 3],
                state.config.zThreshold);
          }
          if (isPeakX || isPeakZ) {
            if (!this.isClosed) {
              add(TrackStep());
            }
          } else if (ax + az > state.config.xzThreshold) {
            if (!this.isClosed) {
              add(TrackStep());
            }
          }
        });
        emit(TrackerRunningState(config: state.config, runData: state.runData));
      }
    });
    on<TrackingTick>((event, emit) {
      if(!_openEarable.bleManager.connected) {
        add(CancelTracking());
        return;
      }
      TrackerRunData updatedRunData = state.runData.tick();
      if (updatedRunData.duration.inSeconds > 0) {
        emit(
            TrackerRunningState(config: state.config, runData: updatedRunData));
        if (updatedRunData.duration.inSeconds % 5 == 1) {
          SimpleEventBus().sendEvent(UpdateDeviceList());
        }
      } else {
        _timer?.cancel();
        _imuSubscription?.cancel();
        add(CompleteTracking());
      }
    });
    on<TrackStep>((event, emit) {
      if (state is TrackerRunningState) {
        emit(TrackerRunningState(
            config: state.config, runData: state.runData.incrementStepCount()));
      }
    });
    on<CancelTracking>((event, emit) {
      _timer?.cancel();
      _imuSubscription?.cancel();
      emit(TrackerIdleState(config: state.config));
      SimpleEventBus().sendEvent(PauseSpotifyPlayback());
    });
    on<CompleteTracking>((event, emit) {
      emit(TrackerFinishedState(config: state.config, runData: state.runData));
      int bpmInFives = (state.runData.bpmAverage / 5).round() * 5;
      // for testing: bpmInFives = 120;
      if (SpotifySettingsData.BPM_PLAYLIST_MAP.containsKey(bpmInFives)) {
        SimpleEventBus().sendEvent(PlaySpotifySong(
            mediaKey: "spotify:playlist:" +
                SpotifySettingsData.BPM_PLAYLIST_MAP[bpmInFives]!));
      }
    });
    on<UpdateTrackerSettings>((event, emit) {
      TrackerThresholdConfig newConfig = state.config.copyWith(
        xThreshold: event.config.xThreshold,
        zThreshold: event.config.zThreshold,
        xzThreshold: event.config.xzThreshold,
      );
      emit(state.copyWith(config: newConfig));
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _imuSubscription?.cancel();
    _imuSubscription = null;
    // SimpleEventBus().dispose();
    return super.close();
  }

  bool _detectPeak(double y2, double y1, double y0, double threshold) {
    List<dynamic> result = findPeaks(Array([y2, y1, y0]), threshold: threshold);
    return result[0].isNotEmpty;
  }
}
