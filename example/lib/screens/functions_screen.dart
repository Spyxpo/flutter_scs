import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';

import '../main.dart';

class FunctionsScreen extends StatefulWidget {
  const FunctionsScreen({super.key});

  @override
  State<FunctionsScreen> createState() => _FunctionsScreenState();
}

class _FunctionsScreenState extends State<FunctionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _functionNameController = TextEditingController();
  final _dataController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<CloudFunction> _functions = [];
  List<FunctionLog> _logs = [];
  Map<String, dynamic> _stats = {};
  bool _loading = false;
  FunctionResult? _lastResult;
  CloudFunction? _selectedFunction;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchFunctions();
    _fetchStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _functionNameController.dispose();
    _dataController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchFunctions() async {
    setState(() => _loading = true);
    try {
      final functions = await ScsExampleApp.scs!.functions.list();
      setState(() => _functions = functions);
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

  Future<void> _fetchStats() async {
    try {
      final stats = await ScsExampleApp.scs!.functions.getStats();
      setState(() => _stats = stats);
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _fetchLogs(String functionId) async {
    try {
      final logs = await ScsExampleApp.scs!.functions.getLogs(functionId, limit: 50);
      setState(() => _logs = logs);
    } catch (e) {
      setState(() => _logs = []);
    }
  }

  Future<void> _callFunction() async {
    final name = _functionNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a function name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _lastResult = null;
    });

    try {
      Map<String, dynamic>? data;
      final dataText = _dataController.text.trim();
      if (dataText.isNotEmpty) {
        try {
          data = jsonDecode(dataText) as Map<String, dynamic>;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid JSON data'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _loading = false);
          return;
        }
      }

      final result = await ScsExampleApp.scs!.functions.call(name, data: data);
      setState(() => _lastResult = result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success ? 'Function executed!' : 'Function failed',
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
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

  Future<void> _createFunction() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final codeController = TextEditingController(text: '''// Your function code
module.exports = async (req, res) => {
  const data = req.body;

  // Your logic here

  return { message: "Hello from cloud function!" };
};
''');
    String runtime = 'nodejs18';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Function'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Function Name',
                      isDense: true,
                      hintText: 'myFunction',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: runtime,
                    decoration: const InputDecoration(
                      labelText: 'Runtime',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'nodejs18', child: Text('Node.js 18')),
                      DropdownMenuItem(value: 'nodejs20', child: Text('Node.js 20')),
                      DropdownMenuItem(value: 'python3', child: Text('Python 3')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => runtime = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      isDense: true,
                    ),
                    maxLines: 10,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
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
                'description': descController.text.trim(),
                'code': codeController.text,
                'runtime': runtime,
              }),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result['name']?.isEmpty == true) return;

    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.functions.create(
        name: result['name'],
        code: result['code'],
        description: result['description']?.isNotEmpty == true ? result['description'] : null,
        runtime: result['runtime'],
      );
      await _fetchFunctions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Function created!'),
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

  Future<void> _testFunction(CloudFunction function) async {
    final dataController = TextEditingController(text: '{}');

    final testData = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Test ${function.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter test data (JSON):'),
            const SizedBox(height: 12),
            TextFormField(
              controller: dataController,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '{"key": "value"}',
              ),
              maxLines: 5,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(dataController.text),
            child: const Text('Test'),
          ),
        ],
      ),
    );

    if (testData == null) return;

    setState(() => _loading = true);
    try {
      Map<String, dynamic>? data;
      if (testData.trim().isNotEmpty && testData.trim() != '{}') {
        data = jsonDecode(testData) as Map<String, dynamic>;
      }

      final result = await ScsExampleApp.scs!.functions.test(function.id, data: data);
      setState(() => _lastResult = result);
      _tabController.animateTo(0); // Switch to Invoke tab

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success ? 'Test passed!' : 'Test failed'),
            backgroundColor: result.success ? Colors.green : Colors.red,
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

  Future<void> _deleteFunction(CloudFunction function) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Function'),
        content: Text('Are you sure you want to delete "${function.name}"?'),
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

    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.functions.delete(function.id);
      await _fetchFunctions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Function deleted'),
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

  Future<void> _clearLogs(CloudFunction function) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: Text('Clear all logs for "${function.name}"?'),
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
      await ScsExampleApp.scs!.functions.clearLogs(function.id);
      setState(() => _logs = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logs cleared'),
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

  void _showFunctionDetails(CloudFunction function) {
    setState(() => _selectedFunction = function);
    _fetchLogs(function.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      function.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deleteFunction(function);
                    },
                    color: Colors.red,
                  ),
                ],
              ),
              if (function.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  function.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 16),
              _buildDetailRow('ID', function.id),
              _buildDetailRow('Runtime', function.runtime),
              if (function.createdAt != null)
                _buildDetailRow('Created', _formatDateTime(function.createdAt!)),
              if (function.updatedAt != null)
                _buildDetailRow('Updated', _formatDateTime(function.updatedAt!)),
              if (function.environment != null && function.environment!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Environment Variables:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...function.environment!.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('${e.key}: ${e.value}'),
                    )),
              ],
              if (function.code != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Code:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    function.code!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _functionNameController.text = function.name;
                        _tabController.animateTo(0);
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Invoke'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _testFunction(function);
                      },
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Test'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _getLogColor(String level) {
    switch (level.toLowerCase()) {
      case 'error':
        return Colors.red;
      case 'warn':
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      case 'debug':
        return Colors.grey;
      default:
        return Colors.black87;
    }
  }

  IconData _getLogIcon(String level) {
    switch (level.toLowerCase()) {
      case 'error':
        return Icons.error;
      case 'warn':
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      case 'debug':
        return Icons.bug_report;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Functions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createFunction,
            tooltip: 'Create Function',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchFunctions();
              _fetchStats();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.play_arrow), text: 'Invoke'),
            Tab(icon: Icon(Icons.list), text: 'Functions'),
            Tab(icon: Icon(Icons.article), text: 'Logs'),
            Tab(icon: Icon(Icons.analytics), text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInvokeTab(),
          _buildFunctionsTab(),
          _buildLogsTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildInvokeTab() {
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
                    'Call Function',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _functionNameController,
                    decoration: const InputDecoration(
                      labelText: 'Function Name',
                      prefixIcon: Icon(Icons.functions),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dataController,
                    decoration: const InputDecoration(
                      labelText: 'Data (JSON)',
                      prefixIcon: Icon(Icons.data_object),
                      hintText: '{"key": "value"}',
                      isDense: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _callFunction,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('Execute'),
                  ),
                ],
              ),
            ),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _lastResult!.success ? Icons.check_circle : Icons.error,
                          color: _lastResult!.success ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Result',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        if (_lastResult!.executionTime != null)
                          Chip(
                            label: Text('${_lastResult!.executionTime}ms'),
                            labelStyle: const TextStyle(fontSize: 10),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _lastResult!.data != null
                            ? const JsonEncoder.withIndent('  ').convert(_lastResult!.data)
                            : _lastResult!.error ?? 'No data',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: _lastResult!.success ? null : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Quick access to functions
          if (_functions.isNotEmpty) ...[
            Text(
              'Quick Select',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _functions.map((f) {
                return ActionChip(
                  label: Text(f.name),
                  avatar: const Icon(Icons.functions, size: 18),
                  onPressed: () {
                    _functionNameController.text = f.name;
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFunctionsTab() {
    if (_functions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.functions,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No functions available',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first function',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _createFunction,
              icon: const Icon(Icons.add),
              label: const Text('Create Function'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFunctions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _functions.length,
        itemBuilder: (context, index) {
          final function = _functions[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: const Icon(Icons.code),
              ),
              title: Text(function.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    function.description ?? 'No description',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Chip(
                        label: Text(function.runtime),
                        labelStyle: const TextStyle(fontSize: 10),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      if (function.updatedAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Updated: ${_formatDateTime(function.updatedAt!)}',
                          style: Theme.of(context).textTheme.bodySmall,
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
                      _functionNameController.text = function.name;
                      _tabController.animateTo(0);
                    },
                    tooltip: 'Invoke',
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => _showFunctionDetails(function),
                    tooltip: 'Details',
                  ),
                ],
              ),
              isThreeLine: true,
              onTap: () => _showFunctionDetails(function),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        // Function selector
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<CloudFunction>(
                      initialValue: _selectedFunction,
                      decoration: const InputDecoration(
                        labelText: 'Select Function',
                        isDense: true,
                        prefixIcon: Icon(Icons.functions),
                      ),
                      items: _functions.map((f) {
                        return DropdownMenuItem(
                          value: f,
                          child: Text(f.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedFunction = value);
                          _fetchLogs(value.id);
                        }
                      },
                    ),
                  ),
                  if (_selectedFunction != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _fetchLogs(_selectedFunction!.id),
                      tooltip: 'Refresh Logs',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _clearLogs(_selectedFunction!),
                      tooltip: 'Clear Logs',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _selectedFunction == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select a function to view logs',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : _logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No logs for ${_selectedFunction!.name}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              _getLogIcon(log.level),
                              color: _getLogColor(log.level),
                            ),
                            title: Text(
                              log.message,
                              style: TextStyle(
                                color: _getLogColor(log.level),
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Chip(
                                  label: Text(log.level.toUpperCase()),
                                  labelStyle: TextStyle(
                                    fontSize: 10,
                                    color: _getLogColor(log.level),
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: _getLogColor(log.level).withValues(alpha: 0.1),
                                ),
                                if (log.timestamp != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDateTime(log.timestamp!),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                            onTap: log.metadata != null
                                ? () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Log Metadata'),
                                        content: SelectableText(
                                          const JsonEncoder.withIndent('  ')
                                              .convert(log.metadata),
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
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
                                : null,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_stats.isNotEmpty) ...[
            Text(
              'Functions Statistics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: _stats.entries.map((e) => _buildStatCard(e.key, e.value)).toList(),
            ),
          ] else ...[
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
          ],
          const SizedBox(height: 24),
          Text(
            'Functions Summary',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.functions),
                      const SizedBox(width: 8),
                      Text(
                        '${_functions.length} functions deployed',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildRuntimeChip('nodejs18'),
                      _buildRuntimeChip('nodejs20'),
                      _buildRuntimeChip('python3'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Available Features',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            'Invoke Functions',
            'Call deployed functions with custom data',
            Icons.play_arrow,
          ),
          _buildFeatureCard(
            'Test Functions',
            'Test functions before deployment',
            Icons.bug_report,
          ),
          _buildFeatureCard(
            'View Logs',
            'Monitor function execution logs',
            Icons.article,
          ),
          _buildFeatureCard(
            'HttpsCallable',
            'Use callable references for type-safe invocation',
            Icons.code,
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeChip(String runtime) {
    final count = _functions.where((f) => f.runtime == runtime).length;
    return Chip(
      label: Text('$runtime: $count'),
      avatar: Icon(
        runtime.startsWith('node') ? Icons.javascript : Icons.code,
        size: 18,
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
