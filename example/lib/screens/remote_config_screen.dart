import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';

import '../main.dart';

class RemoteConfigScreen extends StatefulWidget {
  const RemoteConfigScreen({super.key});

  @override
  State<RemoteConfigScreen> createState() => _RemoteConfigScreenState();
}

class _RemoteConfigScreenState extends State<RemoteConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<ConfigParameter> _parameters = [];
  List<ConfigVersion> _versions = [];
  Map<String, dynamic> _stats = {};
  bool _loading = false;
  String _selectedType = 'string';
  DateTime? _lastFetch;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchConfig();
    _fetchVersions();
    _fetchStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keyController.dispose();
    _valueController.dispose();
    _descriptionController.dispose();
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

  Future<void> _fetchVersions() async {
    try {
      final versions = await ScsExampleApp.scs!.remoteConfig.getVersions();
      setState(() => _versions = versions);
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await ScsExampleApp.scs!.remoteConfig.getStats();
      setState(() => _stats = stats);
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _setParameter() async {
    final key = _keyController.text.trim();
    final value = _valueController.text.trim();
    final description = _descriptionController.text.trim();

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
      } else if (_selectedType == 'json') {
        // Keep as string for JSON
        parsedValue = value;
      }

      await ScsExampleApp.scs!.remoteConfig.setParameter(
        key: key,
        value: parsedValue,
        type: _selectedType,
        description: description.isNotEmpty ? description : null,
      );
      _keyController.clear();
      _valueController.clear();
      _descriptionController.clear();
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

  Future<void> _updateParameter(ConfigParameter param) async {
    final keyController = TextEditingController(text: param.key);
    final valueController = TextEditingController(text: param.value?.toString() ?? '');
    final descController = TextEditingController(text: param.description ?? '');
    String selectedType = param.type ?? 'string';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Parameter'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    isDense: true,
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'string', child: Text('String')),
                    DropdownMenuItem(value: 'number', child: Text('Number')),
                    DropdownMenuItem(value: 'boolean', child: Text('Boolean')),
                    DropdownMenuItem(value: 'json', child: Text('JSON')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: valueController,
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    isDense: true,
                  ),
                  maxLines: selectedType == 'json' ? 5 : 1,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    isDense: true,
                  ),
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
                'value': valueController.text.trim(),
                'type': selectedType,
                'description': descController.text.trim(),
              }),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    setState(() => _loading = true);
    try {
      dynamic parsedValue = result['value'];
      if (result['type'] == 'number') {
        parsedValue = double.tryParse(parsedValue) ?? int.tryParse(parsedValue) ?? parsedValue;
      } else if (result['type'] == 'boolean') {
        parsedValue = parsedValue.toString().toLowerCase() == 'true';
      }

      await ScsExampleApp.scs!.remoteConfig.updateParameter(
        key: param.key,
        value: parsedValue,
        type: result['type'],
        description: result['description']?.isNotEmpty == true ? result['description'] : null,
      );
      await _fetchConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parameter updated!'),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Config'),
        content: const Text(
          'This will create a new version with the current parameters. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final version = await ScsExampleApp.scs!.remoteConfig.publish();
      await _fetchVersions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Published as version ${version.versionNumber}!'),
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

  Future<void> _rollbackToVersion(ConfigVersion version) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rollback Config'),
        content: Text(
          'Are you sure you want to rollback to version ${version.versionNumber}?\n\nThis will restore all parameters from that version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Rollback'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.remoteConfig.rollback(version.id);
      await _fetchConfig();
      await _fetchVersions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rolled back to version ${version.versionNumber}!'),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Key',
                isDense: true,
                hintText: 'Enter parameter key',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Test getValue with type conversion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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

              final value = ScsExampleApp.scs!.remoteConfig.getValue<dynamic>(key);
              final stringValue = ScsExampleApp.scs!.remoteConfig.getString(key);
              final intValue = ScsExampleApp.scs!.remoteConfig.getInt(key);
              final doubleValue = ScsExampleApp.scs!.remoteConfig.getDouble(key);
              final boolValue = ScsExampleApp.scs!.remoteConfig.getBool(key);

              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(key),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildValueRow('Raw', value),
                        _buildValueRow('String', stringValue),
                        _buildValueRow('Int', intValue),
                        _buildValueRow('Double', doubleValue),
                        _buildValueRow('Bool', boolValue),
                      ],
                    ),
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

  Widget _buildValueRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              '$value',
              style: TextStyle(
                color: value != null && value != '' && value != 0 && value != 0.0 && value != false
                    ? Colors.green
                    : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVersionDetails(ConfigVersion version) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Version ${version.versionNumber}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${version.id}'),
                if (version.createdAt != null)
                  Text('Created: ${_formatDateTime(version.createdAt!)}'),
                const SizedBox(height: 16),
                const Text(
                  'Parameters:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (version.parameters != null && version.parameters!.isNotEmpty)
                  ...version.parameters!.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${e.key}: ${e.value}'),
                      ))
                else
                  const Text('No parameters in this version'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _rollbackToVersion(version);
            },
            child: const Text('Rollback to this version'),
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

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
            onPressed: () {
              _fetchConfig();
              _fetchVersions();
              _fetchStats();
            },
            tooltip: 'Refresh All',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'Parameters'),
            Tab(icon: Icon(Icons.history), text: 'Versions'),
            Tab(icon: Icon(Icons.analytics), text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildParametersTab(),
          _buildVersionsTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildParametersTab() {
    return Column(
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
                        DropdownMenuItem(value: 'string', child: Text('String')),
                        DropdownMenuItem(value: 'number', child: Text('Number')),
                        DropdownMenuItem(value: 'boolean', child: Text('Boolean')),
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
                  maxLines: _selectedType == 'json' ? 3 : 1,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
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
            child: Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Last fetch: ${_formatDateTime(_lastFetch!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
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
                      const SizedBox(height: 8),
                      Text(
                        'Add your first config parameter above',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
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
                        leading: CircleAvatar(
                          child: Icon(_getTypeIcon(param.type)),
                        ),
                        title: Text(param.key),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${param.value}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Chip(
                                  label: Text(param.type ?? 'unknown'),
                                  labelStyle: const TextStyle(fontSize: 10),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (param.description != null) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      param.description!,
                                      style: Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _updateParameter(param),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteParameter(param.key),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVersionsTab() {
    return _versions.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No versions yet',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Publish your config to create a version',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _publishConfig,
                  icon: const Icon(Icons.publish),
                  label: const Text('Publish Now'),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _versions.length,
            itemBuilder: (context, index) {
              final version = _versions[index];
              final isLatest = index == 0;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isLatest
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    child: Text(
                      'v${version.versionNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isLatest ? Colors.white : null,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text('Version ${version.versionNumber}'),
                      if (isLatest) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: const Text('Latest'),
                          labelStyle: const TextStyle(fontSize: 10),
                          backgroundColor: Colors.green.shade100,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (version.createdAt != null)
                        Text('Created: ${_formatDateTime(version.createdAt!)}'),
                      Text(
                        '${version.parameters?.length ?? 0} parameters',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () => _showVersionDetails(version),
                        tooltip: 'View Details',
                      ),
                      if (!isLatest)
                        IconButton(
                          icon: const Icon(Icons.restore),
                          onPressed: () => _rollbackToVersion(version),
                          tooltip: 'Rollback',
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () => _showVersionDetails(version),
                ),
              );
            },
          );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          if (_stats.isNotEmpty) ...[
            Text(
              'Configuration Statistics',
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
          // Cached parameters info
          Text(
            'Cached Parameters',
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
                      const Icon(Icons.cached),
                      const SizedBox(width: 8),
                      Text(
                        '${ScsExampleApp.scs!.remoteConfig.cachedParameters.length} cached parameters',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  if (_lastFetch != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Cache updated: ${_formatDateTime(_lastFetch!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Features info
          Text(
            'Available Features',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            'Type Conversion',
            'Automatic conversion between string, int, double, and bool',
            Icons.swap_horiz,
          ),
          _buildFeatureCard(
            'Versioning',
            'Track and rollback to previous configuration versions',
            Icons.history,
          ),
          _buildFeatureCard(
            'Caching',
            'Local cache for instant access to config values',
            Icons.cached,
          ),
          _buildFeatureCard(
            'Publish',
            'Create snapshots of your configuration',
            Icons.publish,
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
