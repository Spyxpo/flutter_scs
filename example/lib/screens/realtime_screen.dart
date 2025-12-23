import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';

import '../main.dart';

class RealtimeScreen extends StatefulWidget {
  const RealtimeScreen({super.key});

  @override
  State<RealtimeScreen> createState() => _RealtimeScreenState();
}

class _RealtimeScreenState extends State<RealtimeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _pathController = TextEditingController(text: 'chat/messages');
  final _messageController = TextEditingController();
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();
  final _scrollController = ScrollController();

  bool _connected = false;
  bool _loading = false;
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _rawData;
  StreamSubscription? _subscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _connect();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _connectionSubscription?.cancel();
    _tabController.dispose();
    _pathController.dispose();
    _messageController.dispose();
    _keyController.dispose();
    _valueController.dispose();
    _scrollController.dispose();
    ScsExampleApp.scs!.realtime.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.realtime.connect();
      setState(() => _connected = true);

      _connectionSubscription = ScsExampleApp.scs!.realtime.connectionState.listen((connected) {
        if (mounted) {
          setState(() => _connected = connected);
        }
      });

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
      setState(() => _rawData = data is Map ? Map<String, dynamic>.from(data) : null);
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

    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await ScsExampleApp.scs!.realtime.getData(_pathController.text.trim());
      setState(() => _rawData = data is Map ? Map<String, dynamic>.from(data) : null);
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
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
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

  Future<void> _setData() async {
    final key = _keyController.text.trim();
    final value = _valueController.text.trim();

    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      dynamic parsedValue = value;
      if (value.toLowerCase() == 'true') {
        parsedValue = true;
      } else if (value.toLowerCase() == 'false') {
        parsedValue = false;
      } else if (double.tryParse(value) != null) {
        parsedValue = double.parse(value);
      } else if (value.startsWith('{') || value.startsWith('[')) {
        try {
          parsedValue = jsonDecode(value);
        } catch (_) {}
      }

      final path = '${_pathController.text.trim()}/$key';
      await ScsExampleApp.scs!.realtime.setData(path, parsedValue);

      _keyController.clear();
      _valueController.clear();
      await _fetchData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data set successfully!'),
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateData() async {
    final key = _keyController.text.trim();
    final value = _valueController.text.trim();

    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      dynamic parsedValue = value;
      if (value.startsWith('{')) {
        try {
          parsedValue = jsonDecode(value);
        } catch (_) {
          parsedValue = {key: value};
        }
      } else {
        parsedValue = {key: value};
      }

      final path = _pathController.text.trim();
      await ScsExampleApp.scs!.realtime.updateData(path, parsedValue as Map<String, dynamic>);

      _keyController.clear();
      _valueController.clear();
      await _fetchData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data updated successfully!'),
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearMessages() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Data'),
        content: const Text('Are you sure you want to clear all data at this path?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ScsExampleApp.scs!.realtime.removeData(_pathController.text.trim());
      setState(() {
        _messages = [];
        _rawData = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data cleared!'),
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

  Future<void> _exportData() async {
    try {
      final data = await ScsExampleApp.scs!.realtime.exportData();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exported Data'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(data),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
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

  Future<void> _importData() async {
    final controller = TextEditingController();
    bool merge = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Import Data'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'JSON Data',
                    hintText: '{"key": "value"}',
                  ),
                  maxLines: 8,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Merge with existing data'),
                  value: merge,
                  onChanged: (value) {
                    setDialogState(() => merge = value ?? false);
                  },
                  contentPadding: EdgeInsets.zero,
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
              onPressed: () {
                try {
                  final data = jsonDecode(controller.text);
                  Navigator.of(context).pop({'data': data, 'merge': merge});
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid JSON format'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      await ScsExampleApp.scs!.realtime.importData(
        result['data'] as Map<String, dynamic>,
        merge: result['merge'] as bool,
      );
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data imported successfully!'),
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

  @override
  Widget build(BuildContext context) {
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
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportData();
                  break;
                case 'import':
                  _importData();
                  break;
                case 'clear':
                  _clearMessages();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export Data'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.upload),
                  title: Text('Import Data'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep, color: Colors.red),
                  title: Text('Clear Data', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chat', icon: Icon(Icons.chat)),
            Tab(text: 'Data', icon: Icon(Icons.data_object)),
            Tab(text: 'Raw', icon: Icon(Icons.code)),
          ],
        ),
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTab(),
                _buildDataTab(),
                _buildRawTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    final currentUserId = ScsExampleApp.scs!.auth.currentUser?.uid;

    return Column(
      children: [
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
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
    );
  }

  Widget _buildDataTab() {
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
                    'Set/Update Data',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _keyController,
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      hintText: 'e.g., username, settings',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _valueController,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      hintText: 'e.g., John, {"theme": "dark"}',
                      isDense: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _setData,
                          icon: const Icon(Icons.add),
                          label: const Text('Set'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _updateData,
                          icon: const Icon(Icons.update),
                          label: const Text('Update'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Current Data',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _fetchData,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_messages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No data at this path',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ...List.generate(_messages.length, (index) {
                      final item = _messages[index];
                      final id = item['id'] ?? index.toString();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text('${index + 1}'),
                        ),
                        title: Text('Key: $id'),
                        subtitle: Text(
                          item.entries
                              .where((e) => e.key != 'id')
                              .map((e) => '${e.key}: ${e.value}')
                              .join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            final path = '${_pathController.text.trim()}/$id';
                            await ScsExampleApp.scs!.realtime.removeData(path);
                            _fetchData();
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Realtime Features',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const _FeatureItem(
                    icon: Icons.sync,
                    title: 'Real-time Sync',
                    subtitle: 'WebSocket-based synchronization',
                  ),
                  const _FeatureItem(
                    icon: Icons.cloud_upload,
                    title: 'Push Data',
                    subtitle: 'Add data with auto-generated keys',
                  ),
                  const _FeatureItem(
                    icon: Icons.edit,
                    title: 'Set/Update',
                    subtitle: 'Overwrite or merge data',
                  ),
                  const _FeatureItem(
                    icon: Icons.download,
                    title: 'Import/Export',
                    subtitle: 'Backup and restore data',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Raw JSON Data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchData,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _rawData == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No data available',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                : SelectableText(
                    const JsonEncoder.withIndent('  ').convert(_rawData),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
        ],
      ),
    );
  }
}
