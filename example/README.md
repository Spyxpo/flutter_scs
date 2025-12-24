# Flutter SCS Example

This example demonstrates how to use the `flutter_scs` package to integrate SCS (Spyxpo Cloud Services) into your Flutter application.

## Getting Started

1. Add your SCS configuration to `lib/main.dart`:

```dart
import 'package:flutter_scs/flutter_scs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final scs = await SCS.initializeApp(
    ScsConfig(
      apiKey: 'your-api-key',
      projectId: 'your-project-id',
      baseUrl: 'https://scs.spyxpo.com',
    ),
  );

  runApp(MyApp(scs: scs));
}
```

1. Run the app:

```bash
flutter run
```

## Features Demonstrated

- **Authentication**: User registration, login, and session management
- **Database**: Document CRUD operations with queries
- **Storage**: File upload and download
- **Real-time**: WebSocket-based data synchronization
- **Messaging**: Push notifications with topics
- **AI Services**: Chat, completion, and image generation

## More Information

For detailed documentation, see the main [README](../README.md) or visit the [API documentation](https://pub.dev/packages/flutter_scs).
