import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/cpready/model/data.dart';
import 'package:open_earable/apps_tab/cpready/utils.dart';

class CPRInstructionView extends StatelessWidget {
  const CPRInstructionView({super.key, required CPRInstruction instruction}) : _instruction = instruction;

  final CPRInstruction _instruction;

  @override
  Widget build(BuildContext context) {
    return Text(
      _instruction.messageString,
      style: TextStyle(
        fontSize: 50,
        color: _instruction.color,
      ),
      textScaler: TextScaler.linear(textScaleFactor(context)),
    );
  }
}
