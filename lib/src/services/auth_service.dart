import 'dart:async';

import '../auth/oauth_config.dart';
import '../auth/oauth_provider.dart';
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
  final String _baseUrl;

  ScsUser? _currentUser;
  final StreamController<ScsUser?> _authStateController =
      StreamController<ScsUser?>.broadcast();

  ScsOAuthProvider? _oauthProvider;
  ScsOAuthConfig? _oauthConfig;
  String _callbackScheme = 'scs';

  AuthService(this._client, this._storage, this._baseUrl);

  /// Configures OAuth providers for native sign-in flows.
  ///
  /// Call this method to enable native OAuth sign-in methods like
  /// [scsSignInWithGoogle], [scsSignInWithApple], etc.
  ///
  /// Example:
  /// ```dart
  /// scs.auth.configureOAuth(
  ///   config: ScsOAuthConfig(
  ///     google: GoogleOAuthConfig(
  ///       iosClientId: 'your-ios-client-id',
  ///       androidClientId: 'your-android-client-id',
  ///       webClientId: 'your-web-client-id',
  ///     ),
  ///     apple: AppleOAuthConfig(
  ///       serviceId: 'your-service-id',
  ///     ),
  ///   ),
  ///   callbackScheme: 'myapp', // Your app's custom URL scheme
  /// );
  /// ```
  void configureOAuth({
    required ScsOAuthConfig config,
    String callbackScheme = 'scs',
  }) {
    _oauthConfig = config;
    _callbackScheme = callbackScheme;
    _oauthProvider = ScsOAuthProvider(
      config: config,
      baseUrl: _baseUrl,
      callbackScheme: callbackScheme,
    );
  }

  /// Gets the OAuth provider instance.
  ///
  /// Throws if OAuth is not configured. Call [configureOAuth] first.
  ScsOAuthProvider get oauthProvider {
    if (_oauthProvider == null) {
      throw ScsException.auth(
        'OAuth is not configured. Call configureOAuth() first.',
      );
    }
    return _oauthProvider!;
  }

  /// Whether OAuth is configured.
  bool get isOAuthConfigured => _oauthProvider != null;

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

  // OAuth and Social Sign-In Methods

  /// Signs in with Google.
  ///
  /// Requires the Google ID token obtained from Google Sign-In.
  Future<ScsUser> signInWithGoogle({
    required String idToken,
    String? accessToken,
  }) async {
    final response = await _client.post(
      'auth/project/oauth/google',
      body: {
        'idToken': idToken,
        if (accessToken != null) 'accessToken': accessToken,
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

  /// Signs in with Facebook.
  ///
  /// Requires the Facebook access token obtained from Facebook Login.
  Future<ScsUser> signInWithFacebook({
    required String accessToken,
  }) async {
    final response = await _client.post(
      'auth/project/oauth/facebook',
      body: {'accessToken': accessToken},
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

  /// Signs in with Apple.
  ///
  /// Requires the Apple identity token obtained from Sign in with Apple.
  Future<ScsUser> signInWithApple({
    required String identityToken,
    String? authorizationCode,
    String? fullName,
  }) async {
    final response = await _client.post(
      'auth/project/oauth/apple',
      body: {
        'identityToken': identityToken,
        if (authorizationCode != null) 'authorizationCode': authorizationCode,
        if (fullName != null) 'fullName': fullName,
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

  /// Signs in with GitHub.
  ///
  /// Requires the GitHub OAuth authorization code.
  Future<ScsUser> signInWithGitHub({
    required String code,
    String? redirectUri,
  }) async {
    final response = await _client.post(
      'auth/project/oauth/github',
      body: {
        'code': code,
        if (redirectUri != null) 'redirectUri': redirectUri,
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

  /// Signs in with Twitter/X.
  ///
  /// Requires the Twitter OAuth token and secret.
  Future<ScsUser> signInWithTwitter({
    required String oauthToken,
    required String oauthTokenSecret,
  }) async {
    final response = await _client.post(
      'auth/project/oauth/twitter',
      body: {
        'oauthToken': oauthToken,
        'oauthTokenSecret': oauthTokenSecret,
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

  /// Signs in with Microsoft.
  ///
  /// Requires the Microsoft access token.
  Future<ScsUser> signInWithMicrosoft({
    required String accessToken,
    String? idToken,
  }) async {
    final response = await _client.post(
      'auth/project/oauth/microsoft',
      body: {
        'accessToken': accessToken,
        if (idToken != null) 'idToken': idToken,
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

  /// Signs in anonymously.
  ///
  /// Creates a temporary anonymous account that can be linked to a
  /// permanent account later using [linkProvider].
  Future<ScsUser> signInAnonymously({
    Map<String, dynamic>? customData,
  }) async {
    final response = await _client.post(
      'auth/project/anonymous',
      body: {
        if (customData != null) 'customData': customData,
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

  /// Sends a verification code to a phone number.
  ///
  /// Returns a verification ID to use with [signInWithPhoneNumber].
  Future<String> sendPhoneVerificationCode({
    required String phoneNumber,
    String? recaptchaToken,
  }) async {
    final response = await _client.post(
      'auth/project/phone/send-code',
      body: {
        'phoneNumber': phoneNumber,
        if (recaptchaToken != null) 'recaptchaToken': recaptchaToken,
      },
    );

    final verificationId = response['verificationId'] as String?;
    if (verificationId == null) {
      throw ScsException.auth('No verification ID received from server');
    }

    return verificationId;
  }

  /// Signs in with phone number using a verification code.
  ///
  /// Use [sendPhoneVerificationCode] first to get the verification ID.
  Future<ScsUser> signInWithPhoneNumber({
    required String verificationId,
    required String code,
  }) async {
    final response = await _client.post(
      'auth/project/phone/verify',
      body: {
        'verificationId': verificationId,
        'code': code,
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

  /// Signs in with a custom token.
  ///
  /// The token should be generated by your backend using your project's
  /// secret key.
  Future<ScsUser> signInWithCustomToken(String token) async {
    final response = await _client.post(
      'auth/project/custom-token',
      body: {'token': token},
    );

    final userData = response['user'] as Map<String, dynamic>? ?? response;
    final authToken = response['token'] as String?;

    if (authToken == null) {
      throw ScsException.auth('No token received from server');
    }

    final user = ScsUser.fromJson(userData, token: authToken);
    await _setCurrentUser(user);

    return user;
  }

  /// Links an OAuth provider to the current account.
  ///
  /// This is useful for linking an anonymous account to a permanent provider.
  Future<ScsUser> linkProvider({
    required String provider,
    required Map<String, dynamic> credentials,
  }) async {
    if (_currentUser == null) {
      throw ScsException.auth('No user signed in');
    }

    final response = await _client.post(
      'auth/project/link/$provider',
      body: credentials,
    );

    final userData = response['user'] as Map<String, dynamic>? ?? response;
    final user = ScsUser.fromJson(userData, token: _currentUser?.token);
    await _setCurrentUser(user);

    return user;
  }

  /// Unlinks an OAuth provider from the current account.
  Future<ScsUser> unlinkProvider(String provider) async {
    if (_currentUser == null) {
      throw ScsException.auth('No user signed in');
    }

    final response = await _client.post('auth/project/unlink/$provider');

    final userData = response['user'] as Map<String, dynamic>? ?? response;
    final user = ScsUser.fromJson(userData, token: _currentUser?.token);
    await _setCurrentUser(user);

    return user;
  }

  /// Gets available sign-in methods for an email.
  Future<List<String>> fetchSignInMethodsForEmail(String email) async {
    final response = await _client.post(
      'auth/project/providers',
      body: {'email': email},
    );

    final methods = response['methods'] as List<dynamic>?;
    return methods?.cast<String>() ?? [];
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.post(
      'auth/project/password-reset',
      body: {'email': email},
    );
  }

  /// Confirms a password reset with a code.
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    await _client.post(
      'auth/project/password-reset/confirm',
      body: {
        'code': code,
        'newPassword': newPassword,
      },
    );
  }

  /// Sends an email verification to the current user.
  Future<void> sendEmailVerification() async {
    if (_currentUser == null) {
      throw ScsException.auth('No user signed in');
    }

    await _client.post('auth/project/verify-email');
  }

  /// Verifies an email with a code.
  Future<void> verifyEmail(String code) async {
    await _client.post(
      'auth/project/verify-email/confirm',
      body: {'code': code},
    );
  }

  // ============== SCS Native OAuth Sign-In Methods ==============
  //
  // These methods handle the complete OAuth flow natively without
  // requiring external plugins like google_sign_in or sign_in_with_apple.
  // Call configureOAuth() before using these methods.

  /// Signs in with Google using native SCS OAuth flow.
  ///
  /// This method handles the complete Google sign-in flow without requiring
  /// the google_sign_in plugin. It opens a web view for authentication and
  /// exchanges the authorization code with the SCS backend.
  ///
  /// Make sure to call [configureOAuth] with Google configuration first.
  ///
  /// Example:
  /// ```dart
  /// // Configure OAuth first
  /// scs.auth.configureOAuth(
  ///   config: ScsOAuthConfig(
  ///     google: GoogleOAuthConfig(
  ///       iosClientId: 'your-ios-client-id.apps.googleusercontent.com',
  ///       androidClientId: 'your-android-client-id.apps.googleusercontent.com',
  ///       webClientId: 'your-web-client-id.apps.googleusercontent.com',
  ///     ),
  ///   ),
  ///   callbackScheme: 'com.yourapp',
  /// );
  ///
  /// // Then sign in
  /// final user = await scs.auth.scsSignInWithGoogle();
  /// ```
  Future<ScsUser> scsSignInWithGoogle() async {
    final result = await oauthProvider.signInWithGoogle();
    return _completeOAuthSignIn(result);
  }

  /// Signs in with Apple using native SCS OAuth flow.
  ///
  /// This method handles the complete Apple sign-in flow without requiring
  /// the sign_in_with_apple plugin. On iOS/macOS, it uses the native Apple
  /// Sign In. On other platforms, it uses the web-based OAuth flow.
  ///
  /// Make sure to call [configureOAuth] with Apple configuration first.
  ///
  /// Example:
  /// ```dart
  /// scs.auth.configureOAuth(
  ///   config: ScsOAuthConfig(
  ///     apple: AppleOAuthConfig(
  ///       serviceId: 'com.yourapp.service',
  ///     ),
  ///   ),
  ///   callbackScheme: 'com.yourapp',
  /// );
  ///
  /// final user = await scs.auth.scsSignInWithApple();
  /// ```
  Future<ScsUser> scsSignInWithApple() async {
    final result = await oauthProvider.signInWithApple();
    return _completeOAuthSignIn(result);
  }

  /// Signs in with Facebook using native SCS OAuth flow.
  ///
  /// This method handles the complete Facebook sign-in flow without requiring
  /// the flutter_facebook_auth plugin.
  ///
  /// Make sure to call [configureOAuth] with Facebook configuration first.
  ///
  /// Example:
  /// ```dart
  /// scs.auth.configureOAuth(
  ///   config: ScsOAuthConfig(
  ///     facebook: FacebookOAuthConfig(
  ///       appId: 'your-facebook-app-id',
  ///     ),
  ///   ),
  ///   callbackScheme: 'fb123456789',
  /// );
  ///
  /// final user = await scs.auth.scsSignInWithFacebook();
  /// ```
  Future<ScsUser> scsSignInWithFacebook() async {
    final result = await oauthProvider.signInWithFacebook();
    return _completeOAuthSignIn(result);
  }

  /// Signs in with GitHub using native SCS OAuth flow.
  ///
  /// This method handles the complete GitHub sign-in flow without requiring
  /// any external plugins.
  ///
  /// Make sure to call [configureOAuth] with GitHub configuration first.
  ///
  /// Example:
  /// ```dart
  /// scs.auth.configureOAuth(
  ///   config: ScsOAuthConfig(
  ///     github: GitHubOAuthConfig(
  ///       clientId: 'your-github-client-id',
  ///     ),
  ///   ),
  ///   callbackScheme: 'com.yourapp',
  /// );
  ///
  /// final user = await scs.auth.scsSignInWithGitHub();
  /// ```
  Future<ScsUser> scsSignInWithGitHub() async {
    final result = await oauthProvider.signInWithGitHub();
    return _completeOAuthSignIn(result);
  }

  /// Signs in with Twitter/X using native SCS OAuth flow.
  ///
  /// This method handles the complete Twitter sign-in flow using OAuth 2.0
  /// without requiring any external plugins.
  ///
  /// Make sure to call [configureOAuth] with Twitter configuration first.
  ///
  /// Example:
  /// ```dart
  /// scs.auth.configureOAuth(
  ///   config: ScsOAuthConfig(
  ///     twitter: TwitterOAuthConfig(
  ///       apiKey: 'your-twitter-api-key',
  ///     ),
  ///   ),
  ///   callbackScheme: 'com.yourapp',
  /// );
  ///
  /// final user = await scs.auth.scsSignInWithTwitter();
  /// ```
  Future<ScsUser> scsSignInWithTwitter() async {
    final result = await oauthProvider.signInWithTwitter();
    return _completeOAuthSignIn(result);
  }

  /// Signs in with Microsoft using native SCS OAuth flow.
  ///
  /// This method handles the complete Microsoft sign-in flow without requiring
  /// any external plugins.
  ///
  /// Make sure to call [configureOAuth] with Microsoft configuration first.
  ///
  /// Example:
  /// ```dart
  /// scs.auth.configureOAuth(
  ///   config: ScsOAuthConfig(
  ///     microsoft: MicrosoftOAuthConfig(
  ///       clientId: 'your-azure-client-id',
  ///       tenantId: 'common', // or specific tenant ID
  ///     ),
  ///   ),
  ///   callbackScheme: 'msauth.com.yourapp',
  /// );
  ///
  /// final user = await scs.auth.scsSignInWithMicrosoft();
  /// ```
  Future<ScsUser> scsSignInWithMicrosoft() async {
    final result = await oauthProvider.signInWithMicrosoft();
    return _completeOAuthSignIn(result);
  }

  /// Signs in with a custom OAuth provider using native SCS OAuth flow.
  ///
  /// This method allows you to authenticate with any OAuth 2.0 provider.
  ///
  /// Example:
  /// ```dart
  /// final user = await scs.auth.scsSignInWithOAuth(
  ///   provider: 'discord',
  ///   authorizationUrl: 'https://discord.com/api/oauth2/authorize',
  ///   clientId: 'your-discord-client-id',
  ///   scopes: ['identify', 'email'],
  /// );
  /// ```
  Future<ScsUser> scsSignInWithOAuth({
    required String provider,
    required String authorizationUrl,
    required String clientId,
    String? redirectUri,
    List<String> scopes = const [],
    bool usePkce = true,
    Map<String, String>? additionalParams,
  }) async {
    final result = await oauthProvider.signInWithOAuth(
      provider: provider,
      authorizationUrl: authorizationUrl,
      clientId: clientId,
      redirectUri: redirectUri,
      scopes: scopes,
      usePkce: usePkce,
      additionalParams: additionalParams,
    );
    return _completeOAuthSignIn(result);
  }

  /// Completes the OAuth sign-in by exchanging tokens with the backend.
  Future<ScsUser> _completeOAuthSignIn(OAuthResult result) async {
    final response = await _client.post(
      'auth/project/oauth/${result.provider}',
      body: {
        if (result.authorizationCode != null) 'code': result.authorizationCode,
        if (result.idToken != null) 'idToken': result.idToken,
        if (result.accessToken != null) 'accessToken': result.accessToken,
        if (result.additionalData != null) ...result.additionalData!,
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

  /// Gets the configured callback scheme for OAuth.
  String get oauthCallbackScheme => _callbackScheme;

  /// Gets the OAuth configuration.
  ScsOAuthConfig? get oauthConfig => _oauthConfig;

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
