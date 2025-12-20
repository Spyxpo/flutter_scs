import '../utils/http_client.dart';

/// Service for remote configuration management.
///
/// Provides methods for fetching and managing dynamic configuration
/// parameters.
class RemoteConfigService {
  final ScsHttpClient _client;
  Map<String, ConfigParameter> _cache = {};
  DateTime? _lastFetch;

  RemoteConfigService(this._client);

  /// Gets the cached config value or fetches if not available.
  T? getValue<T>(String key, {T? defaultValue}) {
    final param = _cache[key];
    if (param == null) return defaultValue;

    final value = param.value;
    if (value is T) return value;

    // Try type conversion
    if (T == int && value is num) return value.toInt() as T;
    if (T == double && value is num) return value.toDouble() as T;
    if (T == String) return value.toString() as T;
    if (T == bool) {
      if (value is bool) return value as T;
      if (value is String) return (value.toLowerCase() == 'true') as T;
    }

    return defaultValue;
  }

  /// Gets a string config value.
  String getString(String key, {String defaultValue = ''}) {
    return getValue<String>(key, defaultValue: defaultValue) ?? defaultValue;
  }

  /// Gets an integer config value.
  int getInt(String key, {int defaultValue = 0}) {
    return getValue<int>(key, defaultValue: defaultValue) ?? defaultValue;
  }

  /// Gets a double config value.
  double getDouble(String key, {double defaultValue = 0.0}) {
    return getValue<double>(key, defaultValue: defaultValue) ?? defaultValue;
  }

  /// Gets a boolean config value.
  bool getBool(String key, {bool defaultValue = false}) {
    return getValue<bool>(key, defaultValue: defaultValue) ?? defaultValue;
  }

  /// Fetches the latest config from the server.
  Future<Map<String, ConfigParameter>> fetch() async {
    final response = await _client.get('remote-config/fetch');
    final params = response['parameters'] as Map<String, dynamic>? ??
        response['params'] as Map<String, dynamic>? ??
        {};

    _cache = params.map((key, value) {
      if (value is Map<String, dynamic>) {
        return MapEntry(key, ConfigParameter.fromJson(key, value));
      }
      return MapEntry(key, ConfigParameter(key: key, value: value));
    });
    _lastFetch = DateTime.now();

    return _cache;
  }

  /// Fetches and activates the config in one call.
  Future<void> fetchAndActivate() async {
    await fetch();
  }

  /// Gets all config parameters.
  Future<List<ConfigParameter>> getAll() async {
    final response = await _client.get('remote-config/params');
    final params = response['parameters'] as List<dynamic>? ??
        response['params'] as List<dynamic>? ??
        [];
    return params
        .map((p) => ConfigParameter.fromJson(
            p['key'] as String? ?? '', p as Map<String, dynamic>))
        .toList();
  }

  /// Gets a specific parameter.
  Future<ConfigParameter> getParameter(String key) async {
    final response = await _client.get('remote-config/params/$key');
    return ConfigParameter.fromJson(key, response);
  }

  /// Sets a parameter value (admin only).
  Future<ConfigParameter> setParameter({
    required String key,
    required dynamic value,
    String? type,
    String? description,
  }) async {
    final response = await _client.post(
      'remote-config/params',
      body: {
        'key': key,
        'value': value,
        if (type != null) 'type': type,
        if (description != null) 'description': description,
      },
    );
    final param = ConfigParameter.fromJson(
        key, response['parameter'] as Map<String, dynamic>? ?? response);
    _cache[key] = param;
    return param;
  }

  /// Updates a parameter value (admin only).
  Future<ConfigParameter> updateParameter({
    required String key,
    required dynamic value,
    String? type,
    String? description,
  }) async {
    final response = await _client.put(
      'remote-config/params/$key',
      body: {
        'value': value,
        if (type != null) 'type': type,
        if (description != null) 'description': description,
      },
    );
    final param = ConfigParameter.fromJson(
        key, response['parameter'] as Map<String, dynamic>? ?? response);
    _cache[key] = param;
    return param;
  }

  /// Deletes a parameter (admin only).
  Future<void> deleteParameter(String key) async {
    await _client.delete('remote-config/params/$key');
    _cache.remove(key);
  }

  /// Publishes the current config as a new version (admin only).
  Future<ConfigVersion> publish() async {
    final response = await _client.post('remote-config/publish');
    return ConfigVersion.fromJson(
        response['version'] as Map<String, dynamic>? ?? response);
  }

  /// Gets all config versions.
  Future<List<ConfigVersion>> getVersions() async {
    final response = await _client.get('remote-config/versions');
    final versions = response['versions'] as List<dynamic>? ?? [];
    return versions
        .map((v) => ConfigVersion.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  /// Rolls back to a specific version (admin only).
  Future<void> rollback(String versionId) async {
    await _client.post('remote-config/versions/$versionId/rollback');
    await fetch(); // Refresh cache after rollback
  }

  /// Gets remote config statistics.
  Future<Map<String, dynamic>> getStats() async {
    final response = await _client.get('remote-config/stats');
    return response['stats'] as Map<String, dynamic>? ?? response;
  }

  /// The time of the last fetch.
  DateTime? get lastFetchTime => _lastFetch;

  /// Gets all cached parameters.
  Map<String, ConfigParameter> get cachedParameters => Map.unmodifiable(_cache);
}

/// A remote config parameter.
class ConfigParameter {
  final String key;
  final dynamic value;
  final String? type;
  final String? description;
  final DateTime? updatedAt;

  const ConfigParameter({
    required this.key,
    required this.value,
    this.type,
    this.description,
    this.updatedAt,
  });

  factory ConfigParameter.fromJson(String key, Map<String, dynamic> json) {
    return ConfigParameter(
      key: json['key'] as String? ?? key,
      value: json['value'],
      type: json['type'] as String?,
      description: json['description'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  /// Gets the value as a specific type.
  T? as<T>() {
    if (value is T) return value as T;
    return null;
  }
}

/// A remote config version.
class ConfigVersion {
  final String id;
  final int versionNumber;
  final Map<String, dynamic>? parameters;
  final DateTime? createdAt;

  const ConfigVersion({
    required this.id,
    required this.versionNumber,
    this.parameters,
    this.createdAt,
  });

  factory ConfigVersion.fromJson(Map<String, dynamic> json) {
    return ConfigVersion(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      versionNumber: json['versionNumber'] as int? ?? json['version'] as int? ?? 0,
      parameters: json['parameters'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
