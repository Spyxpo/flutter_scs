import 'dart:async';

import '../models/message.dart';
import '../utils/http_client.dart';

/// Service for cloud messaging and push notifications.
///
/// Provides methods for registering device tokens, managing topic
/// subscriptions, and sending messages.
class MessagingService {
  final ScsHttpClient _client;
  final StreamController<ScsMessage> _messageController =
      StreamController<ScsMessage>.broadcast();

  MessagingService(this._client);

  /// Stream of incoming messages.
  Stream<ScsMessage> get onMessage => _messageController.stream;

  /// Registers a device token for push notifications.
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    await _client.post(
      'messaging/tokens/register',
      body: {
        'token': token,
        'platform': platform,
      },
    );
  }

  /// Unregisters a device token.
  Future<void> unregisterToken(String token) async {
    await _client.post(
      'messaging/tokens/unregister',
      body: {'token': token},
    );
  }

  /// Gets all registered tokens.
  Future<List<DeviceToken>> getTokens() async {
    final response = await _client.get('messaging/tokens');
    final tokens = response['tokens'] as List<dynamic>? ?? [];
    return tokens
        .map((t) => DeviceToken.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Subscribes a token to a topic.
  Future<void> subscribeToTopic({
    required String token,
    required String topic,
  }) async {
    await _client.post(
      'messaging/topics/subscribe',
      body: {
        'token': token,
        'topic': topic,
      },
    );
  }

  /// Unsubscribes a token from a topic.
  Future<void> unsubscribeFromTopic({
    required String token,
    required String topic,
  }) async {
    await _client.post(
      'messaging/topics/unsubscribe',
      body: {
        'token': token,
        'topic': topic,
      },
    );
  }

  /// Creates a new topic.
  Future<ScsTopic> createTopic(String name) async {
    final response = await _client.post(
      'messaging/topics',
      body: {'name': name},
    );
    return ScsTopic.fromJson(response['topic'] as Map<String, dynamic>? ?? response);
  }

  /// Gets all topics.
  Future<List<ScsTopic>> getTopics() async {
    final response = await _client.get('messaging/topics');
    final topics = response['topics'] as List<dynamic>? ?? [];
    return topics
        .map((t) => ScsTopic.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Gets a specific topic.
  Future<ScsTopic> getTopic(String name) async {
    final response = await _client.get('messaging/topics/$name');
    return ScsTopic.fromJson(response['topic'] as Map<String, dynamic>? ?? response);
  }

  /// Deletes a topic.
  Future<void> deleteTopic(String name) async {
    await _client.delete('messaging/topics/$name');
  }

  /// Sends a message to a topic.
  Future<ScsMessage> sendToTopic({
    required String topic,
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    final response = await _client.post(
      'messaging/send',
      body: {
        'topic': topic,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (data != null) 'data': data,
      },
    );
    return ScsMessage.fromJson(response['message'] as Map<String, dynamic>? ?? response);
  }

  /// Sends a message to specific tokens.
  Future<ScsMessage> sendToTokens({
    required List<String> tokens,
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    final response = await _client.post(
      'messaging/send',
      body: {
        'tokens': tokens,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (data != null) 'data': data,
      },
    );
    return ScsMessage.fromJson(response['message'] as Map<String, dynamic>? ?? response);
  }

  /// Sends a message to a single token.
  Future<ScsMessage> sendToToken({
    required String token,
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    final response = await _client.post(
      'messaging/send/token',
      body: {
        'token': token,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (data != null) 'data': data,
      },
    );
    return ScsMessage.fromJson(response['message'] as Map<String, dynamic>? ?? response);
  }

  /// Sends a message with full options.
  Future<ScsMessage> send(SendMessageOptions options) async {
    final response = await _client.post(
      'messaging/send',
      body: options.toJson(),
    );
    return ScsMessage.fromJson(response['message'] as Map<String, dynamic>? ?? response);
  }

  /// Gets message history.
  Future<List<ScsMessage>> getMessages({int? limit, int? skip}) async {
    final queryParams = <String, dynamic>{};
    if (limit != null) queryParams['limit'] = limit;
    if (skip != null) queryParams['skip'] = skip;

    final response = await _client.get(
      'messaging/messages',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    final messages = response['messages'] as List<dynamic>? ?? [];
    return messages
        .map((m) => ScsMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Gets a specific message.
  Future<ScsMessage> getMessage(String messageId) async {
    final response = await _client.get('messaging/messages/$messageId');
    return ScsMessage.fromJson(response['message'] as Map<String, dynamic>? ?? response);
  }

  /// Deletes a message.
  Future<void> deleteMessage(String messageId) async {
    await _client.delete('messaging/messages/$messageId');
  }

  /// Gets messaging statistics.
  Future<Map<String, dynamic>> getStats() async {
    final response = await _client.get('messaging/stats');
    return response['stats'] as Map<String, dynamic>? ?? response;
  }

  /// Gets all subscriptions.
  Future<List<Map<String, dynamic>>> getSubscriptions() async {
    final response = await _client.get('messaging/subscriptions');
    final subs = response['subscriptions'] as List<dynamic>? ?? [];
    return subs.map((s) => s as Map<String, dynamic>).toList();
  }

  /// Called when a message is received (for platform-specific handling).
  void handleMessage(Map<String, dynamic> message) {
    _messageController.add(ScsMessage.fromJson(message));
  }

  /// Disposes of resources.
  void dispose() {
    _messageController.close();
  }
}
