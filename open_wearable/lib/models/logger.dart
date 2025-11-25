import 'package:logger/logger.dart';

late final Logger _logger;

Logger get logger => _logger;

void initLogger(Logger logger) {
  _logger = logger;
}
