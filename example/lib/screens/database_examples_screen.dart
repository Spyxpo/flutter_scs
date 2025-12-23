import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Screen showcasing database type examples for eaZI and RelaDB.
///
/// This screen provides code examples and documentation for both
/// database backends supported by SCS.
class DatabaseExamplesScreen extends StatefulWidget {
  const DatabaseExamplesScreen({super.key});

  @override
  State<DatabaseExamplesScreen> createState() => _DatabaseExamplesScreenState();
}

class _DatabaseExamplesScreenState extends State<DatabaseExamplesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedExampleIndex = 0;

  final List<DatabaseExample> _eaziExamples = [
    DatabaseExample(
      title: 'Initialize with eaZI',
      description: 'eaZI is the default file-based NoSQL database, ideal for development and small to medium apps.',
      code: '''
import 'package:flutter_scs/flutter_scs.dart';

// Initialize SCS with eaZI database (default)
final scs = await SCS.initializeApp(
  ScsConfig(
    projectId: 'your-project-id',
    apiKey: 'your-api-key',
    // eaZI is the default database type
    // No additional configuration needed
  ),
);

// eaZI features:
// - File-based NoSQL storage
// - Firestore-like collections & documents
// - Automatic ID generation
// - Subcollections support
// - Query filtering and ordering
''',
    ),
    DatabaseExample(
      title: 'CRUD Operations',
      description: 'Basic Create, Read, Update, Delete operations with eaZI database.',
      code: '''
// CREATE - Add a new document
final doc = await scs.database.collection('users').add({
  'name': 'John Doe',
  'email': 'john@example.com',
  'age': 30,
  'createdAt': DateTime.now().toIso8601String(),
});
print('Created document ID: \${doc.id}');

// READ - Get a single document
final snapshot = await scs.database
    .collection('users')
    .doc(doc.id)
    .get();

if (snapshot.exists) {
  print('User: \${snapshot.data}');
}

// READ - Get all documents in collection
final allUsers = await scs.database.collection('users').get();
for (final user in allUsers.docs) {
  print('User: \${user.data}');
}

// UPDATE - Update specific fields
await scs.database
    .collection('users')
    .doc(doc.id)
    .update({'age': 31, 'updatedAt': DateTime.now().toIso8601String()});

// DELETE - Remove a document
await scs.database
    .collection('users')
    .doc(doc.id)
    .delete();
''',
    ),
    DatabaseExample(
      title: 'Queries & Filtering',
      description: 'Filter and query documents using various operators.',
      code: '''
// Equality filter
final activeUsers = await scs.database
    .collection('users')
    .whereEqualTo('status', 'active')
    .get();

// Not equal filter
final nonAdmins = await scs.database
    .collection('users')
    .whereNotEqualTo('role', 'admin')
    .get();

// Comparison filters
final adults = await scs.database
    .collection('users')
    .whereGreaterThanOrEqualTo('age', 18)
    .get();

final youngUsers = await scs.database
    .collection('users')
    .whereLessThan('age', 30)
    .get();

// Array contains
final taggedUsers = await scs.database
    .collection('users')
    .whereArrayContains('tags', 'premium')
    .get();

// In filter (value in list)
final specificRoles = await scs.database
    .collection('users')
    .whereIn('role', ['admin', 'moderator'])
    .get();

// Combine multiple filters
final filteredUsers = await scs.database
    .collection('users')
    .whereEqualTo('status', 'active')
    .whereGreaterThan('age', 21)
    .get();
''',
    ),
    DatabaseExample(
      title: 'Ordering & Pagination',
      description: 'Sort results and implement pagination.',
      code: '''
// Order by ascending
final usersAsc = await scs.database
    .collection('users')
    .orderByAsc('name')
    .get();

// Order by descending
final usersDesc = await scs.database
    .collection('users')
    .orderByDesc('createdAt')
    .get();

// Limit results
final top10 = await scs.database
    .collection('users')
    .orderByDesc('score')
    .limit(10)
    .get();

// Pagination with skip
final page2 = await scs.database
    .collection('users')
    .orderByDesc('createdAt')
    .limit(20)
    .skip(20) // Skip first 20 for page 2
    .get();

// Combined query with filter, order, and pagination
final recentActiveUsers = await scs.database
    .collection('users')
    .whereEqualTo('status', 'active')
    .orderByDesc('lastLogin')
    .limit(10)
    .get();
''',
    ),
    DatabaseExample(
      title: 'Subcollections',
      description: 'Work with nested subcollections for hierarchical data.',
      code: '''
// Add document to subcollection
final comment = await scs.database
    .collection('posts')
    .doc('post-123')
    .collection('comments')
    .add({
      'text': 'Great post!',
      'author': 'user-456',
      'createdAt': DateTime.now().toIso8601String(),
    });

// Get all documents from subcollection
final comments = await scs.database
    .collection('posts')
    .doc('post-123')
    .collection('comments')
    .orderByDesc('createdAt')
    .get();

// List subcollections of a document
final subcollections = await scs.database
    .collection('posts')
    .doc('post-123')
    .listCollections();

// Deep nesting example
final reply = await scs.database
    .collection('posts')
    .doc('post-123')
    .collection('comments')
    .doc('comment-789')
    .collection('replies')
    .add({
      'text': 'Thanks!',
      'author': 'user-original',
    });
''',
    ),
    DatabaseExample(
      title: 'Collection Management',
      description: 'Create, list, and delete collections.',
      code: '''
// List all root collections
final collections = await scs.database.listCollections();
print('Collections: \$collections');

// Create a new collection
await scs.database.createCollection('products');

// Delete a collection (removes all documents)
await scs.database.deleteCollection('temp-data');

// Check if collection exists (by listing)
final exists = (await scs.database.listCollections())
    .contains('products');
''',
    ),
  ];

  final List<DatabaseExample> _reladbExamples = [
    DatabaseExample(
      title: 'Initialize with RelaDB',
      description: 'RelaDB is a production-grade NoSQL database with MongoDB backend for scalability.',
      code: '''
import 'package:flutter_scs/flutter_scs.dart';

// Initialize SCS with RelaDB database
// Note: Database type is configured server-side via DATABASE_TYPE env
// The SDK API remains the same - no client code changes needed!

final scs = await SCS.initializeApp(
  ScsConfig(
    projectId: 'your-project-id',
    apiKey: 'your-api-key',
    // Server configured with DATABASE_TYPE=mongodb for RelaDB
  ),
);

// RelaDB features:
// - MongoDB-powered backend
// - Same Firestore-like API as eaZI
// - Production-grade scalability
// - Advanced indexing
// - Aggregation pipeline support
// - Replica set support for high availability
''',
    ),
    DatabaseExample(
      title: 'CRUD Operations',
      description: 'Same CRUD operations work seamlessly with RelaDB.',
      code: '''
// The API is identical to eaZI!
// Your code works without any changes when switching databases.

// CREATE
final product = await scs.database.collection('products').add({
  'name': 'Premium Widget',
  'price': 99.99,
  'category': 'electronics',
  'stock': 100,
  'tags': ['featured', 'new'],
  'createdAt': DateTime.now().toIso8601String(),
});

// READ single document
final doc = await scs.database
    .collection('products')
    .doc(product.id)
    .get();

// READ all documents
final allProducts = await scs.database.collection('products').get();

// UPDATE with merge
await scs.database
    .collection('products')
    .doc(product.id)
    .update({
      'stock': 95,
      'lastSold': DateTime.now().toIso8601String(),
    });

// SET (overwrite entire document)
await scs.database
    .collection('products')
    .doc(product.id)
    .set({
      'name': 'Premium Widget v2',
      'price': 109.99,
      'category': 'electronics',
      'stock': 200,
    });

// DELETE
await scs.database
    .collection('products')
    .doc(product.id)
    .delete();
''',
    ),
    DatabaseExample(
      title: 'Advanced Queries',
      description: 'RelaDB supports the same query operators with MongoDB performance.',
      code: '''
// All query operators work with RelaDB

// Range queries (optimized with MongoDB indexes)
final priceRange = await scs.database
    .collection('products')
    .whereGreaterThanOrEqualTo('price', 50)
    .whereLessThan('price', 200)
    .get();

// Text matching
final electronics = await scs.database
    .collection('products')
    .whereEqualTo('category', 'electronics')
    .get();

// Array operations
final featured = await scs.database
    .collection('products')
    .whereArrayContains('tags', 'featured')
    .get();

// IN query
final categories = await scs.database
    .collection('products')
    .whereIn('category', ['electronics', 'accessories'])
    .get();

// Complex compound queries
final results = await scs.database
    .collection('products')
    .whereEqualTo('category', 'electronics')
    .whereGreaterThan('stock', 0)
    .whereArrayContains('tags', 'featured')
    .orderByDesc('createdAt')
    .limit(20)
    .get();
''',
    ),
    DatabaseExample(
      title: 'High-Volume Data',
      description: 'RelaDB is optimized for handling large datasets efficiently.',
      code: '''
// Efficient pagination for large collections
Future<List<ScsDocument>> fetchPage(int page, int pageSize) async {
  final snapshot = await scs.database
      .collection('orders')
      .orderByDesc('createdAt')
      .limit(pageSize)
      .skip(page * pageSize)
      .get();
  return snapshot.docs;
}

// Batch-style operations (add multiple documents)
Future<void> addProducts(List<Map<String, dynamic>> products) async {
  for (final product in products) {
    await scs.database.collection('products').add(product);
  }
}

// Efficient filtering with indexes
// (Server-side indexes are automatically used)
final recentOrders = await scs.database
    .collection('orders')
    .whereEqualTo('status', 'completed')
    .whereGreaterThan('total', 100)
    .orderByDesc('completedAt')
    .limit(100)
    .get();

// Count estimation via query
final activeUsers = await scs.database
    .collection('users')
    .whereEqualTo('status', 'active')
    .get();
final count = activeUsers.size;
''',
    ),
    DatabaseExample(
      title: 'Hierarchical Data',
      description: 'Subcollections work identically with RelaDB backend.',
      code: '''
// Subcollections are fully supported

// E-commerce example: Orders with items
final order = await scs.database.collection('orders').add({
  'userId': 'user-123',
  'status': 'pending',
  'total': 249.99,
  'createdAt': DateTime.now().toIso8601String(),
});

// Add items to order subcollection
await scs.database
    .collection('orders')
    .doc(order.id)
    .collection('items')
    .add({
      'productId': 'prod-456',
      'name': 'Widget',
      'quantity': 2,
      'price': 99.99,
    });

await scs.database
    .collection('orders')
    .doc(order.id)
    .collection('items')
    .add({
      'productId': 'prod-789',
      'name': 'Accessory',
      'quantity': 1,
      'price': 50.01,
    });

// Fetch order with items
final orderDoc = await scs.database
    .collection('orders')
    .doc(order.id)
    .get();

final items = await scs.database
    .collection('orders')
    .doc(order.id)
    .collection('items')
    .get();

print('Order: \${orderDoc.data}');
print('Items: \${items.docs.length}');
''',
    ),
    DatabaseExample(
      title: 'Migration Guide',
      description: 'How to switch between eaZI and RelaDB databases.',
      code: '''
// Switching between eaZI and RelaDB is seamless!

// 1. No client code changes required
//    The SDK API is identical for both databases

// 2. Server-side configuration only
//    Set DATABASE_TYPE environment variable:
//    - DATABASE_TYPE=eazi (default, file-based)
//    - DATABASE_TYPE=mongodb (RelaDB, production)

// 3. For MongoDB/RelaDB, also set:
//    - MONGODB_URI=mongodb://localhost:27017/scs
//    - Or use MongoDB Atlas connection string

// Example server .env for development (eaZI):
// DATABASE_TYPE=eazi

// Example server .env for production (RelaDB):
// DATABASE_TYPE=mongodb
// MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/scs

// Your Flutter code remains unchanged:
final scs = await SCS.initializeApp(
  ScsConfig(
    projectId: 'your-project-id',
    apiKey: 'your-api-key',
  ),
);

// Same operations work with both databases!
final users = await scs.database.collection('users').get();
''',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Examples'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.folder_outlined),
              text: 'eaZI Database',
            ),
            Tab(
              icon: Icon(Icons.cloud_outlined),
              text: 'RelaDB',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExamplesView(_eaziExamples, Colors.blue),
          _buildExamplesView(_reladbExamples, Colors.green),
        ],
      ),
    );
  }

  Widget _buildExamplesView(List<DatabaseExample> examples, Color accentColor) {
    return Row(
      children: [
        // Sidebar with example list
        SizedBox(
          width: 240,
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListView.builder(
              itemCount: examples.length,
              itemBuilder: (context, index) {
                final example = examples[index];
                final isSelected = _selectedExampleIndex == index;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: accentColor.withValues(alpha: 0.1),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: isSelected ? accentColor : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    example.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () => setState(() => _selectedExampleIndex = index),
                );
              },
            ),
          ),
        ),
        // Main content
        Expanded(
          child: _buildExampleDetail(examples[_selectedExampleIndex], accentColor),
        ),
      ],
    );
  }

  Widget _buildExampleDetail(DatabaseExample example, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      example.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      example.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: () => _copyToClipboard(example.code),
                icon: const Icon(Icons.copy),
                tooltip: 'Copy code',
                style: IconButton.styleFrom(
                  backgroundColor: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Dart',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _copyToClipboard(example.code),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade400,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      example.code.trim(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DatabaseExample {
  final String title;
  final String description;
  final String code;

  const DatabaseExample({
    required this.title,
    required this.description,
    required this.code,
  });
}
