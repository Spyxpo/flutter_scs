# flutter_scs

Flutter SDK for SCS (Spyxpo Cloud Services) - a complete Backend-as-a-Service solution.

## Features

- **Authentication** - User registration, login, profile management, and session persistence
- **Database** - NoSQL document database with collections, subcollections, and queries
- **Storage** - File upload, download, and management
- **Realtime Database** - Real-time data synchronization with WebSocket
- **Cloud Messaging** - Push notifications with topics and device tokens
- **Remote Config** - Dynamic configuration management with versioning
- **Cloud Functions** - Serverless function invocation
- **ML/AI** - Text recognition, image labeling, and AI chat/completion

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_scs:
    git:
      url: https://github.com/Spyxpo/flutter_scs.git
      path: flutter_scs
```

## Quick Start

### Initialize the SDK

```dart
import 'package:flutter_scs/flutter_scs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final scs = await SCS.initializeApp(
    ScsConfig(
      apiKey: 'your-api-key',
      projectId: 'your-project-id',
      baseUrl: 'https://your-scs-instance.com',
    ),
  );

  runApp(MyApp(scs: scs));
}
```

Or initialize from JSON config:

```dart
final scs = await SCS.initializeAppFromJson({
  'apiKey': 'your-api-key',
  'projectId': 'your-project-id',
  'baseUrl': 'https://your-scs-instance.com',
});
```

## Authentication

### Register a new user

```dart
final user = await scs.auth.register(
  email: 'user@example.com',
  password: 'password123',
  displayName: 'John Doe',
  customData: {'role': 'user'},
);
print('Registered: ${user.email}');
```

### Login

```dart
final user = await scs.auth.login(
  email: 'user@example.com',
  password: 'password123',
);
print('Logged in: ${user.email}');
```

### Restore session on app start

```dart
final user = await scs.auth.restoreSession();
if (user != null) {
  print('Session restored for: ${user.email}');
}
```

### Listen to auth state changes

```dart
scs.auth.authStateChanges.listen((user) {
  if (user != null) {
    print('User signed in: ${user.email}');
  } else {
    print('User signed out');
  }
});
```

### Update profile

```dart
await scs.auth.updateProfile(
  displayName: 'Jane Doe',
  customData: {'role': 'admin'},
);
```

### Sign out

```dart
await scs.auth.signOut();
```

## Database

NoSQL document database with collections and subcollections. SCS supports two powerful database options:

### Database Types

| Type | Name | Description | Best For |
|------|------|-------------|----------|
| `eazi` | **eaZI Database** | Document-based NoSQL with Firestore-like collections, documents, and subcollections | Development, prototyping, small to medium apps |
| `mongodb` | **RelaDB** | Production-grade NoSQL database with relational-style views | Production, scalability, advanced queries |

### Configuration

Configure the backend database type via `DATABASE_TYPE` environment variable:

```env
# For eaZI Database (default) - No external dependencies
DATABASE_TYPE=eazi

# For RelaDB (production-grade)
DATABASE_TYPE=mongodb
MONGODB_URI=mongodb://localhost:27017/scs_main
```

### eaZI Database Features

- **Document-based**: Firestore-like collections and documents
- **Subcollections**: Nested data organization
- **File-based storage**: No external dependencies required
- **Zero configuration**: Works out of the box
- **Query support**: Filtering, ordering, and pagination

### RelaDB Features

- **Production-ready**: Built on MongoDB for reliability and performance
- **Scalable**: Horizontal scaling and replication support
- **Advanced queries**: Aggregation pipelines, complex filters
- **Indexing**: Custom indexes for optimized performance
- **Schema flexibility**: Dynamic schema with validation support
- **Relational-style views**: Table view with columns and rows in the console

### Add a document

```dart
final doc = await scs.database.collection('todos').add({
  'title': 'Buy groceries',
  'completed': false,
  'createdAt': DateTime.now().toIso8601String(),
});
print('Created document: ${doc.id}');
```

### Get a document

```dart
final snapshot = await scs.database
    .collection('todos')
    .doc('document-id')
    .get();

if (snapshot.exists) {
  print('Title: ${snapshot.data!['title']}');
}
```

### Query documents

```dart
final snapshot = await scs.database
    .collection('todos')
    .whereEqualTo('completed', false)
    .orderByDesc('createdAt')
    .limit(10)
    .get();

for (final doc in snapshot.docs) {
  print('${doc.id}: ${doc.data['title']}');
}
```

### Update a document

```dart
await scs.database
    .collection('todos')
    .doc('document-id')
    .update({'completed': true});
```

### Delete a document

```dart
await scs.database
    .collection('todos')
    .doc('document-id')
    .delete();
```

### Subcollections

```dart
// Add to subcollection
await scs.database
    .collection('users')
    .doc('user-id')
    .collection('posts')
    .add({'title': 'My first post'});

// Query subcollection
final posts = await scs.database
    .collection('users')
    .doc('user-id')
    .collection('posts')
    .get();
```

## Storage

### Upload a file

```dart
import 'dart:io';

final file = File('/path/to/image.jpg');
final metadata = await scs.storage.upload(
  file,
  folder: 'images',
);
print('Uploaded: ${metadata.url}');
```

### Upload bytes

```dart
final bytes = Uint8List.fromList([...]);
final metadata = await scs.storage.uploadBytes(
  bytes,
  filename: 'document.pdf',
  folder: 'documents',
);
```

### List files

```dart
final result = await scs.storage.list(
  folder: 'images',
  limit: 20,
);

for (final file in result.files) {
  print('${file.name}: ${file.readableSize}');
}
```

### Download a file

```dart
final bytes = await scs.storage.download('file-id');
// or save to file
final file = await scs.storage.downloadToFile('file-id', '/path/to/save.jpg');
```

### Delete a file

```dart
await scs.storage.delete('file-id');
```

## Realtime Database

### Set data

```dart
await scs.realtime.ref('users/user-id').set({
  'name': 'John',
  'online': true,
});
```

### Update data

```dart
await scs.realtime.ref('users/user-id').update({
  'lastSeen': DateTime.now().toIso8601String(),
});
```

### Listen for changes

```dart
scs.realtime.ref('messages').on('value', (data) {
  print('Messages updated: $data');
});

// Or use stream
scs.realtime.ref('messages').onValue.listen((data) {
  print('Messages: $data');
});
```

### Push new data

```dart
final ref = await scs.realtime.ref('messages').push({
  'text': 'Hello!',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
});
print('New message key: ${ref.path}');
```

### Remove data

```dart
await scs.realtime.ref('users/user-id').remove();
```

## Cloud Messaging

### Register device token

```dart
await scs.messaging.registerToken(
  token: 'device-fcm-token',
  platform: 'android', // or 'ios', 'web'
);
```

### Subscribe to topic

```dart
await scs.messaging.subscribeToTopic(
  token: 'device-token',
  topic: 'news',
);
```

### Send message to topic

```dart
await scs.messaging.sendToTopic(
  topic: 'news',
  title: 'Breaking News',
  body: 'Something important happened!',
  data: {'articleId': '123'},
);
```

### Listen for messages

```dart
scs.messaging.onMessage.listen((message) {
  print('Received: ${message.title}');
});
```

## Remote Config

### Fetch and activate config

```dart
await scs.remoteConfig.fetchAndActivate();
```

### Get config values

```dart
final welcomeMessage = scs.remoteConfig.getString(
  'welcome_message',
  defaultValue: 'Welcome!',
);

final maxItems = scs.remoteConfig.getInt(
  'max_items',
  defaultValue: 10,
);

final featureEnabled = scs.remoteConfig.getBool(
  'new_feature',
  defaultValue: false,
);
```

## Cloud Functions

### Call a function

```dart
final result = await scs.functions.call(
  'processOrder',
  data: {'orderId': '123', 'action': 'confirm'},
);

if (result.success) {
  print('Result: ${result.data}');
}
```

### Using HttpsCallable

```dart
final callable = scs.functions.httpsCallable('sendEmail');
final result = await callable.call({
  'to': 'user@example.com',
  'subject': 'Hello',
  'body': 'Welcome to our app!',
});
```

## Machine Learning

### Text Recognition (OCR)

```dart
import 'dart:io';

final image = File('/path/to/image.jpg');
final result = await scs.ml.recognizeTextFromFile(image);
print('Recognized text: ${result.text}');
```

### Image Labeling

```dart
final result = await scs.ml.labelImageFromFile(image);
for (final label in result.labels) {
  print('${label.label}: ${label.confidence}');
}
```

## AI Services

### Chat

```dart
final response = await scs.ai.chat(
  messages: [
    ChatMessage.system('You are a helpful assistant.'),
    ChatMessage.user('What is the capital of France?'),
  ],
  model: 'llama2',
);
print('AI: ${response.content}');
```

### Completion

```dart
final response = await scs.ai.complete(
  prompt: 'Write a haiku about programming:',
  model: 'llama2',
);
print(response.text);
```

### Image Generation

```dart
final response = await scs.ai.generateImage(
  prompt: 'A sunset over mountains',
  size: '512x512',
);
print('Image URL: ${response.imageUrl}');
```

## AI Agents

Create and manage AI agents with custom instructions and tools.

### Create an Agent

```dart
final agent = await scs.ai.createAgent(
  name: 'Customer Support',
  instructions: 'You are a helpful customer support assistant. Be polite and helpful.',
  model: 'llama3.2',
  temperature: 0.7,
);
print('Created agent: ${agent.id}');
```

### Run the Agent

```dart
// Run the agent
var response = await scs.ai.runAgent(
  agent.id,
  input: 'How do I reset my password?',
);
print('Agent: ${response.output}');
print('Session: ${response.sessionId}');

// Continue the conversation in the same session
response = await scs.ai.runAgent(
  agent.id,
  input: 'Thanks! What about enabling 2FA?',
  sessionId: response.sessionId,
);
```

### Manage Agent Sessions

```dart
// List agent sessions
final sessions = await scs.ai.listAgentSessions(agent.id);

// Get full session history
final session = await scs.ai.getAgentSession(agent.id, response.sessionId);
for (final msg in session.messages) {
  print('${msg.role}: ${msg.content}');
}

// Delete a session
await scs.ai.deleteAgentSession(agent.id, response.sessionId);
```

### Manage Agents

```dart
// List agents
final agents = await scs.ai.listAgents();

// Update agent
await scs.ai.updateAgent(
  agent.id,
  instructions: 'Updated instructions here',
  temperature: 0.5,
);

// Delete agent
await scs.ai.deleteAgent(agent.id);
```

### Agent Tools

```dart
// Define a tool for agents
final tool = await scs.ai.defineTool(
  name: 'get_weather',
  description: 'Get weather for a location',
  parameters: {
    'type': 'object',
    'properties': {
      'location': {'type': 'string', 'description': 'City name'}
    }
  },
);

// List tools
final tools = await scs.ai.listTools();

// Delete a tool
await scs.ai.deleteTool(tool.id);
```

## Error Handling

All SDK methods can throw `ScsException`:

```dart
try {
  await scs.auth.login(email: 'user@example.com', password: 'wrong');
} on ScsException catch (e) {
  print('Error: ${e.message}');
  print('Status code: ${e.statusCode}');
  print('Error code: ${e.code}');
}
```

## Cleanup

When your app is closing:

```dart
scs.dispose();
```

## License

MIT License - See LICENSE file for details.
