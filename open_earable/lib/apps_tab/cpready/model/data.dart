
import 'package:flutter/material.dart';

/// Enum for the possible instructions during a CPR.
/// Stores a [messageString] and a [color] for each instruction.
enum CPRInstruction {
  fine(messageString: "You are doing great!", color: Colors.green),
  faster(messageString: "Go a little bit faster", color: Colors.deepOrangeAccent),
  slower(messageString: "Go a little bit slower", color: Colors.deepOrangeAccent),
  muchFaster(messageString: "Go faster!", color: Colors.red),
  muchSlower(messageString: "Go slower!", color: Colors.red);


  const CPRInstruction({
    required this.messageString,
    required this.color,
  });

  /// The string of the message given with the instruction
  final String messageString;

  /// The color associated with the instruction
  final Color color;
}
