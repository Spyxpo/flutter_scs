import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';

import '../main.dart';

/// EaZI Database screen with full CRUD operations.
///
/// EaZI is a document-based NoSQL database optimized for
/// rapid development and prototyping.
class EaziDatabaseScreen extends StatefulWidget {
  const EaziDatabaseScreen({super.key});

  @override
  State<EaziDatabaseScreen> createState() => _EaziDatabaseScreenState();
}

class _EaziDatabaseScreenState extends State<EaziDatabaseScreen> {
  final _collectionController = TextEditingController(text: 'eazi_notes');
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  List<ScsDocument> _documents = [];
  bool _loading = false;
  String? _selectedCategory = 'all';

  final List<String> _categories = ['all', 'personal', 'work', 'ideas', 'archive'];

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  @override
  void dispose() {
    _collectionController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  String get _collectionName => _collectionController.text.trim().isEmpty
      ? 'eazi_notes'
      : _collectionController.text.trim();

  Future<void> _fetchDocuments() async {
    setState(() => _loading = true);
    try {
      var query = ScsExampleApp.scs!.database.collection(_collectionName);

      if (_selectedCategory != null && _selectedCategory != 'all') {
        query = query.whereEqualTo('category', _selectedCategory);
      }

      query = query.orderByDesc('createdAt').limit(50);

      final snapshot = await query.get();
      setState(() => _documents = snapshot.docs);
    } on ScsException catch (e) {
      if (mounted) {
        _showSnackBar(e.message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createDocument() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a title', isWarning: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final tags = _tagsController.text.trim().isEmpty
          ? <String>[]
          : _tagsController.text.split(',').map((e) => e.trim()).toList();

      await ScsExampleApp.scs!.database.collection(_collectionName).add({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category': _selectedCategory == 'all' ? 'personal' : _selectedCategory,
        'tags': tags,
        'isPinned': false,
        'color': '#FFFFFF',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _titleController.clear();
      _contentController.clear();
      _tagsController.clear();
      await _fetchDocuments();

      if (mounted) {
        _showSnackBar('Note created successfully!');
      }
    } on ScsException catch (e) {
      if (mounted) {
        _showSnackBar(e.message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateDocument(ScsDocument doc, Map<String, dynamic> updates) async {
    setState(() => _loading = true);
    try {
      updates['updatedAt'] = DateTime.now().toIso8601String();
      await ScsExampleApp.scs!.database
          .collection(_collectionName)
          .doc(doc.id)
          .update(updates);
      await _fetchDocuments();
      if (mounted) {
        _showSnackBar('Note updated!');
      }
    } on ScsException catch (e) {
      if (mounted) {
        _showSnackBar(e.message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteDocument(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
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

    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.database
          .collection(_collectionName)
          .doc(docId)
          .delete();
      await _fetchDocuments();
      if (mounted) {
        _showSnackBar('Note deleted!');
      }
    } on ScsException catch (e) {
      if (mounted) {
        _showSnackBar(e.message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false, bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red
            : isWarning
                ? Colors.orange
                : Colors.green,
      ),
    );
  }

  void _showEditDialog(ScsDocument doc) async {
    final titleController = TextEditingController(text: doc.get<String>('title') ?? '');
    final contentController = TextEditingController(text: doc.get<String>('content') ?? '');
    final category = doc.get<String>('category') ?? 'personal';
    String selectedCategory = category;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Note'),
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
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Content'),
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .where((c) => c != 'all')
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c[0].toUpperCase() + c.substring(1)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCategory = value);
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
                'content': contentController.text.trim(),
                'category': selectedCategory,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _updateDocument(doc, result);
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.get<String>('title') ?? 'Untitled',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (doc.get<bool>('isPinned') == true)
                    const Icon(Icons.push_pin, color: Colors.blue),
                ],
              ),
              const SizedBox(height: 8),
              _buildCategoryChip(doc.get<String>('category') ?? 'personal'),
              const SizedBox(height: 16),
              if ((doc.get<String>('content') ?? '').isNotEmpty) ...[
                Text(
                  doc.get<String>('content')!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
              ],
              const Divider(),
              _buildInfoRow('ID', doc.id),
              _buildInfoRow('Created', _formatDate(doc.get<String>('createdAt'))),
              _buildInfoRow('Updated', _formatDate(doc.get<String>('updatedAt'))),
              if ((doc.get<List>('tags') ?? []).isNotEmpty)
                _buildInfoRow('Tags', (doc.get<List>('tags') as List).join(', ')),
              const SizedBox(height: 16),
              const Text('Raw Data', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showEditDialog(doc);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _updateDocument(doc, {'isPinned': !(doc.get<bool>('isPinned') ?? false)});
                      },
                      icon: Icon(
                        doc.get<bool>('isPinned') == true ? Icons.push_pin : Icons.push_pin_outlined,
                      ),
                      label: Text(doc.get<bool>('isPinned') == true ? 'Unpin' : 'Pin'),
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

  Widget _buildCategoryChip(String category) {
    final colors = {
      'personal': Colors.blue,
      'work': Colors.orange,
      'ideas': Colors.purple,
      'archive': Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (colors[category] ?? Colors.blue).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors[category] ?? Colors.blue),
      ),
      child: Text(
        category[0].toUpperCase() + category.substring(1),
        style: TextStyle(
          color: colors[category] ?? Colors.blue,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value ?? '-', style: TextStyle(color: Colors.grey.shade600))),
        ],
      ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '-';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eaZI Database'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDocuments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'eaZI - Document Database',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      Text(
                        'Fast NoSQL storage for rapid development',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Category filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(category[0].toUpperCase() + category.substring(1)),
                    onSelected: (selected) {
                      setState(() => _selectedCategory = category);
                      _fetchDocuments();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Create form
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Create Note', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      prefixIcon: Icon(Icons.notes),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags (comma separated)',
                      prefixIcon: Icon(Icons.label_outline),
                      isDense: true,
                      hintText: 'e.g., important, urgent',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _createDocument,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Note'),
                  ),
                ],
              ),
            ),
          ),

          // Documents list header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Notes (${_documents.length})',
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

          // Documents list
          Expanded(
            child: _documents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No notes found', style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first note above',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
                      final content = doc.get<String>('content') ?? '';
                      final category = doc.get<String>('category') ?? 'personal';
                      final isPinned = doc.get<bool>('isPinned') ?? false;

                      return Card(
                        child: ListTile(
                          leading: isPinned
                              ? const Icon(Icons.push_pin, color: Colors.blue)
                              : const Icon(Icons.note_outlined),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (content.isNotEmpty)
                                Text(
                                  content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              _buildCategoryChip(category),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _showEditDialog(doc),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => _deleteDocument(doc.id),
                              ),
                            ],
                          ),
                          onTap: () => _showDocumentDetails(doc),
                          isThreeLine: content.isNotEmpty,
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
