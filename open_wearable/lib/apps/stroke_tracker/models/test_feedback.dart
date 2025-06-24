import 'package:flutter/material.dart';

class TestFeedback {
  final String name;
  final IconData icon;
  String result;
  TestFeedback(this.name, this.icon, {this.result = "100%"});
}
