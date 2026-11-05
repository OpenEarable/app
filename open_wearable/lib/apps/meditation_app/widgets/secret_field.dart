import 'package:flutter/material.dart';

class SecretField extends StatefulWidget {
  final String title;
  final String description;
  final ValueChanged<String>? onChanged;
  final String? initialValue;

  const SecretField({
    super.key,
    required this.title,
    required this.description,
    this.onChanged,
    this.initialValue,
  });

  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool _isObscured = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          obscureText: _isObscured,
          autocorrect: false,
          enableSuggestions: false,
          initialValue: widget.initialValue,
          keyboardType: TextInputType.visiblePassword,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.description,
            suffixIcon: IconButton(
              tooltip: _isObscured ? 'Show value' : 'Hide value',
              onPressed: () => setState(() => _isObscured = !_isObscured),
              icon: Icon(
                _isObscured ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
