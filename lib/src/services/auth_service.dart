import 'dart:async';

import '../models/user.dart';
import '../scs_exception.dart';
import '../utils/http_client.dart';
import '../utils/session_storage.dart';

/// Service for user authentication and session management.
///
/// Provides methods for user registration, login, profile management,
/// and session persistence.
class AuthService {
  final ScsHttpClient _client;
  final SessionStorage _storage;

  ScsUser? _currentUser;
  final StreamController<ScsUser?> _authStateController =
      StreamController<ScsUser?>.broadcast();

  AuthService(this._client, this._storage);

  /// Gets the currently signed-in user, or null if not signed in.
  ScsUser? get currentUser => _currentUser;

  /// Stream of auth state changes.
  ///
  /// Emits the current user when auth state changes (sign in/out).
  Stream<ScsUser?> get authStateChanges => _authStateController.stream;

  /// Checks if a user is currently signed in.
  bool get isSignedIn => _currentUser != null;

  /// Registers a new user.
  ///
  /// Returns the newly created user with their auth token.
  Future<ScsUser> register({
    required String email,
    required String password,
    String? displayName,
    Map<String, dynamic>? customData,
  }) async {
    final response = await _client.post(
      'auth/project/register',
      body: {
        'email': email,
        'password': password,
        if (displayName != null) 'displayName': displayName,
        if (customData != null) 'customData': customData,
      },
    );

    final userData = response['user'] as Map<String, dynamic>? ?? response;
    final token = response['token'] as String?;

    final user = ScsUser.fromJson(userData, token: token);
    await _setCurrentUser(user);

    return user;
  }

  /// Signs in a user with email and password.
  ///
  /// Returns the signed-in user with their auth token.
  Future<ScsUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      'auth/project/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    final userData = response['user'] as Map<String, dynamic>? ?? response;
    final token = response['token'] as String?;

    if (token == null) {
      throw ScsException.auth('No token received from server');
    }

    final user = ScsUser.fromJson(userData, token: token);
    await _setCurrentUser(user);

    return user;
  }

  /// Signs in with email and password (alias for [login]).
  Future<ScsUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      login(email: email, password: password);

  /// Creates a new user with email and password (alias for [register]).
  Future<ScsUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
    Map<String, dynamic>? customData,
  }) =>
      register(
        email: email,
        password: password,
        displayName: displayName,
        customData: customData,
      );

  /// Gets the current user from the server.
  ///
  /// Useful for refreshing user data or validating the session.
  Future<ScsUser> getCurrentUser() async {
    final response = await _client.get('auth/project/me');
    final userData = response['user'] as Map<String, dynamic>? ?? response;
    final user = ScsUser.fromJson(userData, token: _currentUser?.token);

    _currentUser = user;
    _authStateController.add(user);

    return user;
  }

  /// Updates the current user's profile.
  Future<ScsUser> updateProfile({
    String? displayName,
    Map<String, dynamic>? customData,
  }) async {
    if (_currentUser == null) {
      throw ScsException.auth('No user signed in');
    }

    final response = await _client.put(
      'auth/project/profile',
      body: {
        if (displayName != null) 'displayName': displayName,
        if (customData != null) 'customData': customData,
      },
    );

    final userData = response['user'] as Map<String, dynamic>? ?? response;
    final user = ScsUser.fromJson(userData, token: _currentUser?.token);
    await _setCurrentUser(user);

    return user;
  }

  /// Changes the current user's password.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) {
      throw ScsException.auth('No user signed in');
    }

    await _client.put(
      'auth/project/password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  /// Updates the current user's password (alias for [changePassword]).
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  /// Deletes the current user's account.
  ///
  /// This action is irreversible.
  Future<void> deleteAccount() async {
    if (_currentUser == null) {
      throw ScsException.auth('No user signed in');
    }

    await _client.delete('auth/project/account');
    await _clearCurrentUser();
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _clearCurrentUser();
  }

  /// Signs out the current user (alias for [signOut]).
  Future<void> logout() => signOut();

  /// Restores the auth session from storage.
  ///
  /// Call this when your app starts to restore the previous session.
  Future<ScsUser?> restoreSession() async {
    final storedUser = await _storage.getUser();
    if (storedUser != null && storedUser.token != null) {
      _client.setUserToken(storedUser.token);
      _currentUser = storedUser;
      _authStateController.add(storedUser);

      // Validate the session with the server
      try {
        return await getCurrentUser();
      } catch (e) {
        // Session is invalid, clear it
        await _clearCurrentUser();
        return null;
      }
    }
    return null;
  }

  /// Sets the current user and persists the session.
  Future<void> _setCurrentUser(ScsUser user) async {
    _currentUser = user;
    if (user.token != null) {
      _client.setUserToken(user.token);
    }
    await _storage.saveUser(user);
    _authStateController.add(user);
  }

  /// Clears the current user and session.
  Future<void> _clearCurrentUser() async {
    _currentUser = null;
    _client.clearUserToken();
    await _storage.clearUser();
    _authStateController.add(null);
  }

  /// Disposes of resources.
  void dispose() {
    _authStateController.close();
  }
}
