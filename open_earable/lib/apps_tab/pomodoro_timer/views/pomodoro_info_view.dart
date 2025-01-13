import 'package:flutter/material.dart';

/// The view for the info view,
/// which explains the Pomodoro Timer app.
class PomodoroInfoView extends StatelessWidget {
  const PomodoroInfoView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pomodoro Timer Info'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pomodoro Timer',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Text(
              'The Pomodoro Timer app helps you manage your time effectively using the'
                  ' Pomodoro Technique.'
                  'This technique involves working for a set period, typically 25 minutes,'
                  ' followed by a short break. '
                  'The special feature of this app is that it includes '
                  'exercises to help you stay active.'
                  ' This includes one random exercise before the break,'
                  ' and one random exercise after the break.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: 16),
            Text(
              'Features:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text(
              '1. Start and stop the timer for work sessions and breaks.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              '2. Customize the duration of work sessions and breaks.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              '3. Customize the amount of exercise repetition in the settings.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              '4. Do random exercises before and after the breaks.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: 16),
            Text(
              'How to Use:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text(
              '1. Press the play button to start a work session.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              '2. When the timer ends, take a short break.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              '3. After four work sessions, take a longer break.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              '4. Adjust the settings to customize the duration of work sessions and breaks.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
