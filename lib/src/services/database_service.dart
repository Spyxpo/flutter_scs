import '../models/document.dart';
import '../models/query.dart';
import '../scs_exception.dart';
import '../utils/http_client.dart';

/// Service for database operations with collections and documents.
///
/// Provides a Firestore-like API for working with NoSQL data.
///
/// SCS supports two database backends (configured server-side via DATABASE_TYPE):
/// - **eaZI Database** (DATABASE_TYPE=eazi): File-based NoSQL, ideal for development
/// - **RelaDB** (DATABASE_TYPE=mongodb): Production-grade NoSQL with advanced features
///
/// The SDK API remains the same regardless of backend - switching databases requires
/// no client-side code changes.
class DatabaseService {
  final ScsHttpClient _client;

  DatabaseService(this._client);

  /// Gets a reference to a collection.
  CollectionReference collection(String name) {
    return CollectionReference(_client, name);
  }

  /// Lists all root collections.
  Future<List<String>> listCollections() async {
    final response = await _client.get('database/collections');
    final collections = response['collections'] as List<dynamic>? ?? [];
    return collections.map((c) {
      if (c is String) return c;
      if (c is Map) return c['name'] as String? ?? '';
      return '';
    }).where((c) => c.isNotEmpty).toList();
  }

  /// Creates a new collection.
  Future<void> createCollection(String name) async {
    await _client.post('database/collections', body: {'name': name});
  }

  /// Deletes a collection.
  Future<void> deleteCollection(String name) async {
    await _client.delete('database/collections/$name');
  }
}

/// A reference to a collection in the database.
class CollectionReference {
  final ScsHttpClient _client;
  final String _path;
  final List<QueryFilter> _filters = [];
  final List<QueryOrder> _orderBy = [];
  int? _limitValue;
  int? _skipValue;

  CollectionReference(this._client, this._path);

  /// Gets a reference to a document in this collection.
  DocumentReference doc(String id) {
    return DocumentReference(_client, _path, id);
  }

  /// Adds a new document to this collection.
  ///
  /// Returns the created document with its generated ID.
  Future<ScsDocument> add(Map<String, dynamic> data) async {
    final response = await _client.post(
      'database/collections/$_path/documents',
      body: data,
    );
    final docData = response['document'] as Map<String, dynamic>? ?? response;
    return ScsDocument.fromJson(docData);
  }

  /// Gets all documents in this collection.
  Future<QuerySnapshot> get() async {
    if (_filters.isEmpty && _orderBy.isEmpty && _limitValue == null && _skipValue == null) {
      // Simple get
      final response = await _client.get('database/collections/$_path/documents');
      final docs = response['documents'] as List<dynamic>? ?? [];
      return QuerySnapshot.fromJson(docs);
    }

    // Query with filters
    final queryParams = QueryParams(
      filters: _filters,
      orderBy: _orderBy,
      limit: _limitValue,
      skip: _skipValue,
    );

    final response = await _client.post(
      'database/collections/$_path/query',
      body: queryParams.toJson(),
    );
    final docs = response['documents'] as List<dynamic>? ?? [];
    return QuerySnapshot.fromJson(docs);
  }

  /// Adds a filter to the query.
  CollectionReference where(
    String field,
    QueryOperator operator,
    dynamic value,
  ) {
    final ref = _clone();
    ref._filters.add(QueryFilter(field: field, operator: operator, value: value));
    return ref;
  }

  /// Adds an equality filter (shorthand for where with ==).
  CollectionReference whereEqualTo(String field, dynamic value) {
    return where(field, QueryOperator.equalTo, value);
  }

  /// Adds a not-equal filter.
  CollectionReference whereNotEqualTo(String field, dynamic value) {
    return where(field, QueryOperator.notEqualTo, value);
  }

  /// Adds a less-than filter.
  CollectionReference whereLessThan(String field, dynamic value) {
    return where(field, QueryOperator.lessThan, value);
  }

  /// Adds a less-than-or-equal filter.
  CollectionReference whereLessThanOrEqualTo(String field, dynamic value) {
    return where(field, QueryOperator.lessThanOrEqualTo, value);
  }

  /// Adds a greater-than filter.
  CollectionReference whereGreaterThan(String field, dynamic value) {
    return where(field, QueryOperator.greaterThan, value);
  }

  /// Adds a greater-than-or-equal filter.
  CollectionReference whereGreaterThanOrEqualTo(String field, dynamic value) {
    return where(field, QueryOperator.greaterThanOrEqualTo, value);
  }

  /// Adds an array-contains filter.
  CollectionReference whereArrayContains(String field, dynamic value) {
    return where(field, QueryOperator.arrayContains, value);
  }

  /// Adds an in filter.
  CollectionReference whereIn(String field, List<dynamic> values) {
    return where(field, QueryOperator.isIn, values);
  }

  /// Adds ordering to the query.
  CollectionReference orderBy(
    String field, {
    SortDirection direction = SortDirection.ascending,
  }) {
    final ref = _clone();
    ref._orderBy.add(QueryOrder(field: field, direction: direction));
    return ref;
  }

  /// Orders by ascending.
  CollectionReference orderByAsc(String field) {
    return orderBy(field, direction: SortDirection.ascending);
  }

  /// Orders by descending.
  CollectionReference orderByDesc(String field) {
    return orderBy(field, direction: SortDirection.descending);
  }

  /// Limits the number of documents returned.
  CollectionReference limit(int count) {
    final ref = _clone();
    ref._limitValue = count;
    return ref;
  }

  /// Skips a number of documents.
  CollectionReference skip(int count) {
    final ref = _clone();
    ref._skipValue = count;
    return ref;
  }

  /// Gets a subcollection of a document.
  CollectionReference subcollection(String docId, String subcollectionName) {
    return CollectionReference(_client, '$_path/documents/$docId/collections/$subcollectionName');
  }

  CollectionReference _clone() {
    final ref = CollectionReference(_client, _path);
    ref._filters.addAll(_filters);
    ref._orderBy.addAll(_orderBy);
    ref._limitValue = _limitValue;
    ref._skipValue = _skipValue;
    return ref;
  }
}

/// A reference to a document in the database.
class DocumentReference {
  final ScsHttpClient _client;
  final String _collectionPath;
  final String _id;

  DocumentReference(this._client, this._collectionPath, this._id);

  /// The document ID.
  String get id => _id;

  /// The full path to this document.
  String get path => '$_collectionPath/$_id';

  /// Gets the document.
  Future<DocumentSnapshot> get() async {
    try {
      final response = await _client.get(
        'database/collections/$_collectionPath/documents/$_id',
      );
      final docData = response['document'] as Map<String, dynamic>? ?? response;
      return DocumentSnapshot.fromJson(docData);
    } on ScsException catch (e) {
      if (e.statusCode == 404) {
        return const DocumentSnapshot();
      }
      rethrow;
    }
  }

  /// Sets the document data, overwriting any existing data.
  Future<void> set(Map<String, dynamic> data) async {
    await _client.put(
      'database/collections/$_collectionPath/documents/$_id',
      body: data,
    );
  }

  /// Updates specific fields in the document.
  Future<void> update(Map<String, dynamic> data) async {
    await _client.put(
      'database/collections/$_collectionPath/documents/$_id',
      body: data,
    );
  }

  /// Deletes the document.
  Future<void> delete() async {
    await _client.delete(
      'database/collections/$_collectionPath/documents/$_id',
    );
  }

  /// Gets a reference to a subcollection.
  CollectionReference collection(String name) {
    return CollectionReference(
      _client,
      '$_collectionPath/documents/$_id/collections/$name',
    );
  }

  /// Lists subcollections of this document.
  Future<List<String>> listCollections() async {
    final response = await _client.get(
      'database/collections/$_collectionPath/documents/$_id/collections',
    );
    final collections = response['collections'] as List<dynamic>? ?? [];
    return collections.map((c) {
      if (c is String) return c;
      if (c is Map) return c['name'] as String? ?? '';
      return '';
    }).where((c) => c.isNotEmpty).toList();
  }
}
