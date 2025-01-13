import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/model/pomodoro_config.dart';

/// Showcase for the PomodoroConfig
/// shows minutes for work and break and repetitions left
class PomodoroConfigShowcase extends StatelessWidget {
  final PomodoroConfig pomodoroConfig;
  const PomodoroConfigShowcase(this.pomodoroConfig, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Flex(
        direction: Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.center,
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          getText("work minutes: ${pomodoroConfig.workMinutes}"),
          getText("break minutes: ${pomodoroConfig.breakMinutes}"),
          getText("repetitions left: ${pomodoroConfig.repetitions}"),
        ],
      ),
    );
  }



  /// Returns a text widget with the given text in a consistent Styling
  Widget getText(String text) {
    return Padding(
      padding: const EdgeInsets.all(1.0),
      child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: Colors.green, borderRadius: BorderRadius.circular(30),),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              text,
              style: TextStyle(fontSize: 11),
            ),
          ),),
    );
  }
}
