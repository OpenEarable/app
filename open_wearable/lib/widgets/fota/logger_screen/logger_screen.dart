import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';

class LoggerScreen extends StatelessWidget {
  const LoggerScreen({required this.logger, super.key});
  final FirmwareUpdateLogger logger;

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText('Log'),
      ),
      body: _logFutureBuilder(),
    );
  }

  Widget _logFutureBuilder() {
    return FutureBuilder<List<McuLogMessage>>(
      future: logger.readLogs(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final messages = (snapshot.data ?? const <McuLogMessage>[])
              .where((element) => element.level.rawValue >= 1)
              .toList();
          return _messageList(messages);
        } else if (snapshot.hasError) {
          return Center(
            child: PlatformText(snapshot.error.toString()),
          );
        }
        return const Center(
          child: PlatformCircularProgressIndicator(),
        );
      },
    );
  }

  Widget _messageList(List<McuLogMessage> messages) => ListView.builder(
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return PlatformText(
            message.message,
            style: TextStyle(color: _colorForLevel(message.level)),
          );
        },
      );

  Color _colorForLevel(McuMgrLogLevel level) {
    switch (level) {
      case McuMgrLogLevel.verbose:
        return Colors.grey;
      case McuMgrLogLevel.application:
        return Colors.purple;
      case McuMgrLogLevel.debug:
        return Colors.blue;
      case McuMgrLogLevel.info:
        return Colors.green;
      case McuMgrLogLevel.warning:
        return Colors.orange;
      case McuMgrLogLevel.error:
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}
