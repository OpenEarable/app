import 'package:flutter/material.dart';

class CprStartButton extends StatelessWidget {
  const CprStartButton(
      {super.key, required bool doingCPR, required VoidCallback onPressed, required double size})
      : _doingCPR = doingCPR,
        _onPressed = onPressed,
        _size = size;

  final bool _doingCPR;
  final VoidCallback _onPressed;
  final double _size;

  @override
  Widget build(BuildContext context) {
    return Center(
      //Button for starting the CPR
      child: ElevatedButton(
        style: ButtonStyle(
          elevation: WidgetStateProperty.all(20),
          fixedSize: WidgetStateProperty.all(
            _doingCPR
                ? Size(_size / 4, _size / 4)
                : Size(_size, _size),
          ),
          backgroundColor: WidgetStateProperty.all(Colors.redAccent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_doingCPR ? 10 : 100),
            ),
          ),
        ),
        onPressed: _onPressed,
        child: Text(
          _doingCPR ? "Stop CPR" : "Start CPR",
          textAlign: TextAlign.center,
          style: _doingCPR
              ? Theme
              .of(context)
              .textTheme
              .bodyMedium!
              .copyWith(fontWeight: FontWeight.bold)
              : Theme
              .of(context)
              .textTheme
              .displayMedium!
              .copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
