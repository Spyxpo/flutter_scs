import 'dart:io';
import 'dart:typed_data';

import '../models/file_metadata.dart';
import '../utils/http_client.dart';

/// Service for file storage operations.
///
/// Provides methods for uploading, downloading, and managing files.
class StorageService {
  final ScsHttpClient _client;

  StorageService(this._client);

  /// Uploads a file to storage.
  ///
  /// Returns the metadata of the uploaded file.
  Future<ScsFileMetadata> upload(
    File file, {
    String? folder,
    Map<String, String>? metadata,
  }) async {
    final fields = <String, String>{};
    if (folder != null) fields['folder'] = folder;
    if (metadata != null) {
      fields.addAll(metadata);
    }

    final response = await _client.uploadFile(
      'storage/upload',
      file: file,
      fields: fields.isNotEmpty ? fields : null,
    );

    final fileData = response['file'] as Map<String, dynamic>? ?? response;
    return ScsFileMetadata.fromJson(fileData);
  }

  /// Uploads bytes as a file.
  ///
  /// Returns the metadata of the uploaded file.
  Future<ScsFileMetadata> uploadBytes(
    Uint8List bytes, {
    required String filename,
    String? folder,
    String? mimeType,
    Map<String, String>? metadata,
  }) async {
    final fields = <String, String>{};
    if (folder != null) fields['folder'] = folder;
    if (metadata != null) {
      fields.addAll(metadata);
    }

    final response = await _client.uploadBytes(
      'storage/upload',
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      fields: fields.isNotEmpty ? fields : null,
    );

    final fileData = response['file'] as Map<String, dynamic>? ?? response;
    return ScsFileMetadata.fromJson(fileData);
  }

  /// Lists files in storage.
  Future<FileListResult> list({
    String? folder,
    int? limit,
    int? skip,
  }) async {
    final queryParams = <String, dynamic>{};
    if (folder != null) queryParams['folder'] = folder;
    if (limit != null) queryParams['limit'] = limit;
    if (skip != null) queryParams['skip'] = skip;

    final response = await _client.get(
      'storage/files',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    return FileListResult.fromJson(response);
  }

  /// Gets the metadata for a file.
  Future<ScsFileMetadata> getMetadata(String fileId) async {
    final response = await _client.get('storage/files/$fileId/metadata');
    final fileData = response['file'] as Map<String, dynamic>? ?? response;
    return ScsFileMetadata.fromJson(fileData);
  }

  /// Gets the download URL for a file.
  Future<String> getDownloadUrl(String fileId) async {
    final response = await _client.get('storage/files/$fileId/download');
    return response['url'] as String? ?? '${_client.buildUrl('storage/files/$fileId/download')}';
  }

  /// Downloads a file and returns its bytes.
  Future<Uint8List> download(String fileId) async {
    return await _client.downloadBytes('storage/files/$fileId/download');
  }

  /// Downloads a file to a local path.
  Future<File> downloadToFile(String fileId, String localPath) async {
    final bytes = await download(fileId);
    final file = File(localPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Deletes a file.
  Future<void> delete(String fileId) async {
    await _client.delete('storage/files/$fileId');
  }

  /// Creates a folder.
  Future<void> createFolder(String path) async {
    await _client.post('storage/folders', body: {'path': path});
  }

  /// Deletes a folder and its contents.
  Future<void> deleteFolder(String path) async {
    await _client.delete('storage/folders/$path');
  }

  /// Gets a reference to a storage location.
  StorageReference ref([String? path]) {
    return StorageReference(this, path ?? '');
  }
}

/// A reference to a location in storage.
class StorageReference {
  final StorageService _service;
  final String _path;

  StorageReference(this._service, this._path);

  /// Gets the path this reference points to.
  String get path => _path;

  /// Gets the name (last segment) of this reference's path.
  String get name {
    final segments = _path.split('/');
    return segments.isNotEmpty ? segments.last : '';
  }

  /// Gets a reference to a child location.
  StorageReference child(String childPath) {
    final newPath = _path.isEmpty ? childPath : '$_path/$childPath';
    return StorageReference(_service, newPath);
  }

  /// Gets a reference to the parent location.
  StorageReference? get parent {
    if (_path.isEmpty) return null;
    final segments = _path.split('/');
    if (segments.length <= 1) return StorageReference(_service, '');
    segments.removeLast();
    return StorageReference(_service, segments.join('/'));
  }

  /// Uploads a file to this location.
  Future<ScsFileMetadata> putFile(File file) async {
    return _service.upload(file, folder: _path.isEmpty ? null : _path);
  }

  /// Uploads bytes to this location.
  Future<ScsFileMetadata> putData(
    Uint8List data, {
    required String filename,
    String? mimeType,
  }) async {
    return _service.uploadBytes(
      data,
      filename: filename,
      folder: _path.isEmpty ? null : _path,
      mimeType: mimeType,
    );
  }

  /// Lists items at this location.
  Future<FileListResult> list({int? limit, int? skip}) async {
    return _service.list(
      folder: _path.isEmpty ? null : _path,
      limit: limit,
      skip: skip,
    );
  }
}
