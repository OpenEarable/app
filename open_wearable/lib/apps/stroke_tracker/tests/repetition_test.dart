import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class RepetitionTest extends StatefulWidget {
  final VoidCallback onCompleted;
  const RepetitionTest({Key? key, required this.onCompleted}) : super(key: key);

  @override
  State<RepetitionTest> createState() => _RepetitionTestState();
}

class _RepetitionTestState extends State<RepetitionTest> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _spokenText = '';

  final List<String> _phrases = [
    "Today is a sunny day",
    "The quick brown fox jumps over the lazy dog"
  ];

  int _currentPhraseIndex = 0;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
    setState(() {});
  }

  void _listen() async {
    if (!_isListening) {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _spokenText = result.recognizedWords;
          });
        },
      );
    }
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);

    if (_spokenText.toLowerCase().contains(
        _phrases[_currentPhraseIndex].toLowerCase())) {
      _nextPhrase();
    } else {
      _retryPhrase();
    }
  }

  void _nextPhrase() {
    if (_currentPhraseIndex < _phrases.length - 1) {
      setState(() {
        _currentPhraseIndex++;
        _spokenText = '';
      });
    } else {
      widget.onCompleted();
    }
  }

  void _retryPhrase() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please try again.')),
    );
    setState(() {
      _spokenText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Repetition Test")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Repeat the phrase:\n\"${_phrases[_currentPhraseIndex]}\"",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isListening ? _stopListening : _listen,
              child: Text(_isListening ? "Stop" : "Start Speaking"),
            ),
            const SizedBox(height: 20),
            Text(
              "You said: $_spokenText",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
