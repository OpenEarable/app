import 'package:flutter/material.dart';

// Generic text input in OpenEarable style
class TextInput extends StatelessWidget {

  final String initialValue;
  final String? hintText;
  final TextInputType keyboardType;
  final Function(String) onChanged;

  const TextInput({
    super.key,
    required this.initialValue,
    this.hintText = null,
    this.keyboardType = TextInputType.text,
    required this.onChanged
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.black),
      decoration: InputDecoration(
          contentPadding: EdgeInsets.all(10),
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: Colors.white
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: Colors.black
            ),
          ),
          filled: true,
          fillColor: Colors.white,
      ),
      onChanged: onChanged,
    );
  }
}
