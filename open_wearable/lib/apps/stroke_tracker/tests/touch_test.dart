// lib/stroke_tracker/touch_test.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Provider to track the left-right touch sequence for stroke detection.
class TouchTestProvider extends ChangeNotifier {
  /// Callback to invoke when the sequence is complete.
  final VoidCallback onComplete;

  bool _leftTapped = false;
  bool _rightTapped = false;

  bool get leftTapped => _leftTapped;
  bool get rightTapped => _rightTapped;
  bool get isComplete => _leftTapped && _rightTapped;

  TouchTestProvider({required this.onComplete});

  /// Call when left earphone is tapped
  void tapLeft() {
    if (!_leftTapped) {
      _leftTapped = true;
      notifyListeners();
    }
  }

  /// Call when right earphone is tapped
  void tapRight() {
    if (_leftTapped && !_rightTapped) {
      _rightTapped = true;
      notifyListeners();
      onComplete();
    }
  }

  /// Reset the test
  void reset() {
    _leftTapped = false;
    _rightTapped = false;
    notifyListeners();
  }
}

/// Widget that displays two touch zones (left/right) for the stroke touch test.
class TouchTest extends StatelessWidget {
  /// Title shown in the AppBar
  final String title;
  /// Called when the user has successfully tapped left then right
  final VoidCallback onCompleted;

  const TouchTest({
    Key? key,
    this.title = 'Stroke Touch Test',
    required this.onCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TouchTestProvider>(
      create: (_) => TouchTestProvider(onComplete: onCompleted),
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Consumer<TouchTestProvider>(
          builder: (context, provider, _) {
            String instruction;
            if (!provider.leftTapped) {
              instruction = 'Please tap the LEFT earphone';
            } else if (!provider.rightTapped) {
              instruction = 'Now tap the RIGHT earphone';
            } else {
              instruction = 'Test complete! 🎉';
            }

            return Column(
              children: [
                SizedBox(height: 20),
                Text(instruction, style: TextStyle(fontSize: 20)),
                Expanded(
                  child: Row(
                    children: [
                      // Left earphone zone
                      Expanded(
                        child: GestureDetector(
                          onTap: provider.tapLeft,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            margin: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: provider.leftTapped ? Colors.green[200] : Colors.grey[300],
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: Text('LEFT', style: TextStyle(fontSize: 18))),
                          ),
                        ),
                      ),
                      // Right earphone zone
                      Expanded(
                        child: GestureDetector(
                          onTap: provider.tapRight,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            margin: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: provider.rightTapped ? Colors.green[200] : Colors.grey[300],
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: Text('RIGHT', style: TextStyle(fontSize: 18))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (provider.isComplete) ...[
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: provider.reset,
                    child: Text('Reset Test'),
                  ),
                  SizedBox(height: 20),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
