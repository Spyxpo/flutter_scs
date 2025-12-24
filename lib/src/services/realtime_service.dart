import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../scs_config.dart';
import '../scs_exception.dart';
import '../utils/http_client.dart';

/// Service for real-time database operations.
///
/// Provides Socket.IO-based real-time data synchronization.
class RealtimeService {
  final ScsHttpClient _client;
  final ScsConfig _config;

  io.Socket? _socket;
  bool _connected = false;
  final Map<String, List<void Function(dynamic)>> _listeners = {};
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  Timer? _reconnectTimer;

  RealtimeService(this._client, this._config);

  /// Whether the Socket.IO is connected.
  bool get isConnected => _connected;

  /// Stream of connection state changes.
  Stream<bool> get connectionState => _connectionStateController.stream;

  /// Connects to the real-time database.
  Future<void> connect() async {
    if (_connected) return;

    try {
      // Create Socket.IO connection with proper path
      _socket = io.io(
        _config.baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setPath('/realtime')
            .setAuth({
              'apiKey': _config.apiKey,
              'userToken': _client.userToken,
            })
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .build(),
      );

      final completer = Completer<void>();

      _socket!.onConnect((_) {
        _connected = true;
        _connectionStateController.add(true);
        _resubscribeAll();
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      _socket!.onDisconnect((_) {
        _connected = false;
        _connectionStateController.add(false);
      });

      _socket!.onConnectError((error) {
        _connected = false;
        _connectionStateController.add(false);
        if (!completer.isCompleted) {
          completer.completeError(
            ScsException.network('Failed to connect to real-time database: $error'),
          );
        }
      });

      _socket!.onError((error) {
        // Log error but don't disconnect - Socket.IO will handle reconnection
      });

      // Handle value updates from server
      _socket!.on('value', (data) {
        if (data is Map) {
          final path = data['path'] as String?;
          final value = data['data'];
          if (path != null) {
            _notifyListeners(path, value);
          }
        }
      });

      // Handle child events
      _socket!.on('child_added', (data) {
        _handleChildEvent('child_added', data);
      });

      _socket!.on('child_changed', (data) {
        _handleChildEvent('child_changed', data);
      });

      _socket!.on('child_removed', (data) {
        _handleChildEvent('child_removed', data);
      });

      // Handle presence updates
      _socket!.on('presence:update', (data) {
        if (data is Map) {
          final path = data['path'] as String?;
          if (path != null) {
            _notifyListeners('$path/__presence', data['users']);
          }
        }
      });

      // Connect the socket
      _socket!.connect();

      // Wait for connection with timeout
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw ScsException.network('Connection timeout');
        },
      );
    } catch (e) {
      _connected = false;
      _socket?.dispose();
      _socket = null;
      if (e is ScsException) rethrow;
      throw ScsException.network('Failed to connect to real-time database: $e');
    }
  }

  /// Disconnects from the real-time database.
  void disconnect() {
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
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

    if (_connected && _socket != null) {
      _socket!.emit('subscribe', {'path': path, 'type': 'value'});
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

    if (_connected && _socket != null && !_listeners.containsKey(path)) {
      _socket!.emit('unsubscribe', {'path': path});
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
    // Check for errors before notifying listeners
    if (response.containsKey('error')) {
      throw ScsException(response['error'] as String);
    }
    // Local notification - server will broadcast to other clients
    _notifyListeners(path, data);
  }

  /// Updates data at a path (merge).
  Future<void> updateData(String path, Map<String, dynamic> data) async {
    final response = await _client.patch(
      'realtime/data/$path',
      body: {'data': data},
    );
    if (response.containsKey('error')) {
      throw ScsException(response['error'] as String);
    }
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

  void _handleChildEvent(String event, dynamic data) {
    if (data is Map) {
      final path = data['path'] as String?;
      final key = data['key'] as String?;
      final value = data['data'];
      if (path != null && key != null) {
        // Notify listeners of the parent path about child changes
        _notifyListeners(path, {key: value});
      }
    }
  }

  void _notifyListeners(String path, dynamic data) {
    // Notify exact path listeners
    final listeners = _listeners[path];
    if (listeners != null) {
      for (final callback in List.from(listeners)) {
        try {
          callback(data);
        } catch (e) {
          // Ignore callback errors
        }
      }
    }

    // Notify parent path listeners
    final segments = path.split('/');
    for (var i = segments.length - 1; i > 0; i--) {
      final parentPath = segments.sublist(0, i).join('/');
      final parentListeners = _listeners[parentPath];
      if (parentListeners != null) {
        final childKey = path.substring(parentPath.length + 1);
        for (final callback in List.from(parentListeners)) {
          try {
            callback({childKey: data});
          } catch (e) {
            // Ignore callback errors
          }
        }
      }
    }

    // Notify root listeners
    final rootListeners = _listeners[''];
    if (rootListeners != null) {
      for (final callback in List.from(rootListeners)) {
        try {
          callback({path: data});
        } catch (e) {
          // Ignore callback errors
        }
      }
    }
  }

  void _resubscribeAll() {
    if (_socket == null || !_connected) return;

    for (final path in _listeners.keys) {
      _socket!.emit('subscribe', {'path': path, 'type': 'value'});
    }
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

  /// Cached stream controller for this reference.
  StreamController<dynamic>? _streamController;
  void Function(dynamic)? _streamCallback;

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
  ///
  /// This returns a broadcast stream that can have multiple listeners.
  /// The stream is cached per RealtimeRef instance to prevent memory leaks.
  Stream<dynamic> get onValue {
    // Return existing stream if already created
    if (_streamController != null && !_streamController!.isClosed) {
      return _streamController!.stream;
    }

    // Create a new broadcast stream controller
    _streamController = StreamController<dynamic>.broadcast(
      onListen: () {
        // Subscribe when first listener attaches
        _streamCallback = (dynamic data) {
          if (_streamController != null && !_streamController!.isClosed) {
            _streamController!.add(data);
          }
        };
        _service.subscribe(_path, _streamCallback!);
      },
      onCancel: () {
        // Unsubscribe when all listeners detach
        if (_streamCallback != null) {
          _service.unsubscribe(_path, _streamCallback!);
          _streamCallback = null;
        }
        _streamController?.close();
        _streamController = null;
      },
    );

    return _streamController!.stream;
  }

  /// Disposes of the stream resources for this reference.
  void dispose() {
    if (_streamCallback != null) {
      _service.unsubscribe(_path, _streamCallback!);
      _streamCallback = null;
    }
    _streamController?.close();
    _streamController = null;
  }
}
