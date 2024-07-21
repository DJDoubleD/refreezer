import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

class LogQueueManager {
  final File logFile;
  final Queue<String> _logQueue = Queue<String>();
  bool _isWriting = false;

  LogQueueManager(this.logFile);

  void enqueue(String logEntry) {
    _logQueue.add(logEntry);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isWriting) return;
    _isWriting = true;

    while (_logQueue.isNotEmpty) {
      String logEntry = _logQueue.removeFirst();
      log(logEntry);
      try {
        await logFile.writeAsString(logEntry, mode: FileMode.append);
      } catch (e) {
        log('Error writing to log file: $e');
      }
    }

    _isWriting = false;
  }
}

Future<void> initializeLogging() async {
  final String path =
      p.join((await getExternalStorageDirectory())!.path, 'refreezer.log');
  final File logFile = File(path);

  if (!await logFile.exists()) {
    await logFile.create(recursive: true);
  }

  // Clear old session data
  await logFile.writeAsString('');
  Logger.root.level = Level.ALL;

  final logQueueManager = LogQueueManager(logFile);

  Logger.root.onRecord.listen((record) {
    final logMessage = _formatLogMessage(record);
    logQueueManager.enqueue(logMessage);
  });
}

String _formatLogMessage(LogRecord record) {
  final buffer = StringBuffer();
  buffer.write('${record.level.name}: ${record.time}: ${record.message}\n');

  if (record.error != null) {
    buffer.write('Error: ${record.error}\n');
  }

  if (record.stackTrace != null) {
    buffer.write('Stack Trace: ${record.stackTrace}\n');
  }

  return buffer.toString();
}
