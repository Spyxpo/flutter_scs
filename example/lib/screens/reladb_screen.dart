import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';

import '../config.dart';

/// RelaDB screen with full CRUD operations.
///
/// RelaDB is a production-ready database optimized for
/// scalability and complex queries.
class ReladbScreen extends StatefulWidget {
  const ReladbScreen({super.key});

  @override
  State<ReladbScreen> createState() => _ReladbScreenState();
}

class _ReladbScreenState extends State<ReladbScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _collectionController = TextEditingController(text: 'reladb_products');
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _queryFieldController = TextEditingController();
  final _queryValueController = TextEditingController();

  /// SCS instance configured for RelaDB (MongoDB)
  SCS? _relaDbScs;
  bool _initialized = false;

  List<ScsDocument> _documents = [];
  bool _loading = false;
  String _selectedStatus = 'all';
  String _sortBy = 'createdAt';
  bool _sortDescending = true;
  String _selectedOperator = '==';

  final List<String> _statuses = ['all', 'active', 'draft', 'archived'];
  final List<String> _operators = ['==', '!=', '<', '<=', '>', '>=', 'contains', 'in'];

  // Preset rules for common queries
  final List<Map<String, dynamic>> _presetRules = [
    {
      'name': 'Active Products',
      'description': 'Show all active products',
      'field': 'status',
      'operator': '==',
      'value': 'active',
    },
    {
      'name': 'Low Stock Alert',
      'description': 'Products with stock less than 10',
      'field': 'stock',
      'operator': '<',
      'value': '10',
    },
    {
      'name': 'Out of Stock',
      'description': 'Products with zero stock',
      'field': 'stock',
      'operator': '==',
      'value': '0',
    },
    {
      'name': 'Premium Products',
      'description': 'Products priced above \$100',
      'field': 'price',
      'operator': '>',
      'value': '100',
    },
    {
      'name': 'Budget Products',
      'description': 'Products priced under \$50',
      'field': 'price',
      'operator': '<',
      'value': '50',
    },
    {
      'name': 'Draft Products',
      'description': 'Products in draft status',
      'field': 'status',
      'operator': '==',
      'value': 'draft',
    },
    {
      'name': 'Archived Products',
      'description': 'Products that are archived',
      'field': 'status',
      'operator': '==',
      'value': 'archived',
    },
    {
      'name': 'High Stock',
      'description': 'Products with stock over 100',
      'field': 'stock',
      'operator': '>',
      'value': '100',
    },
    {
      'name': 'Top Rated',
      'description': 'Products with rating above 4',
      'field': 'rating',
      'operator': '>=',
      'value': '4',
    },
    {
      'name': 'Best Sellers',
      'description': 'Products with sales over 50',
      'field': 'soldCount',
      'operator': '>',
      'value': '50',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeRelaDb();
  }

  Future<void> _initializeRelaDb() async {
    try {
      // Create a separate SCS instance configured for RelaDB (MongoDB)
      _relaDbScs = await SCS.initializeApp(
        ScsConfig(
          apiKey: AppConfig.apiKey,
          projectId: AppConfig.projectId,
          baseUrl: AppConfig.baseUrl,
          databaseType: ScsDatabaseType.mongodb, // Use RelaDB (MongoDB)
        ),
      );
      setState(() => _initialized = true);
      _fetchDocuments();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to initialize RelaDB: $e', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _relaDbScs?.dispose();
    _tabController.dispose();
    _collectionController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _queryFieldController.dispose();
    _queryValueController.dispose();
    super.dispose();
  }

  String get _collectionName => _collectionController.text.trim().isEmpty
      ? 'reladb_products'
      : _collectionController.text.trim();

  Future<void> _fetchDocuments() async {
    if (_relaDbScs == null) return;

    setState(() => _loading = true);
    try {
      var query = _relaDbScs!.database.collection(_collectionName);

      if (_selectedStatus != 'all') {
        query = query.whereEqualTo('status', _selectedStatus);
      }

      query = _sortDescending
          ? query.orderByDesc(_sortBy)
          : query.orderByAsc(_sortBy);

      query = query.limit(50);

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
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a product name', isWarning: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final stock = int.tryParse(_stockController.text.trim()) ?? 0;

      await _relaDbScs!.database.collection(_collectionName).add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': price,
        'stock': stock,
        'status': 'active',
        'sku': 'SKU-${DateTime.now().millisecondsSinceEpoch}',
        'rating': 0.0,
        'reviewCount': 0,
        'soldCount': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _nameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _stockController.clear();
      await _fetchDocuments();

      if (mounted) {
        _showSnackBar('Product created successfully!');
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
      await _relaDbScs!.database
          .collection(_collectionName)
          .doc(doc.id)
          .update(updates);
      await _fetchDocuments();
      if (mounted) {
        _showSnackBar('Product updated!');
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
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
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
      await _relaDbScs!.database
          .collection(_collectionName)
          .doc(docId)
          .delete();
      await _fetchDocuments();
      if (mounted) {
        _showSnackBar('Product deleted!');
      }
    } on ScsException catch (e) {
      if (mounted) {
        _showSnackBar(e.message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStock(ScsDocument doc, int delta) async {
    final currentStock = doc.get<int>('stock') ?? 0;
    final newStock = (currentStock + delta).clamp(0, 999999);
    await _updateDocument(doc, {'stock': newStock});
  }

  Future<void> _applyPresetRule(Map<String, dynamic> rule) async {
    _queryFieldController.text = rule['field'];
    _queryValueController.text = rule['value'];
    setState(() => _selectedOperator = rule['operator']);
    await _runRuleQuery();
  }

  Future<void> _runRuleQuery() async {
    final field = _queryFieldController.text.trim();
    final value = _queryValueController.text.trim();

    if (field.isEmpty) {
      _showSnackBar('Please enter a field name', isWarning: true);
      return;
    }

    setState(() => _loading = true);
    try {
      var query = _relaDbScs!.database.collection(_collectionName);

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

      query = _sortDescending
          ? query.orderByDesc(_sortBy)
          : query.orderByAsc(_sortBy);

      query = query.limit(50);
      final snapshot = await query.get();
      setState(() => _documents = snapshot.docs);

      if (mounted) {
        _showSnackBar('Found ${snapshot.size} products');
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
    final nameController = TextEditingController(text: doc.get<String>('name') ?? '');
    final descController = TextEditingController(text: doc.get<String>('description') ?? '');
    final priceController = TextEditingController(text: (doc.get<num>('price') ?? 0).toString());
    final stockController = TextEditingController(text: (doc.get<int>('stock') ?? 0).toString());
    final status = doc.get<String>('status') ?? 'active';
    String selectedStatus = status;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixText: '\$ ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: stockController,
                        decoration: const InputDecoration(labelText: 'Stock'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statuses
                      .where((s) => s != 'all')
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s[0].toUpperCase() + s.substring(1)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedStatus = value);
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
                'name': nameController.text.trim(),
                'description': descController.text.trim(),
                'price': double.tryParse(priceController.text) ?? 0.0,
                'stock': int.tryParse(stockController.text) ?? 0,
                'status': selectedStatus,
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
        initialChildSize: 0.7,
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
                      doc.get<String>('name') ?? 'Unnamed Product',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  _buildStatusChip(doc.get<String>('status') ?? 'active'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'SKU: ${doc.get<String>('sku') ?? '-'}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              if ((doc.get<String>('description') ?? '').isNotEmpty) ...[
                Text(
                  doc.get<String>('description')!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
              ],
              // Price and Stock cards
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              '\$${(doc.get<num>('price') ?? 0).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const Text('Price'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              '${doc.get<int>('stock') ?? 0}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const Text('In Stock'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stock adjustment buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _updateStock(doc, -10);
                    },
                    icon: const Text('-10'),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _updateStock(doc, -1);
                    },
                    icon: const Text('-1'),
                  ),
                  const SizedBox(width: 16),
                  const Text('Adjust Stock'),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _updateStock(doc, 1);
                    },
                    icon: const Text('+1'),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _updateStock(doc, 10);
                    },
                    icon: const Text('+10'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Rating', '${(doc.get<num>('rating') ?? 0).toStringAsFixed(1)} ★'),
                  _buildStatItem('Reviews', '${doc.get<int>('reviewCount') ?? 0}'),
                  _buildStatItem('Sold', '${doc.get<int>('soldCount') ?? 0}'),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              _buildInfoRow('ID', doc.id),
              _buildInfoRow('Created', _formatDate(doc.get<String>('createdAt'))),
              _buildInfoRow('Updated', _formatDate(doc.get<String>('updatedAt'))),
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

  Widget _buildStatusChip(String status) {
    final colors = {
      'active': Colors.green,
      'draft': Colors.orange,
      'archived': Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (colors[status] ?? Colors.green).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors[status] ?? Colors.green),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: colors[status] ?? Colors.green,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
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
    if (!_initialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('RelaDB')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing RelaDB...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('RelaDB'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (value) {
              setState(() {
                if (value == _sortBy) {
                  _sortDescending = !_sortDescending;
                } else {
                  _sortBy = value;
                  _sortDescending = true;
                }
              });
              _fetchDocuments();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'createdAt',
                child: Row(
                  children: [
                    const Text('Date Created'),
                    if (_sortBy == 'createdAt')
                      Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'price',
                child: Row(
                  children: [
                    const Text('Price'),
                    if (_sortBy == 'price')
                      Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'stock',
                child: Row(
                  children: [
                    const Text('Stock'),
                    if (_sortBy == 'stock')
                      Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    const Text('Name'),
                    if (_sortBy == 'name')
                      Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDocuments,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Products', icon: Icon(Icons.inventory_2)),
            Tab(text: 'Rules', icon: Icon(Icons.rule)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(),
          _buildRulesTab(),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    return Column(
      children: [
        // Header info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.green.withValues(alpha: 0.1),
          child: Row(
            children: [
              Icon(Icons.cloud_outlined, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RelaDB - Production Database',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    Text(
                      'Scalable database for complex queries',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Status filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: _statuses.map((status) {
              final isSelected = _selectedStatus == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(status[0].toUpperCase() + status.substring(1)),
                  onSelected: (selected) {
                    setState(() => _selectedStatus = status);
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
                Text('Add Product', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_outlined),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixIcon: Icon(Icons.attach_money),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _stockController,
                        decoration: const InputDecoration(
                          labelText: 'Stock',
                          prefixIcon: Icon(Icons.inventory),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _createDocument,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                ),
              ],
            ),
          ),
        ),

        // Products list header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Products (${_documents.length})',
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

        // Products list
        Expanded(
          child: _documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No products found', style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first product above',
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
                    final name = doc.get<String>('name') ?? 'Unnamed';
                    final price = doc.get<num>('price') ?? 0;
                    final stock = doc.get<int>('stock') ?? 0;
                    final status = doc.get<String>('status') ?? 'active';

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: stock > 0 ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(
                            Icons.inventory_2,
                            color: stock > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\$${price.toStringAsFixed(2)} • Stock: $stock',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            _buildStatusChip(status),
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
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.rule, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Query Rules',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'Select a preset rule to filter products',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Custom Query Builder
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Query',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _queryFieldController,
                          decoration: const InputDecoration(
                            labelText: 'Field',
                            hintText: 'e.g., status',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedOperator,
                          decoration: const InputDecoration(
                            labelText: 'Op',
                            isDense: true,
                          ),
                          items: _operators.map((op) {
                            return DropdownMenuItem(value: op, child: Text(op));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedOperator = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _queryValueController,
                          decoration: const InputDecoration(
                            labelText: 'Value',
                            hintText: 'e.g., active',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _queryFieldController.clear();
                            _queryValueController.clear();
                            setState(() => _selectedOperator = '==');
                            _fetchDocuments();
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _runRuleQuery,
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

          // Preset Rules
          Text(
            'Preset Rules',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._presetRules.map((rule) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.rule, color: Colors.green.shade700, size: 20),
                  ),
                  title: Text(rule['name'] as String),
                  subtitle: Text(
                    '${rule['field']} ${rule['operator']} ${rule['value']}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: _loading ? null : () => _applyPresetRule(rule),
                    child: const Text('Apply'),
                  ),
                  onTap: _loading ? null : () => _applyPresetRule(rule),
                ),
              )),

          const SizedBox(height: 16),
          // Results section
          if (_documents.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Results (${_documents.length})',
                  style: Theme.of(context).textTheme.titleMedium,
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
            ...List.generate(_documents.length, (index) {
              final doc = _documents[index];
              final name = doc.get<String>('name') ?? 'Unnamed';
              final price = doc.get<num>('price') ?? 0;
              final stock = doc.get<int>('stock') ?? 0;

              return Card(
                child: ListTile(
                  title: Text(name),
                  subtitle: Text('\$${price.toStringAsFixed(2)} • Stock: $stock'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDocumentDetails(doc),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
