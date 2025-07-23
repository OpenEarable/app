import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// First, let's define the Attitude class if it's not available
class Attitude {
  final double roll;
  final double pitch;
  final double yaw;

  const Attitude({
    this.roll = 0.0,
    this.pitch = 0.0,
    this.yaw = 0.0,
  });

  Attitude operator -(Attitude other) {
    return Attitude(
      roll: roll - other.roll,
      pitch: pitch - other.pitch,
      yaw: yaw - other.yaw,
    );
  }
}

enum TurnDirection { left, right, none }

class DirectionSettings {
  /// The minimum yaw angle threshold in degrees to register a turn
  final double yawAngleThreshold;
  
  /// Time in seconds the user must hold the turn to register it
  final double holdTimeThreshold;
  
  /// Time in seconds to reset if user returns to neutral position
  final double resetTimeThreshold;

  const DirectionSettings({
    this.yawAngleThreshold = 15.0, // 30 degrees
    this.holdTimeThreshold = 1.0,  // 1 second
    this.resetTimeThreshold = 1.0, // 0.5 seconds
  });
}

class DirectionTracker {
  final StreamController<Attitude> _attitudeController = StreamController<Attitude>.broadcast();
  final DirectionSettings _settings;
  
  // Callbacks
  void Function(TurnDirection direction)? onDirectionDetected;
  void Function(TurnDirection direction)? onDirectionStarted;
  void Function()? onReturnToCenter;
  
  // State tracking
  DateTime? _turnStartTime;
  DateTime? _neutralStartTime;
  TurnDirection _currentDirection = TurnDirection.none;
  TurnDirection _lastDetectedDirection = TurnDirection.none;
  bool _isTracking = false;
  StreamSubscription<Attitude>? _subscription;
  Attitude _referenceAttitude = const Attitude();
  
  DirectionTracker({
    DirectionSettings? settings,
    this.onDirectionDetected,
    this.onDirectionStarted,
    this.onReturnToCenter,
  }) : _settings = settings ?? const DirectionSettings();

  bool get isTracking => _isTracking;
  TurnDirection get currentDirection => _currentDirection;
  TurnDirection get lastDetectedDirection => _lastDetectedDirection;

  void start() {
    if (_isTracking) return;
    
    _isTracking = true;
    _reset();
    
    _subscription = _attitudeController.stream.listen((attitude) {
      if (!_isTracking) return;
      _processAttitude(attitude);
    });
  }

  void stop() {
    _isTracking = false;
    _subscription?.cancel();
    _reset();
  }

  void _reset() {
    _turnStartTime = null;
    _neutralStartTime = null;
    _currentDirection = TurnDirection.none;
  }

  void _processAttitude(Attitude attitude) {
    final DateTime now = DateTime.now();
    final Attitude adjustedAttitude = attitude - _referenceAttitude;
    final double yawDegrees = adjustedAttitude.yaw * (180 / pi); // Convert to degrees
    
    TurnDirection detectedDirection = _getDirectionFromYaw(yawDegrees);
    
    if (detectedDirection != _currentDirection) {
      _handleDirectionChange(detectedDirection, now);
    } else {
      _handleDirectionContinued(detectedDirection, now);
    }
    
    _currentDirection = detectedDirection;
  }

  TurnDirection _getDirectionFromYaw(double yawDegrees) {
    if (yawDegrees > _settings.yawAngleThreshold) {
      return TurnDirection.right;
    } else if (yawDegrees < -_settings.yawAngleThreshold) {
      return TurnDirection.left;
    } else {
      return TurnDirection.none;
    }
  }

  void _handleDirectionChange(TurnDirection newDirection, DateTime now) {
    if (newDirection == TurnDirection.none) {
      // User returned to neutral
      _neutralStartTime = now;
      _turnStartTime = null;
      onReturnToCenter?.call();
    } else {
      // User started turning in a new direction
      _turnStartTime = now;
      _neutralStartTime = null;
      onDirectionStarted?.call(newDirection);
      
      if (kDebugMode) {
        print('Direction started: ${newDirection.name}');
      }
    }
  }

  void _handleDirectionContinued(TurnDirection direction, DateTime now) {
    if (direction != TurnDirection.none && _turnStartTime != null) {
      // Check if user has held the turn long enough
      final Duration turnDuration = now.difference(_turnStartTime!);
      
      if (turnDuration.inMilliseconds >= (_settings.holdTimeThreshold * 1000) &&
          direction != _lastDetectedDirection) {
        _lastDetectedDirection = direction;
        onDirectionDetected?.call(direction);
        
        if (kDebugMode) {
          print('Direction detected: ${direction.name} after ${turnDuration.inMilliseconds}ms');
        }
      }
    } else if (direction == TurnDirection.none && _neutralStartTime != null) {
      // Check if user has been neutral long enough to reset
      final Duration neutralDuration = now.difference(_neutralStartTime!);
      
      if (neutralDuration.inMilliseconds >= (_settings.resetTimeThreshold * 1000)) {
        // Reset the last detected direction after being neutral
        // This allows detecting the same direction again
        if (_lastDetectedDirection != TurnDirection.none) {
          _lastDetectedDirection = TurnDirection.none;
          if (kDebugMode) {
            print('Reset - ready to detect directions again');
          }
        }
      }
    }
  }

  void calibrate() {
    // This will be called when you want to set the reference position
    if (kDebugMode) {
      print('Calibration completed');
    }
  }

  void updateAttitude(Attitude attitude) {
    _attitudeController.add(attitude);
  }

  void setReferenceAttitude(Attitude attitude) {
    _referenceAttitude = attitude;
  }

  void dispose() {
    _subscription?.cancel();
    _attitudeController.close();
  }
}

// Direction Test Widget (matches your existing call pattern)
class DirectionTest extends StatefulWidget {
  final VoidCallback onCompleted;
  final TurnDirection? requiredDirection; // null means any direction is acceptable
  
  const DirectionTest({
    Key? key, 
    required this.onCompleted,
    this.requiredDirection,
  }) : super(key: key);

  @override
  State<DirectionTest> createState() => _DirectionTestState();
}

class _DirectionTestState extends State<DirectionTest> {
  late DirectionTracker _directionTracker;
  TurnDirection? _detectedDirection;
  bool _isCalibrating = true;
  String _statusMessage = "Calibrating... Keep your head straight";
  Color _statusColor = Colors.orange;
  bool _hasSimulatedTurn = false;
  late DateTime _initTime;

  @override
  void initState() {
    super.initState();
    _initTime = DateTime.now();
    _setupDirectionTracker();
    _startCalibration();
    _simulateAttitudeData(); // For demo purposes - remove when integrating with real sensor
  }

  void _setupDirectionTracker() {
    _directionTracker = DirectionTracker(
      settings: const DirectionSettings(
        yawAngleThreshold: 25.0, // 25 degrees for sensitivity
        holdTimeThreshold: 1.5,  // 1.5 seconds to confirm direction
        resetTimeThreshold: 1.0, // 1 second to reset
      ),
      onDirectionStarted: (direction) {
        if (!_isCalibrating) {
          setState(() {
            _statusMessage = "Turning ${direction.name}... hold position";
            _statusColor = Colors.blue;
          });
        }
      },
      onDirectionDetected: (direction) {
        if (!_isCalibrating) {
          setState(() {
            _detectedDirection = direction;
            if (widget.requiredDirection == null || direction == widget.requiredDirection) {
              _statusMessage = "Direction detected: ${direction.name.toUpperCase()} ✓";
              _statusColor = Colors.green;
            } else {
              _statusMessage = "Wrong direction! Turn ${widget.requiredDirection!.name}";
              _statusColor = Colors.red;
            }
          });
        }
      },
      onReturnToCenter: () {
        if (!_isCalibrating) {
          setState(() {
            _statusMessage = widget.requiredDirection != null 
              ? "Turn your head ${widget.requiredDirection!.name}"
              : "Turn your head left or right";
            _statusColor = Colors.grey;
          });
        }
      },
    );
  }

  void _startCalibration() async {
    // Give user time to position head straight
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      _directionTracker.calibrate();
      _directionTracker.start();
      
      setState(() {
        _isCalibrating = false;
        _statusMessage = widget.requiredDirection != null 
          ? "Turn your head ${widget.requiredDirection!.name}"
          : "Turn your head left or right";
        _statusColor = Colors.grey;
      });
    }
  }

  @override
  void dispose() {
    _directionTracker.stop();
    _directionTracker.dispose();
    super.dispose();
  }

  // Demo method - replace with real sensor integration
  void _simulateAttitudeData() {
    // This simulates attitude changes for demo purposes
    // Remove this method when integrating with your real AttitudeTracker
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Simulate turning left after 3 seconds for testing
      if (DateTime.now().difference(_initTime).inSeconds > 3 && !_hasSimulatedTurn) {
        _hasSimulatedTurn = true;
        _directionTracker.updateAttitude(const Attitude(yaw: -0.6)); // Left turn
        
        // Return to neutral after 2 more seconds
        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            _directionTracker.updateAttitude(const Attitude(yaw: 0.0));
          }
        });
      } else {
        _directionTracker.updateAttitude(const Attitude(yaw: 0.0)); // Neutral
      }
    });
  }

  // Method to integrate with your real AttitudeTracker
  void connectToAttitudeTracker(dynamic attitudeTracker) {
    // Call this method to connect your existing AttitudeTracker
    // attitudeTracker.listen((attitude) {
    //   _directionTracker.updateAttitude(attitude);
    // });
    // _directionTracker.setReferenceAttitude(attitudeTracker.attitude);
  }

  bool get _canComplete {
    if (widget.requiredDirection != null) {
      return _detectedDirection == widget.requiredDirection;
    }
    return _detectedDirection != null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isCalibrating)
          const CircularProgressIndicator()
        else if (_detectedDirection == TurnDirection.left)
          const Icon(Icons.arrow_back, size: 48, color: Colors.green)
        else if (_detectedDirection == TurnDirection.right)
          const Icon(Icons.arrow_forward, size: 48, color: Colors.green),
        
        const SizedBox(height: 20),
        
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: _statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 30),
        
        ElevatedButton(
          onPressed: _canComplete ? widget.onCompleted : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _canComplete ? Colors.green : null,
          ),
          child: Text(_canComplete ? "Complete ✓" : "Turn Your Head"),
        ),
      ],
    );
  }
}

// Integration helper class to connect with existing AttitudeTracker
class DirectionTestIntegration {
  final DirectionTracker directionTracker;
  StreamSubscription? _attitudeSubscription;
  
  DirectionTestIntegration(this.directionTracker);
  
  // Call this method to connect existing AttitudeTracker
  void connectToAttitudeTracker(dynamic attitudeTracker) {
    // Listen to existing attitude tracker and forward the data
    attitudeTracker.listen((attitude) {
      directionTracker.updateAttitude(attitude);
    });
    
    // Set the reference attitude for calibration
    directionTracker.setReferenceAttitude(attitudeTracker.attitude);
  }
  
  void dispose() {
    _attitudeSubscription?.cancel();
    directionTracker.dispose();
  }
}