import 'package:flutter/material.dart';
import 'package:open_wearable/widgets/welcome_wizard/theme_settings.dart';
import 'package:provider/provider.dart';

class StartupWizard extends StatefulWidget {
  const StartupWizard({Key? key}) : super(key: key);

  @override
  State<StartupWizard> createState() => _StartupWizardDialogState();
}

class _StartupWizardDialogState extends State<StartupWizard> {
  int _currentStep = 0;

  late final List<Widget> steps = [
    // Step 1: Welcome Screen
    Column(
      children: [
        // TECO Logo Placeholder
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Image.asset(
            'lib/widgets/welcome_wizard/assets/teco-logo.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Welcome to OpenWearable',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          "Get ready to connect and use your wearable device with advanced posture and heart tracking. This quick setup will guide you through everything you need.",
          style: TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    ),
    // Step 2: Theme Selection
    Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.palette_outlined, size: 36, color: Colors.grey[700]),
        ),
        const SizedBox(height: 24),
        const Text(
          'Choose Your Theme',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Pick your favorite look. You can always change this later in the settings.",
          style: TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.light_mode),
              label: const Text('Light'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Provider.of<ThemeSettings>(context, listen: false).setTheme(ThemeMode.light);
              },
            ),
            const SizedBox(width: 18),
            ElevatedButton.icon(
              icon: const Icon(Icons.dark_mode),
              label: const Text('Dark'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Provider.of<ThemeSettings>(context, listen: false).setTheme(ThemeMode.dark);
              },
            ),
          ],
        ),
      ],
    ),
    // Step 3: Data is Info Page
    Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            border: Border.all(),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Image.asset(
            'lib/widgets/welcome_wizard/assets/encrypted.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Your Data, Your Device, 100% Secure',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "We respect your privacy. All data is stored locally on your device never shared, and never uploaded to the cloud. You're always in control.",
          style: TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    )
  ];

  void _next() {
    if (_currentStep < steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              steps[_currentStep],
              const SizedBox(height: 28),
              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  steps.length,
                      (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentStep == index ? 14 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentStep == index
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[400],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: _back,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 80),
                  ElevatedButton(
                    onPressed: _next,
                    child: Text(
                      _currentStep == steps.length - 1 ? 'Finish' : 'Next',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}