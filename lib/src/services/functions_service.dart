import '../scs_config.dart';
import '../utils/http_client.dart';

/// Service for serverless cloud functions.
///
/// Provides methods for invoking and managing cloud functions.
class FunctionsService {
  final ScsHttpClient _client;
  final ScsConfig _config;

  FunctionsService(this._client, this._config);

  /// Invokes a cloud function by name.
  Future<FunctionResult> call(
    String functionName, {
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    final response = await _client.post(
      'functions/invoke/${_config.projectId}/$functionName',
      body: data,
    );
    return FunctionResult.fromJson(response);
  }

  /// Gets a callable function reference.
  HttpsCallable httpsCallable(String functionName) {
    return HttpsCallable(this, functionName);
  }

  /// Lists all functions.
  Future<List<CloudFunction>> list() async {
    final response = await _client.get('functions');
    final functions = response['functions'] as List<dynamic>? ?? [];
    return functions
        .map((f) => CloudFunction.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  /// Gets a specific function.
  Future<CloudFunction> get(String functionId) async {
    final response = await _client.get('functions/$functionId');
    return CloudFunction.fromJson(
        response['function'] as Map<String, dynamic>? ?? response);
  }

  /// Creates a new function (admin only).
  Future<CloudFunction> create({
    required String name,
    required String code,
    String? description,
    String runtime = 'nodejs18',
    Map<String, String>? environment,
  }) async {
    final response = await _client.post(
      'functions',
      body: {
        'name': name,
        'code': code,
        if (description != null) 'description': description,
        'runtime': runtime,
        if (environment != null) 'environment': environment,
      },
    );
    return CloudFunction.fromJson(
        response['function'] as Map<String, dynamic>? ?? response);
  }

  /// Updates a function (admin only).
  Future<CloudFunction> update(
    String functionId, {
    String? name,
    String? code,
    String? description,
    Map<String, String>? environment,
  }) async {
    final response = await _client.put(
      'functions/$functionId',
      body: {
        if (name != null) 'name': name,
        if (code != null) 'code': code,
        if (description != null) 'description': description,
        if (environment != null) 'environment': environment,
      },
    );
    return CloudFunction.fromJson(
        response['function'] as Map<String, dynamic>? ?? response);
  }

  /// Deletes a function (admin only).
  Future<void> delete(String functionId) async {
    await _client.delete('functions/$functionId');
  }

  /// Tests a function without saving (admin only).
  Future<FunctionResult> test(
    String functionId, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _client.post(
      'functions/$functionId/test',
      body: data,
    );
    return FunctionResult.fromJson(response);
  }

  /// Gets function logs.
  Future<List<FunctionLog>> getLogs(String functionId, {int? limit}) async {
    final queryParams = <String, dynamic>{};
    if (limit != null) queryParams['limit'] = limit;

    final response = await _client.get(
      'functions/$functionId/logs',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    final logs = response['logs'] as List<dynamic>? ?? [];
    return logs
        .map((l) => FunctionLog.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  /// Clears function logs.
  Future<void> clearLogs(String functionId) async {
    await _client.delete('functions/$functionId/logs');
  }

  /// Gets functions statistics.
  Future<Map<String, dynamic>> getStats() async {
    final response = await _client.get('functions/stats');
    return response['stats'] as Map<String, dynamic>? ?? response;
  }
}

/// A callable function reference.
class HttpsCallable {
  final FunctionsService _service;
  final String _functionName;

  HttpsCallable(this._service, this._functionName);

  /// Calls the function with the given data.
  Future<FunctionResult> call([Map<String, dynamic>? data]) async {
    return await _service.call(_functionName, data: data);
  }
}

/// The result of a function invocation.
class FunctionResult {
  final dynamic data;
  final bool success;
  final String? error;
  final int? executionTime;

  const FunctionResult({
    this.data,
    this.success = true,
    this.error,
    this.executionTime,
  });

  factory FunctionResult.fromJson(Map<String, dynamic> json) {
    return FunctionResult(
      data: json['data'] ?? json['result'],
      success: json['success'] as bool? ?? json['error'] == null,
      error: json['error'] as String?,
      executionTime: json['executionTime'] as int?,
    );
  }
}

/// A cloud function definition.
class CloudFunction {
  final String id;
  final String name;
  final String? description;
  final String runtime;
  final String? code;
  final Map<String, String>? environment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CloudFunction({
    required this.id,
    required this.name,
    this.description,
    this.runtime = 'nodejs18',
    this.code,
    this.environment,
    this.createdAt,
    this.updatedAt,
  });

  factory CloudFunction.fromJson(Map<String, dynamic> json) {
    return CloudFunction(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      runtime: json['runtime'] as String? ?? 'nodejs18',
      code: json['code'] as String?,
      environment: (json['environment'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v.toString())),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

/// A function execution log entry.
class FunctionLog {
  final String id;
  final String level;
  final String message;
  final DateTime? timestamp;
  final Map<String, dynamic>? metadata;

  const FunctionLog({
    required this.id,
    required this.level,
    required this.message,
    this.timestamp,
    this.metadata,
  });

  factory FunctionLog.fromJson(Map<String, dynamic> json) {
    return FunctionLog(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      level: json['level'] as String? ?? 'info',
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
