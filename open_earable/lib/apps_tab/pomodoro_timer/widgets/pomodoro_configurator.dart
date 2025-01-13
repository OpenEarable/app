import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/model/pomodoro_config.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/widgets/assignment_text.dart';

class PomodoroConfigurator extends StatefulWidget {
  final PomodoroConfig pomodoroConfig;
  const PomodoroConfigurator(this.pomodoroConfig, {super.key});

  @override
  State<PomodoroConfigurator> createState() => _PomodoroConfiguratorState();
}

class _PomodoroConfiguratorState extends State<PomodoroConfigurator> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AssignmentText(
            "Select the length of work and break time in minutes and the number of repetitions!",),
        Flex(
          direction: Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: NumberPicker(
                    minValue: 1,
                    step: 1,
                    maxValue: 60,
                    value: widget.pomodoroConfig.workMinutes,
                    infiniteLoop: false,
                    onChanged: (newValue) => {
                      setState(() {
                        widget.pomodoroConfig.workMinutes = newValue;
                      }),
                    },
                  ),
                ),
                Text("minutes work"),
              ],
            ),
            VerticalDivider(
              color: Colors.black,
              thickness: 1,
              width: 20,
              indent: 10,
              endIndent: 10,
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: NumberPicker(
                    minValue: 1,
                    maxValue: 60,
                    value: widget.pomodoroConfig.breakMinutes,
                    infiniteLoop: false,
                    onChanged: (value) => {
                      setState(() {
                        widget.pomodoroConfig.breakMinutes = value;
                        print(
                            "break minutes: ${widget.pomodoroConfig.breakMinutes}",);
                      }),
                    },
                  ),
                ),
                Text(
                  "minutes break",
                ),
              ],
            ),
          ],
        ),
        SizedBox(
          height: 20,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Divider(color: Colors.black, thickness: 0),
        ),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: NumberPicker(
                axis: Axis.horizontal,
                minValue: 0,
                maxValue: 99,
                value: widget.pomodoroConfig.repetitions,
                infiniteLoop: true,
                haptics: true,
                onChanged: (value) => {
                  setState(() {
                    widget.pomodoroConfig.repetitions = value;
                  }),
                },
              ),
            ),
            Text("${widget.pomodoroConfig.repetitions} repetitions"),
          ],
        ),
      ],
    );
  }
}
