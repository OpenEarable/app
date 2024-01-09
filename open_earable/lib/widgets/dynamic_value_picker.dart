import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

class DynamicValuePicker extends StatelessWidget {
  final BuildContext context;
  final List<String> options;
  final String currentValue;
  final Function(String) onValueChange;
  final Function(bool) onValueNotZero;
  final bool isConnected;

  DynamicValuePicker(
    this.context,
    this.options,
    this.currentValue,
    this.onValueChange,
    this.onValueNotZero,
    this.isConnected,
  );

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoButton(
        borderRadius: BorderRadius.all(Radius.circular(4.0)),
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              currentValue,
              style: TextStyle(
                color: isConnected ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
        onPressed: () => _showCupertinoPicker(),
      );
    } else {
      return DropdownButton<String>(
        dropdownColor: isConnected ? Colors.white : Colors.grey[200],
        alignment: Alignment.centerRight,
        value: currentValue,
        onChanged: (String? newValue) {
          onValueChange(newValue!);
          if (int.parse(newValue) != 0) {
            onValueNotZero(true);
          } else {
            onValueNotZero(false);
          }
        },
        items: options.map((String value) {
          return DropdownMenuItem<String>(
            alignment: Alignment.centerRight,
            value: value,
            child: Text(
              value,
              style: TextStyle(
                color: isConnected ? Colors.black : Colors.grey,
              ),
              textAlign: TextAlign.end,
            ),
          );
        }).toList(),
        underline: Container(),
        icon: Icon(
          Icons.arrow_drop_down,
          color: isConnected ? Colors.black : Colors.grey,
        ),
      );
    }
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
          itemExtent: 32, // Height of each item
          onSelectedItemChanged: (int index) {
            String newValue = options[index];
            int? newValueInt = int.tryParse(newValue);
            onValueChange(newValue);
            if (newValueInt != 0) {
              onValueNotZero(true);
            } else {
              onValueNotZero(false);
            }
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
