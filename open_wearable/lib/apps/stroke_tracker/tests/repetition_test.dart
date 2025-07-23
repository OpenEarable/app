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
  bool _speechEnabled = false;
  String _text = '';
  String? _feedback;
  double _soundLevel = 0.0;
  String _currentLocale = '';
  
  int _currentPhraseIndex = 0;
  List<bool> _completedPhrases = [false, false];
  
  final List<String> _phrases = [
    "Today is a sunny day",
    "The quick brown fox jumps over the lazy dog"
  ];

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
        
        setState(() => _feedback = 'Speech recognition ready. Click "Start" to begin.');
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

    if (_currentPhraseIndex >= _phrases.length) {
      _completeTest();
      return;
    }

    try {
      setState(() {
        _text = '';
        _feedback = 'Listening... Please say: "${_phrases[_currentPhraseIndex]}"';
        _soundLevel = 0.0;
      });

      await _speech.listen(
        onResult: (result) {
          print('Speech result: "${result.recognizedWords}" (final: ${result.finalResult})');
          setState(() {
            _text = result.recognizedWords;
            // Check on partial results too
            _checkRepetition(result.recognizedWords);
          });
        },
        onSoundLevelChange: (level) {
          setState(() => _soundLevel = level);
        },
        listenFor: const Duration(seconds: 90), // Long duration like counting test
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

  void _checkRepetition(String spokenText) {
    if (spokenText.isEmpty || _currentPhraseIndex >= _phrases.length) return;

    print('Checking phrase ${_currentPhraseIndex + 1}: "$spokenText"');
    
    String targetPhrase = _phrases[_currentPhraseIndex].toLowerCase();
    String spokenLower = spokenText.toLowerCase().trim();
    
    // Calculate similarity - more flexible matching
    double similarity = _calculateSimilarity(targetPhrase, spokenLower);
    print('Similarity: $similarity');
    
    if (similarity > 0.7) { // 70% similarity threshold
      setState(() {
        _completedPhrases[_currentPhraseIndex] = true;
        _feedback = '✅ Great! Moving to next phrase...';
      });
      
      _stopListening();
      
      // Move to next phrase after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _currentPhraseIndex++;
            _text = '';
          });
          
          if (_currentPhraseIndex >= _phrases.length) {
            _completeTest();
          } else {
            setState(() => _feedback = 'Ready for next phrase. Click "Start" when ready.');
          }
        }
      });
    } else if (similarity > 0.4) { // Partial match
      setState(() => _feedback = '⚠️ Close! Please try to repeat more clearly: "${_phrases[_currentPhraseIndex]}"');
    } else {
      setState(() => _feedback = '❌ Please repeat: "${_phrases[_currentPhraseIndex]}"');
    }
  }
  
  double _calculateSimilarity(String target, String spoken) {
    // Simple word-based similarity calculation
    List<String> targetWords = target.split(' ');
    List<String> spokenWords = spoken.split(' ');
    
    int matches = 0;
    for (String targetWord in targetWords) {
      for (String spokenWord in spokenWords) {
        // Check for exact match or close match (handles common speech-to-text variations)
        if (spokenWord.contains(targetWord) || targetWord.contains(spokenWord) ||
            _levenshteinDistance(targetWord, spokenWord) <= 2) {
          matches++;
          break;
        }
      }
    }
    
    return matches / targetWords.length;
  }
  
  int _levenshteinDistance(String s1, String s2) {
    if (s1.length < s2.length) {
      return _levenshteinDistance(s2, s1);
    }
    
    if (s2.isEmpty) {
      return s1.length;
    }
    
    List<int> previousRow = List.generate(s2.length + 1, (i) => i);
    
    for (int i = 0; i < s1.length; i++) {
      List<int> currentRow = [i + 1];
      
      for (int j = 0; j < s2.length; j++) {
        int insertCost = previousRow[j + 1] + 1;
        int deleteCost = currentRow[j] + 1;
        int replaceCost = previousRow[j];
        
        if (s1[i] != s2[j]) {
          replaceCost += 1;
        }
        
        currentRow.add([insertCost, deleteCost, replaceCost].reduce((a, b) => a < b ? a : b));
      }
      
      previousRow = currentRow;
    }
    
    return previousRow.last;
  }

  void _completeTest() {
    setState(() => _feedback = '✅ All phrases completed successfully!');
    Future.delayed(const Duration(seconds: 2), widget.onCompleted);
  }

  void _resetTest() {
    setState(() {
      _currentPhraseIndex = 0;
      _completedPhrases = [false, false];
      _text = '';
      _feedback = 'Test reset. Click "Start" to begin.';
    });
    _stopListening();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Repetition Test - Phrase ${_currentPhraseIndex + 1} of ${_phrases.length}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Show current phrase to repeat
          if (_currentPhraseIndex < _phrases.length) ...[
            const Text("Please repeat:", style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                '"${_phrases[_currentPhraseIndex]}"',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Progress indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _phrases.asMap().entries.map((entry) {
              int index = entry.key;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  _completedPhrases[index] 
                    ? Icons.check_circle 
                    : (index == _currentPhraseIndex ? Icons.radio_button_unchecked : Icons.circle_outlined),
                  color: _completedPhrases[index] 
                    ? Colors.green 
                    : (index == _currentPhraseIndex ? Colors.blue : Colors.grey),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
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
            _text.isEmpty ? "(Your speech will appear here)" : _text,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          
          if (_feedback != null) ...[
            const SizedBox(height: 8),
            Text(
              _feedback!,
              style: TextStyle(
                color: _feedback!.startsWith('✅') ? Colors.green : 
                       _feedback!.startsWith('⚠️') ? Colors.orange :
                       _feedback!.startsWith('❌') ? Colors.red : Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                label: Text(_isListening ? "Stop" : "Start"),
                onPressed: _speechEnabled && _currentPhraseIndex < _phrases.length
                  ? (_isListening ? _stopListening : _startListening) 
                  : null,
              ),
              if (_currentPhraseIndex > 0 && _currentPhraseIndex < _phrases.length)
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Reset"),
                  onPressed: _resetTest,
                ),
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