/// Query operators for database queries.
///
/// Used to filter documents in collection queries.
enum QueryOperator {
  /// Matches documents where field equals value.
  equalTo('=='),

  /// Matches documents where field does not equal value.
  notEqualTo('!='),

  /// Matches documents where field is less than value.
  lessThan('<'),

  /// Matches documents where field is less than or equal to value.
  lessThanOrEqualTo('<='),

  /// Matches documents where field is greater than value.
  greaterThan('>'),

  /// Matches documents where field is greater than or equal to value.
  greaterThanOrEqualTo('>='),

  /// Matches documents where string field contains substring.
  contains('contains'),

  /// Matches documents where array field contains value.
  arrayContains('array-contains'),

  /// Matches documents where field value is in the given list.
  isIn('in'),

  /// Matches documents where field value is not in the given list.
  notIn('not-in');

  /// The string representation of the operator.
  final String value;

  const QueryOperator(this.value);
}

/// Sort direction for query ordering.
///
/// Used to specify the order in which query results are returned.
enum SortDirection {
  /// Sort in ascending order (A-Z, 0-9, oldest first).
  ascending('asc'),

  /// Sort in descending order (Z-A, 9-0, newest first).
  descending('desc');

  /// The string representation of the direction.
  final String value;

  const SortDirection(this.value);
}

/// A filter condition for a query.
///
/// Represents a single filter criterion that can be applied to a query.
class QueryFilter {
  /// The field name to filter on.
  final String field;

  /// The comparison operator to use.
  final QueryOperator operator;

  /// The value to compare against.
  final dynamic value;

  const QueryFilter({
    required this.field,
    required this.operator,
    required this.value,
  });

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'operator': operator.value,
      'value': value,
    };
  }
}

/// An ordering clause for a query.
///
/// Specifies how query results should be sorted.
class QueryOrder {
  /// The field name to sort by.
  final String field;

  /// The direction to sort in.
  final SortDirection direction;

  const QueryOrder({
    required this.field,
    this.direction = SortDirection.ascending,
  });

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'direction': direction.value,
    };
  }
}

/// Query parameters for database operations.
///
/// Combines filters, ordering, and pagination for querying collections.
class QueryParams {
  /// List of filter conditions to apply.
  final List<QueryFilter> filters;

  /// List of ordering clauses to apply.
  final List<QueryOrder> orderBy;

  /// Maximum number of documents to return.
  final int? limit;

  /// Number of documents to skip (for pagination).
  final int? skip;

  const QueryParams({
    this.filters = const [],
    this.orderBy = const [],
    this.limit,
    this.skip,
  });

  Map<String, dynamic> toJson() {
    return {
      if (filters.isNotEmpty) 'filters': filters.map((f) => f.toJson()).toList(),
      if (orderBy.isNotEmpty) 'orderBy': orderBy.map((o) => o.toJson()).toList(),
      if (limit != null) 'limit': limit,
      if (skip != null) 'skip': skip,
    };
  }

  /// Creates a copy with updated parameters.
  QueryParams copyWith({
    List<QueryFilter>? filters,
    List<QueryOrder>? orderBy,
    int? limit,
    int? skip,
  }) {
    return QueryParams(
      filters: filters ?? this.filters,
      orderBy: orderBy ?? this.orderBy,
      limit: limit ?? this.limit,
      skip: skip ?? this.skip,
    );
  }
}
