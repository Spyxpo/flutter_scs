// SCS Flutter SDK — bindings for the 25 new SCS services.
//
// Each class takes the ScsHttpClient and exposes thin methods that hit the
// backend REST routes under /api/. All methods return the raw decoded JSON
// as Map<String, dynamic> so callers can read whichever fields they care
// about without needing bespoke model classes.

import '../utils/http_client.dart';

class _Base {
  final ScsHttpClient client;
  final String projectId;
  _Base(this.client, this.projectId);
}

// ===========================================================================
// Tier 1
// ===========================================================================

class SqlService extends _Base {
  SqlService(super.client, super.projectId);

  Future<Map<String, dynamic>> listTables() =>
      client.get('sql/$projectId/tables');

  Future<Map<String, dynamic>> createTable(String name, List<Map<String, dynamic>> columns) =>
      client.post('sql/$projectId/tables', body: {'name': name, 'columns': columns});

  Future<Map<String, dynamic>> describeTable(String table) =>
      client.get('sql/$projectId/tables/$table');

  Future<Map<String, dynamic>> dropTable(String table) =>
      client.delete('sql/$projectId/tables/$table');

  Future<Map<String, dynamic>> insert(String table, Map<String, dynamic> row) =>
      client.post('sql/$projectId/tables/$table/rows', body: {'row': row});

  Future<Map<String, dynamic>> select(String table, {Map<String, dynamic>? where, int? limit, String? orderBy}) =>
      client.post('sql/$projectId/tables/$table/select', body: {
        if (where != null) 'where': where,
        if (limit != null) 'limit': limit,
        if (orderBy != null) 'orderBy': orderBy,
      });

  Future<Map<String, dynamic>> update(String table, Map<String, dynamic> where, Map<String, dynamic> patch) =>
      client.patch('sql/$projectId/tables/$table/rows', body: {'where': where, 'patch': patch});

  Future<Map<String, dynamic>> query(String sql, [List params = const []]) =>
      client.post('sql/$projectId/query', body: {'sql': sql, 'params': params});
}

class MailService {
  final ScsHttpClient client;
  MailService(this.client);

  Future<Map<String, dynamic>> status() => client.get('mail/status');

  Future<Map<String, dynamic>> send({
    required String to,
    required String subject,
    String? html,
    String? text,
  }) =>
      client.post('mail/send', body: {
        'to': to,
        'subject': subject,
        if (html != null) 'html': html,
        if (text != null) 'text': text,
      });

  Future<Map<String, dynamic>> sendBulk({
    required List<String> recipients,
    required String subject,
    String? html,
    String? text,
  }) =>
      client.post('mail/send-bulk', body: {
        'recipients': recipients,
        'subject': subject,
        if (html != null) 'html': html,
        if (text != null) 'text': text,
      });
}

class QueueService extends _Base {
  QueueService(super.client, super.projectId);

  Future<Map<String, dynamic>> publish(String topic, dynamic payload, {int delaySeconds = 0}) =>
      client.post('queue/$projectId/publish',
          body: {'topic': topic, 'payload': payload, 'delaySeconds': delaySeconds});

  Future<Map<String, dynamic>> pull(String topic, {int limit = 10}) =>
      client.get('queue/pull/$topic', queryParams: {'limit': '$limit'});

  Future<Map<String, dynamic>> ack(String jobId) =>
      client.post('queue/ack/$jobId');

  Future<Map<String, dynamic>> nack(String jobId, {bool requeue = true}) =>
      client.post('queue/nack/$jobId', body: {'requeue': requeue});

  Future<Map<String, dynamic>> stats() => client.get('queue/stats');
}

class CronService {
  final ScsHttpClient client;
  CronService(this.client);

  Future<Map<String, dynamic>> list() => client.get('cron');

  Future<Map<String, dynamic>> create({
    required String name,
    required String schedule,
    required Map<String, dynamic> target,
    String? projectId,
    bool enabled = true,
  }) =>
      client.post('cron', body: {
        'name': name,
        'schedule': schedule,
        'target': target,
        if (projectId != null) 'projectId': projectId,
        'enabled': enabled,
      });

  Future<Map<String, dynamic>> setEnabled(String id, bool enabled) =>
      client.patch('cron/$id/enabled', body: {'enabled': enabled});

  Future<Map<String, dynamic>> delete(String id) => client.delete('cron/$id');
}

class VaultService extends _Base {
  VaultService(super.client, super.projectId);

  Future<Map<String, dynamic>> list() => client.get('vault/$projectId/secrets');

  Future<Map<String, dynamic>> set(String name, String value) =>
      client.post('vault/$projectId/secrets', body: {'name': name, 'value': value});

  Future<Map<String, dynamic>> get(String name) =>
      client.get('vault/$projectId/secrets/$name');

  Future<Map<String, dynamic>> delete(String name) =>
      client.delete('vault/$projectId/secrets/$name');
}

class AnalyticsService extends _Base {
  AnalyticsService(super.client, super.projectId);

  Future<Map<String, dynamic>> track({
    required String event,
    String? userId,
    String? sessionId,
    Map<String, dynamic>? properties,
  }) =>
      client.post('analytics/$projectId/track', body: {
        'event': event,
        if (userId != null) 'userId': userId,
        if (sessionId != null) 'sessionId': sessionId,
        if (properties != null) 'properties': properties,
      });

  Future<Map<String, dynamic>> summary({int rangeDays = 7}) =>
      client.get('analytics/$projectId/summary', queryParams: {'rangeDays': '$rangeDays'});

  Future<Map<String, dynamic>> query({String? event, String? userId, int limit = 100}) =>
      client.get('analytics/$projectId/events', queryParams: {
        if (event != null) 'event': event,
        if (userId != null) 'userId': userId,
        'limit': '$limit',
      });
}

class MonitorService extends _Base {
  MonitorService(super.client, super.projectId);

  Future<Map<String, dynamic>> listChecks() => client.get('monitor/checks');

  Future<Map<String, dynamic>> createCheck({
    required String name,
    required String url,
    String method = 'GET',
    int intervalSeconds = 60,
    int timeoutMs = 10000,
  }) =>
      client.post('monitor/checks', body: {
        'name': name,
        'url': url,
        'method': method,
        'intervalSeconds': intervalSeconds,
        'timeoutMs': timeoutMs,
        'projectId': projectId,
      });

  Future<Map<String, dynamic>> deleteCheck(String id) =>
      client.delete('monitor/checks/$id');

  Future<Map<String, dynamic>> checkResults(String id, {int limit = 50}) =>
      client.get('monitor/checks/$id/results', queryParams: {'limit': '$limit'});

  Future<Map<String, dynamic>> recordMetric(String name, num value, {Map<String, dynamic>? labels}) =>
      client.post('monitor/$projectId/metrics', body: {
        'name': name,
        'value': value,
        if (labels != null) 'labels': labels,
      });

  Future<Map<String, dynamic>> queryMetric(String name, {int sinceMs = 3600000}) =>
      client.get('monitor/$projectId/metrics/$name', queryParams: {'sinceMs': '$sinceMs'});
}

// ===========================================================================
// Tier 2
// ===========================================================================

class SearchService extends _Base {
  SearchService(super.client, super.projectId);

  Future<Map<String, dynamic>> upsert(String index, {String? id, required Map<String, dynamic> fields}) =>
      client.post('search/$projectId/$index/docs', body: {if (id != null) 'id': id, 'fields': fields});

  Future<Map<String, dynamic>> delete(String index, String docId) =>
      client.delete('search/$projectId/$index/docs/$docId');

  Future<Map<String, dynamic>> search(String index, String q, {int limit = 20}) =>
      client.get('search/$projectId/$index/search', queryParams: {'q': q, 'limit': '$limit'});
}

class CdnService {
  final ScsHttpClient client;
  CdnService(this.client);

  Future<Map<String, dynamic>> stats() => client.get('cdn/stats');
  Future<Map<String, dynamic>> purge(String url) => client.post('cdn/purge', body: {'url': url});
}

class SmsService {
  final ScsHttpClient client;
  SmsService(this.client);

  Future<Map<String, dynamic>> send({
    required String to,
    required String message,
    String provider = 'msg91',
  }) =>
      client.post('sms/send', body: {'to': to, 'message': message, 'provider': provider});
}

class AccessService extends _Base {
  AccessService(super.client, super.projectId);

  Future<Map<String, dynamic>> listRoles() => client.get('access/$projectId/roles');

  Future<Map<String, dynamic>> createRole(String name, List<String> permissions) =>
      client.post('access/$projectId/roles', body: {'name': name, 'permissions': permissions});

  Future<Map<String, dynamic>> deleteRole(String name) =>
      client.delete('access/$projectId/roles/$name');

  Future<Map<String, dynamic>> bind(String userId, String roleName) =>
      client.post('access/$projectId/bindings', body: {'userId': userId, 'roleName': roleName});

  Future<Map<String, dynamic>> listBindings() => client.get('access/$projectId/bindings');

  Future<Map<String, dynamic>> check(String userId, String permission) =>
      client.post('access/$projectId/check', body: {'userId': userId, 'permission': permission});
}

class PipelineService extends _Base {
  PipelineService(super.client, super.projectId);

  Future<Map<String, dynamic>> list() => client.get('pipeline/$projectId/pipelines');

  Future<Map<String, dynamic>> create(String name, List<String> steps, {String? cwd}) =>
      client.post('pipeline/$projectId/pipelines',
          body: {'name': name, 'steps': steps, if (cwd != null) 'cwd': cwd});

  Future<Map<String, dynamic>> trigger(String pipelineId) =>
      client.post('pipeline/pipelines/$pipelineId/trigger');

  Future<Map<String, dynamic>> getRun(String runId) =>
      client.get('pipeline/runs/$runId');
}

class ExperimentsService extends _Base {
  ExperimentsService(super.client, super.projectId);

  Future<Map<String, dynamic>> list() => client.get('experiments/$projectId');

  Future<Map<String, dynamic>> create(String key, List<Map<String, dynamic>> variants) =>
      client.post('experiments/$projectId', body: {'key': key, 'variants': variants});

  Future<Map<String, dynamic>> assign(String key, String userId) =>
      client.post('experiments/$projectId/$key/assign', body: {'userId': userId});
}

class InboxService extends _Base {
  InboxService(super.client, super.projectId);

  Future<Map<String, dynamic>> send({
    required String userId,
    required String title,
    String? body,
    Map<String, dynamic>? data,
  }) =>
      client.post('inbox/$projectId/send', body: {
        'userId': userId,
        'title': title,
        if (body != null) 'body': body,
        if (data != null) 'data': data,
      });

  Future<Map<String, dynamic>> list(String userId, {bool unread = false, int limit = 50}) =>
      client.get('inbox/$projectId/users/$userId/messages',
          queryParams: {'unread': '$unread', 'limit': '$limit'});

  Future<Map<String, dynamic>> markRead(String messageId) =>
      client.patch('inbox/messages/$messageId/read');

  Future<Map<String, dynamic>> delete(String messageId) =>
      client.delete('inbox/messages/$messageId');
}

class LinksService extends _Base {
  LinksService(super.client, super.projectId);

  Future<Map<String, dynamic>> create({
    required String web,
    String? slug,
    String? android,
    String? ios,
    Map<String, dynamic>? meta,
  }) =>
      client.post('links/$projectId', body: {
        'web': web,
        if (slug != null) 'slug': slug,
        if (android != null) 'android': android,
        if (ios != null) 'ios': ios,
        if (meta != null) 'meta': meta,
      });

  Future<Map<String, dynamic>> list() => client.get('links/$projectId');
  Future<Map<String, dynamic>> delete(String slug) => client.delete('links/$slug');
}

// ===========================================================================
// Tier 3 — observability
// ===========================================================================

class CrashService extends _Base {
  CrashService(super.client, super.projectId);

  Future<Map<String, dynamic>> report({
    required String name,
    String? message,
    String? stack,
    String? userId,
    Map<String, dynamic>? context,
    String? platform,
  }) =>
      client.post('crash/$projectId/report', body: {
        'name': name,
        if (message != null) 'message': message,
        if (stack != null) 'stack': stack,
        if (userId != null) 'userId': userId,
        if (context != null) 'context': context,
        if (platform != null) 'platform': platform,
      });

  Future<Map<String, dynamic>> groups({int limit = 50}) =>
      client.get('crash/$projectId/groups', queryParams: {'limit': '$limit'});

  Future<Map<String, dynamic>> events(String groupId, {int limit = 50}) =>
      client.get('crash/groups/$groupId/events', queryParams: {'limit': '$limit'});
}

class PerfService extends _Base {
  PerfService(super.client, super.projectId);

  Future<Map<String, dynamic>> record({
    required String name,
    required num durationMs,
    Map<String, dynamic>? attributes,
  }) =>
      client.post('perf/$projectId/traces', body: {
        'name': name,
        'durationMs': durationMs,
        if (attributes != null) 'attributes': attributes,
      });

  Future<Map<String, dynamic>> summary({int rangeDays = 1}) =>
      client.get('perf/$projectId/summary', queryParams: {'rangeDays': '$rangeDays'});
}

// ===========================================================================
// Extra GCP
// ===========================================================================

class DnsService extends _Base {
  DnsService(super.client, super.projectId);

  Future<Map<String, dynamic>> listZones() => client.get('dns/$projectId/zones');
  Future<Map<String, dynamic>> createZone(String domain) =>
      client.post('dns/$projectId/zones', body: {'domain': domain});
  Future<Map<String, dynamic>> listRecords(String zoneId) =>
      client.get('dns/zones/$zoneId/records');
  Future<Map<String, dynamic>> addRecord(String zoneId,
          {required String name, required String type, required String value, int ttl = 300}) =>
      client.post('dns/zones/$zoneId/records',
          body: {'name': name, 'type': type, 'value': value, 'ttl': ttl});
  Future<Map<String, dynamic>> deleteRecord(String recordId) =>
      client.delete('dns/records/$recordId');
  Future<Map<String, dynamic>> exportZone(String zoneId) =>
      client.get('dns/zones/$zoneId/export');
}

class TranslateService {
  final ScsHttpClient client;
  TranslateService(this.client);

  Future<Map<String, dynamic>> translate({
    required String text,
    required String target,
    String? source,
    Map<String, dynamic>? providerConfig,
  }) =>
      client.post('translate', body: {
        'text': text,
        'target': target,
        if (source != null) 'source': source,
        if (providerConfig != null) 'providerConfig': providerConfig,
      });
}

class WarehouseService extends _Base {
  WarehouseService(super.client, super.projectId);

  Future<Map<String, dynamic>> datasets() => client.get('warehouse/$projectId/datasets');

  Future<Map<String, dynamic>> query(String dataset, String sql, [List params = const []]) =>
      client.post('warehouse/$projectId/$dataset/query', body: {'sql': sql, 'params': params});
}

class ArtifactService extends _Base {
  ArtifactService(super.client, super.projectId);

  Future<Map<String, dynamic>> list() => client.get('artifact/$projectId');

  Future<Map<String, dynamic>> upload({
    required String name,
    required String version,
    required String data,
    String contentType = 'application/octet-stream',
  }) =>
      client.post('artifact/$projectId/upload', body: {
        'name': name,
        'version': version,
        'data': data,
        'contentType': contentType,
      });
}

class BillingService extends _Base {
  BillingService(super.client, super.projectId);

  Future<Map<String, dynamic>> record(String metric, {num qty = 1, Map<String, dynamic>? meta}) =>
      client.post('billing/$projectId/usage',
          body: {'metric': metric, 'qty': qty, if (meta != null) 'meta': meta});

  Future<Map<String, dynamic>> summary({int sinceMs = 2592000000}) =>
      client.get('billing/$projectId/summary', queryParams: {'sinceMs': '$sinceMs'});
}

class WorkflowsService extends _Base {
  WorkflowsService(super.client, super.projectId);

  Future<Map<String, dynamic>> list() => client.get('workflows/$projectId');

  Future<Map<String, dynamic>> create(String name, List<Map<String, dynamic>> steps) =>
      client.post('workflows/$projectId', body: {'name': name, 'steps': steps});

  Future<Map<String, dynamic>> execute(String workflowId, {Map<String, dynamic>? input}) =>
      client.post('workflows/workflows/$workflowId/execute',
          body: {'input': input ?? {}});

  Future<Map<String, dynamic>> getExecution(String execId) =>
      client.get('workflows/executions/$execId');
}

class IotService extends _Base {
  IotService(super.client, super.projectId);

  Future<Map<String, dynamic>> registerDevice(String deviceId, {Map<String, dynamic>? meta}) =>
      client.post('iot/$projectId/devices',
          body: {'deviceId': deviceId, if (meta != null) 'meta': meta});

  Future<Map<String, dynamic>> listDevices() => client.get('iot/$projectId/devices');

  Future<Map<String, dynamic>> ingest({
    required String deviceId,
    required String token,
    required dynamic payload,
  }) =>
      client.post('iot/ingest', body: {'deviceId': deviceId, 'token': token, 'payload': payload});

  Future<Map<String, dynamic>> telemetry(String deviceId, {int limit = 50}) =>
      client.get('iot/devices/$deviceId/telemetry', queryParams: {'limit': '$limit'});
}

class FirewallService {
  final ScsHttpClient client;
  FirewallService(this.client);

  Future<Map<String, dynamic>> listRules() => client.get('firewall/rules');

  Future<Map<String, dynamic>> addRule({required Map<String, dynamic> match, String action = 'deny'}) =>
      client.post('firewall/rules', body: {'action': action, 'match': match});

  Future<Map<String, dynamic>> deleteRule(String id) => client.delete('firewall/rules/$id');
}
