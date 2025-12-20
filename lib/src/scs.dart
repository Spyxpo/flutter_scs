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

  bool _initialized = false;

  /// Creates a new SCS instance.
  SCS._(this.config)
      : _httpClient = ScsHttpClient(config),
        _sessionStorage = SessionStorage(projectId: config.projectId) {
    _initServices();
  }

  void _initServices() {
    _auth = AuthService(_httpClient, _sessionStorage);
    _database = DatabaseService(_httpClient);
    _storage = StorageService(_httpClient);
    _realtime = RealtimeService(_httpClient, config);
    _messaging = MessagingService(_httpClient);
    _remoteConfig = RemoteConfigService(_httpClient);
    _functions = FunctionsService(_httpClient, config);
    _ml = MlService(_httpClient);
    _ai = AiService(_httpClient);
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

  /// Gets the project ID.
  String get projectId => config.projectId;

  /// Gets the base URL.
  String get baseUrl => config.baseUrl;

  /// Disposes of resources used by the SDK.
  void dispose() {
    _realtime.dispose();
    _httpClient.close();
  }
}
