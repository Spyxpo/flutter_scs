import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';

import '../main.dart';

class FunctionsScreen extends StatefulWidget {
  const FunctionsScreen({super.key});

  @override
  State<FunctionsScreen> createState() => _FunctionsScreenState();
}

class _FunctionsScreenState extends State<FunctionsScreen> {
  final _functionNameController = TextEditingController();
  final _dataController = TextEditingController();
  List<CloudFunction> _functions = [];
  bool _loading = false;
  FunctionResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _fetchFunctions();
  }

  @override
  void dispose() {
    _functionNameController.dispose();
    _dataController.dispose();
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

  void _showFunctionDetails(CloudFunction function) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                function.name,
                style: Theme.of(context).textTheme.titleLarge,
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
                _buildDetailRow('Created', function.createdAt!.toString()),
              if (function.updatedAt != null)
                _buildDetailRow('Updated', function.updatedAt!.toString()),
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
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _functionNameController.text = function.name;
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Call This Function'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Functions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchFunctions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                            _lastResult!.success
                                ? Icons.check_circle
                                : Icons.error,
                            color: _lastResult!.success
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Result',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          if (_lastResult!.executionTime != null)
                            Text(
                              '${_lastResult!.executionTime}ms',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _lastResult!.data != null
                              ? const JsonEncoder.withIndent('  ')
                                  .convert(_lastResult!.data)
                              : _lastResult!.error ?? 'No data',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Available Functions (${_functions.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_functions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.functions,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No functions available',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deploy functions from the SCS dashboard',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(_functions.length, (index) {
                final function = _functions[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.code),
                    title: Text(function.name),
                    subtitle: Text(
                      function.description ?? 'No description',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => _showFunctionDetails(function),
                    ),
                    onTap: () {
                      _functionNameController.text = function.name;
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
