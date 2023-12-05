import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class Recorder extends StatefulWidget {
  final OpenEarable _openEarable;
  Recorder(this._openEarable);
  @override
  _RecorderState createState() => _RecorderState(_openEarable);
}

class _RecorderState extends State<Recorder> {
  List<File> _recordings = [];
  final OpenEarable _openEarable;
  bool _recording = false;
  StreamSubscription? _imuSubscription;
  StreamSubscription? _barometerSubscription;
  _RecorderState(this._openEarable);
  CsvWriter? _csvWriter;
  late List<String> _csvHeader;
  late List<String> _labels;
  late String _selectedLabel;
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
    _csvHeader = [
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
      "sensor_baro[Pa]",
      "sensor_temp[°C]",
    ];
    _csvHeader.addAll(
        _labels.sublist(1).map((label) => "label_OpenEarable_${label}"));
    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }
    listFilesInDocumentsDirectory();
  }

  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
    _barometerSubscription?.cancel();
  }

  Future<void> listFilesInDocumentsDirectory() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> files = documentsDirectory.listSync();
    _recordings.clear();
    for (var file in files) {
      if (file is File) {
        _recordings.add(file);
      }
    }
    _recordings.sort((a, b) {
      return b.statSync().changed.compareTo(a.statSync().changed);
    });

    setState(() {});
  }

  _setupListeners() {
    _imuSubscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
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
        "",
        "",
      ];
      imuRow.addAll(_getLabels());
      _csvWriter?.addData(imuRow);
    });

    _barometerSubscription =
        _openEarable.sensorManager.subscribeToSensorData(1).listen((data) {
      if (!_recording) {
        return;
      }
      String timestamp = data["timestamp"].toString();
      String pressure = data["BARO"]["Pressure"].toString();
      String temperature = data["TEMP"]["Temperature"].toString();

      List<String> barometerRow = [
        timestamp,
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        pressure,
        temperature,
      ];
      barometerRow.addAll(_getLabels());
      _csvWriter?.addData(barometerRow);
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
      _csvWriter?.cancelTimer();
    } else {
      _csvWriter = CsvWriter(listFilesInDocumentsDirectory);
      _csvWriter?.addData(_csvHeader);
      setState(() {
        _recording = true;
      });
    }
  }

  void deleteFile(File file) {
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (e) {
        print('Error deleting file: $e');
      }
    } else {
      print('File does not exist.');
    }
    listFilesInDocumentsDirectory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text('Recorder'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: startStopRecording,
                    style: ElevatedButton.styleFrom(
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
                  items: _labels.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
            Text("Recordings", style: TextStyle(fontSize: 20.0)),
            Divider(
              thickness: 2,
            ),
            Expanded(
              child: _recordings.isEmpty
                  ? Stack(
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
                    )
                  : ListView.builder(
                      itemCount: _recordings.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _recordings[index].path.split("/").last,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () {
                                  deleteFile(_recordings[index]);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            OpenFile.open(_recordings[index].path);
                          },
                        );
                      },
                    ),
            )
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

  CsvWriter(void Function() fileCreationClosure) {
    if (file == null) {
      _openFile(fileCreationClosure);
    }
    _timer = Timer.periodic(Duration(milliseconds: 250), (Timer timer) {
      if (buffer.isNotEmpty) {
        if (file == null) {
          _openFile(fileCreationClosure);
        }
        writeBufferToFile();
      }
    });
  }

  cancelTimer() {
    _timer.cancel();
  }

  void addData(List<String> data) {
    buffer.add(data);
  }

  Future<void> _openFile(void Function() fileCreationClosure) async {
    DateTime startTime = DateTime.now();
    String formattedDate =
        startTime.toUtc().toIso8601String().replaceAll(':', '_');
    formattedDate = "${formattedDate.substring(0, formattedDate.length - 4)}Z";
    String fileName = 'recording_$formattedDate';
    String directory = (await getApplicationDocumentsDirectory()).path;
    String filePath = '$directory/$fileName.csv';
    file = File(filePath);
    await file?.create();
    fileCreationClosure();
  }

  void writeBufferToFile() async {
    if (file != null) {
      String csvData = buffer.map((row) => row.join(',')).join('\n');
      file!.writeAsStringSync('$csvData\n', mode: FileMode.append);
      buffer.clear();
    }
  }
}
