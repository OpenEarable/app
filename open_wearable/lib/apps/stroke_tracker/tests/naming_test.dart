import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// A speech-based naming test widget that prompts the user to name an animal
// (expected: "elephant") and provides feedback based on the spoken input
// using speech recognition.

class NamingTest extends StatefulWidget {
  final VoidCallback onCompleted;

  const NamingTest({Key? key, required this.onCompleted}) : super(key: key);

  @override
  State<NamingTest> createState() => _NamingTestState();
}

class _NamingTestState extends State<NamingTest> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _text = '';
  String? _feedback;
  double _soundLevel = 0.0;
  String _currentLocale = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();
  }

  // Initializes the speech recognition engine and chooses the best locale.
  void _initializeSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == stt.SpeechToText.listeningStatus) {
            setState(() => _isListening = true);
          } else if (status == stt.SpeechToText.notListeningStatus) {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          setState(() {
            _isListening = false;
            _feedback = 'Error: ${error.errorMsg}';
          });
        },
      );

      if (available) {
        setState(() => _speechEnabled = true);

        // Picks the best available English locale
        List<stt.LocaleName> locales = await _speech.locales();
        String? bestLocale = locales.where((l) => l.localeId.startsWith('en')).map((l) => l.localeId).firstOrNull;
        _currentLocale = bestLocale ?? 'en_US';
      } else {
        setState(() {
          _speechEnabled = false;
          _feedback = 'Speech recognition not available';
        });
      }
    } catch (e) {
      setState(() {
        _speechEnabled = false;
        _feedback = 'Failed to initialize speech recognition';
      });
    }
  }


  // Begins listening for speech and handles recognition results
  void _startListening() async {
    if (!_speechEnabled) {
      setState(() => _feedback = 'Speech recognition not available');
      return;
    }

    try {
      setState(() {
        _text = '';
        _feedback = 'Listening...';
        _soundLevel = 0.0;
      });

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _text = result.recognizedWords;
            _checkAnswer(result.recognizedWords);
          });
        },
        onSoundLevelChange: (level) {
          setState(() => _soundLevel = level);
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: _currentLocale,
        cancelOnError: false,
      );
    } catch (e) {
      setState(() {
        _isListening = false;
        _feedback = 'Error starting speech recognition';
      });
    }
  }


  // Stops speech recognition and resets the state
  void _stopListening() {
    if (_speech.isListening) {
      _speech.stop();
    }
    setState(() => _isListening = false);
  }

  // Validates the spoken text against accepted variations of "elephant".
  void _checkAnswer(String spokenText) {
    if (spokenText.isEmpty) return;

    String answer = spokenText.trim().toLowerCase();

    // Accept a few plausible correct responses:
    List<String> acceptable = [
      "elephant",
      "an elephant",
      "the elephant",
      "a big elephant",
      "large elephant",
      "big elephant"
    ];

    // If the answer includes "elephant" at all, that's enough, a partial match
    // is considered correct.
    bool containsElephant = answer.contains("elephant");

    if (acceptable.contains(answer) || containsElephant) {
      setState(() => _feedback = '✅ Correct! The answer is elephant.');
      _stopListening();
      Future.delayed(const Duration(seconds: 2), widget.onCompleted);
    } else if (answer.isNotEmpty) {
      setState(() => _feedback = '❌ That’s not quite right. Try again or say "elephant".');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Please name the large gray animal that roams in Africa.",
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Shows live feedback when listening
          if (_isListening) ...[
            const Text("Listening...", style: TextStyle(color: Colors.blue)),
            const SizedBox(height: 4),
            Container(
              width: 120,
              height: 6,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _soundLevel,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _soundLevel > 0.3 ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            _text.isEmpty ? "(Speech will appear here)" : _text,
            style: const TextStyle(fontSize: 16),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 6),
            Text(
              _feedback!,
              style: TextStyle(
                color: _feedback!.startsWith('✅') ? Colors.green :
                       _feedback!.startsWith('❌') ? Colors.red : Colors.blue,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            // Control buttons: stop/start speech or skip
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                label: Text(_isListening ? "Stop" : "Start Listening"),
                onPressed: _speechEnabled ? (_isListening ? _stopListening : _startListening) : null,
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: widget.onCompleted,
                child: const Text("Skip/Done"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
