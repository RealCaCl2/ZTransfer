import 'package:logger/logger.dart';

/// Single shared [Logger] instance.
///
/// In debug builds this logs everything; in release builds only warnings
/// and errors are printed.  The [PrettyPrinter] includes timestamps and
/// stack traces for errors.
final appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: Level.debug,
);
