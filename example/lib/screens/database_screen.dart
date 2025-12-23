import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';

import '../main.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  final _collectionController = TextEditingController(text: 'tasks');
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<ScsDocument> _documents = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  @override
  void dispose() {
    _collectionController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String get _collectionName => _collectionController.text.trim().isEmpty
      ? 'tasks'
      : _collectionController.text.trim();

  Future<void> _fetchDocuments() async {
    setState(() => _loading = true);
    try {
      final snapshot =
          await ScsExampleApp.scs!.database.collection(_collectionName).get();
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
        'createdAt': DateTime.now().toIso8601String(),
      });
      _titleController.clear();
      _descriptionController.clear();
      await _fetchDocuments();
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

  void _showDocumentDetails(ScsDocument doc) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doc.get<String>('title') ?? 'Untitled',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _buildDetailRow('ID', doc.id),
            _buildDetailRow('Collection', _collectionName),
            if (doc.get<String>('description')?.isNotEmpty ?? false)
              _buildDetailRow('Description', doc.get<String>('description')!),
            _buildDetailRow(
              'Completed',
              (doc.get<bool>('completed') ?? false) ? 'Yes' : 'No',
            ),
            if (doc.get<String>('createdAt') != null)
              _buildDetailRow('Created', doc.get<String>('createdAt')!),
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
    );
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

  Future<void> _queryDocuments() async {
    setState(() => _loading = true);
    try {
      final snapshot = await ScsExampleApp.scs!.database
          .collection(_collectionName)
          .whereEqualTo('completed', true)
          .orderByDesc('createdAt')
          .limit(10)
          .get();
      setState(() => _documents = snapshot.docs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${snapshot.size} completed tasks'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _queryDocuments,
            tooltip: 'Show Completed Only',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDocuments,
            tooltip: 'Refresh',
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

                      return Card(
                        child: ListTile(
                          leading: Checkbox(
                            value: completed,
                            onChanged: (_) => _updateDocument(doc),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              decoration: completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (description.isNotEmpty) Text(description),
                              Text(
                                'ID: ${doc.id}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteDocument(doc.id),
                          ),
                          onTap: () => _showDocumentDetails(doc),
                          isThreeLine: description.isNotEmpty,
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
