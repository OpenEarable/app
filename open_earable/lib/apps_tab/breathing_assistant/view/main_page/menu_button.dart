import 'package:flutter/material.dart';

/// A reusable [MenuButton] widget that provides a styled button with an icon and text.
/// 
///
class MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  /// Creates a [MenuButton] with the specified [label], [icon], [color], and [onPressed] callback.
  const MenuButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
        elevation: 5, 
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, 
        children: [
          // The icon displayed to the left of the label
          Icon(icon, size: 30, color: Colors.white),

          const SizedBox(width: 10),

          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
