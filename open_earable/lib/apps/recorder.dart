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
  List<Directory> _recordingFolders = [];
  final OpenEarable _openEarable;
  bool _recording = false;
  StreamSubscription? _imuSubscription;
  StreamSubscription? _barometerSubscription;
  _RecorderState(this._openEarable);
  CsvWriter? _imuCsvWriter;
  CsvWriter? _barometerCsvWriter;
  List<String> _imuHeader = [
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
    "yaw[°]",
    "pitch[°]",
    "roll[°]"
  ];
  List<String> _barometerHeader = [
    "time",
    "sensor_baro[kPa]",
    "sensor_temp[°C]",
  ];

  @override
  void initState() {
    super.initState();
    if (_openEarable.bleManager.connected) {
      _setupListeners();
    }
    listSubfoldersInDocumentsDirectory();
  }

  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
    _barometerSubscription?.cancel();
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
        eulerRoll
      ];
      _imuCsvWriter?.addData(imuRow);
    });

    _barometerSubscription =
        _openEarable.sensorManager.subscribeToSensorData(1).listen((data) {
      if (!_recording) {
        return;
      }
      String timestamp = data["timestamp"].toString();
      String pressure = data["BARO"]["Pressure"].toString();
      String temperature = data["TEMP"]["Temperature"].toString();

      List<String> barometerRow = [timestamp, pressure, temperature];
      _barometerCsvWriter?.addData(barometerRow);
    });
  }

  void startStopRecording() async {
    if (_recording) {
      setState(() {
        _recording = false;
      });
      _imuCsvWriter?.cancelTimer();
      _barometerCsvWriter?.cancelTimer();
    } else {
      DateTime startTime = DateTime.now();
      _imuCsvWriter =
          CsvWriter("imu", startTime, listSubfoldersInDocumentsDirectory);
      _imuCsvWriter?.addData(_imuHeader);
      _barometerCsvWriter =
          CsvWriter("baro", startTime, listSubfoldersInDocumentsDirectory);
      _barometerCsvWriter?.addData(_barometerHeader);
      setState(() {
        _recording = true;
      });
    }
  }

  void deleteFolder(Directory folder) {
    if (folder.existsSync()) {
      try {
        folder.deleteSync(recursive: true);
      } catch (e) {
        print('Error deleting folder: $e');
      }
    } else {
      print('Folder does not exist.');
    }
    listSubfoldersInDocumentsDirectory();
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
            Text(
              'Record',
              style: TextStyle(fontSize: 20.0),
            ),
            ElevatedButton(
              onPressed: startStopRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: _recording
                    ? Color(0xfff27777)
                    : Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
              ),
              child: Icon(
                  _recording ? Icons.stop_outlined : Icons.play_arrow_outlined),
            ),
            Divider(
              thickness: 2,
            ),
            Text("Recordings", style: TextStyle(fontSize: 20.0)),
            Expanded(
              child: ListView.builder(
                itemCount: _recordingFolders.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_recordingFolders[index].path.split("/").last),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            deleteFolder(_recordingFolders[index]);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      OpenFile.open(_recordingFolders[index].path);
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

  CsvWriter(String prefix, DateTime startTime,
      void Function() folderCreationClosure) {
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

  cancelTimer() {
    _timer.cancel();
  }

  void addData(List<String> data) {
    buffer.add(data);
  }

  Future<void> _openFile(String prefix, DateTime startTime,
      void Function() folderCreationClosure) async {
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
  }

  void writeBufferToFile() async {
    if (file != null) {
      String csvData = buffer.map((row) => row.join(',')).join('\n');
      file!.writeAsStringSync('$csvData\n', mode: FileMode.append);
      buffer.clear();
    }
  }
}
