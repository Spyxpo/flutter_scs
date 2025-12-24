/// Represents a document in the SCS database.
class ScsDocument {
  /// The document ID.
  final String id;

  /// The document data.
  final Map<String, dynamic> data;

  /// The collection path this document belongs to.
  final String? collectionPath;

  /// When the document was created.
  final DateTime? createdAt;

  /// When the document was last updated.
  final DateTime? updatedAt;

  const ScsDocument({
    required this.id,
    required this.data,
    this.collectionPath,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a document from a JSON map.
  ///
  /// The backend returns documents in this format:
  /// ```json
  /// {
  ///   "id": "docId",
  ///   "path": "collection/docId",
  ///   "data": { ... actual document data ... },
  ///   "createdAt": "2024-01-01T00:00:00.000Z",
  ///   "updatedAt": "2024-01-01T00:00:00.000Z"
  /// }
  /// ```
  factory ScsDocument.fromJson(Map<String, dynamic> json) {
    // Get the document ID (supports both 'id' and '_id' formats)
    final id = json['id'] as String? ?? json['_id'] as String? ?? json['docId'] as String? ?? '';

    // Get the document data - it's nested under 'data' field from the backend
    // If 'data' field exists, use it; otherwise fall back to the entire json (for backwards compatibility)
    Map<String, dynamic> data;
    if (json.containsKey('data') && json['data'] is Map) {
      data = Map<String, dynamic>.from(json['data'] as Map);
    } else {
      // Fallback: treat the entire json as data (minus metadata fields)
      data = Map<String, dynamic>.from(json);
      data.remove('_id');
      data.remove('id');
      data.remove('docId');
      data.remove('path');
      data.remove('createdAt');
      data.remove('updatedAt');
      data.remove('subcollections');
    }

    // Parse timestamps
    DateTime? createdAt;
    DateTime? updatedAt;

    if (json['createdAt'] != null) {
      createdAt = DateTime.tryParse(json['createdAt'].toString());
    }
    if (json['updatedAt'] != null) {
      updatedAt = DateTime.tryParse(json['updatedAt'].toString());
    }

    // Get collection path if available
    final collectionPath = json['path'] as String?;

    return ScsDocument(
      id: id,
      data: data,
      collectionPath: collectionPath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Converts the document to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      ...data,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  /// Gets a field value from the document data.
  T? get<T>(String field) {
    return data[field] as T?;
  }

  /// Checks if the document exists (has an ID).
  bool get exists => id.isNotEmpty;

  @override
  String toString() {
    return 'ScsDocument(id: $id, data: $data)';
  }
}

/// Represents a snapshot of query results.
class QuerySnapshot {
  /// The documents in this snapshot.
  final List<ScsDocument> docs;

  /// Whether the snapshot is empty.
  bool get isEmpty => docs.isEmpty;

  /// Whether the snapshot is not empty.
  bool get isNotEmpty => docs.isNotEmpty;

  /// The number of documents in this snapshot.
  int get size => docs.length;

  const QuerySnapshot({required this.docs});

  /// Creates a snapshot from a list of JSON maps.
  factory QuerySnapshot.fromJson(List<dynamic> json) {
    return QuerySnapshot(
      docs: json
          .map((doc) => ScsDocument.fromJson(doc as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Represents a snapshot of a single document.
class DocumentSnapshot {
  /// The document, or null if it doesn't exist.
  final ScsDocument? document;

  /// Whether the document exists.
  bool get exists => document != null && document!.exists;

  /// The document data, or null if it doesn't exist.
  Map<String, dynamic>? get data => document?.data;

  /// The document ID.
  String? get id => document?.id;

  const DocumentSnapshot({this.document});

  /// Creates a snapshot from a JSON map.
  factory DocumentSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const DocumentSnapshot();
    }
    return DocumentSnapshot(document: ScsDocument.fromJson(json));
  }

  /// Gets a field value from the document.
  T? get<T>(String field) => document?.get<T>(field);
}
