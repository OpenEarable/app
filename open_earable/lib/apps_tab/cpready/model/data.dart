
import 'package:flutter/material.dart';

enum CPRInstruction {
  fine(messageString: "You are doing great!", color: Colors.green),
  faster(messageString: "Go a little bit faster", color: Colors.redAccent),
  slower(messageString: "Go a little bit slower", color: Colors.redAccent);

  const CPRInstruction({
    required this.messageString,
    required this.color,
  });

  final String messageString;
  final Color color;
}
