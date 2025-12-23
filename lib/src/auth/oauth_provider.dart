import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../scs_exception.dart';
import 'oauth_config.dart';

/// Result of an OAuth authentication flow.
class OAuthResult {
  /// The OAuth provider name.
  final String provider;

  /// The access token from the OAuth provider.
  final String? accessToken;

  /// The ID token from the OAuth provider (if available).
  final String? idToken;

  /// The authorization code (for server-side token exchange).
  final String? authorizationCode;

  /// The refresh token (if available).
  final String? refreshToken;

  /// Additional data from the OAuth response.
  final Map<String, dynamic>? additionalData;

  /// Token expiry time (if available).
  final DateTime? expiresAt;

  /// Creates an OAuth result.
  const OAuthResult({
    required this.provider,
    this.accessToken,
    this.idToken,
    this.authorizationCode,
    this.refreshToken,
    this.additionalData,
    this.expiresAt,
  });

  /// Creates from JSON.
  factory OAuthResult.fromJson(Map<String, dynamic> json) {
    return OAuthResult(
      provider: json['provider'] as String,
      accessToken: json['accessToken'] as String?,
      idToken: json['idToken'] as String?,
      authorizationCode: json['authorizationCode'] as String?,
      refreshToken: json['refreshToken'] as String?,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      if (accessToken != null) 'accessToken': accessToken,
      if (idToken != null) 'idToken': idToken,
      if (authorizationCode != null) 'authorizationCode': authorizationCode,
      if (refreshToken != null) 'refreshToken': refreshToken,
      if (additionalData != null) 'additionalData': additionalData,
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    };
  }
}

/// Handles OAuth authentication flows for SCS.
///
/// This class provides native OAuth flows for various providers without
/// requiring external plugins like google_sign_in or sign_in_with_apple.
class ScsOAuthProvider {
  final ScsOAuthConfig _config;
  final String _baseUrl;
  final String _callbackScheme;

  /// Creates an OAuth provider.
  ///
  /// [config] - The OAuth configuration for all providers.
  /// [baseUrl] - The SCS backend base URL.
  /// [callbackScheme] - The custom URL scheme for OAuth callbacks (e.g., 'myapp').
  ScsOAuthProvider({
    required ScsOAuthConfig config,
    required String baseUrl,
    String? callbackScheme,
  })  : _config = config,
        _baseUrl = baseUrl,
        _callbackScheme = callbackScheme ?? 'scs';

  /// Generates a random state parameter for OAuth.
  String _generateState() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  /// Generates a PKCE code verifier.
  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  /// Generates a PKCE code challenge from a verifier.
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Parses URL query parameters including fragments.
  Map<String, String> _parseUrlParams(String url) {
    final uri = Uri.parse(url);
    final params = <String, String>{};

    // Parse query parameters
    params.addAll(uri.queryParameters);

    // Parse fragment parameters (for implicit flow)
    if (uri.fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      params.addAll(fragmentParams);
    }

    return params;
  }

  // ============== Google Sign-In ==============

  /// Initiates Google Sign-In flow.
  ///
  /// Returns an [OAuthResult] with the ID token and access token.
  Future<OAuthResult> signInWithGoogle() async {
    final config = _config.google;
    if (config == null) {
      throw ScsException.auth('Google OAuth is not configured');
    }

    // Determine which client ID to use based on platform
    String? clientId;
    if (Platform.isIOS) {
      clientId = config.iosClientId ?? config.webClientId;
    } else if (Platform.isAndroid) {
      clientId = config.androidClientId ?? config.webClientId;
    } else {
      clientId = config.webClientId;
    }

    if (clientId == null) {
      throw ScsException.auth('Google client ID is not configured for this platform');
    }

    final state = _generateState();
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final redirectUri = '$_callbackScheme://auth/google/callback';

    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': config.scopes.join(' '),
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final params = _parseUrlParams(result);

    // Verify state
    if (params['state'] != state) {
      throw ScsException.auth('OAuth state mismatch');
    }

    final code = params['code'];
    if (code == null) {
      final error = params['error'] ?? 'Unknown error';
      throw ScsException.auth('Google Sign-In failed: $error');
    }

    // Return the auth code for server-side token exchange
    return OAuthResult(
      provider: 'google',
      authorizationCode: code,
      additionalData: {
        'codeVerifier': codeVerifier,
        'redirectUri': redirectUri,
      },
    );
  }

  // ============== Apple Sign-In ==============

  /// Initiates Apple Sign-In flow.
  ///
  /// Note: On iOS/macOS, this uses the native Sign in with Apple flow.
  /// On other platforms, it uses the web-based OAuth flow.
  Future<OAuthResult> signInWithApple() async {
    final config = _config.apple;
    if (config == null) {
      throw ScsException.auth('Apple OAuth is not configured');
    }

    if (Platform.isIOS || Platform.isMacOS) {
      // Use native Sign in with Apple via web auth
      // The native flow is handled by the OS when using apple-signin URL scheme
      final state = _generateState();
      final redirectUri = config.redirectUri ?? '$_callbackScheme://auth/apple/callback';

      final authUrl = Uri.https('appleid.apple.com', '/auth/authorize', {
        'client_id': config.serviceId ?? '',
        'redirect_uri': redirectUri,
        'response_type': 'code id_token',
        'response_mode': 'form_post',
        'scope': config.scopes.join(' '),
        'state': state,
      });

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: _callbackScheme,
      );

      final params = _parseUrlParams(result);

      if (params['state'] != state) {
        throw ScsException.auth('OAuth state mismatch');
      }

      final idToken = params['id_token'];
      final code = params['code'];

      if (idToken == null && code == null) {
        final error = params['error'] ?? 'Unknown error';
        throw ScsException.auth('Apple Sign-In failed: $error');
      }

      return OAuthResult(
        provider: 'apple',
        idToken: idToken,
        authorizationCode: code,
        additionalData: {
          if (params['user'] != null) 'user': params['user'],
        },
      );
    } else {
      // Web-based flow for other platforms
      final state = _generateState();
      final redirectUri = config.redirectUri ?? '$_baseUrl/auth/project/oauth/apple/callback';

      final authUrl = Uri.https('appleid.apple.com', '/auth/authorize', {
        'client_id': config.serviceId ?? '',
        'redirect_uri': redirectUri,
        'response_type': 'code id_token',
        'response_mode': 'fragment',
        'scope': config.scopes.join(' '),
        'state': state,
      });

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: _callbackScheme,
      );

      final params = _parseUrlParams(result);

      if (params['state'] != state) {
        throw ScsException.auth('OAuth state mismatch');
      }

      return OAuthResult(
        provider: 'apple',
        idToken: params['id_token'],
        authorizationCode: params['code'],
      );
    }
  }

  // ============== Facebook Sign-In ==============

  /// Initiates Facebook Sign-In flow.
  Future<OAuthResult> signInWithFacebook() async {
    final config = _config.facebook;
    if (config == null) {
      throw ScsException.auth('Facebook OAuth is not configured');
    }

    final state = _generateState();
    final redirectUri = config.redirectUri ?? '$_callbackScheme://auth/facebook/callback';

    final authUrl = Uri.https('www.facebook.com', '/v18.0/dialog/oauth', {
      'client_id': config.appId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': config.scopes.join(','),
      'state': state,
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final params = _parseUrlParams(result);

    if (params['state'] != state) {
      throw ScsException.auth('OAuth state mismatch');
    }

    final code = params['code'];
    if (code == null) {
      final error = params['error'] ?? params['error_description'] ?? 'Unknown error';
      throw ScsException.auth('Facebook Sign-In failed: $error');
    }

    return OAuthResult(
      provider: 'facebook',
      authorizationCode: code,
      additionalData: {
        'redirectUri': redirectUri,
      },
    );
  }

  // ============== GitHub Sign-In ==============

  /// Initiates GitHub Sign-In flow.
  Future<OAuthResult> signInWithGitHub() async {
    final config = _config.github;
    if (config == null) {
      throw ScsException.auth('GitHub OAuth is not configured');
    }

    final state = _generateState();
    final redirectUri = config.redirectUri ?? '$_callbackScheme://auth/github/callback';

    final authUrl = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': config.clientId,
      'redirect_uri': redirectUri,
      'scope': config.scopes.join(' '),
      'state': state,
      'allow_signup': 'true',
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final params = _parseUrlParams(result);

    if (params['state'] != state) {
      throw ScsException.auth('OAuth state mismatch');
    }

    final code = params['code'];
    if (code == null) {
      final error = params['error'] ?? params['error_description'] ?? 'Unknown error';
      throw ScsException.auth('GitHub Sign-In failed: $error');
    }

    return OAuthResult(
      provider: 'github',
      authorizationCode: code,
      additionalData: {
        'redirectUri': redirectUri,
      },
    );
  }

  // ============== Twitter Sign-In ==============

  /// Initiates Twitter/X Sign-In flow using OAuth 2.0.
  Future<OAuthResult> signInWithTwitter() async {
    final config = _config.twitter;
    if (config == null) {
      throw ScsException.auth('Twitter OAuth is not configured');
    }

    final state = _generateState();
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final redirectUri = config.redirectUri ?? '$_callbackScheme://auth/twitter/callback';

    // Twitter OAuth 2.0 with PKCE
    final authUrl = Uri.https('twitter.com', '/i/oauth2/authorize', {
      'client_id': config.apiKey,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'users.read tweet.read offline.access',
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final params = _parseUrlParams(result);

    if (params['state'] != state) {
      throw ScsException.auth('OAuth state mismatch');
    }

    final code = params['code'];
    if (code == null) {
      final error = params['error'] ?? params['error_description'] ?? 'Unknown error';
      throw ScsException.auth('Twitter Sign-In failed: $error');
    }

    return OAuthResult(
      provider: 'twitter',
      authorizationCode: code,
      additionalData: {
        'codeVerifier': codeVerifier,
        'redirectUri': redirectUri,
      },
    );
  }

  // ============== Microsoft Sign-In ==============

  /// Initiates Microsoft Sign-In flow.
  Future<OAuthResult> signInWithMicrosoft() async {
    final config = _config.microsoft;
    if (config == null) {
      throw ScsException.auth('Microsoft OAuth is not configured');
    }

    final state = _generateState();
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final redirectUri = config.redirectUri ?? '$_callbackScheme://auth/microsoft/callback';

    final authUrl = Uri.https(
      'login.microsoftonline.com',
      '/${config.tenantId}/oauth2/v2.0/authorize',
      {
        'client_id': config.clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': config.scopes.join(' '),
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'response_mode': 'query',
      },
    );

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final params = _parseUrlParams(result);

    if (params['state'] != state) {
      throw ScsException.auth('OAuth state mismatch');
    }

    final code = params['code'];
    if (code == null) {
      final error = params['error'] ?? params['error_description'] ?? 'Unknown error';
      throw ScsException.auth('Microsoft Sign-In failed: $error');
    }

    return OAuthResult(
      provider: 'microsoft',
      authorizationCode: code,
      additionalData: {
        'codeVerifier': codeVerifier,
        'redirectUri': redirectUri,
      },
    );
  }

  // ============== Generic OAuth ==============

  /// Initiates a generic OAuth 2.0 flow.
  ///
  /// This can be used for custom OAuth providers.
  Future<OAuthResult> signInWithOAuth({
    required String provider,
    required String authorizationUrl,
    required String clientId,
    String? redirectUri,
    List<String> scopes = const [],
    bool usePkce = true,
    Map<String, String>? additionalParams,
  }) async {
    final state = _generateState();
    final effectiveRedirectUri = redirectUri ?? '$_callbackScheme://auth/$provider/callback';

    final params = <String, String>{
      'client_id': clientId,
      'redirect_uri': effectiveRedirectUri,
      'response_type': 'code',
      'state': state,
      if (scopes.isNotEmpty) 'scope': scopes.join(' '),
      if (additionalParams != null) ...additionalParams,
    };

    String? codeVerifier;
    if (usePkce) {
      codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      params['code_challenge'] = codeChallenge;
      params['code_challenge_method'] = 'S256';
    }

    final uri = Uri.parse(authorizationUrl);
    final authUrl = Uri(
      scheme: uri.scheme,
      host: uri.host,
      path: uri.path,
      queryParameters: params,
    );

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final responseParams = _parseUrlParams(result);

    if (responseParams['state'] != state) {
      throw ScsException.auth('OAuth state mismatch');
    }

    final code = responseParams['code'];
    if (code == null) {
      final error = responseParams['error'] ?? responseParams['error_description'] ?? 'Unknown error';
      throw ScsException.auth('OAuth Sign-In failed: $error');
    }

    return OAuthResult(
      provider: provider,
      authorizationCode: code,
      additionalData: {
        if (codeVerifier != null) 'codeVerifier': codeVerifier,
        'redirectUri': effectiveRedirectUri,
      },
    );
  }
}
