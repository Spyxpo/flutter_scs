import 'scs_config.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/storage_service.dart';
import 'services/realtime_service.dart';
import 'services/messaging_service.dart';
import 'services/remote_config_service.dart';
import 'services/functions_service.dart';
import 'services/ml_service.dart';
import 'services/ai_service.dart';
import 'services/call_service.dart';
import 'services/new_services.dart' as ns;
import 'utils/http_client.dart';
import 'utils/session_storage.dart';

/// The main entry point for the SCS SDK.
///
/// Use [SCS.initializeApp] to create an instance from configuration.
///
/// Example:
/// ```dart
/// final scs = await SCS.initializeApp(ScsConfig(
///   apiKey: 'your-api-key',
///   projectId: 'your-project-id',
///   baseUrl: 'https://api.scs.app',
/// ));
///
/// // Use services
/// final user = await scs.auth.login(
///   email: 'user@example.com',
///   password: 'password',
/// );
/// ```
class SCS {
  /// The configuration for this SCS instance.
  final ScsConfig config;

  /// The HTTP client used for API requests.
  final ScsHttpClient _httpClient;

  /// The session storage for persisting auth state.
  final SessionStorage _sessionStorage;

  // Services
  late final AuthService _auth;
  late final DatabaseService _database;
  late final StorageService _storage;
  late final RealtimeService _realtime;
  late final MessagingService _messaging;
  late final RemoteConfigService _remoteConfig;
  late final FunctionsService _functions;
  late final MlService _ml;
  late final AiService _ai;
  late final CallService _calls;

  bool _initialized = false;

  /// Creates a new SCS instance.
  SCS._(this.config)
      : _httpClient = ScsHttpClient(config),
        _sessionStorage = SessionStorage(projectId: config.projectId) {
    _initServices();
  }

  void _initServices() {
    _auth = AuthService(_httpClient, _sessionStorage, config.baseUrl);
    _database = DatabaseService(_httpClient);
    _storage = StorageService(_httpClient);
    _realtime = RealtimeService(_httpClient, config);
    _messaging = MessagingService(_httpClient);
    _remoteConfig = RemoteConfigService(_httpClient);
    _functions = FunctionsService(_httpClient, config);
    _ml = MlService(_httpClient);
    _ai = AiService(_httpClient);
    _calls = CallService(_httpClient, config);
  }

  /// Initializes the SCS SDK from a configuration object.
  static Future<SCS> initializeApp(ScsConfig config) async {
    final instance = SCS._(config);
    await instance._initialize();
    return instance;
  }

  /// Initializes the SCS SDK from a JSON configuration map.
  static Future<SCS> initializeAppFromJson(Map<String, dynamic> json) async {
    final config = ScsConfig.fromJson(json);
    return initializeApp(config);
  }

  /// Initializes the SCS SDK from a configuration file path.
  static Future<SCS> initializeAppFromFile(String path) async {
    final config = await ScsConfig.fromFile(path);
    return initializeApp(config);
  }

  /// Internal initialization.
  Future<void> _initialize() async {
    if (_initialized) return;

    // Initialize session storage and restore auth state
    await _sessionStorage.init();
    final token = await _sessionStorage.getToken();
    if (token != null) {
      _httpClient.setUserToken(token);
    }

    _initialized = true;
  }

  /// Gets the authentication service.
  AuthService get auth => _auth;

  /// Gets the database service.
  DatabaseService get database => _database;

  /// Gets the storage service.
  StorageService get storage => _storage;

  /// Gets the real-time database service.
  RealtimeService get realtime => _realtime;

  /// Gets the cloud messaging service.
  MessagingService get messaging => _messaging;

  /// Gets the remote config service.
  RemoteConfigService get remoteConfig => _remoteConfig;

  /// Gets the cloud functions service.
  FunctionsService get functions => _functions;

  /// Gets the machine learning service.
  MlService get ml => _ml;

  /// Gets the AI service.
  AiService get ai => _ai;

  /// Gets the call service for voice/video calls, group calls, and live streaming.
  CallService get calls => _calls;

  /// Gets the project ID.
  String get projectId => config.projectId;

  /// Gets the base URL.
  String get baseUrl => config.baseUrl;

  // ---- new services (25) — lazily instantiated ----
  ns.SqlService? _sql;
  ns.MailService? _mail;
  ns.QueueService? _queue;
  ns.CronService? _cron;
  ns.VaultService? _vault;
  ns.AnalyticsService? _analytics;
  ns.MonitorService? _monitor;
  ns.SearchService? _search;
  ns.CdnService? _cdn;
  ns.SmsService? _sms;
  ns.AccessService? _access;
  ns.PipelineService? _pipeline;
  ns.ExperimentsService? _experiments;
  ns.InboxService? _inbox;
  ns.LinksService? _links;
  ns.CrashService? _crash;
  ns.PerfService? _perf;
  ns.DnsService? _dns;
  ns.TranslateService? _translate;
  ns.WarehouseService? _warehouse;
  ns.ArtifactService? _artifact;
  ns.BillingService? _billing;
  ns.WorkflowsService? _workflows;
  ns.IotService? _iot;
  ns.FirewallService? _firewall;

  ns.SqlService         get sql         => _sql         ??= ns.SqlService(_httpClient, config.projectId);
  ns.MailService        get mail        => _mail        ??= ns.MailService(_httpClient);
  ns.QueueService       get queue       => _queue       ??= ns.QueueService(_httpClient, config.projectId);
  ns.CronService        get cron        => _cron        ??= ns.CronService(_httpClient);
  ns.VaultService       get vault       => _vault       ??= ns.VaultService(_httpClient, config.projectId);
  ns.AnalyticsService   get analytics   => _analytics   ??= ns.AnalyticsService(_httpClient, config.projectId);
  ns.MonitorService     get monitor     => _monitor     ??= ns.MonitorService(_httpClient, config.projectId);
  ns.SearchService      get search      => _search      ??= ns.SearchService(_httpClient, config.projectId);
  ns.CdnService         get cdn         => _cdn         ??= ns.CdnService(_httpClient);
  ns.SmsService         get sms         => _sms         ??= ns.SmsService(_httpClient);
  ns.AccessService      get access      => _access      ??= ns.AccessService(_httpClient, config.projectId);
  ns.PipelineService    get pipeline    => _pipeline    ??= ns.PipelineService(_httpClient, config.projectId);
  ns.ExperimentsService get experiments => _experiments ??= ns.ExperimentsService(_httpClient, config.projectId);
  ns.InboxService       get inbox       => _inbox       ??= ns.InboxService(_httpClient, config.projectId);
  ns.LinksService       get links       => _links       ??= ns.LinksService(_httpClient, config.projectId);
  ns.CrashService       get crash       => _crash       ??= ns.CrashService(_httpClient, config.projectId);
  ns.PerfService        get perf        => _perf        ??= ns.PerfService(_httpClient, config.projectId);
  ns.DnsService         get dns         => _dns         ??= ns.DnsService(_httpClient, config.projectId);
  ns.TranslateService   get translate   => _translate   ??= ns.TranslateService(_httpClient);
  ns.WarehouseService   get warehouse   => _warehouse   ??= ns.WarehouseService(_httpClient, config.projectId);
  ns.ArtifactService    get artifact    => _artifact    ??= ns.ArtifactService(_httpClient, config.projectId);
  ns.BillingService     get billing     => _billing     ??= ns.BillingService(_httpClient, config.projectId);
  ns.WorkflowsService   get workflows   => _workflows   ??= ns.WorkflowsService(_httpClient, config.projectId);
  ns.IotService         get iot         => _iot         ??= ns.IotService(_httpClient, config.projectId);
  ns.FirewallService    get firewall    => _firewall    ??= ns.FirewallService(_httpClient);

  /// Disposes of resources used by the SDK.
  void dispose() {
    _realtime.dispose();
    _calls.dispose();
    _httpClient.close();
  }
}
