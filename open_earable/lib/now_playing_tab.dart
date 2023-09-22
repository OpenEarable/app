import 'package:flutter/material.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'dart:async';

class NowPlayingTab extends StatefulWidget {
  final OpenEarable _openEarable;
  NowPlayingTab(this._openEarable);
  @override
  _NowPlayingTabState createState() => _NowPlayingTabState(_openEarable);
}

class _NowPlayingTabState extends State<NowPlayingTab> {
  final OpenEarable _openEarable;
  _NowPlayingTabState(this._openEarable);
  bool isPlaying = false;
  int currentSongIndex = 0;
  int elapsedTime = 0; // elapsed time in seconds
  Timer? _timer;

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
      _startTimer();
      print("Playing ${songs[currentSongIndex]['title']}.wav");
      _openEarable.wavAudioPlayer.writeWAVState(WavAudioPlayerState.unpause,
          "${songs[currentSongIndex]['title']}.wav");
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

    setState(() {
      currentSongIndex = newIndex;
    });
    _openEarable.wavAudioPlayer.writeWAVState(
        WavAudioPlayerState.start, "${songs[newIndex]['title']}.wav");
  }

  String formatTime(int seconds) {
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final double progress = elapsedTime / songs[currentSongIndex]['duration'];
    final int remainingTime = songs[currentSongIndex]['duration'] - elapsedTime;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Spacer(),
        ClipRect(
          child: Image.network(
            songs[currentSongIndex]['albumCover'],
            width: 320,
            height: 320,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 20),
        Text(
          songs[currentSongIndex]['title'],
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          songs[currentSongIndex]['artist'],
          style: TextStyle(fontSize: 20, color: Colors.grey[700]),
        ),
        SizedBox(height: 20),
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  formatTime(songs[currentSongIndex]['duration']),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                SizedBox(width: 10),
                Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: LinearProgressIndicator(
                    value: progress,
                    color: Colors.brown,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  '-${formatTime(remainingTime)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous, size: 30.0),
                  onPressed: () {
                    previous_song();
                  },
                ),
                SizedBox(width: 25.0), // provide space between buttons
                SizedBox(
                  height: 100.0, // desired height
                  width: 80.0, // desired width
                  child: IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 60.0),
                    onPressed: togglePlay,
                  ),
                ),
                SizedBox(width: 25.0),
                IconButton(
                  icon: Icon(Icons.skip_next, size: 30.0),
                  onPressed: () {
                    next_song();
                  },
                ),
              ],
            ),
          ],
        ),
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
