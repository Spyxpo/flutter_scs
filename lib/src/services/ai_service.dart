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
  ///
  /// Parameters:
  /// - [messages]: List of chat messages for context
  /// - [model]: Model to use (e.g., 'llama3.2', 'codellama')
  /// - [temperature]: Response randomness (0.0-2.0, default 0.7)
  /// - [maxTokens]: Maximum response length (default 2048)
  /// - [systemPrompt]: System instructions for the AI
  /// - [conversationId]: Optional conversation ID to continue a conversation
  Future<ChatResponse> chat({
    required List<ChatMessage> messages,
    String? model,
    double? temperature,
    int? maxTokens,
    String? systemPrompt,
    String? conversationId,
  }) async {
    // If there's a message in the list, extract it for the API
    final String? message = messages.isNotEmpty ? messages.last.content : null;

    final response = await _client.post(
      'ai/chat',
      body: {
        if (message != null) 'message': message,
        'messages': messages.map((m) => m.toJson()).toList(),
        if (model != null) 'model': model,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'maxTokens': maxTokens,
        if (systemPrompt != null) 'systemPrompt': systemPrompt,
        if (conversationId != null) 'conversationId': conversationId,
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

  // ==================== TTS & STT ====================

  /// Converts text to speech.
  ///
  /// Args:
  ///   text: Text to convert to speech
  ///   voice: Optional voice preset (defaults to 'v2/en_speaker_6')
  ///
  /// Returns:
  ///   TTSResponse with base64 encoded audio data
  Future<TTSResponse> textToSpeech(String text, {String? voice}) async {
    final body = <String, dynamic>{
      'text': text,
    };
    if (voice != null) {
      body['voice'] = voice;
    }

    final response = await _client.post('ai/tts', body: body);
    return TTSResponse.fromJson(response);
  }

  /// Converts speech to text.
  ///
  /// Args:
  ///   audio: Base64 encoded audio data
  ///
  /// Returns:
  ///   STTResponse with transcribed text
  Future<STTResponse> speechToText(String audio) async {
    final body = <String, dynamic>{
      'audio': audio,
    };

    final response = await _client.post('ai/stt', body: body);
    return STTResponse.fromJson(response);
  }
}

/// Represents an AI model available in the SCS platform.
///
/// Contains metadata about the model including its name, capabilities,
/// and availability status.
class AiModel {
  /// The unique identifier/name of the model.
  final String name;

  /// Human-readable display name for the model.
  final String? displayName;

  /// Description of the model's capabilities.
  final String? description;

  /// The number of parameters in the model (in millions/billions).
  final int? parameterSize;

  /// Category of the model (e.g., 'chat', 'completion', 'image').
  final String? category;

  /// Whether the model is currently available for use.
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

/// Represents a message in a chat conversation.
///
/// Each message has a role (user, assistant, or system) and content.
/// Use the factory constructors for convenient message creation.
class ChatMessage {
  /// The role of the message sender ('user', 'assistant', or 'system').
  final String role;

  /// The text content of the message.
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

/// Response from the AI chat endpoint.
///
/// Contains the assistant's response message along with metadata
/// about token usage and the model used.
class ChatResponse {
  /// The assistant's response message.
  final ChatMessage message;

  /// The model that generated the response.
  final String? model;

  /// Number of tokens in the prompt.
  final int? promptTokens;

  /// Number of tokens in the completion.
  final int? completionTokens;

  /// Total tokens used (prompt + completion).
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

/// Response from the AI text completion endpoint.
///
/// Contains the generated text along with metadata
/// about token usage and the model used.
class CompletionResponse {
  /// The generated completion text.
  final String text;

  /// The model that generated the completion.
  final String? model;

  /// Number of tokens in the prompt.
  final int? promptTokens;

  /// Number of tokens in the completion.
  final int? completionTokens;

  /// Total tokens used (prompt + completion).
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

/// Response from the AI image generation endpoint.
///
/// Contains either a URL to the generated image or base64-encoded image data.
class ImageGenerationResponse {
  /// URL to the generated image (if available).
  final String? imageUrl;

  /// Base64-encoded image data (if available).
  final String? base64;

  /// The model that generated the image.
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

/// Represents a conversation session with the AI.
///
/// Contains the conversation history and metadata for persistent chat sessions.
class Conversation {
  /// Unique identifier for the conversation.
  final String id;

  /// Optional title for the conversation.
  final String? title;

  /// List of messages in the conversation.
  final List<ChatMessage> messages;

  /// When the conversation was created.
  final DateTime? createdAt;

  /// When the conversation was last updated.
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

/// Represents an AI agent with custom instructions and tools.
///
/// Agents are persistent AI assistants that can be configured with
/// specific behaviors, tools, and knowledge to perform specialized tasks.
class Agent {
  /// Unique identifier for the agent.
  final String id;

  /// Name of the agent.
  final String name;

  /// Description of what the agent does.
  final String? description;

  /// System instructions that define the agent's behavior.
  final String? instructions;

  /// The AI model to use for this agent.
  final String? model;

  /// List of tool IDs the agent can use.
  final List<String> tools;

  /// Temperature setting for response randomness (0.0-2.0).
  final double? temperature;

  /// Maximum tokens for responses.
  final int? maxTokens;

  /// Custom metadata associated with the agent.
  final Map<String, dynamic>? metadata;

  /// Current status of the agent ('active', 'inactive', etc.).
  final String status;

  /// When the agent was created.
  final DateTime? createdAt;

  /// When the agent was last updated.
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

/// Represents a conversation session with an AI agent.
///
/// Sessions maintain state and conversation history between
/// multiple interactions with an agent.
class AgentSession {
  /// Unique identifier for the session.
  final String sessionId;

  /// The agent this session belongs to.
  final String agentId;

  /// List of messages in this session.
  final List<ChatMessage> messages;

  /// Custom context data for this session.
  final Map<String, dynamic>? context;

  /// When the session was created.
  final DateTime? createdAt;

  /// When the session was last updated.
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

/// Response from running an AI agent.
///
/// Contains the agent's output along with metadata about
/// the execution including token usage and processing time.
class AgentRunResponse {
  /// The agent's response output.
  final String output;

  /// The session ID for this interaction.
  final String sessionId;

  /// The agent that processed the request.
  final String agentId;

  /// The model that generated the response.
  final String? model;

  /// Number of tokens used in the request.
  final int? tokensUsed;

  /// Processing time in milliseconds.
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

/// Represents a tool that AI agents can use.
///
/// Tools extend agent capabilities by allowing them to perform
/// specific actions like API calls, calculations, or data retrieval.
class AgentTool {
  /// Unique identifier for the tool.
  final String id;

  /// Name of the tool.
  final String name;

  /// Description of what the tool does.
  final String? description;

  /// JSON schema defining the tool's parameters.
  final Map<String, dynamic>? parameters;

  /// Current status of the tool ('active', 'inactive', etc.).
  final String status;

  /// When the tool was created.
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

/// Response from the text-to-speech endpoint.
///
/// Contains the generated audio data in base64 format along with
/// metadata about the audio format.
class TTSResponse {
  /// Whether the TTS operation was successful.
  final bool success;

  /// Base64-encoded audio data.
  final String audio;

  /// Audio format (e.g., 'wav', 'mp3').
  final String format;

  /// Audio sample rate in Hz.
  final int sampleRate;

  const TTSResponse({
    required this.success,
    required this.audio,
    required this.format,
    required this.sampleRate,
  });

  factory TTSResponse.fromJson(Map<String, dynamic> json) {
    return TTSResponse(
      success: json['success'] as bool? ?? false,
      audio: json['audio'] as String? ?? '',
      format: json['format'] as String? ?? 'wav',
      sampleRate: json['sample_rate'] as int? ?? 24000,
    );
  }
}

/// Response from the speech-to-text endpoint.
///
/// Contains the transcribed text from the audio input.
class STTResponse {
  /// Whether the STT operation was successful.
  final bool success;

  /// The transcribed text from the audio.
  final String text;

  const STTResponse({
    required this.success,
    required this.text,
  });

  factory STTResponse.fromJson(Map<String, dynamic> json) {
    return STTResponse(
      success: json['success'] as bool? ?? false,
      text: json['text'] as String? ?? '',
    );
  }
}
