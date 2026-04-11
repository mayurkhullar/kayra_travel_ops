import 'package:flutter/foundation.dart';

void appLog(String tag, String message) {
  final line = '[$tag] $message';
  debugPrint(line);
  if (kIsWeb) {
    // Ensures visibility in browser console for Flutter web debugging.
    print(line);
  }
}

void appLogError(
  String tag,
  String stage,
  Object error,
  StackTrace stackTrace,
) {
  appLog(tag, 'ERROR at $stage: $error');
  appLog(tag, 'STACK: $stackTrace');
}
