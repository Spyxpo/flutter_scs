import '../utils/http_client.dart';

/// Service for AI operations.
///
/// Provides methods for chat, completions, and image generation
/// using local LLM models (Ollama).
class AiService {
  final ScsHttpClient _client;

  AiService(this._client);

  /// Lists available AI models.
  Future<List<AiModel>> listModels() async {
    final response = await _client.get('ai/models');
    final models = response['models'] as List<dynamic>? ?? [];
    return models
        .map((m) => AiModel.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Pulls (downloads) a model.
  Future<void> pullModel(String modelName) async {
    await _client.post(
      'ai/models/pull',
      body: {'modelName': modelName},
    );
  }

  /// Sends a chat message and gets a response.
  Future<ChatResponse> chat({
    required List<ChatMessage> messages,
    String? model,
    double? temperature,
    int? maxTokens,
  }) async {
    final response = await _client.post(
      'ai/chat',
      body: {
        'messages': messages.map((m) => m.toJson()).toList(),
        if (model != null) 'model': model,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'maxTokens': maxTokens,
      },
    );
    return ChatResponse.fromJson(response);
  }

  /// Generates a completion for a prompt.
  Future<CompletionResponse> complete({
    required String prompt,
    String? model,
    double? temperature,
    int? maxTokens,
  }) async {
    final response = await _client.post(
      'ai/complete',
      body: {
        'prompt': prompt,
        if (model != null) 'model': model,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'maxTokens': maxTokens,
      },
    );
    return CompletionResponse.fromJson(response);
  }

  /// Generates an image from a prompt.
  Future<ImageGenerationResponse> generateImage({
    required String prompt,
    String? model,
    int? width,
    int? height,
  }) async {
    final response = await _client.post(
      'ai/generate-image',
      body: {
        'prompt': prompt,
        if (model != null) 'model': model,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      },
    );
    return ImageGenerationResponse.fromJson(response);
  }

  /// Lists all conversations.
  Future<List<Conversation>> listConversations() async {
    final response = await _client.get('ai/conversations');
    final conversations = response['conversations'] as List<dynamic>? ?? [];
    return conversations
        .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new conversation.
  Future<Conversation> createConversation({String? title}) async {
    final response = await _client.post(
      'ai/conversations',
      body: {
        if (title != null) 'title': title,
      },
    );
    return Conversation.fromJson(
        response['conversation'] as Map<String, dynamic>? ?? response);
  }

  /// Gets a conversation by ID.
  Future<Conversation> getConversation(String conversationId) async {
    final response = await _client.get('ai/conversations/$conversationId');
    return Conversation.fromJson(
        response['conversation'] as Map<String, dynamic>? ?? response);
  }

  /// Deletes a conversation.
  Future<void> deleteConversation(String conversationId) async {
    await _client.delete('ai/conversations/$conversationId');
  }

  /// Gets AI service statistics.
  Future<Map<String, dynamic>> getStats() async {
    final response = await _client.get('ai/stats');
    return response['stats'] as Map<String, dynamic>? ?? response;
  }
}

/// An AI model.
class AiModel {
  final String name;
  final String? displayName;
  final String? description;
  final int? parameterSize;
  final String? category;
  final bool isAvailable;

  const AiModel({
    required this.name,
    this.displayName,
    this.description,
    this.parameterSize,
    this.category,
    this.isAvailable = true,
  });

  factory AiModel.fromJson(Map<String, dynamic> json) {
    return AiModel(
      name: json['name'] as String? ?? '',
      displayName: json['displayName'] as String?,
      description: json['description'] as String?,
      parameterSize: json['parameterSize'] as int?,
      category: json['category'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }
}

/// A chat message.
class ChatMessage {
  final String role;
  final String content;

  const ChatMessage({
    required this.role,
    required this.content,
  });

  /// Creates a user message.
  factory ChatMessage.user(String content) {
    return ChatMessage(role: 'user', content: content);
  }

  /// Creates an assistant message.
  factory ChatMessage.assistant(String content) {
    return ChatMessage(role: 'assistant', content: content);
  }

  /// Creates a system message.
  factory ChatMessage.system(String content) {
    return ChatMessage(role: 'system', content: content);
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}

/// A chat response.
class ChatResponse {
  final ChatMessage message;
  final String? model;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  const ChatResponse({
    required this.message,
    this.model,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final messageData = json['message'] as Map<String, dynamic>? ??
        {'role': 'assistant', 'content': json['response'] ?? json['content'] ?? ''};

    return ChatResponse(
      message: ChatMessage.fromJson(messageData),
      model: json['model'] as String?,
      promptTokens: json['promptTokens'] as int?,
      completionTokens: json['completionTokens'] as int?,
      totalTokens: json['totalTokens'] as int?,
    );
  }

  /// Convenience getter for the response content.
  String get content => message.content;
}

/// A completion response.
class CompletionResponse {
  final String text;
  final String? model;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  const CompletionResponse({
    required this.text,
    this.model,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  factory CompletionResponse.fromJson(Map<String, dynamic> json) {
    return CompletionResponse(
      text: json['text'] as String? ?? json['response'] as String? ?? json['completion'] as String? ?? '',
      model: json['model'] as String?,
      promptTokens: json['promptTokens'] as int?,
      completionTokens: json['completionTokens'] as int?,
      totalTokens: json['totalTokens'] as int?,
    );
  }
}

/// An image generation response.
class ImageGenerationResponse {
  final String? imageUrl;
  final String? base64;
  final String? model;

  const ImageGenerationResponse({
    this.imageUrl,
    this.base64,
    this.model,
  });

  factory ImageGenerationResponse.fromJson(Map<String, dynamic> json) {
    return ImageGenerationResponse(
      imageUrl: json['imageUrl'] as String? ?? json['url'] as String?,
      base64: json['base64'] as String? ?? json['image'] as String?,
      model: json['model'] as String?,
    );
  }

  /// Whether the response contains an image.
  bool get hasImage => imageUrl != null || base64 != null;
}

/// A conversation.
class Conversation {
  final String id;
  final String? title;
  final List<ChatMessage> messages;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Conversation({
    required this.id,
    this.title,
    this.messages = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final messages = (json['messages'] as List<dynamic>? ?? [])
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();

    return Conversation(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String?,
      messages: messages,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}
