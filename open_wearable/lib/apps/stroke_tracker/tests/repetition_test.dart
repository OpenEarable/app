import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class RepetitionTest extends StatefulWidget {
  final VoidCallback onCompleted;
  const RepetitionTest({Key? key, required this.onCompleted}) : super(key: key);

  @override
  State<RepetitionTest> createState() => _RepetitionTestState();
}

class _RepetitionTestState extends State<RepetitionTest> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _ttsEnabled = false;
  String _text = '';
  String? _feedback;
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
    _flutterTts = FlutterTts();
    _initializeSpeech();
    _initializeTts();
  }

  void _initializeTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(0.8);
      await _flutterTts.setPitch(1.0);
      setState(() => _ttsEnabled = true);
    } catch (e) {
      print('TTS initialization error: $e');
      setState(() => _ttsEnabled = false);
    }
  }

  void _speakPhrase(String phrase) async {
    if (_ttsEnabled) {
      await _flutterTts.speak(phrase);
    }
  }

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

        List<stt.LocaleName> locales = await _speech.locales();
        String? bestLocale = locales
            .where((l) => l.localeId.startsWith('en'))
            .map((l) => l.localeId)
            .firstOrNull;
        
        _currentLocale = bestLocale ?? 'en_US';
        
        setState(() => _feedback = 'Speech recognition ready. Click "Start" to begin.');
        
        Future.delayed(const Duration(milliseconds: 500), () {
          _speakPhrase(_phrases[0]);
        });
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
      });

      // _speakPhrase(_phrases[_currentPhraseIndex]);

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _text = result.recognizedWords;
            _checkRepetition(result.recognizedWords);
          });
        },
        listenFor: const Duration(seconds: 90),
        pauseFor: const Duration(seconds: 5),
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

  void _stopListening() {
    if (_speech.isListening) {
      _speech.stop();
    }
    setState(() => _isListening = false);
  }

  void _checkRepetition(String spokenText) {
    if (spokenText.isEmpty || _currentPhraseIndex >= _phrases.length) return;

    String targetPhrase = _phrases[_currentPhraseIndex].toLowerCase();
    String spokenLower = spokenText.toLowerCase().trim();
    
    double similarity = _calculateSimilarity(targetPhrase, spokenLower);
    
    if (similarity > 0.7) {
      setState(() {
        _completedPhrases[_currentPhraseIndex] = true;
        
        if (_currentPhraseIndex == _phrases.length - 1) {
          _feedback = '✅ Excellent! All phrases completed successfully!';
        } else {
          _feedback = '✅ Great! Moving to next phrase...';
        }
      });
      
      _stopListening();
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _currentPhraseIndex++;
            _text = '';
          });
          
          if (_currentPhraseIndex >= _phrases.length) {
            bool allCompleted = _completedPhrases.every((completed) => completed);
            if (allCompleted) {
              _completeTest();
            } else {
              _currentPhraseIndex = _completedPhrases.indexWhere((completed) => !completed);
              setState(() => _feedback = 'Please complete the remaining phrases. Click "Start" when ready.');
            }
          } else {
            setState(() => _feedback = 'Ready for next phrase. Click "Start" when ready.');
            _speakPhrase(_phrases[_currentPhraseIndex]);
          }
        }
      });
    } else if (similarity > 0.4) {
      setState(() => _feedback = '⚠️ Close! Please try to repeat more clearly: "${_phrases[_currentPhraseIndex]}"');
    } else {
      setState(() => _feedback = '❌ Please repeat: "${_phrases[_currentPhraseIndex]}"');
    }
  }
  
  double _calculateSimilarity(String target, String spoken) {
    List<String> targetWords = target.split(' ');
    List<String> spokenWords = spoken.split(' ');
    
    int matches = 0;
    for (String targetWord in targetWords) {
      for (String spokenWord in spokenWords) {
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
    bool allCompleted = _completedPhrases.every((completed) => completed);
    if (allCompleted) {
      setState(() => _feedback = '✅ Repetition test completed! Both phrases repeated correctly.');
      Future.delayed(const Duration(seconds: 2), widget.onCompleted);
    } else {
      setState(() {
        _feedback = 'Please complete all phrases before finishing the test.';
        _currentPhraseIndex = _completedPhrases.indexWhere((completed) => !completed);
      });
    }
  }

  void _resetTest() {
    setState(() {
      _currentPhraseIndex = 0;
      _completedPhrases = [false, false];
      _text = '';
      _feedback = 'Test reset. Click "Start" to begin with the first phrase.';
    });
    _stopListening();
    Future.delayed(const Duration(milliseconds: 500), () {
      _speakPhrase(_phrases[0]);
    });
  }

  @override
    Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (_currentPhraseIndex < _phrases.length) ...[
            const Text("Please repeat:", style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              '"${_phrases[_currentPhraseIndex]}"',  // Just a regular Text widget
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
