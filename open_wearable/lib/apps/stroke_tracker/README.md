Stroke Detection Flutter App

A Flutter app designed for tracking stroke recovery through a series of interactive tests. The app guides users through various stages that assess different cognitive and motor skills to detect signs of a stroke.

Features:
    Interactive Tests: Guides the user through tests such as counting, direction following, touch response, mouth movement, and naming tasks.

    Text-to-Speech (TTS): Provides audio instructions for each step to ensure accessibility.

    Wearable Integration: Supports integration with wearable devices to enhance testing accuracy.

    Test Feedback: Displays real-time feedback on the user's performance with a detailed progress panel.

    Pause, Resume, and Skip: Allows the user to pause, resume, and skip tests during the sequence.

    Results: Calculates the stroke probability based on the user's performance across various tests.

Requirements:
    Flutter SDK

    Dart SDK

    flutter_tts package (for text-to-speech functionality)

    open_earable_flutter package (for wearable integration)

    Android or iOS device with Bluetooth support (for wearable device integration)

App Overview:
    The app consists of a series of tests designed to assess different cognitive and motor skills. These tests include:

    Counting Test: The user counts from 1 to 10 aloud.

    Direction Test: The user turns their head in the direction a sound is played.

    Touch Test: The user is asked to touch their left and right earphones with the opposite hand.

    Repetition Test: The user repeats phrases such as "Today is a sunny day" and "The quick brown fox jumps over the lazy dog".

    Mouth Movement Test: The user is asked to hold a neutral expression and then smile.

    Naming Test: The user is asked to name a large gray animal that roams in Africa (e.g., Elephant).

Code Structure:
    stroke_tracker_view.dart: The main screen that handles the test flow and user interface.

    test_feedback_panel.dart: A widget that shows feedback on the status of each test.

    test_progress_bubbles.dart: A widget that shows the current progress of the tests.

    tests/: Contains the individual test widgets such as counting_test.dart, direction_test.dart, etc.

    models/test_feedback.dart: A model class to store feedback data for each test.