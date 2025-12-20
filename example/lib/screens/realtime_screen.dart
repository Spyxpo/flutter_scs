import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';

import '../main.dart';

class RealtimeScreen extends StatefulWidget {
  const RealtimeScreen({super.key});

  @override
  State<RealtimeScreen> createState() => _RealtimeScreenState();
}

class _RealtimeScreenState extends State<RealtimeScreen> {
  final _pathController = TextEditingController(text: 'chat/messages');
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _connected = false;
  bool _loading = false;
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pathController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    ScsExampleApp.scs!.realtime.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.realtime.connect();
      setState(() => _connected = true);
      _subscribeToPath();
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeToPath() {
    _subscription?.cancel();
    final path = _pathController.text.trim();
    if (path.isEmpty) return;

    final ref = ScsExampleApp.scs!.realtime.ref(path);
    _subscription = ref.onValue.listen((data) {
      if (data is List) {
        setState(() {
          _messages = data.cast<Map<String, dynamic>>();
        });
      } else if (data is Map) {
        final messages = <Map<String, dynamic>>[];
        data.forEach((key, value) {
          if (value is Map) {
            messages.add({'id': key, ...Map<String, dynamic>.from(value)});
          }
        });
        setState(() => _messages = messages);
      }
      _scrollToBottom();
    });

    // Initial fetch
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await ScsExampleApp.scs!.realtime.getData(_pathController.text.trim());
      if (data is List) {
        setState(() {
          _messages = data.cast<Map<String, dynamic>>();
        });
      } else if (data is Map) {
        final messages = <Map<String, dynamic>>[];
        data.forEach((key, value) {
          if (value is Map) {
            messages.add({'id': key, ...Map<String, dynamic>.from(value)});
          }
        });
        setState(() => _messages = messages);
      }
    } catch (e) {
      // Ignore errors for initial fetch
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _loading = true);
    try {
      final path = _pathController.text.trim();
      final user = ScsExampleApp.scs!.auth.currentUser;

      await ScsExampleApp.scs!.realtime.push(path, {
        'text': message,
        'sender': user?.displayName ?? user?.email ?? 'Anonymous',
        'senderId': user?.uid ?? 'anonymous',
        'timestamp': DateTime.now().toIso8601String(),
      });

      _messageController.clear();
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearMessages() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Messages'),
        content: const Text('Are you sure you want to clear all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ScsExampleApp.scs!.realtime.removeData(_pathController.text.trim());
      setState(() => _messages = []);
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
    final currentUserId = ScsExampleApp.scs!.auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Database'),
        actions: [
          IconButton(
            icon: Icon(
              _connected ? Icons.cloud_done : Icons.cloud_off,
              color: _connected ? Colors.green : Colors.red,
            ),
            onPressed: _connected ? null : _connect,
            tooltip: _connected ? 'Connected' : 'Disconnected',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearMessages,
            tooltip: 'Clear Messages',
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pathController,
                      decoration: const InputDecoration(
                        labelText: 'Path',
                        prefixIcon: Icon(Icons.route),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _subscribeToPath,
                    child: const Text('Subscribe'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _messages.isEmpty
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
                          'No messages yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to get started',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final text = msg['text'] as String? ?? '';
                      final sender = msg['sender'] as String? ?? 'Unknown';
                      final senderId = msg['senderId'] as String? ?? '';
                      final isMe = senderId == currentUserId;
                      final timestamp = msg['timestamp'] as String?;

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Card(
                            color: isMe
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sender,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(text),
                                  if (timestamp != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimestamp(timestamp),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onFieldSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _loading ? null : _sendMessage,
                    icon: _loading
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
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
