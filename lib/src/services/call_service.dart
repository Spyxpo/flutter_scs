import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../utils/http_client.dart';
import '../scs_config.dart';

/// Types of calls supported by the call service.
enum CallType {
  /// Audio-only voice call.
  voice,

  /// Video call with optional audio.
  video,

  /// One-to-many livestream broadcast.
  livestream,
}

/// Modes of call organization.
enum CallMode {
  /// Peer-to-peer call between two participants.
  p2p,

  /// Group call with multiple participants.
  group,

  /// Broadcast mode with hosts and viewers.
  broadcast,
}

/// Roles that participants can have in a call.
enum ParticipantRole {
  /// Primary call host with full permissions.
  host,

  /// Co-host with elevated permissions.
  coHost,

  /// Regular participant who can interact.
  participant,

  /// View-only participant (for broadcasts).
  viewer,
}

/// Represents a voice/video call or livestream session.
///
/// Contains all metadata about a call including its type, mode,
/// participants, settings, and timing information.
class Call {
  /// Unique identifier for the call.
  final String callId;

  /// Room identifier for the call.
  final String roomId;

  /// Project this call belongs to.
  final String projectId;

  /// Type of call (voice, video, or livestream).
  final CallType type;

  /// Mode of the call (p2p, group, or broadcast).
  final CallMode mode;

  /// Current status of the call (e.g., 'waiting', 'active', 'ended').
  final String status;

  /// User ID of the call host.
  final String? hostId;

  /// Display name of the call host.
  final String? hostDisplayName;

  /// Maximum number of participants allowed.
  final int maxParticipants;

  /// Call settings and configuration.
  final Map<String, dynamic> settings;

  /// When the call started.
  final DateTime? startedAt;

  /// When the call ended.
  final DateTime? endedAt;

  /// Duration of the call in seconds.
  final int duration;

  /// When the call was created.
  final DateTime createdAt;

  Call({
    required this.callId,
    required this.roomId,
    required this.projectId,
    required this.type,
    required this.mode,
    required this.status,
    this.hostId,
    this.hostDisplayName,
    required this.maxParticipants,
    required this.settings,
    this.startedAt,
    this.endedAt,
    required this.duration,
    required this.createdAt,
  });

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      callId: json['callId'] ?? '',
      roomId: json['roomId'] ?? '',
      projectId: json['projectId'] ?? '',
      type: _parseCallType(json['type']),
      mode: _parseCallMode(json['mode']),
      status: json['status'] ?? '',
      hostId: json['hostId'],
      hostDisplayName: json['hostDisplayName'],
      maxParticipants: json['maxParticipants'] ?? 50,
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
      duration: json['duration'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  static CallType _parseCallType(String? type) {
    switch (type) {
      case 'voice':
        return CallType.voice;
      case 'livestream':
        return CallType.livestream;
      default:
        return CallType.video;
    }
  }

  static CallMode _parseCallMode(String? mode) {
    switch (mode) {
      case 'p2p':
        return CallMode.p2p;
      case 'broadcast':
        return CallMode.broadcast;
      default:
        return CallMode.group;
    }
  }
}

/// Represents a participant in a call.
///
/// Contains information about the participant including their
/// role, media state, and session timing.
class Participant {
  /// Unique identifier for the participant.
  final String participantId;

  /// User ID if the participant is authenticated.
  final String? userId;

  /// Display name shown to other participants.
  final String displayName;

  /// Role of the participant in the call.
  final ParticipantRole role;

  /// Current status (e.g., 'connected', 'disconnected').
  final String status;

  /// Current media state (e.g., {'audio': true, 'video': false}).
  final Map<String, bool> mediaState;

  /// When the participant joined the call.
  final DateTime joinedAt;

  /// When the participant left the call (null if still in call).
  final DateTime? leftAt;

  /// Duration of participation in seconds.
  final int duration;

  Participant({
    required this.participantId,
    this.userId,
    required this.displayName,
    required this.role,
    required this.status,
    required this.mediaState,
    required this.joinedAt,
    this.leftAt,
    required this.duration,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      participantId: json['participantId'] ?? '',
      userId: json['userId'],
      displayName: json['displayName'] ?? '',
      role: _parseRole(json['role']),
      status: json['status'] ?? '',
      mediaState: Map<String, bool>.from(json['mediaState'] ?? {}),
      joinedAt: DateTime.parse(json['joinedAt'] ?? DateTime.now().toIso8601String()),
      leftAt: json['leftAt'] != null ? DateTime.parse(json['leftAt']) : null,
      duration: json['duration'] ?? 0,
    );
  }

  static ParticipantRole _parseRole(String? role) {
    switch (role) {
      case 'host':
        return ParticipantRole.host;
      case 'co-host':
        return ParticipantRole.coHost;
      case 'viewer':
        return ParticipantRole.viewer;
      default:
        return ParticipantRole.participant;
    }
  }
}

/// Authentication token for joining a call.
///
/// Contains the JWT token and associated metadata for
/// authenticating a participant to join a call.
class CallToken {
  /// The JWT token string.
  final String token;

  /// Unique identifier for this token.
  final String tokenId;

  /// Role granted by this token.
  final ParticipantRole role;

  /// List of permissions granted by this token.
  final List<String> permissions;

  /// When this token expires.
  final DateTime expiresAt;

  CallToken({
    required this.token,
    required this.tokenId,
    required this.role,
    required this.permissions,
    required this.expiresAt,
  });

  factory CallToken.fromJson(Map<String, dynamic> json) {
    return CallToken(
      token: json['token'] ?? '',
      tokenId: json['tokenId'] ?? '',
      role: Participant._parseRole(json['role']),
      permissions: List<String>.from(json['permissions'] ?? []),
      expiresAt: DateTime.parse(json['expiresAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Statistics about call service usage.
///
/// Contains aggregate metrics about calls in the project.
class CallStats {
  /// Total number of calls created.
  final int totalCalls;

  /// Number of currently active calls.
  final int activeCalls;

  /// Total call duration in minutes.
  final int totalMinutes;

  /// Number of recorded calls.
  final int recordings;

  CallStats({
    required this.totalCalls,
    required this.activeCalls,
    required this.totalMinutes,
    required this.recordings,
  });

  factory CallStats.fromJson(Map<String, dynamic> json) {
    return CallStats(
      totalCalls: json['totalCalls'] ?? 0,
      activeCalls: json['activeCalls'] ?? 0,
      totalMinutes: json['totalMinutes'] ?? 0,
      recordings: json['recordings'] ?? 0,
    );
  }
}

/// Call service for voice/video calls, group calls, and live streaming
class CallService {
  final ScsHttpClient _httpClient;
  final ScsConfig _config;
  io.Socket? _socket;
  bool _connected = false;
  String? _currentCallId;
  String? _participantId;

  // Event stream controllers
  final _participantJoinedController = StreamController<Participant>.broadcast();
  final _participantLeftController = StreamController<Participant>.broadcast();
  final _newProducerController = StreamController<Map<String, dynamic>>.broadcast();
  final _mediaStateChangedController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _callEndedController = StreamController<Map<String, dynamic>>.broadcast();
  final _transcriptionSegmentController = StreamController<Map<String, dynamic>>.broadcast();

  CallService(this._httpClient, this._config);

  /// Whether connected to a call
  bool get isConnected => _connected;

  /// Current call ID
  String? get currentCallId => _currentCallId;

  /// Current participant ID
  String? get participantId => _participantId;

  // Event streams
  Stream<Participant> get onParticipantJoined => _participantJoinedController.stream;
  Stream<Participant> get onParticipantLeft => _participantLeftController.stream;
  Stream<Map<String, dynamic>> get onNewProducer => _newProducerController.stream;
  Stream<Map<String, dynamic>> get onMediaStateChanged => _mediaStateChangedController.stream;
  Stream<Map<String, dynamic>> get onChatMessage => _chatMessageController.stream;
  Stream<Map<String, dynamic>> get onCallEnded => _callEndedController.stream;
  Stream<Map<String, dynamic>> get onTranscriptionSegment => _transcriptionSegmentController.stream;

  /// Get call service statistics
  Future<CallStats> getStats() async {
    final response = await _httpClient.get('calls/stats');
    return CallStats.fromJson(response['stats'] ?? {});
  }

  /// Create a new call
  Future<Call> createCall({
    CallType type = CallType.video,
    CallMode mode = CallMode.group,
    String? displayName,
    int maxParticipants = 50,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _httpClient.post('calls/create', body: {
      'type': type.name,
      'mode': mode.name,
      'displayName': displayName ?? 'Host',
      'maxParticipants': maxParticipants,
      'settings': settings ?? {},
      'metadata': metadata ?? {},
    });
    return Call.fromJson(response['call'] ?? {});
  }

  /// List calls
  Future<List<Call>> listCalls({
    String? status,
    String? type,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status;
    if (type != null) queryParams['type'] = type;
    queryParams['limit'] = limit.toString();

    final response = await _httpClient.get('calls', queryParams: queryParams);

    final callsList = response['calls'] as List? ?? [];
    return callsList.map((c) => Call.fromJson(c as Map<String, dynamic>)).toList();
  }

  /// Get call details
  Future<Call> getCall(String callId) async {
    final response = await _httpClient.get('calls/$callId');
    return Call.fromJson(response['call'] ?? {});
  }

  /// Update call settings
  Future<Call> updateCall(String callId, Map<String, dynamic> updates) async {
    final response = await _httpClient.put('calls/$callId', body: updates);
    return Call.fromJson(response['call'] ?? {});
  }

  /// End a call
  Future<Call> endCall(String callId) async {
    final response = await _httpClient.delete('calls/$callId');
    return Call.fromJson(response['call'] ?? {});
  }

  /// Generate a join token
  Future<CallToken> generateToken(
    String callId, {
    String? userId,
    required String displayName,
    ParticipantRole role = ParticipantRole.participant,
    List<String>? permissions,
    int? expiresIn,
  }) async {
    final response = await _httpClient.post('calls/$callId/tokens', body: {
      'userId': userId,
      'displayName': displayName,
      'role': _roleToString(role),
      'permissions': permissions,
      'expiresIn': expiresIn,
    });
    return CallToken.fromJson(response);
  }

  /// Validate a call token
  Future<Map<String, dynamic>> validateToken(String callId, String token) async {
    return await _httpClient.post('calls/$callId/tokens/validate', body: {'token': token});
  }

  /// Join a call using Socket.IO
  Future<Map<String, dynamic>> joinCall(String callId, String token) async {
    if (_connected) {
      throw Exception('Already connected to a call');
    }

    final completer = Completer<Map<String, dynamic>>();

    _socket = io.io(
      '${_config.baseUrl}/calls',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      // Connected to call signaling server
    });

    _socket!.on('call:joined', (data) {
      _connected = true;
      _currentCallId = callId;
      _participantId = data['participantId'];
      _setupEventHandlers();
      completer.complete(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('call:error', (data) {
      final errorData = data as Map;
      completer.completeError(Exception(errorData['message'] ?? 'Connection error'));
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      _currentCallId = null;
      _participantId = null;
    });

    _socket!.connect();

    return completer.future;
  }

  void _setupEventHandlers() {
    _socket?.on('call:participant:joined', (data) {
      _participantJoinedController.add(Participant.fromJson(Map<String, dynamic>.from(data as Map)));
    });

    _socket?.on('call:participant:left', (data) {
      _participantLeftController.add(Participant.fromJson(Map<String, dynamic>.from(data as Map)));
    });

    _socket?.on('call:producer:new', (data) {
      _newProducerController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket?.on('call:media-state:changed', (data) {
      _mediaStateChangedController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket?.on('call:chat:message', (data) {
      _chatMessageController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket?.on('call:ended', (data) {
      _callEndedController.add(Map<String, dynamic>.from(data as Map));
      leaveCall();
    });

    _socket?.on('call:transcription:segment', (data) {
      _transcriptionSegmentController.add(Map<String, dynamic>.from(data as Map));
    });
  }

  /// Leave the current call
  void leaveCall() {
    if (_socket != null) {
      _socket!.emit('call:leave');
      _socket!.disconnect();
      _socket = null;
    }
    _connected = false;
    _currentCallId = null;
    _participantId = null;
  }

  /// Update media state
  Future<void> updateMediaState({bool? video, bool? audio}) async {
    final completer = Completer<void>();
    _socket?.emitWithAck('call:media-state', {
      if (video != null) 'video': video,
      if (audio != null) 'audio': audio,
    }, ack: (response) {
      final data = response as Map;
      if (data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(Exception(data['error']));
      }
    });
    return completer.future;
  }

  /// Send chat message
  Future<String> sendChatMessage(String message) async {
    final completer = Completer<String>();
    _socket?.emitWithAck('call:chat:message', {'message': message}, ack: (response) {
      final data = response as Map;
      if (data['success'] == true) {
        completer.complete(data['messageId'] as String);
      } else {
        completer.completeError(Exception(data['error']));
      }
    });
    return completer.future;
  }

  /// Send reaction
  void sendReaction(String emoji) {
    _socket?.emit('call:reaction', {'emoji': emoji});
  }

  /// Raise/lower hand
  void raiseHand(bool raised) {
    _socket?.emit('call:raise-hand', {'raised': raised});
  }

  /// Get participants in a call
  Future<List<Participant>> getParticipants(String callId) async {
    final response = await _httpClient.get('calls/$callId/participants');
    final participantsList = response['participants'] as List? ?? [];
    return participantsList.map((p) => Participant.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// Kick a participant
  Future<void> kickParticipant(String callId, String participantId) async {
    await _httpClient.post('calls/$callId/participants/$participantId/kick', body: {});
  }

  /// Mute a participant
  Future<void> muteParticipant(String callId, String participantId, {String mediaType = 'audio'}) async {
    await _httpClient.post('calls/$callId/participants/$participantId/mute', body: {
      'mediaType': mediaType,
    });
  }

  /// Start recording
  Future<Map<String, dynamic>> startRecording(String callId, {
    String type = 'composite',
    String format = 'mp4',
  }) async {
    return await _httpClient.post('calls/$callId/recordings/start', body: {
      'type': type,
      'format': format,
    });
  }

  /// Stop recording
  Future<Map<String, dynamic>> stopRecording(String callId) async {
    return await _httpClient.post('calls/$callId/recordings/stop', body: {});
  }

  /// List recordings
  Future<List<Map<String, dynamic>>> listRecordings(String callId) async {
    final response = await _httpClient.get('calls/$callId/recordings');
    return List<Map<String, dynamic>>.from(response['recordings'] ?? []);
  }

  /// Start transcription
  Future<Map<String, dynamic>> startTranscription(String callId) async {
    return await _httpClient.post('calls/$callId/transcription/start', body: {});
  }

  /// Stop transcription
  Future<Map<String, dynamic>> stopTranscription(String callId) async {
    return await _httpClient.post('calls/$callId/transcription/stop', body: {});
  }

  /// Get transcription
  Future<Map<String, dynamic>?> getTranscription(String callId) async {
    final response = await _httpClient.get('calls/$callId/transcription');
    return response['transcription'] as Map<String, dynamic>?;
  }

  /// Get TURN servers
  Future<List<Map<String, dynamic>>> getTurnServers() async {
    final response = await _httpClient.get('calls/turn-servers');
    return List<Map<String, dynamic>>.from(response['servers'] ?? []);
  }

  String _roleToString(ParticipantRole role) {
    switch (role) {
      case ParticipantRole.host:
        return 'host';
      case ParticipantRole.coHost:
        return 'co-host';
      case ParticipantRole.viewer:
        return 'viewer';
      default:
        return 'participant';
    }
  }

  /// Dispose resources
  void dispose() {
    leaveCall();
    _participantJoinedController.close();
    _participantLeftController.close();
    _newProducerController.close();
    _mediaStateChangedController.close();
    _chatMessageController.close();
    _callEndedController.close();
    _transcriptionSegmentController.close();
  }
}
