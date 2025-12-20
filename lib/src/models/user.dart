/// Represents a user in the SCS authentication system.
class ScsUser {
  /// The unique user ID.
  final String uid;

  /// The user's email address.
  final String email;

  /// The user's display name.
  final String? displayName;

  /// Custom data associated with the user.
  final Map<String, dynamic>? customData;

  /// Whether the user account is disabled.
  final bool disabled;

  /// When the user was created.
  final DateTime? createdAt;

  /// When the user last logged in.
  final DateTime? lastLoginAt;

  /// The authentication token for the user.
  final String? token;

  const ScsUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.customData,
    this.disabled = false,
    this.createdAt,
    this.lastLoginAt,
    this.token,
  });

  /// Creates a user from a JSON map.
  factory ScsUser.fromJson(Map<String, dynamic> json, {String? token}) {
    return ScsUser(
      uid: json['uid'] as String? ?? json['_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      customData: json['customData'] as Map<String, dynamic>?,
      disabled: json['disabled'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'].toString())
          : null,
      token: token ?? json['token'] as String?,
    );
  }

  /// Converts the user to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      if (displayName != null) 'displayName': displayName,
      if (customData != null) 'customData': customData,
      'disabled': disabled,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (lastLoginAt != null) 'lastLoginAt': lastLoginAt!.toIso8601String(),
      if (token != null) 'token': token,
    };
  }

  /// Creates a copy of this user with updated fields.
  ScsUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    Map<String, dynamic>? customData,
    bool? disabled,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? token,
  }) {
    return ScsUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      customData: customData ?? this.customData,
      disabled: disabled ?? this.disabled,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      token: token ?? this.token,
    );
  }

  @override
  String toString() {
    return 'ScsUser(uid: $uid, email: $email, displayName: $displayName)';
  }
}

/// Authentication credentials for login/register.
class AuthCredentials {
  final String email;
  final String password;
  final String? displayName;
  final Map<String, dynamic>? customData;

  const AuthCredentials({
    required this.email,
    required this.password,
    this.displayName,
    this.customData,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      if (displayName != null) 'displayName': displayName,
      if (customData != null) 'customData': customData,
    };
  }
}
