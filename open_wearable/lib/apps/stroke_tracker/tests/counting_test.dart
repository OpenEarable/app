import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class CountingTest extends StatefulWidget {
  final VoidCallback onCompleted;
  const CountingTest({Key? key, required this.onCompleted}) : super(key: key);

  @override
  State<CountingTest> createState() => _CountingTestState();
}

class _CountingTestState extends State<CountingTest> {
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

  void _initializeSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
          if (status == stt.SpeechToText.listeningStatus) {
            setState(() => _isListening = true);
          } else if (status == stt.SpeechToText.notListeningStatus) {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          print('Speech error: ${error.errorMsg}');
          setState(() {
            _isListening = false;
            _feedback = 'Error: ${error.errorMsg}';
          });
        },
      );

      if (available) {
        setState(() => _speechEnabled = true);
        
        // Get available locales
        List<stt.LocaleName> locales = await _speech.locales();
        print('Available locales: ${locales.map((l) => l.localeId).join(', ')}');
        
        // Find the best English locale
        String? bestLocale = locales
            .where((l) => l.localeId.startsWith('en'))
            .map((l) => l.localeId)
            .firstOrNull;
        
        _currentLocale = bestLocale ?? 'en_US';
        print('Using locale: $_currentLocale');
        
        setState(() => _feedback = 'Speech recognition ready');
      } else {
        setState(() {
          _speechEnabled = false;
          _feedback = 'Speech recognition not available';
        });
      }
    } catch (e) {
      print('Speech initialization error: $e');
      setState(() {
        _speechEnabled = false;
        _feedback = 'Failed to initialize speech recognition';
      });
    }
  }

  void _startListening() async {
    if (!_speechEnabled) {
      setState(() => _feedback = 'Speech recognition not available');
      return;
    }

    try {
      setState(() {
        _text = '';
        _feedback = 'Listening... Say numbers 0 to 10';
        _soundLevel = 0.0;
      });

      await _speech.listen(
        onResult: (result) {
          print('Speech result: "${result.recognizedWords}" (final: ${result.finalResult})');
          setState(() {
            _text = result.recognizedWords;
            // Check on partial results too, not just final
            _checkCounting(result.recognizedWords);
          });
        },
        onSoundLevelChange: (level) {
          setState(() => _soundLevel = level);
        },
        listenFor: const Duration(seconds: 90), // Much longer
        pauseFor: const Duration(seconds: 5),   // Longer pause tolerance
        partialResults: true,
        localeId: _currentLocale,
        cancelOnError: false,
      );
    } catch (e) {
      print('Listen error: $e');
      setState(() {
        _isListening = false;
        _feedback = 'Error starting speech recognition';
      });
    }
  }

  void _stopListening() {
    if (_speech.isListening) {
      _speech.stop();
    }
    setState(() => _isListening = false);
  }

  void _checkCounting(String spokenText) {
    if (spokenText.isEmpty) return;

    print('Checking: "$spokenText"');
    
    // Convert to lowercase and clean up
    String cleaned = spokenText.toLowerCase().trim();
    
    // Define number patterns to match
    List<RegExp> patterns = [
      // Numbers as words: "zero one two three four five six seven eight nine ten"
      RegExp(r'\b(zero|one|two|three|four|five|six|seven|eight|nine|ten)\b'),
      // Numbers as digits: "0 1 2 3 4 5 6 7 8 9 10"
      RegExp(r'\b([0-9]|10)\b'),
      // Mixed: "0 one 2 three" etc.
    ];

    // Extract all number-like words
    Set<String> foundNumbers = {};
    for (RegExp pattern in patterns) {
      foundNumbers.addAll(pattern.allMatches(cleaned).map((m) => m.group(0)!));
    }

    print('Found numbers: $foundNumbers');

    // Convert words to numbers for comparison
    Map<String, int> wordToNum = {
      'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
      '0': 0, '1': 1, '2': 2, '3': 3, '4': 4, '5': 5,
      '6': 6, '7': 7, '8': 8, '9': 9, '10': 10,
    };

    // Convert found numbers to integers
    Set<int> foundInts = foundNumbers
        .where((word) => wordToNum.containsKey(word))
        .map((word) => wordToNum[word]!)
        .toSet();

    print('Found integers: $foundInts');

    // Check if we have enough sequential numbers
    List<int> sortedFound = foundInts.toList()..sort();
    
    // Success if we have at least 8 numbers and they include 0 and some high numbers
    bool hasGoodRange = foundInts.contains(0) && 
                       foundInts.where((n) => n >= 7).isNotEmpty &&
                       foundInts.length >= 8;

    if (hasGoodRange) {
      setState(() => _feedback = '✅ Great! Counting recognized successfully!');
      _stopListening();
      Future.delayed(const Duration(seconds: 2), widget.onCompleted);
    } else if (foundInts.length >= 4) {
      setState(() => _feedback = '⚠️ Good start! Please try to count all numbers from 0 to 10');
    } else {
      setState(() => _feedback = '❌ Please count clearly from 0 to 10');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Please count from 0 to 10 out loud."),
          const SizedBox(height: 8),
          
          if (_isListening) ...[
            const Text("Listening...", style: TextStyle(color: Colors.blue)),
            const SizedBox(height: 4),
            // Compact sound level indicator
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
                       _feedback!.startsWith('⚠️') ? Colors.orange :
                       _feedback!.startsWith('❌') ? Colors.red : Colors.blue,
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          Row(
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
