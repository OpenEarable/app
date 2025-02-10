import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/cpready/model/data.dart';
import 'package:open_earable/apps_tab/cpready/utils.dart';

/// Widget that displays a [CPRInstruction].
class CprInstructionView extends StatelessWidget {
  const CprInstructionView({
    super.key,
    required CPRInstruction instruction,
  }) : _instruction = instruction;

  /// The instruction that is displayed.
  final CPRInstruction _instruction;

  @override
  Widget build(BuildContext context) {
    return Text(
      _instruction.messageString,
      style: TextStyle(
        fontSize: 50,
        color: _instruction.color,
      ),
      textScaler:
          TextScaler.linear(textScaleFactor(context, maxTextScaleFactor: 1.5)),
    );
  }
}
