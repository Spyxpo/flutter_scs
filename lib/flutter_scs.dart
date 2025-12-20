/// Flutter SDK for SCS (Spyxpo Cloud Services)
///
/// A complete backend-as-a-service SDK providing authentication, database,
/// storage, real-time sync, messaging, remote config, and ML/AI services.
library flutter_scs;

// Core
export 'src/scs.dart';
export 'src/scs_config.dart';
export 'src/scs_exception.dart';

// Services
export 'src/services/auth_service.dart';
export 'src/services/database_service.dart';
export 'src/services/storage_service.dart';
export 'src/services/realtime_service.dart';
export 'src/services/messaging_service.dart';
export 'src/services/remote_config_service.dart';
export 'src/services/functions_service.dart';
export 'src/services/ml_service.dart';
export 'src/services/ai_service.dart';

// Models
export 'src/models/user.dart';
export 'src/models/document.dart';
export 'src/models/file_metadata.dart';
export 'src/models/query.dart';
export 'src/models/message.dart';
