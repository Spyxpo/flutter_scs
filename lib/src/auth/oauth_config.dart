/// Configuration for OAuth providers in SCS.
///
/// This class holds the configuration for various OAuth providers
/// that can be used with the SCS authentication system.
class ScsOAuthConfig {
  /// Google OAuth configuration.
  final GoogleOAuthConfig? google;

  /// Apple OAuth configuration.
  final AppleOAuthConfig? apple;

  /// Facebook OAuth configuration.
  final FacebookOAuthConfig? facebook;

  /// GitHub OAuth configuration.
  final GitHubOAuthConfig? github;

  /// Twitter OAuth configuration.
  final TwitterOAuthConfig? twitter;

  /// Microsoft OAuth configuration.
  final MicrosoftOAuthConfig? microsoft;

  /// Creates an OAuth configuration.
  const ScsOAuthConfig({
    this.google,
    this.apple,
    this.facebook,
    this.github,
    this.twitter,
    this.microsoft,
  });

  /// Creates an OAuth configuration from JSON.
  factory ScsOAuthConfig.fromJson(Map<String, dynamic> json) {
    return ScsOAuthConfig(
      google: json['google'] != null
          ? GoogleOAuthConfig.fromJson(json['google'] as Map<String, dynamic>)
          : null,
      apple: json['apple'] != null
          ? AppleOAuthConfig.fromJson(json['apple'] as Map<String, dynamic>)
          : null,
      facebook: json['facebook'] != null
          ? FacebookOAuthConfig.fromJson(json['facebook'] as Map<String, dynamic>)
          : null,
      github: json['github'] != null
          ? GitHubOAuthConfig.fromJson(json['github'] as Map<String, dynamic>)
          : null,
      twitter: json['twitter'] != null
          ? TwitterOAuthConfig.fromJson(json['twitter'] as Map<String, dynamic>)
          : null,
      microsoft: json['microsoft'] != null
          ? MicrosoftOAuthConfig.fromJson(json['microsoft'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      if (google != null) 'google': google!.toJson(),
      if (apple != null) 'apple': apple!.toJson(),
      if (facebook != null) 'facebook': facebook!.toJson(),
      if (github != null) 'github': github!.toJson(),
      if (twitter != null) 'twitter': twitter!.toJson(),
      if (microsoft != null) 'microsoft': microsoft!.toJson(),
    };
  }
}

/// Google OAuth configuration.
class GoogleOAuthConfig {
  /// The OAuth client ID for iOS.
  final String? iosClientId;

  /// The OAuth client ID for Android.
  final String? androidClientId;

  /// The OAuth client ID for web.
  final String? webClientId;

  /// Server client ID for backend verification.
  final String? serverClientId;

  /// OAuth scopes to request.
  final List<String> scopes;

  /// Creates a Google OAuth configuration.
  const GoogleOAuthConfig({
    this.iosClientId,
    this.androidClientId,
    this.webClientId,
    this.serverClientId,
    this.scopes = const ['email', 'profile'],
  });

  /// Creates from JSON.
  factory GoogleOAuthConfig.fromJson(Map<String, dynamic> json) {
    return GoogleOAuthConfig(
      iosClientId: json['iosClientId'] as String?,
      androidClientId: json['androidClientId'] as String?,
      webClientId: json['webClientId'] as String?,
      serverClientId: json['serverClientId'] as String?,
      scopes: (json['scopes'] as List<dynamic>?)?.cast<String>() ??
          const ['email', 'profile'],
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      if (iosClientId != null) 'iosClientId': iosClientId,
      if (androidClientId != null) 'androidClientId': androidClientId,
      if (webClientId != null) 'webClientId': webClientId,
      if (serverClientId != null) 'serverClientId': serverClientId,
      'scopes': scopes,
    };
  }
}

/// Apple OAuth configuration.
class AppleOAuthConfig {
  /// The service ID for Apple Sign In.
  final String? serviceId;

  /// The team ID.
  final String? teamId;

  /// The key ID.
  final String? keyId;

  /// Redirect URI for web flow.
  final String? redirectUri;

  /// OAuth scopes to request.
  final List<String> scopes;

  /// Creates an Apple OAuth configuration.
  const AppleOAuthConfig({
    this.serviceId,
    this.teamId,
    this.keyId,
    this.redirectUri,
    this.scopes = const ['email', 'name'],
  });

  /// Creates from JSON.
  factory AppleOAuthConfig.fromJson(Map<String, dynamic> json) {
    return AppleOAuthConfig(
      serviceId: json['serviceId'] as String?,
      teamId: json['teamId'] as String?,
      keyId: json['keyId'] as String?,
      redirectUri: json['redirectUri'] as String?,
      scopes: (json['scopes'] as List<dynamic>?)?.cast<String>() ??
          const ['email', 'name'],
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      if (serviceId != null) 'serviceId': serviceId,
      if (teamId != null) 'teamId': teamId,
      if (keyId != null) 'keyId': keyId,
      if (redirectUri != null) 'redirectUri': redirectUri,
      'scopes': scopes,
    };
  }
}

/// Facebook OAuth configuration.
class FacebookOAuthConfig {
  /// The Facebook App ID.
  final String appId;

  /// The Facebook App Secret (for server-side flow).
  final String? appSecret;

  /// Redirect URI for OAuth flow.
  final String? redirectUri;

  /// OAuth scopes to request.
  final List<String> scopes;

  /// Creates a Facebook OAuth configuration.
  const FacebookOAuthConfig({
    required this.appId,
    this.appSecret,
    this.redirectUri,
    this.scopes = const ['email', 'public_profile'],
  });

  /// Creates from JSON.
  factory FacebookOAuthConfig.fromJson(Map<String, dynamic> json) {
    return FacebookOAuthConfig(
      appId: json['appId'] as String,
      appSecret: json['appSecret'] as String?,
      redirectUri: json['redirectUri'] as String?,
      scopes: (json['scopes'] as List<dynamic>?)?.cast<String>() ??
          const ['email', 'public_profile'],
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'appId': appId,
      if (appSecret != null) 'appSecret': appSecret,
      if (redirectUri != null) 'redirectUri': redirectUri,
      'scopes': scopes,
    };
  }
}

/// GitHub OAuth configuration.
class GitHubOAuthConfig {
  /// The GitHub OAuth App client ID.
  final String clientId;

  /// The GitHub OAuth App client secret (for server-side flow).
  final String? clientSecret;

  /// Redirect URI for OAuth flow.
  final String? redirectUri;

  /// OAuth scopes to request.
  final List<String> scopes;

  /// Creates a GitHub OAuth configuration.
  const GitHubOAuthConfig({
    required this.clientId,
    this.clientSecret,
    this.redirectUri,
    this.scopes = const ['read:user', 'user:email'],
  });

  /// Creates from JSON.
  factory GitHubOAuthConfig.fromJson(Map<String, dynamic> json) {
    return GitHubOAuthConfig(
      clientId: json['clientId'] as String,
      clientSecret: json['clientSecret'] as String?,
      redirectUri: json['redirectUri'] as String?,
      scopes: (json['scopes'] as List<dynamic>?)?.cast<String>() ??
          const ['read:user', 'user:email'],
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      if (clientSecret != null) 'clientSecret': clientSecret,
      if (redirectUri != null) 'redirectUri': redirectUri,
      'scopes': scopes,
    };
  }
}

/// Twitter OAuth configuration.
class TwitterOAuthConfig {
  /// The Twitter API key (consumer key).
  final String apiKey;

  /// The Twitter API secret (consumer secret).
  final String? apiSecret;

  /// Redirect URI for OAuth flow.
  final String? redirectUri;

  /// Creates a Twitter OAuth configuration.
  const TwitterOAuthConfig({
    required this.apiKey,
    this.apiSecret,
    this.redirectUri,
  });

  /// Creates from JSON.
  factory TwitterOAuthConfig.fromJson(Map<String, dynamic> json) {
    return TwitterOAuthConfig(
      apiKey: json['apiKey'] as String,
      apiSecret: json['apiSecret'] as String?,
      redirectUri: json['redirectUri'] as String?,
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      if (apiSecret != null) 'apiSecret': apiSecret,
      if (redirectUri != null) 'redirectUri': redirectUri,
    };
  }
}

/// Microsoft OAuth configuration.
class MicrosoftOAuthConfig {
  /// The Azure AD application (client) ID.
  final String clientId;

  /// The Azure AD tenant ID (or 'common' for multi-tenant).
  final String tenantId;

  /// Redirect URI for OAuth flow.
  final String? redirectUri;

  /// OAuth scopes to request.
  final List<String> scopes;

  /// Creates a Microsoft OAuth configuration.
  const MicrosoftOAuthConfig({
    required this.clientId,
    this.tenantId = 'common',
    this.redirectUri,
    this.scopes = const ['openid', 'profile', 'email', 'User.Read'],
  });

  /// Creates from JSON.
  factory MicrosoftOAuthConfig.fromJson(Map<String, dynamic> json) {
    return MicrosoftOAuthConfig(
      clientId: json['clientId'] as String,
      tenantId: json['tenantId'] as String? ?? 'common',
      redirectUri: json['redirectUri'] as String?,
      scopes: (json['scopes'] as List<dynamic>?)?.cast<String>() ??
          const ['openid', 'profile', 'email', 'User.Read'],
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'tenantId': tenantId,
      if (redirectUri != null) 'redirectUri': redirectUri,
      'scopes': scopes,
    };
  }
}
