import 'package:flutter/material.dart';
import '../model/user_account.dart' show Gender;

class GenderSelector extends StatelessWidget {
  final Gender currentSelection;
  final ValueChanged<Gender> onChanged;

  const GenderSelector({
    super.key,
    required this.currentSelection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioGroup<Gender>(
      groupValue: currentSelection,
      onChanged: (Gender? value) {
        onChanged(value!);
      },
      child: Column(
        children: [
          RadioListTile<Gender>(
            title: Row(
              children: [
                Icon(Icons.male),
                const SizedBox(width: 8),
                Text('Male'),
              ],
            ),
            value: Gender.male,
          ),
          RadioListTile<Gender>(
            title: Row(
              children: [
                Icon(Icons.female),
                const SizedBox(width: 8),
                Text('Female'),
              ],
            ),
            value: Gender.female,
          ),
          RadioListTile<Gender>(
            title: Row(
              children: [
                Icon(Icons.person),
                const SizedBox(width: 8),
                Text('Non-Binary'),
              ],
            ),
            value: Gender.nonBinary,
          ),
          RadioListTile<Gender>(
            title: Row(
              children: [
                Icon(Icons.question_mark),
                const SizedBox(width: 8),
                Text('Unspecified'),
              ],
            ),
            value: Gender.unspecified,
          ),
        ],
      ),
    );
  }
}
