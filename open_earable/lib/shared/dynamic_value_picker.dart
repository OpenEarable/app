import 'package:flutter/material.dart';

class DynamicValuePicker extends StatelessWidget {
  final BuildContext context;
  final List<String> options;
  final String currentValue;
  final Function(String) onValueChange;
  final bool isConnected;
  final bool isFakeDisabled;

  const DynamicValuePicker(
    this.context,
    this.options,
    this.currentValue,
    this.onValueChange,
    this.isConnected,
    this.isFakeDisabled, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      dropdownColor: Colors.white,
      alignment: Alignment.centerRight,
      value: currentValue,
      onChanged: isConnected
          ? (String? newValue) {
              onValueChange(newValue!);
            }
          : null,
      items: options.map((String value) {
        return DropdownMenuItem<String>(
          alignment: Alignment.centerRight,
          value: value,
          child: Text(
            value,
            style: TextStyle(
              color: isFakeDisabled || !isConnected
                  ? Colors.grey[700]
                  : Colors.black,
            ),
            textAlign: TextAlign.end,
          ),
        );
      }).toList(),
      underline: Container(),
      icon: Icon(
        Icons.arrow_drop_down,
        color: isConnected ? Colors.black : Colors.grey[700],
      ),
    );
  }
}
