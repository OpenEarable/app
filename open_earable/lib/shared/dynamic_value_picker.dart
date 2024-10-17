import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

class DynamicValuePicker extends StatelessWidget {
  final BuildContext context;
  final List<String> options;
  final String currentValue;
  final Function(String) onValueChange;
  final bool isConnected;
  final bool isFakeDisabled;

  DynamicValuePicker(
    this.context,
    this.options,
    this.currentValue,
    this.onValueChange,
    this.isConnected,
    this.isFakeDisabled,
  );

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
              color: this.isFakeDisabled || !isConnected
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

  void _showCupertinoPicker() {
    var currentIndex = options.indexOf(currentValue);
    final FixedExtentScrollController scrollController =
        FixedExtentScrollController(initialItem: currentIndex);
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 200,
        color: Colors.white,
        child: CupertinoPicker(
          scrollController: scrollController,
          backgroundColor: isConnected ? Colors.white : Colors.grey[200],
          itemExtent: 32,
          // Height of each item
          onSelectedItemChanged: (int index) {
            String newValue = options[index];
            onValueChange(newValue);
          },
          children: options
              .map((String value) => Center(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: isConnected ? Colors.black : Colors.grey,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
