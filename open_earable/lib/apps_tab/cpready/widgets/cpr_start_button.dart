import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/cpready/utils.dart';

/// Widget that displays a button for starting the CPR procedure.
/// The button is a rounded square with length [size] and performs [onPressed] when pressed.
class CprStartButton extends StatelessWidget {
  const CprStartButton({
    super.key,
    required VoidCallback onPressed,
    required double size,
  })  : _onPressed = onPressed,
        _size = size;

  /// The function that is executed when the button is pressed.
  final VoidCallback _onPressed;

  /// The size of the button which is the width and the height.
  final double _size;

  @override
  Widget build(BuildContext context) {
    return Center(
      //Button for starting the CPR
      child: ElevatedButton(
        style: ButtonStyle(
          elevation: WidgetStateProperty.all(20),
          fixedSize: WidgetStateProperty.all(
            Size(_size, _size),
          ),
          backgroundColor: WidgetStateProperty.all(Colors.redAccent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
        onPressed: _onPressed,
        child: Text(
          "Start CPR",
          textAlign: TextAlign.center,
          style: Theme.of(context)
                  .textTheme
                  .displaySmall!
                  .copyWith(fontWeight: FontWeight.bold),
          textScaler: TextScaler.linear(textScaleFactor(context)),
        ),
      ),
    );
  }
}
