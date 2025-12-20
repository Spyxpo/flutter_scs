import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

/// Handles persistent storage of auth sessions.
class SessionStorage {
  static const String _userKey = 'scs_current_user';
  static const String _tokenKey = 'scs_auth_token';
  static const String _projectPrefix = 'scs_project_';

  SharedPreferences? _prefs;
  final String projectId;

  SessionStorage({required this.projectId});

  /// Initializes the session storage.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Gets the project-specific key.
  String _getKey(String key) => '$_projectPrefix${projectId}_$key';

  /// Saves the current user.
  Future<void> saveUser(ScsUser user) async {
    await init();
    await _prefs!.setString(_getKey(_userKey), jsonEncode(user.toJson()));
    if (user.token != null) {
      await _prefs!.setString(_getKey(_tokenKey), user.token!);
    }
  }

  /// Gets the current user.
  Future<ScsUser?> getUser() async {
    await init();
    final userJson = _prefs!.getString(_getKey(_userKey));
    if (userJson == null) return null;

    try {
      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      final token = _prefs!.getString(_getKey(_tokenKey));
      return ScsUser.fromJson(userData, token: token);
    } catch (e) {
      return null;
    }
  }

  /// Gets the stored auth token.
  Future<String?> getToken() async {
    await init();
    return _prefs!.getString(_getKey(_tokenKey));
  }

  /// Saves just the auth token.
  Future<void> saveToken(String token) async {
    await init();
    await _prefs!.setString(_getKey(_tokenKey), token);
  }

  /// Clears the current user session.
  Future<void> clearUser() async {
    await init();
    await _prefs!.remove(_getKey(_userKey));
    await _prefs!.remove(_getKey(_tokenKey));
  }

  /// Clears all data for this project.
  Future<void> clearAll() async {
    await init();
    final keys = _prefs!.getKeys().where(
      (key) => key.startsWith('$_projectPrefix$projectId'),
    );
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }

  /// Stores a custom value.
  Future<void> setString(String key, String value) async {
    await init();
    await _prefs!.setString(_getKey(key), value);
  }

  /// Gets a custom string value.
  Future<String?> getString(String key) async {
    await init();
    return _prefs!.getString(_getKey(key));
  }

  /// Removes a custom value.
  Future<void> remove(String key) async {
    await init();
    await _prefs!.remove(_getKey(key));
  }
}
