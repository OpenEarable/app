import 'package:flutter/material.dart';
import 'package:open_earable/shared/earable_not_connected_warning.dart';
import 'dart:async';
import 'dart:io';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class Recorder extends StatefulWidget {
  final OpenEarable openEarable;

  const Recorder(this.openEarable, {super.key});

  @override
  State<Recorder> createState() => _RecorderState();
}

class _RecorderState extends State<Recorder> {
  final List<FileSystemEntity> _recordingFolders = [];
  Directory? _selectedFolder;
  bool _recording = false;
  StreamSubscription? _imuSubscription;
  StreamSubscription? _barometerSubscription;

  CsvWriter? _imuCsvWriter;
  CsvWriter? _barometerCsvWriter;
  late List<String> _imuHeader;
  late List<String> _barometerHeader;
  late List<String> _labels;
  late String _selectedLabel;
  Timer? _timer;
  Duration _duration = Duration();
  StreamSubscription? _connectionStateSubscription;

  @override
  void initState() {
    super.initState();

    _labels = [
      "No Label",
      "Label 1",
      "Label 2",
      "Label 3",
      "Label 4",
      "Label 5",
      "Label 6",
      "Label 7",
      "Label 8",
    ];
    _selectedLabel = "No Label";
    _imuHeader = [
      "time",
      "sensor_accX[m/s]",
      "sensor_accY[m/s]",
      "sensor_accZ[m/s]",
      "sensor_gyroX[°/s]",
      "sensor_gyroY[°/s]",
      "sensor_gyroZ[°/s]",
      "sensor_magX[µT]",
      "sensor_magY[µT]",
      "sensor_magZ[µT]",
      "sensor_yaw[°]",
      "sensor_pitch[°]",
      "sensor_roll[°]",
    ];

    _barometerHeader = [
      "time",
      "sensor_baro[Pa]",
      "sensor_temp[°C]",
    ];
    _imuHeader.addAll(
      _labels.sublist(1).map((label) => "label_OpenEarable_$label"),
    );
    _barometerHeader.addAll(
      _labels.sublist(1).map((label) => "label_OpenEarable_$label"),
    );
    if (widget.openEarable.bleManager.connected) {
      _setupListeners();
    }
    listSubfoldersInDocumentsDirectory();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _duration = _duration + Duration(seconds: 1);
      });
    });
  }

  void _stopTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _duration = Duration();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    _imuSubscription?.cancel();
    _barometerSubscription?.cancel();
    _connectionStateSubscription?.cancel();
  }

  Future<void> listSubfoldersInDocumentsDirectory() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> subfolders = documentsDirectory.listSync();
    _recordingFolders.clear();
    for (var subfolder in subfolders) {
      if (subfolder is Directory) {
        _recordingFolders.add(subfolder);
      }
    }
    _recordingFolders.sort((a, b) {
      final folderAName = a.path.split("/").last;
      final folderBName = b.path.split("/").last;
      return -folderAName.compareTo(folderBName);
    });

    if (_selectedFolder != null && _selectedFolder!.existsSync()) {
      List<FileSystemEntity> files = _selectedFolder!.listSync();
      var index = _recordingFolders
          .indexWhere((element) => element.path == _selectedFolder!.path);
      _recordingFolders.insertAll(index + 1, files);
    }

    setState(() {});
  }

  void _setupListeners() {
    _connectionStateSubscription =
        widget.openEarable.bleManager.connectionStateStream.listen((connected) {
      setState(() {
        if (!connected) {
          _recording = false;
        }
      });
    });
    _imuSubscription =
        widget.openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
      if (!_recording) {
        return;
      }
      String timestamp = data["timestamp"].toString();

      String ax = data["ACC"]["X"].toString();
      String ay = data["ACC"]["Y"].toString();
      String az = data["ACC"]["Z"].toString();

      String gx = data["GYRO"]["X"].toString();
      String gy = data["GYRO"]["Y"].toString();
      String gz = data["GYRO"]["Z"].toString();

      String mx = data["MAG"]["X"].toString();
      String my = data["MAG"]["Y"].toString();
      String mz = data["MAG"]["Z"].toString();

      String eulerYaw = data["EULER"]["YAW"].toString();
      String eulerPitch = data["EULER"]["PITCH"].toString();
      String eulerRoll = data["EULER"]["ROLL"].toString();

      List<String> imuRow = [
        timestamp,
        ax,
        ay,
        az,
        gx,
        gy,
        gz,
        mx,
        my,
        mz,
        eulerYaw,
        eulerPitch,
        eulerRoll,
      ];
      imuRow.addAll(_getLabels());
      _imuCsvWriter?.addData(imuRow);
    });

    _barometerSubscription =
        widget.openEarable.sensorManager.subscribeToSensorData(1).listen((data) {
      if (!_recording) {
        return;
      }
      String timestamp = data["timestamp"].toString();
      String pressure = data["BARO"]["Pressure"].toString();
      String temperature = data["TEMP"]["Temperature"].toString();

      List<String> barometerRow = [
        timestamp,
        pressure,
        temperature,
      ];
      barometerRow.addAll(_getLabels());
      _barometerCsvWriter?.addData(barometerRow);
    });
  }

  List<String> _getLabels() {
    List<String> markedLabels = List<String>.filled(_labels.length - 1, "");
    int selectedLabelIndex = _labels.indexOf(_selectedLabel);
    if (_selectedLabel == "No Label" || selectedLabelIndex == -1) {
      return markedLabels;
    }
    markedLabels[selectedLabelIndex - 1] = "x";
    return markedLabels;
  }

  void startStopRecording() async {
    if (_recording) {
      setState(() {
        _recording = false;
      });
      _imuCsvWriter?.cancelTimer();
      _barometerCsvWriter?.cancelTimer();
      _stopTimer();
    } else {
      DateTime startTime = DateTime.now();
      _imuCsvWriter =
          CsvWriter("imu", startTime, listSubfoldersInDocumentsDirectory);
      _imuCsvWriter?.addData(_imuHeader);
      _barometerCsvWriter =
          CsvWriter("baro", startTime, listSubfoldersInDocumentsDirectory);
      _barometerCsvWriter?.addData(_barometerHeader);
      _startTimer();
      setState(() {
        _recording = true;
      });
    }
  }

  void deleteFileSystemEntity(FileSystemEntity entity) {
    if (entity.existsSync()) {
      try {
        entity.deleteSync(recursive: true);
      } catch (e) {
        print('Error deleting folder: $e');
      }
    } else {
      print('Folder does not exist.');
    }
    if (entity is File && entity.parent.listSync().isEmpty) {
      deleteFileSystemEntity(entity.parent);
    }
    listSubfoldersInDocumentsDirectory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Recorder'),
      ),
      body: _recorderWidget(),
    );
  }

  Widget _recorderWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: !widget.openEarable.bleManager.connected
              ? EarableNotConnectedWarning()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          fontFamily:
                              'Digital', // This is a common monospaced font
                          fontSize: 80,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: ElevatedButton(
                            onPressed: startStopRecording,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(200, 36),
                              backgroundColor: _recording
                                  ? Color(0xfff27777)
                                  : Theme.of(context).colorScheme.secondary,
                              foregroundColor: Colors.black,
                            ),
                            child: Text(
                              _recording ? "Stop Recording" : "Start Recording",
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        DropdownButton<String>(
                          value: _selectedLabel,
                          icon: const Icon(Icons.arrow_drop_down),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedLabel = newValue!;
                            });
                          },
                          items: _labels
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        Text("Recordings", style: TextStyle(fontSize: 20.0)),
        Divider(
          thickness: 2,
        ),
        _noRecordingsWidget(),
        Expanded(
          child: ListView.builder(
            itemCount: _recordingFolders.length,
            itemBuilder: (context, index) {
              return ListTile(
                contentPadding: _recordingFolders[index] is File
                    ? EdgeInsets.fromLTRB(40, 0, 16, 0)
                    : null,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _recordingFolders[index].path.split("/").last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:
                              _recordingFolders[index] is File ? 14 : null,
                        ),
                      ),
                    ),
                    Visibility(
                      visible: _recordingFolders[index] is Directory,
                      child: Transform.rotate(
                        angle: _recordingFolders[index].path ==
                                _selectedFolder?.path
                            ? 90 * 3.14 / 180
                            : 0,
                        child: Icon(Icons.arrow_right),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  if (_recordingFolders[index].path == _selectedFolder?.path) {
                    _selectedFolder = null;
                    listSubfoldersInDocumentsDirectory();
                  } else if (_recordingFolders[index] is Directory) {
                    Directory d = _recordingFolders[index] as Directory;
                    _selectedFolder = d;
                    listSubfoldersInDocumentsDirectory();
                  } else if (_recordingFolders[index] is File) {
                    OpenFile.open(_recordingFolders[index].path);
                  }
                },
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: (_recording && index == 0)
                        ? Color.fromARGB(50, 255, 255, 255)
                        : Colors.white,
                  ),
                  onPressed: () {
                    if (_recording && index == 0) {
                      deleteFileSystemEntity(_recordingFolders[index]);
                    }
                  },
                  splashColor: (_recording && index == 0)
                      ? Colors.transparent
                      : Theme.of(context).splashColor,
                ),
                splashColor: Colors.transparent,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _noRecordingsWidget() {
    return Visibility(
      visible: _recordingFolders.isEmpty,
      child: Expanded(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning,
                    size: 48,
                    color: Colors.red,
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      "No recordings found",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CsvWriter {
  List<List<String>> buffer = [];
  File? file;
  late Timer _timer;

  CsvWriter(
    String prefix,
    DateTime startTime,
    void Function() folderCreationClosure,
  ) {
    if (file == null) {
      _openFile(prefix, startTime, folderCreationClosure);
    }
    _timer = Timer.periodic(Duration(milliseconds: 250), (Timer timer) {
      if (buffer.isNotEmpty) {
        if (file == null) {
          _openFile(prefix, startTime, folderCreationClosure);
        }
        writeBufferToFile();
      }
    });
  }

  void cancelTimer() {
    _timer.cancel();
  }

  void addData(List<String> data) {
    buffer.add(data);
  }

  Future<void> _openFile(
    String prefix,
    DateTime startTime,
    void Function() folderCreationClosure,
  ) async {
    String formattedDate =
        startTime.toUtc().toIso8601String().replaceAll(':', '_');
    formattedDate = "${formattedDate.substring(0, formattedDate.length - 4)}Z";
    String fileName = '${prefix}_recording_$formattedDate';
    String directory = (await getApplicationDocumentsDirectory()).path;
    String folderPath = '$directory/$formattedDate';

    String filePath = '$folderPath/$fileName.csv';
    Directory folder = Directory(folderPath);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
      folderCreationClosure();
    }
    file = File(filePath);
    await file?.create();
    folderCreationClosure();
  }

  void writeBufferToFile() async {
    if (file != null) {
      String csvData = buffer.map((row) => row.join(',')).join('\n');
      file!.writeAsStringSync('$csvData\n', mode: FileMode.append);
      buffer.clear();
    }
  }
}
