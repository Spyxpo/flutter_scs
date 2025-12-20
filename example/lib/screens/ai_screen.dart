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

  // Models
  List<AiModel> _models = [];
  String? _selectedModel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchModels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _promptController.dispose();
    _imagePromptController.dispose();
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
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chat', icon: Icon(Icons.chat)),
            Tab(text: 'Complete', icon: Icon(Icons.edit_note)),
            Tab(text: 'Image', icon: Icon(Icons.image)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(),
          _buildCompletionTab(),
          _buildImageTab(),
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
                                Text(
                                  isUser ? 'You' : 'AI',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(message.content),
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
                    Text(_completionResult!),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48),
                            const SizedBox(height: 8),
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
}
