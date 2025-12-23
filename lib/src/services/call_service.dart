import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../utils/http_client.dart';
import '../scs_config.dart';

/// Call types
enum CallType { voice, video, livestream }

/// Call modes
enum CallMode { p2p, group, broadcast }

/// Participant roles
enum ParticipantRole { host, coHost, participant, viewer }

/// Call model
class Call {
  final String callId;
  final String roomId;
  final String projectId;
  final CallType type;
  final CallMode mode;
  final String status;
  final String? hostId;
  final String? hostDisplayName;
  final int maxParticipants;
  final Map<String, dynamic> settings;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int duration;
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

/// Participant model
class Participant {
  final String participantId;
  final String? userId;
  final String displayName;
  final ParticipantRole role;
  final String status;
  final Map<String, bool> mediaState;
  final DateTime joinedAt;
  final DateTime? leftAt;
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

/// Call token data
class CallToken {
  final String token;
  final String tokenId;
  final ParticipantRole role;
  final List<String> permissions;
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

/// Call service statistics
class CallStats {
  final int totalCalls;
  final int activeCalls;
  final int totalMinutes;
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
