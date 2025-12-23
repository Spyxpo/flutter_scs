import 'dart:io';

import 'package:flutter_scs/flutter_scs.dart';

class AppConfig {
  static const String apiKey =
      'scs_6fc639e5a28aa9a9c01a8c2785c03ed268aeac09af7ef1bc5afadc7da3cb1310';
  static const String projectId = 'test';

  // Use 10.0.2.2 for Android emulator, localhost for iOS simulator/desktop
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3001';
    }
    return 'http://localhost:3001';
  }

  static ScsConfig get scsConfig => ScsConfig(
        apiKey: apiKey,
        projectId: projectId,
        baseUrl: baseUrl,
      );
}
