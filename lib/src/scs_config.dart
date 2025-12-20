import 'dart:convert';
import 'dart:io';

/// Configuration for the SCS SDK.
class ScsConfig {
  /// The API key for authenticating requests.
  final String apiKey;

  /// The project ID.
  final String projectId;

  /// The base URL for the SCS API.
  final String baseUrl;

  /// Creates a new SCS configuration.
  const ScsConfig({
    required this.apiKey,
    required this.projectId,
    required this.baseUrl,
  });

  /// Creates a configuration from a JSON map.
  factory ScsConfig.fromJson(Map<String, dynamic> json) {
    // Support multiple config formats
    String? apiKey;
    String? projectId;
    String? baseUrl;

    // Check sdk_config format
    if (json.containsKey('sdk_config')) {
      final sdkConfig = json['sdk_config'] as Map<String, dynamic>;
      apiKey = sdkConfig['api_key'] as String?;
      projectId = sdkConfig['project_id'] as String?;
      baseUrl = sdkConfig['base_url'] as String?;
    }

    // Check client format
    if (apiKey == null && json.containsKey('client')) {
      final client = json['client'] as Map<String, dynamic>;
      apiKey = client['api_key'] as String?;
    }

    // Check project_info format
    if (json.containsKey('project_info')) {
      final projectInfo = json['project_info'] as Map<String, dynamic>;
      projectId ??= projectInfo['project_id'] as String?;
      baseUrl ??= projectInfo['api_url'] as String?;
    }

    // Direct properties
    apiKey ??= json['apiKey'] as String? ?? json['api_key'] as String?;
    projectId ??= json['projectId'] as String? ?? json['project_id'] as String?;
    baseUrl ??= json['baseUrl'] as String? ?? json['base_url'] as String?;

    if (apiKey == null || apiKey.isEmpty) {
      throw ArgumentError('API key is required');
    }
    if (projectId == null || projectId.isEmpty) {
      throw ArgumentError('Project ID is required');
    }
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ArgumentError('Base URL is required');
    }

    return ScsConfig(
      apiKey: apiKey,
      projectId: projectId,
      baseUrl: baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
    );
  }

  /// Creates a configuration from a JSON file.
  static Future<ScsConfig> fromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw ArgumentError('Config file not found: $path');
    }
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return ScsConfig.fromJson(json);
  }

  /// Creates a configuration from the default scs-info.json file in assets.
  static Future<ScsConfig> fromAssets(String assetPath) async {
    // This would be used with rootBundle in Flutter
    throw UnimplementedError('Use fromJson with asset loading in your app');
  }

  /// Converts the configuration to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      'projectId': projectId,
      'baseUrl': baseUrl,
    };
  }

  @override
  String toString() {
    return 'ScsConfig(projectId: $projectId, baseUrl: $baseUrl)';
  }
}
