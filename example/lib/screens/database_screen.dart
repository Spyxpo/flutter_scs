import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';

import '../main.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _collectionController = TextEditingController(text: 'tasks');
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _queryFieldController = TextEditingController();
  final _queryValueController = TextEditingController();
  List<ScsDocument> _documents = [];
  List<String> _collections = [];
  bool _loading = false;
  String _selectedOperator = '==';
  int _limit = 20;
  int _skip = 0;
  String? _orderByField;
  bool _orderDescending = true;

  final List<String> _operators = [
    '==',
    '!=',
    '<',
    '<=',
    '>',
    '>=',
    'contains',
    'in',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchDocuments();
    _fetchCollections();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _collectionController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _queryFieldController.dispose();
    _queryValueController.dispose();
    super.dispose();
  }

  String get _collectionName => _collectionController.text.trim().isEmpty
      ? 'tasks'
      : _collectionController.text.trim();

  Future<void> _fetchCollections() async {
    try {
      final collections = await ScsExampleApp.scs!.database.listCollections();
      setState(() => _collections = collections);
    } catch (e) {
      // Ignore errors for collection listing
    }
  }

  Future<void> _fetchDocuments() async {
    setState(() => _loading = true);
    try {
      var query = ScsExampleApp.scs!.database.collection(_collectionName);

      if (_orderByField != null && _orderByField!.isNotEmpty) {
        query = _orderDescending
            ? query.orderByDesc(_orderByField!)
            : query.orderByAsc(_orderByField!);
      }

      query = query.limit(_limit);
      if (_skip > 0) {
        query = query.skip(_skip);
      }

      final snapshot = await query.get();
      setState(() => _documents = snapshot.docs);
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

  Future<void> _addDocument() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.database.collection(_collectionName).add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'completed': false,
        'priority': 'medium',
        'tags': ['general'],
        'createdAt': DateTime.now().toIso8601String(),
      });
      _titleController.clear();
      _descriptionController.clear();
      await _fetchDocuments();
      await _fetchCollections();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document added successfully!'),
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

  Future<void> _updateDocument(ScsDocument doc) async {
    final completed = doc.get<bool>('completed') ?? false;
    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.database
          .collection(_collectionName)
          .doc(doc.id)
          .update({'completed': !completed});
      await _fetchDocuments();
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

  Future<void> _deleteDocument(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
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
      await ScsExampleApp.scs!.database
          .collection(_collectionName)
          .doc(docId)
          .delete();
      await _fetchDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted!'),
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

  Future<void> _runCustomQuery() async {
    final field = _queryFieldController.text.trim();
    final value = _queryValueController.text.trim();

    if (field.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a field name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      var query = ScsExampleApp.scs!.database.collection(_collectionName);

      // Parse value based on type
      dynamic parsedValue = value;
      if (value.toLowerCase() == 'true') {
        parsedValue = true;
      } else if (value.toLowerCase() == 'false') {
        parsedValue = false;
      } else if (double.tryParse(value) != null) {
        parsedValue = double.parse(value);
      } else if (_selectedOperator == 'in' && value.startsWith('[')) {
        try {
          parsedValue = jsonDecode(value);
        } catch (_) {
          parsedValue = value.split(',').map((e) => e.trim()).toList();
        }
      }

      switch (_selectedOperator) {
        case '==':
          query = query.whereEqualTo(field, parsedValue);
          break;
        case '!=':
          query = query.whereNotEqualTo(field, parsedValue);
          break;
        case '<':
          query = query.whereLessThan(field, parsedValue);
          break;
        case '<=':
          query = query.whereLessThanOrEqualTo(field, parsedValue);
          break;
        case '>':
          query = query.whereGreaterThan(field, parsedValue);
          break;
        case '>=':
          query = query.whereGreaterThanOrEqualTo(field, parsedValue);
          break;
        case 'contains':
          query = query.whereArrayContains(field, parsedValue);
          break;
        case 'in':
          if (parsedValue is List) {
            query = query.whereIn(field, parsedValue);
          }
          break;
      }

      if (_orderByField != null && _orderByField!.isNotEmpty) {
        query = _orderDescending
            ? query.orderByDesc(_orderByField!)
            : query.orderByAsc(_orderByField!);
      }

      query = query.limit(_limit);
      final snapshot = await query.get();
      setState(() => _documents = snapshot.docs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${snapshot.size} documents'),
            backgroundColor: Colors.blue,
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

  Future<void> _createCollection() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Create Collection'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Collection Name',
              hintText: 'e.g., users, products, orders',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    try {
      await ScsExampleApp.scs!.database.createCollection(name);
      await _fetchCollections();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Collection "$name" created!'),
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

  Future<void> _deleteCollection(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Text('Are you sure you want to delete "$name" and all its documents?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ScsExampleApp.scs!.database.deleteCollection(name);
      await _fetchCollections();
      if (_collectionName == name) {
        _collectionController.text = 'tasks';
        await _fetchDocuments();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Collection "$name" deleted!'),
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

  void _showDocumentDetails(ScsDocument doc) {
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
                doc.get<String>('title') ?? 'Untitled',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildDetailRow('ID', doc.id),
              _buildDetailRow('Collection', _collectionName),
              _buildDetailRow('Path', doc.collectionPath ?? _collectionName),
              const Divider(height: 24),
              Text(
                'All Fields',
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
                  const JsonEncoder.withIndent('  ').convert(doc.data),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _updateDocument(doc);
                      },
                      icon: Icon(
                        (doc.get<bool>('completed') ?? false)
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                      ),
                      label: Text(
                        (doc.get<bool>('completed') ?? false)
                            ? 'Mark Incomplete'
                            : 'Mark Complete',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _deleteDocument(doc.id);
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
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

  void _showEditDialog(ScsDocument doc) async {
    final titleController = TextEditingController(text: doc.get<String>('title') ?? '');
    final descController = TextEditingController(text: doc.get<String>('description') ?? '');
    final priority = doc.get<String>('priority') ?? 'medium';
    String selectedPriority = priority;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Document'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedPriority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedPriority = value);
                    }
                  },
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
                'title': titleController.text.trim(),
                'description': descController.text.trim(),
                'priority': selectedPriority,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.database
          .collection(_collectionName)
          .doc(doc.id)
          .update(result);
      await _fetchDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document updated!'),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: _createCollection,
            tooltip: 'Create Collection',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchDocuments();
              _fetchCollections();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Documents', icon: Icon(Icons.description)),
            Tab(text: 'Query', icon: Icon(Icons.search)),
            Tab(text: 'Collections', icon: Icon(Icons.folder)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDocumentsTab(),
          _buildQueryTab(),
          _buildCollectionsTab(),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
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
                  'Add New Document',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _collectionController,
                  decoration: const InputDecoration(
                    labelText: 'Collection Name',
                    prefixIcon: Icon(Icons.folder_outlined),
                    isDense: true,
                  ),
                  onChanged: (_) => _fetchDocuments(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_outlined),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _addDocument,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Document'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Documents (${_documents.length})',
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
          child: _documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No documents found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    final title = doc.get<String>('title') ?? 'Untitled';
                    final description = doc.get<String>('description') ?? '';
                    final completed = doc.get<bool>('completed') ?? false;
                    final priority = doc.get<String>('priority') ?? 'medium';

                    return Card(
                      child: ListTile(
                        leading: Checkbox(
                          value: completed,
                          onChanged: (_) => _updateDocument(doc),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            decoration:
                                completed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (description.isNotEmpty) Text(description),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: priority == 'high'
                                        ? Colors.red.shade100
                                        : priority == 'low'
                                            ? Colors.green.shade100
                                            : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    priority.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: priority == 'high'
                                          ? Colors.red.shade700
                                          : priority == 'low'
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'ID: ${doc.id.substring(0, 8)}...',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showEditDialog(doc),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteDocument(doc.id),
                            ),
                          ],
                        ),
                        onTap: () => _showDocumentDetails(doc),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildQueryTab() {
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
                    'Query Builder',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _queryFieldController,
                          decoration: const InputDecoration(
                            labelText: 'Field',
                            hintText: 'e.g., completed',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _selectedOperator,
                        items: _operators.map((op) {
                          return DropdownMenuItem(value: op, child: Text(op));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedOperator = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _queryValueController,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      hintText: 'e.g., true, 10, "text"',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Order By',
                            hintText: 'e.g., createdAt',
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() => _orderByField = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('DESC'),
                        selected: _orderDescending,
                        onSelected: (value) {
                          setState(() => _orderDescending = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Limit',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: '$_limit',
                          onChanged: (value) {
                            setState(() => _limit = int.tryParse(value) ?? 20);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Skip',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: '$_skip',
                          onChanged: (value) {
                            setState(() => _skip = int.tryParse(value) ?? 0);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _queryFieldController.clear();
                            _queryValueController.clear();
                            setState(() {
                              _selectedOperator = '==';
                              _orderByField = null;
                              _orderDescending = true;
                              _limit = 20;
                              _skip = 0;
                            });
                            _fetchDocuments();
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _runCustomQuery,
                          icon: const Icon(Icons.search),
                          label: const Text('Run Query'),
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
                  Text(
                    'Query Examples',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildQueryExample(
                    'Find completed tasks',
                    'completed == true',
                    () {
                      _queryFieldController.text = 'completed';
                      _queryValueController.text = 'true';
                      setState(() => _selectedOperator = '==');
                    },
                  ),
                  _buildQueryExample(
                    'Find high priority',
                    'priority == high',
                    () {
                      _queryFieldController.text = 'priority';
                      _queryValueController.text = 'high';
                      setState(() => _selectedOperator = '==');
                    },
                  ),
                  _buildQueryExample(
                    'Find tasks with tag',
                    'tags contains general',
                    () {
                      _queryFieldController.text = 'tags';
                      _queryValueController.text = 'general';
                      setState(() => _selectedOperator = 'contains');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Results (${_documents.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (_documents.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No results',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            )
          else
            ...List.generate(_documents.length, (index) {
              final doc = _documents[index];
              return Card(
                child: ListTile(
                  title: Text(doc.get<String>('title') ?? doc.id),
                  subtitle: Text('ID: ${doc.id}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDocumentDetails(doc),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildQueryExample(String title, String query, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(query, style: const TextStyle(fontFamily: 'monospace')),
      trailing: IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildCollectionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Collections (${_collections.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _createCollection,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _collections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No collections',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _collections.length,
                  itemBuilder: (context, index) {
                    final collection = _collections[index];
                    final isSelected = collection == _collectionName;
                    return ListTile(
                      leading: Icon(
                        Icons.folder,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        collection,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                      selected: isSelected,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () {
                              _collectionController.text = collection;
                              _fetchDocuments();
                              _tabController.animateTo(0);
                            },
                            tooltip: 'Open',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteCollection(collection),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                      onTap: () {
                        _collectionController.text = collection;
                        _fetchDocuments();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
