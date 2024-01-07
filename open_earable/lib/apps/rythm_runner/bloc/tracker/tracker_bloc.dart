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

/// This is the Bloc class handling the event
/// listeners (logic) for tracker related events
class TrackerBloc extends Bloc<TrackerEvent, TrackerState> {
  final OpenEarable _openEarable;
  StreamSubscription? _imuSubscription;
  Timer? _timer;

  // Default config for thresholds
  final TrackerThresholdConfig defaultConfig =
      TrackerThresholdConfig(xThreshold: 13, zThreshold: 13, xzThreshold: 21);

  TrackerBloc(this._openEarable)
      : super(TrackerIdleState(
            config: TrackerThresholdConfig(
                xThreshold: 13, zThreshold: 13, xzThreshold: 21))) {
    // Listen for CancelTracking events on the event bus
    SimpleEventBus().stream.listen((event) {
      if (event is CancelTracking) {
        // Only call event if widget isn't closed
        if (!this.isClosed) {
          add(CancelTracking());
        }
      }
    });

    on<StartTracking>((event, emit) {
      // Make sure we are in the idle state when starting
      emit(TrackerIdleState(config: state.config));
      // Cancel a possibly running timer
      _timer?.cancel();
      // If we are connected to bluetooth, start new timer
      if (_openEarable.bleManager.connected) {
        _timer = Timer.periodic(Duration(seconds: 1), (timer) {
          // Call Tick event every second
          add(TrackingTick());
        });

        // Play a ticking playlist, while the countdown runs. This makes sure
        // That the current device has playback and we don't get an API error
        // when we want to play a song after completing the tracking.
        SimpleEventBus().sendEvent(PlaySpotifySong(
            mediaKey: SpotifySettingsData.TICKING_TRACK, positionMs: 31000));

        // Storage for X and Z Axis values
        List<double> _xAxisValues = [];
        List<double> _zAxisValues = [];
        // Open Subscription for IMU
        _imuSubscription =
            _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
          double ax = data["ACC"]["X"];
          double az = data["ACC"]["Z"];
          _xAxisValues.add(ax);
          _zAxisValues.add(az);

          bool isPeakX = false;
          bool isPeakZ = false;

          // Check for peaks in the X and Z values using the last three values we recieved
          // and the threshold value for the corresponding parameter
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
          // If there is a peak in either value, call the TrackStep event
          if (isPeakX || isPeakZ) {
            if (!this.isClosed) {
              add(TrackStep());
            }
            // We primitively add together the values for x and z
            // and if the sum is larger than the threshold, we track a step
          } else if (ax + az > state.config.xzThreshold) {
            if (!this.isClosed) {
              add(TrackStep());
            }
          }
        });
        // When we are done setting up our listeners, emit the Running State
        emit(TrackerRunningState(config: state.config, runData: state.runData));
      }
    });
    on<TrackingTick>((event, emit) {
      // Check if we are connected to earable. If not, cancel tracking.
      if (!_openEarable.bleManager.connected) {
        add(CancelTracking());
        return;
      }
      // Update the run data and emit the Running state with this new data
      TrackerRunData updatedRunData = state.runData.tick();
      if (updatedRunData.duration.inSeconds > 0) {
        emit(
            TrackerRunningState(config: state.config, runData: updatedRunData));
        // To make sure our selected playback device stays online, we update
        // the device list periodically to abort if the device went offline.
        if (updatedRunData.duration.inSeconds % 5 == 1) {
          SimpleEventBus().sendEvent(UpdateDeviceList());
        }
      } else {
        // If the timer has run out, cancel the timer and
        // IMU subscription and call the CompleteTracking event
        _timer?.cancel();
        _imuSubscription?.cancel();
        add(CompleteTracking());
      }
    });
    on<TrackStep>((event, emit) {
      // If we are tracking, emit the state with an increased step count
      if (state is TrackerRunningState) {
        emit(TrackerRunningState(
            config: state.config, runData: state.runData.incrementStepCount()));
      }
    });
    on<CancelTracking>((event, emit) {
      // Cancel the timer and IMU subscription
      _timer?.cancel();
      _imuSubscription?.cancel();
      // Emit the idle state and pause possible spotify playback
      emit(TrackerIdleState(config: state.config));
      SimpleEventBus().sendEvent(PauseSpotifyPlayback());
    });
    on<CompleteTracking>((event, emit) {
      // Calculate the nearest number devidable by 5 to the BPM count
      int bpmInFives = (state.runData.bpmAverage / 5).round() * 5;
      // Check if we have a playlist for this speed. 
      if (SpotifySettingsData.BPM_PLAYLIST_MAP.containsKey(bpmInFives)) {
        // Emit state to indicate the tracking completed normally
        emit(
            TrackerFinishedState(config: state.config, runData: state.runData));
      // Send PlaySpotifySong event over the Event Bus.
        SimpleEventBus().sendEvent(PlaySpotifySong(
            mediaKey: "spotify:playlist:" +
                SpotifySettingsData.BPM_PLAYLIST_MAP[bpmInFives]!,
            positionMs: 0));
      } else {
        // Don't play music if we don't have a playlist
        emit(TrackerIdleState(config: state.config));
        SimpleEventBus().sendEvent(PauseSpotifyPlayback());
      }
    });
    on<UpdateTrackerSettings>((event, emit) {
      // Update the configuration according to the data passed in the event
      TrackerThresholdConfig newConfig = state.config.copyWith(
        xThreshold: event.config.xThreshold,
        zThreshold: event.config.zThreshold,
        xzThreshold: event.config.xzThreshold,
      );
      // Emit the current state with a new configuration
      emit(state.copyWith(config: newConfig));
    });
  }

  @override
  Future<void> close() {
    // Close subscriptions, stop timer to prevent memory leaks
    _timer?.cancel();
    _imuSubscription?.cancel();
    _imuSubscription = null;
    return super.close();
  }

  /// The function `_detectPeak` checks if a peak is detected based on three consecutive values and a
  /// threshold.
  ///
  /// Args:
  ///   threshold (double): Determines how large the peak has to be to be counted
  ///
  /// Returns:
  ///   a boolean, if a peak was detected
  bool _detectPeak(double y2, double y1, double y0, double threshold) {
    List<dynamic> result = findPeaks(Array([y2, y1, y0]), threshold: threshold);
    return result[0].isNotEmpty;
  }
}
