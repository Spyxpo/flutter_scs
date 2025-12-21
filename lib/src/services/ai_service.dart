import '../utils/http_client.dart';

/// Service for AI operations.
///
/// Provides methods for chat, completions, image generation,
/// and AI agents using local LLM models (Ollama).
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

  // ==================== AI AGENTS ====================

  /// Creates a new AI agent.
  Future<Agent> createAgent({
    required String name,
    String? instructions,
    String? description,
    String? model,
    List<String>? tools,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _client.post(
      'ai/agents',
      body: {
        'name': name,
        if (instructions != null) 'instructions': instructions,
        if (description != null) 'description': description,
        if (model != null) 'model': model,
        if (tools != null) 'tools': tools,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'maxTokens': maxTokens,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return Agent.fromJson(response['agent'] as Map<String, dynamic>? ?? response);
  }

  /// Lists all agents.
  Future<List<Agent>> listAgents({int? limit, int? offset, String? status}) async {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();
    if (status != null) params['status'] = status;

    final queryString = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';

    final response = await _client.get('ai/agents$queryString');
    final agents = response['agents'] as List<dynamic>? ?? [];
    return agents.map((a) => Agent.fromJson(a as Map<String, dynamic>)).toList();
  }

  /// Gets an agent by ID.
  Future<Agent> getAgent(String agentId) async {
    final response = await _client.get('ai/agents/$agentId');
    return Agent.fromJson(response['agent'] as Map<String, dynamic>? ?? response);
  }

  /// Updates an agent.
  Future<Agent> updateAgent(
    String agentId, {
    String? name,
    String? instructions,
    String? description,
    String? model,
    List<String>? tools,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic>? metadata,
    String? status,
  }) async {
    final response = await _client.put(
      'ai/agents/$agentId',
      body: {
        if (name != null) 'name': name,
        if (instructions != null) 'instructions': instructions,
        if (description != null) 'description': description,
        if (model != null) 'model': model,
        if (tools != null) 'tools': tools,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'maxTokens': maxTokens,
        if (metadata != null) 'metadata': metadata,
        if (status != null) 'status': status,
      },
    );
    return Agent.fromJson(response['agent'] as Map<String, dynamic>? ?? response);
  }

  /// Deletes an agent.
  Future<void> deleteAgent(String agentId) async {
    await _client.delete('ai/agents/$agentId');
  }

  /// Runs an agent with input.
  Future<AgentRunResponse> runAgent(
    String agentId, {
    required String input,
    String? sessionId,
    Map<String, dynamic>? context,
  }) async {
    final response = await _client.post(
      'ai/agents/$agentId/run',
      body: {
        'input': input,
        if (sessionId != null) 'sessionId': sessionId,
        if (context != null) 'context': context,
      },
    );
    return AgentRunResponse.fromJson(response);
  }

  /// Lists sessions for an agent.
  Future<List<AgentSession>> listAgentSessions(
    String agentId, {
    int? limit,
    int? offset,
  }) async {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();

    final queryString = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';

    final response = await _client.get('ai/agents/$agentId/sessions$queryString');
    final sessions = response['sessions'] as List<dynamic>? ?? [];
    return sessions.map((s) => AgentSession.fromJson(s as Map<String, dynamic>)).toList();
  }

  /// Gets an agent session with full message history.
  Future<AgentSession> getAgentSession(String agentId, String sessionId) async {
    final response = await _client.get('ai/agents/$agentId/sessions/$sessionId');
    return AgentSession.fromJson(response['session'] as Map<String, dynamic>? ?? response);
  }

  /// Deletes an agent session.
  Future<void> deleteAgentSession(String agentId, String sessionId) async {
    await _client.delete('ai/agents/$agentId/sessions/$sessionId');
  }

  // Agent Tools

  /// Defines a tool that agents can use.
  Future<AgentTool> defineTool({
    required String name,
    String? description,
    Map<String, dynamic>? parameters,
  }) async {
    final response = await _client.post(
      'ai/tools',
      body: {
        'name': name,
        if (description != null) 'description': description,
        if (parameters != null) 'parameters': parameters,
      },
    );
    return AgentTool.fromJson(response['tool'] as Map<String, dynamic>? ?? response);
  }

  /// Lists all defined tools.
  Future<List<AgentTool>> listTools() async {
    final response = await _client.get('ai/tools');
    final tools = response['tools'] as List<dynamic>? ?? [];
    return tools.map((t) => AgentTool.fromJson(t as Map<String, dynamic>)).toList();
  }

  /// Deletes a tool.
  Future<void> deleteTool(String toolId) async {
    await _client.delete('ai/tools/$toolId');
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

// ==================== AI AGENTS ====================

/// An AI agent.
class Agent {
  final String id;
  final String name;
  final String? description;
  final String? instructions;
  final String? model;
  final List<String> tools;
  final double? temperature;
  final int? maxTokens;
  final Map<String, dynamic>? metadata;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Agent({
    required this.id,
    required this.name,
    this.description,
    this.instructions,
    this.model,
    this.tools = const [],
    this.temperature,
    this.maxTokens,
    this.metadata,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['agentId'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      instructions: json['instructions'] as String?,
      model: json['model'] as String?,
      tools: (json['tools'] as List<dynamic>?)?.cast<String>() ?? [],
      temperature: (json['temperature'] as num?)?.toDouble(),
      maxTokens: json['maxTokens'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      status: json['status'] as String? ?? 'active',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

/// An agent session.
class AgentSession {
  final String sessionId;
  final String agentId;
  final List<ChatMessage> messages;
  final Map<String, dynamic>? context;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AgentSession({
    required this.sessionId,
    required this.agentId,
    this.messages = const [],
    this.context,
    this.createdAt,
    this.updatedAt,
  });

  factory AgentSession.fromJson(Map<String, dynamic> json) {
    final messages = (json['messages'] as List<dynamic>? ?? [])
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();

    return AgentSession(
      sessionId: json['sessionId'] as String? ?? '',
      agentId: json['agentId'] as String? ?? '',
      messages: messages,
      context: json['context'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

/// An agent run response.
class AgentRunResponse {
  final String output;
  final String sessionId;
  final String agentId;
  final String? model;
  final int? tokensUsed;
  final int? processingTime;

  const AgentRunResponse({
    required this.output,
    required this.sessionId,
    required this.agentId,
    this.model,
    this.tokensUsed,
    this.processingTime,
  });

  factory AgentRunResponse.fromJson(Map<String, dynamic> json) {
    return AgentRunResponse(
      output: json['output'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      agentId: json['agentId'] as String? ?? '',
      model: json['model'] as String?,
      tokensUsed: json['tokensUsed'] as int?,
      processingTime: json['processingTime'] as int?,
    );
  }
}

/// An agent tool.
class AgentTool {
  final String id;
  final String name;
  final String? description;
  final Map<String, dynamic>? parameters;
  final String status;
  final DateTime? createdAt;

  const AgentTool({
    required this.id,
    required this.name,
    this.description,
    this.parameters,
    this.status = 'active',
    this.createdAt,
  });

  factory AgentTool.fromJson(Map<String, dynamic> json) {
    return AgentTool(
      id: json['toolId'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      parameters: json['parameters'] as Map<String, dynamic>?,
      status: json['status'] as String? ?? 'active',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
