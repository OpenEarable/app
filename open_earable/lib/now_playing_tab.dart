import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:async';

class ActuatorsTab extends StatefulWidget {
  final OpenEarable _openEarable;
  ActuatorsTab(this._openEarable);
  @override
  _ActuatorsTabState createState() => _ActuatorsTabState(_openEarable);
}

class _ActuatorsTabState extends State<ActuatorsTab> {
  final OpenEarable _openEarable;
  _ActuatorsTabState(this._openEarable);
  bool isPlaying = false;
  bool songStarted = false;
  int currentSongIndex = 0;
  int elapsedTime = 0; // elapsed time in seconds
  Timer? _timer;
  Color _selectedColor = Colors.deepPurple;

  List<Map<String, dynamic>> songs = [
    {
      'title': 'Midnight City',
      'artist': 'M83',
      'albumCover':
          'https://i.scdn.co/image/ab67616d0000b273fff2cb485c36a6d8f639bdba',
      'duration': 243
    },
    {
      'title': 'Radioactive',
      'artist': 'Imagine Dragons',
      'albumCover':
          'https://i1.sndcdn.com/artworks-000069495641-rx1t0z-t500x500.jpg',
      'duration': 186
    },
    {
      'title': 'Lose Yourself to Dance',
      'artist': 'Daft Punk',
      'albumCover':
          'https://i1.sndcdn.com/artworks-nbWsTnCZR3m7yAyd-KBkcDQ-t500x500.jpg',
      'duration': 353
    },
  ];

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (elapsedTime < songs[currentSongIndex]['duration']) {
        setState(() {
          elapsedTime++;
        });
      } else {
        next_song();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
  }

  void _resetTimer() {
    setState(() {
      elapsedTime = 0;
    });
  }

  void togglePlay() {
    if (isPlaying) {
      _pauseTimer();
      _openEarable.wavAudioPlayer.writeWAVState(
          WavAudioPlayerState.pause, "${songs[currentSongIndex]['title']}.wav");
    } else {
      print("Playing ${songs[currentSongIndex]['title']}.wav");
      _startTimer();
      if (!songStarted) {
        _openEarable.wavAudioPlayer.writeWAVState(WavAudioPlayerState.start,
            "${songs[currentSongIndex]['title']}.wav");
      } else {
        _openEarable.wavAudioPlayer.writeWAVState(WavAudioPlayerState.unpause,
            "${songs[currentSongIndex]['title']}.wav");
      }
    }

    setState(() {
      isPlaying = !isPlaying;
    });
    // Implement actual play/pause logic here
  }

  void previous_song() {
    changeSong((currentSongIndex - 1) % songs.length);
  }

  void next_song() {
    changeSong((currentSongIndex + 1) % songs.length);
  }

  void changeSong(int newIndex) {
    _resetTimer();
    //_openEarable.wavAudioPlayer.writeWAVState(
    //    WavAudioPlayerState.stop, "${songs[currentSongIndex]['title']}.wav");

    setState(() {
      currentSongIndex = newIndex;
    });
    if (isPlaying) {
      Future.delayed(Duration(seconds: 2));
      _openEarable.wavAudioPlayer.writeWAVState(
          WavAudioPlayerState.start, "${songs[newIndex]['title']}.wav");
    }
  }

  String formatTime(int seconds) {
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color for the RGB LED'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) {
                setState(() {
                  _selectedColor = color;
                });
              },
              showLabel: true,
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progress = elapsedTime / songs[currentSongIndex]['duration'];
    final int remainingTime = songs[currentSongIndex]['duration'] - elapsedTime;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Card(
          //LED Color picker card
          color: Colors.black,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween, // Align to the right
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LED Color',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _openColorPicker,
                      child: Text('Configure RGB-LED color'),
                    ),
                    ElevatedButton(
                      onPressed: () {}, //TODO
                      child: Text('Turn on'),
                    )
                  ],
                ),
                Container(
                  width: 40,
                  height: 40,
                  color: _selectedColor,
                ),
              ],
            ),
          ),
        ),

        Card(
          //Audio Player Card
          color: Colors.black,
          child: Padding(
            padding: const EdgeInsets.all(16.0), // Add padding around all items
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio Player',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: togglePlay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff77F2A1),
                        foregroundColor: Colors.black,
                      ),
                      child: Icon(Icons.play_arrow),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 37.0, // Set the desired height
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: TextField(
                            obscureText: false,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'filename.wav',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10, width: 10),
                    ElevatedButton(
                      onPressed: togglePlay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xffe0f277),
                        foregroundColor: Colors.black,
                      ),
                      child: Icon(Icons.pause),
                    ),
                    SizedBox(height: 10, width: 5),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xfff27777),
                        foregroundColor: Colors.black,
                      ),
                      child: Icon(Icons.stop),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ClipRect(
        //   child: Image.network(
        //     songs[currentSongIndex]['albumCover'],
        //     width: 320,
        //     height: 320,
        //     fit: BoxFit.cover,
        //   ),
        // ),
        // SizedBox(height: 20),
        // Text(
        //   songs[currentSongIndex]['title'],
        //   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        // ),
        // Text(
        //   songs[currentSongIndex]['artist'],
        //   style: TextStyle(fontSize: 20, color: Colors.grey[700]),
        // ),
        // SizedBox(height: 20),
        // Column(
        //   children: [
        //     Row(
        //       mainAxisAlignment: MainAxisAlignment.center,
        //       children: [
        //         Text(
        //           formatTime(songs[currentSongIndex]['duration']),
        //           style: TextStyle(fontSize: 12, color: Colors.grey),
        //         ),
        //         SizedBox(width: 10),
        //         Container(
        //           width: MediaQuery.of(context).size.width * 0.6,
        //           child: LinearProgressIndicator(
        //             value: progress,
        //             color: Colors.brown,
        //             backgroundColor: Colors.grey[200],
        //           ),
        //         ),
        //         SizedBox(width: 10),
        //         Text(
        //           '-${formatTime(remainingTime)}',
        //           style: TextStyle(fontSize: 12, color: Colors.grey),
        //         ),
        //       ],
        //     ),
        //   ],
        // ),

        Spacer(),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }
}
