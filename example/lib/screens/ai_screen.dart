import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';

import '../main.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Chat
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  List<ChatMessage> _chatMessages = [];
  bool _chatLoading = false;

  // Completion
  final _promptController = TextEditingController();
  String? _completionResult;
  bool _completionLoading = false;

  // Image Generation
  final _imagePromptController = TextEditingController();
  String? _generatedImageUrl;
  bool _imageLoading = false;

  // Models & Stats
  List<AiModel> _models = [];
  String? _selectedModel;
  Map<String, dynamic> _stats = {};

  // Agents
  List<Agent> _agents = [];
  Agent? _selectedAgent;
  String? _agentSessionId;
  final _agentInputController = TextEditingController();
  AgentRunResponse? _agentResponse;

  // Conversations
  List<Conversation> _conversations = [];

  // TTS
  final _ttsController = TextEditingController();
  TTSResponse? _ttsResponse;
  bool _ttsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchModels();
    _fetchAgents();
    _fetchConversations();
    _fetchStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _promptController.dispose();
    _imagePromptController.dispose();
    _agentInputController.dispose();
    _ttsController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    try {
      final models = await ScsExampleApp.scs!.ai.listModels();
      setState(() {
        _models = models;
        if (models.isNotEmpty) {
          _selectedModel = models.first.name;
        }
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _fetchAgents() async {
    try {
      final agents = await ScsExampleApp.scs!.ai.listAgents();
      setState(() => _agents = agents);
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _fetchConversations() async {
    try {
      final conversations = await ScsExampleApp.scs!.ai.listConversations();
      setState(() => _conversations = conversations);
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await ScsExampleApp.scs!.ai.getStats();
      setState(() => _stats = stats);
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add(ChatMessage.user(text));
      _chatLoading = true;
    });
    _chatController.clear();
    _scrollToBottom();

    try {
      final response = await ScsExampleApp.scs!.ai.chat(
        messages: _chatMessages,
        model: _selectedModel,
      );
      setState(() {
        _chatMessages.add(ChatMessage.assistant(response.message.content));
      });
      _scrollToBottom();
    } on ScsException catch (e) {
      setState(() {
        _chatMessages.add(ChatMessage.assistant('Error: ${e.message}'));
      });
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _clearChat() {
    setState(() {
      _chatMessages = [];
    });
  }

  Future<void> _generateCompletion() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _completionLoading = true;
      _completionResult = null;
    });

    try {
      final response = await ScsExampleApp.scs!.ai.complete(
        prompt: prompt,
        model: _selectedModel,
      );
      setState(() => _completionResult = response.text);
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _completionLoading = false);
    }
  }

  Future<void> _generateImage() async {
    final prompt = _imagePromptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _imageLoading = true;
      _generatedImageUrl = null;
    });

    try {
      final response = await ScsExampleApp.scs!.ai.generateImage(
        prompt: prompt,
        model: _selectedModel,
      );
      setState(() => _generatedImageUrl = response.imageUrl);
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _imageLoading = false);
    }
  }

  Future<void> _createAgent() async {
    final nameController = TextEditingController();
    final instructionsController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Agent'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  isDense: true,
                  hintText: 'My Assistant',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  isDense: true,
                  hintText: 'You are a helpful assistant...',
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'name': nameController.text.trim(),
              'description': descriptionController.text.trim(),
              'instructions': instructionsController.text.trim(),
            }),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == null || result['name']?.isEmpty == true) return;

    try {
      await ScsExampleApp.scs!.ai.createAgent(
        name: result['name'],
        description: result['description']?.isNotEmpty == true ? result['description'] : null,
        instructions: result['instructions']?.isNotEmpty == true ? result['instructions'] : null,
        model: _selectedModel,
      );
      await _fetchAgents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agent created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _runAgent() async {
    if (_selectedAgent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an agent'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final input = _agentInputController.text.trim();
    if (input.isEmpty) return;

    setState(() => _chatLoading = true);

    try {
      final response = await ScsExampleApp.scs!.ai.runAgent(
        _selectedAgent!.id,
        input: input,
        sessionId: _agentSessionId,
      );
      setState(() {
        _agentResponse = response;
        _agentSessionId = response.sessionId;
      });
      _agentInputController.clear();
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  Future<void> _deleteAgent(Agent agent) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Agent'),
        content: Text('Are you sure you want to delete "${agent.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ScsExampleApp.scs!.ai.deleteAgent(agent.id);
      await _fetchAgents();
      if (_selectedAgent?.id == agent.id) {
        setState(() {
          _selectedAgent = null;
          _agentSessionId = null;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agent deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _textToSpeech() async {
    final text = _ttsController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _ttsLoading = true;
      _ttsResponse = null;
    });

    try {
      final response = await ScsExampleApp.scs!.ai.textToSpeech(text);
      setState(() => _ttsResponse = response);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.success
                ? 'Audio generated! (${response.format}, ${response.sampleRate}Hz)'
                : 'TTS failed'),
            backgroundColor: response.success ? Colors.green : Colors.red,
          ),
        );
      }
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _ttsLoading = false);
    }
  }

  Future<void> _createConversation() async {
    final titleController = TextEditingController();

    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Conversation'),
        content: TextFormField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Title (optional)',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(titleController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (title == null) return;

    try {
      await ScsExampleApp.scs!.ai.createConversation(title: title.isNotEmpty ? title : null);
      await _fetchConversations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    try {
      await ScsExampleApp.scs!.ai.deleteConversation(conversation.id);
      await _fetchConversations();
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Services'),
        actions: [
          if (_models.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.smart_toy),
              tooltip: 'Select Model',
              onSelected: (value) {
                setState(() => _selectedModel = value);
              },
              itemBuilder: (context) {
                return _models.map((model) {
                  return PopupMenuItem(
                    value: model.name,
                    child: Row(
                      children: [
                        if (model.name == _selectedModel)
                          const Icon(Icons.check, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(model.displayName ?? model.name),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchModels();
              _fetchAgents();
              _fetchConversations();
              _fetchStats();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Chat', icon: Icon(Icons.chat)),
            Tab(text: 'Complete', icon: Icon(Icons.edit_note)),
            Tab(text: 'Image', icon: Icon(Icons.image)),
            Tab(text: 'Agents', icon: Icon(Icons.psychology)),
            Tab(text: 'More', icon: Icon(Icons.more_horiz)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(),
          _buildCompletionTab(),
          _buildImageTab(),
          _buildAgentsTab(),
          _buildMoreTab(),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: _chatMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Start a conversation',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (_selectedModel != null) ...[
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(_selectedModel!),
                          avatar: const Icon(Icons.smart_toy, size: 16),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final message = _chatMessages[index];
                    final isUser = message.role == 'user';

                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        child: Card(
                          color: isUser
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isUser ? Icons.person : Icons.smart_toy,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isUser ? 'You' : 'AI',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SelectableText(message.content),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_chatLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _clearChat,
                  tooltip: 'Clear Chat',
                ),
                Expanded(
                  child: TextFormField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onFieldSubmitted: (_) => _sendChatMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _chatLoading ? null : _sendChatMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Text Completion',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter a prompt and the AI will complete it.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      labelText: 'Prompt',
                      hintText: 'Once upon a time...',
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _completionLoading ? null : _generateCompletion,
                    icon: _completionLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: const Text('Generate'),
                  ),
                ],
              ),
            ),
          ),
          if (_completionResult != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Result',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(_completionResult!),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Image Generation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Describe the image you want to generate.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _imagePromptController,
                    decoration: const InputDecoration(
                      labelText: 'Prompt',
                      hintText: 'A beautiful sunset over mountains...',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _imageLoading ? null : _generateImage,
                    icon: _imageLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: const Text('Generate Image'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_generatedImageUrl != null)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Image.network(
                    _generatedImageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 300,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48),
                            SizedBox(height: 8),
                            Text('Failed to load image'),
                          ],
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Generated Image',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generated image will appear here',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAgentsTab() {
    return Column(
      children: [
        // Agent selector
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownMenu<Agent>(
                    initialSelection: _selectedAgent,
                    label: const Text('Select Agent'),
                    leadingIcon: const Icon(Icons.psychology),
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: _agents.map((agent) {
                      return DropdownMenuEntry(
                        value: agent,
                        label: agent.name,
                      );
                    }).toList(),
                    onSelected: (value) {
                      setState(() {
                        _selectedAgent = value;
                        _agentSessionId = null;
                        _agentResponse = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _createAgent,
                  tooltip: 'Create Agent',
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _selectedAgent == null
              ? _buildAgentsList()
              : _buildAgentInteraction(),
        ),
      ],
    );
  }

  Widget _buildAgentsList() {
    if (_agents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No agents available',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first AI agent',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _createAgent,
              icon: const Icon(Icons.add),
              label: const Text('Create Agent'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _agents.length,
      itemBuilder: (context, index) {
        final agent = _agents[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: const Icon(Icons.psychology),
            ),
            title: Text(agent.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agent.description ?? 'No description'),
                Row(
                  children: [
                    Chip(
                      label: Text(agent.status),
                      labelStyle: const TextStyle(fontSize: 10),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: agent.status == 'active'
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                    ),
                    if (agent.model != null) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(agent.model!),
                        labelStyle: const TextStyle(fontSize: 10),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () {
                    setState(() {
                      _selectedAgent = agent;
                      _agentSessionId = null;
                    });
                  },
                  tooltip: 'Run',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteAgent(agent),
                  color: Colors.red,
                ),
              ],
            ),
            isThreeLine: true,
            onTap: () {
              setState(() {
                _selectedAgent = agent;
                _agentSessionId = null;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildAgentInteraction() {
    return Column(
      children: [
        // Agent info card
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            leading: const Icon(Icons.psychology),
            title: Text(_selectedAgent!.name),
            subtitle: Text(_selectedAgent!.instructions ?? 'No instructions'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _selectedAgent = null;
                  _agentSessionId = null;
                  _agentResponse = null;
                });
              },
            ),
          ),
        ),
        // Response area
        Expanded(
          child: _agentResponse == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Send a message to ${_selectedAgent!.name}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (_agentSessionId != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Session: ${_agentSessionId!.substring(0, 8)}...',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.psychology),
                              const SizedBox(width: 8),
                              Text(
                                'Agent Response',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              if (_agentResponse!.processingTime != null)
                                Chip(
                                  label: Text('${_agentResponse!.processingTime}ms'),
                                  labelStyle: const TextStyle(fontSize: 10),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SelectableText(_agentResponse!.output),
                          const Divider(),
                          Text(
                            'Session: ${_agentResponse!.sessionId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (_agentResponse!.tokensUsed != null)
                            Text(
                              'Tokens: ${_agentResponse!.tokensUsed}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        // Input area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _agentInputController,
                    decoration: InputDecoration(
                      hintText: 'Message ${_selectedAgent!.name}...',
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onFieldSubmitted: (_) => _runAgent(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _chatLoading ? null : _runAgent,
                  icon: _chatLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TTS Section
          Text(
            'Text to Speech',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _ttsController,
                    decoration: const InputDecoration(
                      labelText: 'Text to speak',
                      hintText: 'Hello, welcome to SCS!',
                      isDense: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _ttsLoading ? null : _textToSpeech,
                          icon: _ttsLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.record_voice_over),
                          label: const Text('Generate Speech'),
                        ),
                      ),
                    ],
                  ),
                  if (_ttsResponse != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _ttsResponse!.success
                              ? Icons.check_circle
                              : Icons.error,
                          color:
                              _ttsResponse!.success ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Format: ${_ttsResponse!.format}, ${_ttsResponse!.sampleRate}Hz',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Conversations Section
          Row(
            children: [
              Text(
                'Conversations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _createConversation,
                tooltip: 'New Conversation',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_conversations.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...List.generate(_conversations.length, (index) {
              final conversation = _conversations[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.forum),
                  title: Text(conversation.title ?? 'Untitled'),
                  subtitle: Text(
                    '${conversation.messages.length} messages',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteConversation(conversation),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          // Stats Section
          Text(
            'Statistics',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (_stats.isNotEmpty)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children:
                  _stats.entries.map((e) => _buildStatCard(e.key, e.value)).toList(),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No statistics available',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          // Features
          Text(
            'Available Features',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            'Chat',
            'Multi-turn conversations with AI',
            Icons.chat,
          ),
          _buildFeatureCard(
            'Completion',
            'Generate text from prompts',
            Icons.edit_note,
          ),
          _buildFeatureCard(
            'Image Generation',
            'Create images from text descriptions',
            Icons.image,
          ),
          _buildFeatureCard(
            'AI Agents',
            'Create custom AI assistants with tools',
            Icons.psychology,
          ),
          _buildFeatureCard(
            'Text to Speech',
            'Convert text to spoken audio',
            Icons.record_voice_over,
          ),
          _buildFeatureCard(
            'Speech to Text',
            'Transcribe audio to text',
            Icons.mic,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, dynamic value) {
    String displayLabel = label
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}')
        .trim()
        .replaceFirst(label[0], label[0].toUpperCase());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              displayLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(String title, String description, IconData icon) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(description),
      ),
    );
  }
}
