import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';

import '../main.dart';

class RemoteConfigScreen extends StatefulWidget {
  const RemoteConfigScreen({super.key});

  @override
  State<RemoteConfigScreen> createState() => _RemoteConfigScreenState();
}

class _RemoteConfigScreenState extends State<RemoteConfigScreen> {
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();
  List<ConfigParameter> _parameters = [];
  bool _loading = false;
  String _selectedType = 'string';
  DateTime? _lastFetch;

  @override
  void initState() {
    super.initState();
    _fetchConfig();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _fetchConfig() async {
    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.remoteConfig.fetchAndActivate();
      final parameters = await ScsExampleApp.scs!.remoteConfig.getAll();
      setState(() {
        _parameters = parameters;
        _lastFetch = ScsExampleApp.scs!.remoteConfig.lastFetchTime;
      });
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

  Future<void> _setParameter() async {
    final key = _keyController.text.trim();
    final value = _valueController.text.trim();

    if (key.isEmpty || value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter key and value'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      dynamic parsedValue = value;
      if (_selectedType == 'number') {
        parsedValue = double.tryParse(value) ?? int.tryParse(value) ?? value;
      } else if (_selectedType == 'boolean') {
        parsedValue = value.toLowerCase() == 'true';
      }

      await ScsExampleApp.scs!.remoteConfig.setParameter(
        key: key,
        value: parsedValue,
        type: _selectedType,
      );
      _keyController.clear();
      _valueController.clear();
      await _fetchConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parameter saved!'),
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

  Future<void> _deleteParameter(String key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Parameter'),
        content: Text('Are you sure you want to delete "$key"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.remoteConfig.deleteParameter(key);
      await _fetchConfig();
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

  Future<void> _publishConfig() async {
    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.remoteConfig.publish();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration published!'),
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

  void _showGetValueDialog() {
    final keyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Get Value'),
        content: TextFormField(
          controller: keyController,
          decoration: const InputDecoration(
            labelText: 'Key',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final key = keyController.text.trim();
              if (key.isEmpty) return;

              Navigator.of(context).pop();

              final value =
                  ScsExampleApp.scs!.remoteConfig.getValue<dynamic>(key);
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(key),
                    content: Text('Value: $value'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('Get'),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'string':
        return Icons.text_fields;
      case 'number':
        return Icons.numbers;
      case 'boolean':
        return Icons.toggle_on;
      case 'json':
        return Icons.data_object;
      default:
        return Icons.settings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Config'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showGetValueDialog,
            tooltip: 'Get Value',
          ),
          IconButton(
            icon: const Icon(Icons.publish),
            onPressed: _publishConfig,
            tooltip: 'Publish',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchConfig,
            tooltip: 'Fetch & Activate',
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add Parameter',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _keyController,
                          decoration: const InputDecoration(
                            labelText: 'Key',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedType,
                        items: const [
                          DropdownMenuItem(
                              value: 'string', child: Text('String')),
                          DropdownMenuItem(
                              value: 'number', child: Text('Number')),
                          DropdownMenuItem(
                              value: 'boolean', child: Text('Boolean')),
                          DropdownMenuItem(value: 'json', child: Text('JSON')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedType = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _valueController,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _setParameter,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Parameter'),
                  ),
                ],
              ),
            ),
          ),
          if (_lastFetch != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Last fetch: ${_lastFetch!.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Parameters (${_parameters.length})',
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
          ),
          const Divider(),
          Expanded(
            child: _parameters.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No parameters',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _parameters.length,
                    itemBuilder: (context, index) {
                      final param = _parameters[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(_getTypeIcon(param.type)),
                          title: Text(param.key),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${param.value}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Type: ${param.type ?? 'unknown'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteParameter(param.key),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
