import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import '../scs_config.dart';
import '../scs_exception.dart';

/// HTTP client for making API requests to SCS.
class ScsHttpClient {
  final ScsConfig config;
  final http.Client _client;
  String? _userToken;

  ScsHttpClient(this.config) : _client = http.Client();

  /// Sets the user authentication token.
  void setUserToken(String? token) {
    _userToken = token;
  }

  /// Gets the current user token.
  String? get userToken => _userToken;

  /// Clears the user token.
  void clearUserToken() {
    _userToken = null;
  }

  /// Builds the full URL for an API endpoint.
  Uri buildUrl(String path, [Map<String, dynamic>? queryParams]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('${config.baseUrl}/api/$cleanPath');

    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ));
    }
    return uri;
  }

  /// Builds request headers.
  Map<String, String> _buildHeaders({
    bool includeContentType = true,
    Map<String, String>? additionalHeaders,
  }) {
    final headers = <String, String>{
      'X-API-Key': config.apiKey,
      'X-Database-Type': config.databaseTypeHeader,
      if (_userToken != null) 'Authorization': 'Bearer $_userToken',
      if (includeContentType) 'Content-Type': 'application/json',
      ...?additionalHeaders,
    };
    return headers;
  }

  /// Makes a GET request.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _client.get(
        buildUrl(path, queryParams),
        headers: _buildHeaders(includeContentType: false),
      );
      return _handleResponse(response);
    } on SocketException {
      throw ScsException.network('Unable to connect to server');
    }
  }

  /// Makes a POST request.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _client.post(
        buildUrl(path, queryParams),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException {
      throw ScsException.network('Unable to connect to server');
    }
  }

  /// Makes a PUT request.
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _client.put(
        buildUrl(path, queryParams),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException {
      throw ScsException.network('Unable to connect to server');
    }
  }

  /// Makes a PATCH request.
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _client.patch(
        buildUrl(path, queryParams),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException {
      throw ScsException.network('Unable to connect to server');
    }
  }

  /// Makes a DELETE request.
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _client.delete(
        buildUrl(path, queryParams),
        headers: _buildHeaders(includeContentType: false),
      );
      return _handleResponse(response);
    } on SocketException {
      throw ScsException.network('Unable to connect to server');
    }
  }

  /// Uploads a file using multipart form data.
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required File file,
    String fieldName = 'file',
    Map<String, String>? fields,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        buildUrl(path),
      );

      request.headers.addAll(_buildHeaders(includeContentType: false));

      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final multipartFile = await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        contentType: http.MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw ScsException.network('Unable to connect to server');
    }
  }

  /// Uploads bytes as a file.
  Future<Map<String, dynamic>> uploadBytes(
    String path, {
    required Uint8List bytes,
    required String filename,
    String fieldName = 'file',
    String? mimeType,
    Map<String, String>? fields,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        buildUrl(path),
      );

      request.headers.addAll(_buildHeaders(includeContentType: false));

      final contentType = mimeType ?? lookupMimeType(filename) ?? 'application/octet-stream';
      final multipartFile = http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
        contentType: http.MediaType.parse(contentType),
      );

      request.files.add(multipartFile);

      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw ScsException.network('Unable to connect to server');
    }
  }

  /// Downloads a file and returns its bytes.
  Future<Uint8List> downloadBytes(String path) async {
    try {
      final response = await _client.get(
        buildUrl(path),
        headers: _buildHeaders(includeContentType: false),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }

      throw ScsException(
        'Download failed',
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw ScsException.network('Unable to connect to server');
    }
  }

  /// Handles the HTTP response and returns the parsed body.
  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw ScsException.fromResponse(response.statusCode, body);
  }

  /// Closes the HTTP client.
  void close() {
    _client.close();
  }
}
