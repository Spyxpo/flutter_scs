/// Query operators for database queries.
enum QueryOperator {
  equalTo('=='),
  notEqualTo('!='),
  lessThan('<'),
  lessThanOrEqualTo('<='),
  greaterThan('>'),
  greaterThanOrEqualTo('>='),
  contains('contains'),
  arrayContains('array-contains'),
  isIn('in'),
  notIn('not-in');

  final String value;
  const QueryOperator(this.value);
}

/// Sort direction for query ordering.
enum SortDirection {
  ascending('asc'),
  descending('desc');

  final String value;
  const SortDirection(this.value);
}

/// A filter condition for a query.
class QueryFilter {
  final String field;
  final QueryOperator operator;
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
class QueryOrder {
  final String field;
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
class QueryParams {
  final List<QueryFilter> filters;
  final List<QueryOrder> orderBy;
  final int? limit;
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
