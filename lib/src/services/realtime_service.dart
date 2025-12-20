import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../scs_config.dart';
import '../scs_exception.dart';
import '../utils/http_client.dart';

/// Service for real-time database operations.
///
/// Provides WebSocket-based real-time data synchronization.
class RealtimeService {
  final ScsHttpClient _client;
  final ScsConfig _config;

  WebSocketChannel? _channel;
  bool _connected = false;
  final Map<String, List<void Function(dynamic)>> _listeners = {};
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  RealtimeService(this._client, this._config);

  /// Whether the WebSocket is connected.
  bool get isConnected => _connected;

  /// Stream of connection state changes.
  Stream<bool> get connectionState => _connectionStateController.stream;

  /// Connects to the real-time database.
  Future<void> connect() async {
    if (_connected) return;

    try {
      final wsUrl = _config.baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');

      final uri = Uri.parse('$wsUrl/socket.io/?EIO=4&transport=websocket')
          .replace(queryParameters: {
        'EIO': '4',
        'transport': 'websocket',
        'apiKey': _config.apiKey,
      });

      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _connected = true;
      _connectionStateController.add(true);
      _startPingTimer();
    } catch (e) {
      throw ScsException.network('Failed to connect to real-time database: $e');
    }
  }

  /// Disconnects from the real-time database.
  void disconnect() {
    _stopPingTimer();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    _connectionStateController.add(false);
  }

  /// Gets a reference to a path in the real-time database.
  RealtimeRef ref([String? path]) {
    return RealtimeRef(this, _client, path ?? '');
  }

  /// Subscribes to changes at a path.
  void subscribe(String path, void Function(dynamic data) callback) {
    _listeners.putIfAbsent(path, () => []).add(callback);

    if (_connected) {
      _sendMessage({
        'type': 'subscribe',
        'path': path,
      });
    }
  }

  /// Unsubscribes from changes at a path.
  void unsubscribe(String path, [void Function(dynamic data)? callback]) {
    if (callback != null) {
      _listeners[path]?.remove(callback);
      if (_listeners[path]?.isEmpty ?? false) {
        _listeners.remove(path);
      }
    } else {
      _listeners.remove(path);
    }

    if (_connected && !_listeners.containsKey(path)) {
      _sendMessage({
        'type': 'unsubscribe',
        'path': path,
      });
    }
  }

  /// Gets data at a path (via REST fallback).
  Future<dynamic> getData([String? path]) async {
    final endpoint = path != null && path.isNotEmpty
        ? 'realtime/data/$path'
        : 'realtime/data';
    final response = await _client.get(endpoint);
    return response['data'];
  }

  /// Sets data at a path.
  Future<void> setData(String path, dynamic data) async {
    final response = await _client.put(
      'realtime/data/$path',
      body: {'data': data},
    );
    _notifyListeners(path, data);
    if (response.containsKey('error')) {
      throw ScsException(response['error'] as String);
    }
  }

  /// Updates data at a path (merge).
  Future<void> updateData(String path, Map<String, dynamic> data) async {
    await _client.patch(
      'realtime/data/$path',
      body: {'data': data},
    );
    _notifyListeners(path, data);
  }

  /// Removes data at a path.
  Future<void> removeData(String path) async {
    await _client.delete('realtime/data/$path');
    _notifyListeners(path, null);
  }

  /// Pushes a new child with auto-generated key.
  Future<String> push(String path, dynamic data) async {
    final response = await _client.post(
      'realtime/data/$path',
      body: {'data': data},
    );
    return response['key'] as String? ?? '';
  }

  /// Exports all data.
  Future<Map<String, dynamic>> exportData() async {
    final response = await _client.get('realtime/export');
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Imports data.
  Future<void> importData(Map<String, dynamic> data, {bool merge = false}) async {
    await _client.post(
      'realtime/import',
      body: {
        'data': data,
        'merge': merge,
      },
    );
  }

  void _handleMessage(dynamic message) {
    try {
      // Handle Socket.IO protocol messages
      if (message is String) {
        if (message.startsWith('0')) {
          // Connection established
          return;
        }
        if (message.startsWith('40')) {
          // Connected to namespace
          _resubscribeAll();
          return;
        }
        if (message.startsWith('42')) {
          // Event message
          final jsonStr = message.substring(2);
          final data = jsonDecode(jsonStr) as List<dynamic>;
          if (data.length >= 2) {
            final eventName = data[0] as String;
            final eventData = data[1];
            _handleEvent(eventName, eventData);
          }
          return;
        }
        if (message == '3') {
          // Pong
          return;
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
  }

  void _handleEvent(String event, dynamic data) {
    if (event == 'data_changed' && data is Map) {
      final path = data['path'] as String?;
      final value = data['data'];
      if (path != null) {
        _notifyListeners(path, value);
      }
    }
  }

  void _notifyListeners(String path, dynamic data) {
    // Notify exact path listeners
    _listeners[path]?.forEach((callback) => callback(data));

    // Notify parent path listeners
    final segments = path.split('/');
    for (var i = segments.length - 1; i > 0; i--) {
      final parentPath = segments.sublist(0, i).join('/');
      _listeners[parentPath]?.forEach((callback) => callback({
            path.substring(parentPath.length + 1): data,
          }));
    }

    // Notify root listeners
    _listeners['']?.forEach((callback) => callback({path: data}));
  }

  void _handleError(dynamic error) {
    _connected = false;
    _connectionStateController.add(false);
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    _connected = false;
    _connectionStateController.add(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_connected && _listeners.isNotEmpty) {
        connect();
      }
    });
  }

  void _resubscribeAll() {
    for (final path in _listeners.keys) {
      _sendMessage({
        'type': 'subscribe',
        'path': path,
      });
    }
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_connected && _channel != null) {
      final encoded = '42${jsonEncode(['message', message])}';
      _channel!.sink.add(encoded);
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_connected && _channel != null) {
        _channel!.sink.add('2');
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Disposes of resources.
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _listeners.clear();
  }
}

/// A reference to a path in the real-time database.
class RealtimeRef {
  final RealtimeService _service;
  final ScsHttpClient _client;
  final String _path;

  RealtimeRef(this._service, this._client, this._path);

  /// The path this reference points to.
  String get path => _path;

  /// Gets a child reference.
  RealtimeRef child(String childPath) {
    final newPath = _path.isEmpty ? childPath : '$_path/$childPath';
    return RealtimeRef(_service, _client, newPath);
  }

  /// Gets the parent reference.
  RealtimeRef? get parent {
    if (_path.isEmpty) return null;
    final segments = _path.split('/');
    if (segments.length <= 1) return RealtimeRef(_service, _client, '');
    segments.removeLast();
    return RealtimeRef(_service, _client, segments.join('/'));
  }

  /// Listens for value changes at this path.
  void on(String event, void Function(dynamic data) callback) {
    if (event == 'value') {
      _service.subscribe(_path, callback);
    }
  }

  /// Removes a listener.
  void off([void Function(dynamic data)? callback]) {
    _service.unsubscribe(_path, callback);
  }

  /// Gets the current value once.
  Future<dynamic> get() async {
    return await _service.getData(_path);
  }

  /// Sets the value at this path.
  Future<void> set(dynamic data) async {
    await _service.setData(_path, data);
  }

  /// Updates values at this path (merge).
  Future<void> update(Map<String, dynamic> data) async {
    await _service.updateData(_path, data);
  }

  /// Removes the data at this path.
  Future<void> remove() async {
    await _service.removeData(_path);
  }

  /// Pushes a new child with auto-generated key.
  Future<RealtimeRef> push([dynamic data]) async {
    final key = await _service.push(_path, data ?? {});
    return child(key);
  }

  /// Creates a stream of value changes.
  Stream<dynamic> get onValue {
    final controller = StreamController<dynamic>.broadcast();

    void callback(dynamic data) {
      controller.add(data);
    }

    _service.subscribe(_path, callback);

    controller.onCancel = () {
      _service.unsubscribe(_path, callback);
    };

    return controller.stream;
  }
}
