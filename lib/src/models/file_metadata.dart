/// Represents metadata for a file in SCS storage.
class ScsFileMetadata {
  /// The file ID.
  final String id;

  /// The file name.
  final String name;

  /// The file path in storage.
  final String path;

  /// The folder containing the file.
  final String? folder;

  /// The MIME type of the file.
  final String mimeType;

  /// The file size in bytes.
  final int size;

  /// The public URL to access the file.
  final String? url;

  /// When the file was created.
  final DateTime? createdAt;

  /// When the file was last updated.
  final DateTime? updatedAt;

  const ScsFileMetadata({
    required this.id,
    required this.name,
    required this.path,
    this.folder,
    required this.mimeType,
    required this.size,
    this.url,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates file metadata from a JSON map.
  factory ScsFileMetadata.fromJson(Map<String, dynamic> json) {
    return ScsFileMetadata(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['filename'] as String? ?? '',
      path: json['path'] as String? ?? '',
      folder: json['folder'] as String?,
      mimeType: json['mimeType'] as String? ?? json['contentType'] as String? ?? 'application/octet-stream',
      size: json['size'] as int? ?? 0,
      url: json['url'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  /// Converts the metadata to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      if (folder != null) 'folder': folder,
      'mimeType': mimeType,
      'size': size,
      if (url != null) 'url': url,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  /// Gets the file extension.
  String get extension {
    final dotIndex = name.lastIndexOf('.');
    return dotIndex != -1 ? name.substring(dotIndex + 1) : '';
  }

  /// Gets a human-readable file size.
  String get readableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() {
    return 'ScsFileMetadata(id: $id, name: $name, size: $readableSize)';
  }
}

/// Represents upload options for files.
class UploadOptions {
  /// The folder to upload to.
  final String? folder;

  /// Custom metadata to attach to the file.
  final Map<String, String>? metadata;

  const UploadOptions({
    this.folder,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      if (folder != null) 'folder': folder,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Result of a file list operation.
class FileListResult {
  /// The files in this result.
  final List<ScsFileMetadata> files;

  /// The total count of files.
  final int total;

  /// Whether there are more files.
  final bool hasMore;

  const FileListResult({
    required this.files,
    required this.total,
    this.hasMore = false,
  });

  factory FileListResult.fromJson(Map<String, dynamic> json) {
    final files = (json['files'] as List<dynamic>? ?? [])
        .map((f) => ScsFileMetadata.fromJson(f as Map<String, dynamic>))
        .toList();
    return FileListResult(
      files: files,
      total: json['total'] as int? ?? files.length,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
