import 'package:flutter_scs/flutter_scs.dart';

class AppConfig {
  // TODO: Replace these with your actual SCS credentials
  static const String apiKey = 'your-api-key-here';
  static const String projectId = 'your-project-id-here';
  static const String baseUrl = 'https://your-scs-server.com';

  static ScsConfig get scsConfig => ScsConfig(
        apiKey: apiKey,
        projectId: projectId,
        baseUrl: baseUrl,
      );
}
