import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/cpready/model/data.dart';

class CPRInstructionView extends StatelessWidget {
  const CPRInstructionView({super.key, required this.instruction});

  final CPRInstruction instruction;

  @override
  Widget build(BuildContext context) {
    var style = Theme.of(context)
        .textTheme
        .bodyLarge!
        .copyWith(color: instruction.color);
    return Text(
      instruction.messageString,
      style: style,
    );
  }
}
