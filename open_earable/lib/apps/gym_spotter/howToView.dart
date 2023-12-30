import 'package:flutter/material.dart';
import 'package:open_earable/apps/gym_spotter/return_button.dart';

class HowToRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text('GYMKnopf'),
      ),
      floatingActionButton: returnButton(),
      body: Column(
        children: [
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 24,
              backgroundColor: Theme.of(context).colorScheme.background,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            child: const Center(
              child: Text('How to Deadlift properly'),
            ),
          ),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 20,
              backgroundColor: Theme.of(context).colorScheme.primary,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            child: const Text(
                'Step 1: Stand shoulder-width apart and place your mid-foots below the bar'),
          ),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 20,
              backgroundColor: Theme.of(context).colorScheme.primary,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            child: const Text(
                'Step 2: Bend over and grab the bar just outside your knees'),
          ),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 20,
              backgroundColor: Theme.of(context).colorScheme.primary,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            child: const Text(
                'Step 3: Bend your knees until your shin touches the bar'),
          ),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 20,
              backgroundColor: Theme.of(context).colorScheme.primary,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            child: const Text(
                'Step 4: Squeeze your shoulder blades together to lift your Chest up'),
          ),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 20,
              backgroundColor: Theme.of(context).colorScheme.primary,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            child: const Text(
                'Step 5: make sure your back is straight by engaging your core. Your head should be an extention your spine'),
          ),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 20,
              backgroundColor: Theme.of(context).colorScheme.primary,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            child: const Text(
                'Step 6: Lift the bar up by pushing your feet through the floor untill the bar passes your knees'),
          ),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 20,
              backgroundColor: Theme.of(context).colorScheme.primary,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            child: const Text(
                'Step 7: Finish the lift by pushing your hips forward'),
          ),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 20,
              backgroundColor: Theme.of(context).colorScheme.primary,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            child: const Text(
                'Step 8: To lower the bar again push your hips back untill the bar passes your knee, then bend your knees untill the plates hit the ground'),
          ),
        ],
      ),
    );
  }
}
