/// Represents a push notification message.
class ScsMessage {
  /// The message ID.
  final String id;

  /// The notification title.
  final String? title;

  /// The notification body.
  final String? body;

  /// Custom data payload.
  final Map<String, dynamic>? data;

  /// The topic this message was sent to.
  final String? topic;

  /// When the message was sent.
  final DateTime? sentAt;

  const ScsMessage({
    required this.id,
    this.title,
    this.body,
    this.data,
    this.topic,
    this.sentAt,
  });

  factory ScsMessage.fromJson(Map<String, dynamic> json) {
    return ScsMessage(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String?,
      body: json['body'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      topic: json['topic'] as String?,
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (data != null) 'data': data,
      if (topic != null) 'topic': topic,
      if (sentAt != null) 'sentAt': sentAt!.toIso8601String(),
    };
  }
}

/// Represents a messaging topic.
class ScsTopic {
  /// The topic name.
  final String name;

  /// The number of subscribers.
  final int subscriberCount;

  /// When the topic was created.
  final DateTime? createdAt;

  const ScsTopic({
    required this.name,
    this.subscriberCount = 0,
    this.createdAt,
  });

  factory ScsTopic.fromJson(Map<String, dynamic> json) {
    return ScsTopic(
      name: json['name'] as String? ?? '',
      subscriberCount: json['subscriberCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

/// Device token for push notifications.
class DeviceToken {
  /// The device token.
  final String token;

  /// The platform (ios, android, web).
  final String platform;

  /// When the token was registered.
  final DateTime? registeredAt;

  const DeviceToken({
    required this.token,
    required this.platform,
    this.registeredAt,
  });

  factory DeviceToken.fromJson(Map<String, dynamic> json) {
    return DeviceToken(
      token: json['token'] as String? ?? '',
      platform: json['platform'] as String? ?? 'unknown',
      registeredAt: json['registeredAt'] != null
          ? DateTime.tryParse(json['registeredAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'platform': platform,
    };
  }
}

/// Options for sending a message.
class SendMessageOptions {
  /// Send to a specific topic.
  final String? topic;

  /// Send to specific device tokens.
  final List<String>? tokens;

  /// The notification title.
  final String? title;

  /// The notification body.
  final String? body;

  /// Custom data payload.
  final Map<String, dynamic>? data;

  const SendMessageOptions({
    this.topic,
    this.tokens,
    this.title,
    this.body,
    this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      if (topic != null) 'topic': topic,
      if (tokens != null && tokens!.isNotEmpty) 'tokens': tokens,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (data != null) 'data': data,
    };
  }
}
