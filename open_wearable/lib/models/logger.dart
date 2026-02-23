import 'package:logger/logger.dart';

/// Shared application logger initialized during app bootstrap.
late final Logger _logger;

/// Global logger accessor used by app modules.
Logger get logger => _logger;

/// Initializes the global logger instance once at startup.
void initLogger(Logger logger) {
  _logger = logger;
}
