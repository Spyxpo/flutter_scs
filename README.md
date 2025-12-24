# flutter_scs

[![GitHub stars](https://img.shields.io/github/stars/spyxpo/flutter_scs.svg?style=social)](https://github.com/spyxpo/flutter_scs)
[![pub package](https://img.shields.io/pub/v/flutter_scs.svg)](https://pub.dartlang.org/packages/flutter_scs)

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

or

```yaml
dependencies:
  flutter_scs: ^1.0.0
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
      baseUrl: 'https://scs.spyxpo.com',
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
  'baseUrl': 'https://scs.spyxpo.com',
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

### OAuth and Social Sign-In

SCS provides built-in native OAuth support for all major providers. **No external packages required** - SCS handles the complete OAuth flow internally.

#### Configure OAuth Providers

Before using social sign-in, configure the OAuth providers you need:

```dart
// Configure OAuth providers (do this once, e.g., after SCS.initializeApp)
scs.auth.configureOAuth(
  config: ScsOAuthConfig(
    google: GoogleOAuthConfig(
      iosClientId: 'your-ios-client-id.apps.googleusercontent.com',
      androidClientId: 'your-android-client-id.apps.googleusercontent.com',
      webClientId: 'your-web-client-id.apps.googleusercontent.com',
    ),
    apple: AppleOAuthConfig(
      serviceId: 'com.yourapp.service',
    ),
    facebook: FacebookOAuthConfig(
      appId: 'your-facebook-app-id',
    ),
    github: GitHubOAuthConfig(
      clientId: 'your-github-client-id',
    ),
    twitter: TwitterOAuthConfig(
      apiKey: 'your-twitter-api-key',
    ),
    microsoft: MicrosoftOAuthConfig(
      clientId: 'your-azure-client-id',
      tenantId: 'common', // or specific tenant ID
    ),
  ),
  callbackScheme: 'com.yourapp', // Your app's custom URL scheme
);
```

#### Google Sign-In

Authenticate users with their Google account using SCS native OAuth.

```dart
// Sign in with Google (no external packages needed!)
final user = await scs.auth.scsSignInWithGoogle();

print('User ID: ${user.uid}');
print('Email: ${user.email}');
print('Display Name: ${user.displayName}');
print('Photo URL: ${user.photoURL}');
```

**Returns:** `Future<ScsUser>`

**Complete Example:**

```dart
class AuthService {
  final SCS scs;

  AuthService(this.scs) {
    // Configure OAuth once
    scs.auth.configureOAuth(
      config: ScsOAuthConfig(
        google: GoogleOAuthConfig(
          iosClientId: 'your-ios-client-id.apps.googleusercontent.com',
          androidClientId: 'your-android-client-id.apps.googleusercontent.com',
          webClientId: 'your-web-client-id.apps.googleusercontent.com',
        ),
      ),
      callbackScheme: 'com.yourapp',
    );
  }

  Future<ScsUser?> signInWithGoogle() async {
    try {
      // SCS handles the complete OAuth flow
      final user = await scs.auth.scsSignInWithGoogle();
      return user;
    } catch (e) {
      print('Google sign-in error: $e');
      rethrow;
    }
  }
}
```

#### Facebook Sign-In

Authenticate users with their Facebook account using SCS native OAuth.

```dart
// Sign in with Facebook (no external packages needed!)
final user = await scs.auth.scsSignInWithFacebook();

print('User: ${user.displayName}');
print('Email: ${user.email}'); // May be null if permission not granted
```

**Complete Example:**

```dart
Future<ScsUser?> signInWithFacebook() async {
  try {
    // Configure Facebook OAuth
    scs.auth.configureOAuth(
      config: ScsOAuthConfig(
        facebook: FacebookOAuthConfig(
          appId: 'your-facebook-app-id',
        ),
      ),
      callbackScheme: 'fb123456789', // fb + your app ID
    );

    // SCS handles the complete OAuth flow
    final user = await scs.auth.scsSignInWithFacebook();
    return user;
  } catch (e) {
    print('Facebook sign-in error: $e');
    rethrow;
  }
}
```

#### Apple Sign-In

Authenticate users with their Apple ID using SCS native OAuth. Required for iOS apps with social login.

```dart
// Sign in with Apple (no external packages needed!)
final user = await scs.auth.scsSignInWithApple();

print('User ID: ${user.uid}');
print('Email: ${user.email}');
print('Display Name: ${user.displayName}');
```

**Important Notes:**

- Apple only provides the user's name on the **first sign-in**. SCS handles this automatically.
- Users can choose to hide their email (Apple provides a relay email).
- Required for apps with social login on iOS/macOS App Store.

**Complete Example:**

```dart
Future<ScsUser?> signInWithApple() async {
  try {
    // Configure Apple OAuth
    scs.auth.configureOAuth(
      config: ScsOAuthConfig(
        apple: AppleOAuthConfig(
          serviceId: 'com.yourapp.service',
        ),
      ),
      callbackScheme: 'com.yourapp',
    );

    // SCS handles the complete OAuth flow (native on iOS/macOS, web-based elsewhere)
    final user = await scs.auth.scsSignInWithApple();
    return user;
  } catch (e) {
    print('Apple sign-in error: $e');
    rethrow;
  }
}
```

#### GitHub Sign-In

Authenticate users with their GitHub account using SCS native OAuth.

```dart
// Sign in with GitHub (no external packages needed!)
final user = await scs.auth.scsSignInWithGitHub();

print('GitHub username: ${user.displayName}');
print('Email: ${user.email}');
```

**Complete Example:**

```dart
Future<ScsUser?> signInWithGitHub() async {
  try {
    // Configure GitHub OAuth
    scs.auth.configureOAuth(
      config: ScsOAuthConfig(
        github: GitHubOAuthConfig(
          clientId: 'your-github-client-id',
        ),
      ),
      callbackScheme: 'com.yourapp',
    );

    // SCS handles the complete OAuth flow
    final user = await scs.auth.scsSignInWithGitHub();
    return user;
  } catch (e) {
    print('GitHub sign-in error: $e');
    rethrow;
  }
}
```

#### Twitter/X Sign-In

Authenticate users with their Twitter/X account using SCS native OAuth 2.0.

```dart
// Sign in with Twitter/X (no external packages needed!)
final user = await scs.auth.scsSignInWithTwitter();

print('Twitter username: ${user.displayName}');
print('Email: ${user.email}');
```

**Complete Example:**

```dart
Future<ScsUser?> signInWithTwitter() async {
  try {
    // Configure Twitter OAuth
    scs.auth.configureOAuth(
      config: ScsOAuthConfig(
        twitter: TwitterOAuthConfig(
          apiKey: 'your-twitter-api-key',
        ),
      ),
      callbackScheme: 'com.yourapp',
    );

    // SCS handles the complete OAuth flow
    final user = await scs.auth.scsSignInWithTwitter();
    return user;
  } catch (e) {
    print('Twitter sign-in error: $e');
    rethrow;
  }
}
```

#### Microsoft Sign-In

Authenticate users with their Microsoft account (personal, work, or school) using SCS native OAuth.

```dart
// Sign in with Microsoft (no external packages needed!)
final user = await scs.auth.scsSignInWithMicrosoft();

print('User: ${user.displayName}');
print('Email: ${user.email}');
```

**Complete Example:**

```dart
Future<ScsUser?> signInWithMicrosoft() async {
  try {
    // Configure Microsoft OAuth
    scs.auth.configureOAuth(
      config: ScsOAuthConfig(
        microsoft: MicrosoftOAuthConfig(
          clientId: 'your-azure-client-id',
          tenantId: 'common', // 'common' for all accounts, or specific tenant ID
        ),
      ),
      callbackScheme: 'msauth.com.yourapp',
    );

    // SCS handles the complete OAuth flow
    final user = await scs.auth.scsSignInWithMicrosoft();
    return user;
  } catch (e) {
    print('Microsoft sign-in error: $e');
    rethrow;
  }
}
```

#### Custom OAuth Provider

Authenticate with any OAuth 2.0 provider using SCS native OAuth.

```dart
// Sign in with any OAuth 2.0 provider
final user = await scs.auth.scsSignInWithOAuth(
  provider: 'discord',
  authorizationUrl: 'https://discord.com/api/oauth2/authorize',
  clientId: 'your-discord-client-id',
  scopes: ['identify', 'email'],
);

print('Discord user: ${user.displayName}');
```

### Anonymous Authentication

Allow users to use your app without creating an account. Anonymous accounts can later be upgraded to permanent accounts by linking a provider.

```dart
// Sign in anonymously (creates a temporary account)
final user = await scs.auth.signInAnonymously(
  customData: {
    'referrer': 'landing-page',
    'campaign': 'summer-sale',
  }, // optional
);

print('Anonymous user ID: ${user.uid}');
print('Is anonymous: ${user.isAnonymous}'); // true
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `customData` | Map<String, dynamic> | No | Custom data for analytics |

**Use Cases:**

- Allow users to try your app before signing up
- Guest checkout in e-commerce
- Save user progress/preferences before account creation
- A/B testing with user tracking

**Converting Anonymous to Permanent Account:**

```dart
// User decides to create a permanent account
// Link their anonymous account to a provider
try {
  final updatedUser = await scs.auth.linkProvider(
    provider: 'google',
    credentials: {'idToken': 'google-id-token'},
  );

  print('Account upgraded! User data preserved.');
  print('Is anonymous: ${updatedUser.isAnonymous}'); // false
} on ScsException catch (e) {
  if (e.code == 'auth/credential-already-in-use') {
    print('This Google account is already registered. Please sign in instead.');
  } else {
    rethrow;
  }
}
```

### Phone Number Authentication

Two-step authentication flow using SMS verification codes.

```dart
// Step 1: Send verification code to phone
final verificationId = await scs.auth.sendPhoneVerificationCode(
  phoneNumber: '+1234567890',          // Required: E.164 format
  recaptchaToken: 'recaptcha-token',   // Optional: For bot protection
);

print('Verification ID: $verificationId');
// Store this ID - you'll need it in step 2

// Step 2: User enters the code they received
final user = await scs.auth.signInWithPhoneNumber(
  verificationId: verificationId,   // The ID from step 1
  code: '123456',                   // 6-digit code from SMS
);

print('Phone verified: ${user.phoneNumber}');
```

**sendPhoneVerificationCode Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `phoneNumber` | String | Yes | Phone number in E.164 format (e.g., +1234567890) |
| `recaptchaToken` | String | No | reCAPTCHA token for abuse prevention |

**signInWithPhoneNumber Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `verificationId` | String | Yes | Verification ID from sendPhoneVerificationCode |
| `code` | String | Yes | 6-digit verification code from SMS |

**Complete Flow Example:**

```dart
class PhoneAuthService {
  final SCS scs;
  String? _verificationId;

  PhoneAuthService(this.scs);

  Future<void> sendCode(String phoneNumber) async {
    try {
      _verificationId = await scs.auth.sendPhoneVerificationCode(
        phoneNumber: phoneNumber,
      );
    } on ScsException catch (e) {
      switch (e.code) {
        case 'auth/invalid-phone-number':
          throw Exception('Invalid phone number format. Use E.164 format (+1234567890)');
        case 'auth/too-many-requests':
          throw Exception('Too many attempts. Please try again later.');
        default:
          rethrow;
      }
    }
  }

  Future<ScsUser> verifyCode(String code) async {
    if (_verificationId == null) {
      throw Exception('Must call sendCode first');
    }

    try {
      return await scs.auth.signInWithPhoneNumber(
        verificationId: _verificationId!,
        code: code,
      );
    } on ScsException catch (e) {
      switch (e.code) {
        case 'auth/invalid-verification-code':
          throw Exception('Invalid verification code. Please try again.');
        case 'auth/code-expired':
          throw Exception('Code expired. Please request a new one.');
        default:
          rethrow;
      }
    }
  }
}

// Usage
final phoneAuth = PhoneAuthService(scs);
await phoneAuth.sendCode('+1234567890');
// ... show OTP input UI ...
final user = await phoneAuth.verifyCode('123456');
```

### Custom Token Authentication

Sign in using a JWT token generated by your backend. Useful for migration or custom auth.

```dart
// Sign in with a custom token (generated by your backend)
final user = await scs.auth.signInWithCustomToken('your-custom-jwt-token');

print('Signed in user: ${user.uid}');
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `token` | String | Yes | JWT token generated by your backend |

**Use Cases:**

- Migrating users from another authentication system
- Server-side user creation with immediate client sign-in
- Integration with enterprise SSO systems
- Machine-to-machine authentication

### Account Linking

Link multiple authentication providers to a single account. Users can sign in with any linked provider.

```dart
// Link a provider to current account
final user = await scs.auth.linkProvider(
  provider: 'facebook',
  credentials: {'accessToken': 'facebook-access-token'},
);

print('Linked providers: ${user.providerData}');
// [ScsProviderData(providerId: 'password'), ScsProviderData(providerId: 'google'), ...]

// Unlink a provider from current account
final updatedUser = await scs.auth.unlinkProvider('facebook');
print('Remaining providers: ${updatedUser.providerData}');

// Get available sign-in methods for an email
final methods = await scs.auth.fetchSignInMethodsForEmail('user@example.com');
print('Available methods: $methods');
// ['password', 'google', 'facebook']
```

**linkProvider Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `provider` | String | Yes | Provider name: 'google', 'facebook', 'apple', 'github', 'twitter', 'microsoft' |
| `credentials` | Map<String, dynamic> | Yes | Provider-specific credentials (tokens) |

**Supported Providers and Credentials:**

| Provider | Required Credentials |
|----------|---------------------|
| `google` | `{'idToken': '...', 'accessToken': '...'}` |
| `facebook` | `{'accessToken': '...'}` |
| `apple` | `{'identityToken': '...', 'authorizationCode': '...', 'fullName': '...'}` |
| `github` | `{'code': '...', 'redirectUri': '...'}` |
| `twitter` | `{'oauthToken': '...', 'oauthTokenSecret': '...'}` |
| `microsoft` | `{'accessToken': '...', 'idToken': '...'}` |

### Password Reset & Email Verification

Handle password recovery and email verification flows.

```dart
// Send password reset email
await scs.auth.sendPasswordResetEmail('user@example.com');
print('Password reset email sent');

// Confirm password reset (user clicks link in email, you extract the code)
await scs.auth.confirmPasswordReset(
  code: 'reset-code-from-email',       // Code from the reset link
  newPassword: 'newSecurePassword123',  // User's new password
);
print('Password successfully reset');

// Send email verification to current user
await scs.auth.sendEmailVerification();
print('Verification email sent');

// Verify email with code (user clicks link, you extract the code)
await scs.auth.verifyEmail('verification-code');
print('Email verified');
```

**Error Handling:**

```dart
Future<bool> resetPassword(String email) async {
  try {
    await scs.auth.sendPasswordResetEmail(email);
    return true;
  } on ScsException catch (e) {
    switch (e.code) {
      case 'auth/user-not-found':
        // Don't reveal if user exists for security
        return true;
      case 'auth/too-many-requests':
        throw Exception('Too many attempts. Please try later.');
      default:
        rethrow;
    }
  }
}

Future<void> confirmReset(String code, String newPassword) async {
  if (newPassword.length < 8) {
    throw Exception('Password must be at least 8 characters');
  }

  try {
    await scs.auth.confirmPasswordReset(
      code: code,
      newPassword: newPassword,
    );
  } on ScsException catch (e) {
    switch (e.code) {
      case 'auth/expired-action-code':
        throw Exception('Reset link expired. Please request a new one.');
      case 'auth/invalid-action-code':
        throw Exception('Invalid reset link.');
      case 'auth/weak-password':
        throw Exception('Password is too weak.');
      default:
        rethrow;
    }
  }
}
```

### Complete Authentication Example

```dart
import 'package:flutter_scs/flutter_scs.dart';

class AuthService {
  final SCS scs;

  AuthService(this.scs) {
    // Configure all OAuth providers once
    scs.auth.configureOAuth(
      config: ScsOAuthConfig(
        google: GoogleOAuthConfig(
          iosClientId: 'your-ios-client-id.apps.googleusercontent.com',
          androidClientId: 'your-android-client-id.apps.googleusercontent.com',
          webClientId: 'your-web-client-id.apps.googleusercontent.com',
        ),
        apple: AppleOAuthConfig(
          serviceId: 'com.yourapp.service',
        ),
        facebook: FacebookOAuthConfig(
          appId: 'your-facebook-app-id',
        ),
      ),
      callbackScheme: 'com.yourapp',
    );
  }

  // Email/Password registration
  Future<ScsUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final user = await scs.auth.register(
      email: email,
      password: password,
      displayName: displayName,
    );

    // Send verification email
    await scs.auth.sendEmailVerification();

    return user;
  }

  // Email/Password login
  Future<ScsUser> login({
    required String email,
    required String password,
  }) async {
    return await scs.auth.login(email: email, password: password);
  }

  // Google Sign-In (using SCS native OAuth)
  Future<ScsUser> signInWithGoogle() async {
    return await scs.auth.scsSignInWithGoogle();
  }

  // Apple Sign-In (using SCS native OAuth)
  Future<ScsUser> signInWithApple() async {
    return await scs.auth.scsSignInWithApple();
  }

  // Facebook Sign-In (using SCS native OAuth)
  Future<ScsUser> signInWithFacebook() async {
    return await scs.auth.scsSignInWithFacebook();
  }

  // Guest mode
  Future<ScsUser> continueAsGuest({Map<String, dynamic>? customData}) async {
    return await scs.auth.signInAnonymously(customData: customData);
  }

  // Upgrade guest to permanent account
  Future<ScsUser> upgradeGuestAccount({
    required String provider,
    required Map<String, dynamic> credentials,
  }) async {
    final user = scs.auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw Exception('Current user is not anonymous');
    }

    return await scs.auth.linkProvider(
      provider: provider,
      credentials: credentials,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await scs.auth.signOut();
  }

  // Auth state stream
  Stream<ScsUser?> get authStateChanges => scs.auth.authStateChanges;
}

// Usage in Widget
class AuthScreen extends StatelessWidget {
  final AuthService authService;

  const AuthScreen({Key? key, required this.authService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ScsUser?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return HomeScreen(user: snapshot.data!);
        }
        return LoginScreen(authService: authService);
      },
    );
  }
}
```

## Database

NoSQL document database with collections and subcollections. SCS supports two powerful database options:

### Database Types

| Type | Name | Description | Best For |
|------|------|-------------|----------|
| `eazi` | **eaZI Database** | Document-based NoSQL with Firestore-like collections, documents, and subcollections | Development, prototyping, small to medium apps |
| `reladb` | **RelaDB** | Production-grade NoSQL database with relational-style views | Production, scalability, advanced queries |

### Initialize with eaZI (Default)

```dart
import 'package:flutter_scs/flutter_scs.dart';

// eaZI is the default database - no special configuration needed
final scs = await SCS.initializeApp(
  ScsConfig(
    projectId: 'your-project-id',
    apiKey: 'your-api-key',
    // databaseType: 'eazi' is implicit
  ),
);
```

### Initialize with RelaDB (Production)

```dart
import 'package:flutter_scs/flutter_scs.dart';

// Use RelaDB for production
final scs = await SCS.initializeApp(
  ScsConfig(
    projectId: 'your-project-id',
    apiKey: 'your-api-key',
    databaseType: 'reladb',  // Enable RelaDB
  ),
);
```

### eaZI Database Features

- **Document-based**: Firestore-like collections and documents
- **Subcollections**: Nested data organization
- **File-based storage**: No external dependencies required
- **Zero configuration**: Works out of the box
- **Query support**: Filtering, ordering, and pagination

### RelaDB Features

- **Production-ready**: Built for reliability and performance
- **Scalable**: Horizontal scaling and replication support
- **Advanced queries**: Aggregation pipelines, complex filters
- **Indexing**: Custom indexes for optimized performance
- **Schema flexibility**: Dynamic schema with validation support
- **Relational-style views**: Table view with columns and rows in the console

### Collection Operations

```dart
// Get a collection reference
final users = scs.database.collection('users');

// List all collections
final collections = await scs.database.listCollections();

// Create a collection
await scs.database.createCollection('newCollection');

// Delete a collection
await scs.database.deleteCollection('oldCollection');
```

### Document Operations

```dart
// Add document with auto-generated ID
final doc = await scs.database.collection('users').add({
  'name': 'John Doe',
  'email': 'john@example.com',
  'age': 30,
  'tags': ['developer', 'flutter'],
  'profile': {
    'bio': 'Software developer',
    'avatar': 'https://example.com/avatar.jpg',
  },
});
print('Document ID: ${doc.id}');

// Set document with custom ID (creates or overwrites)
await scs.database.collection('users').doc('user-123').set({
  'name': 'Jane Doe',
  'email': 'jane@example.com',
});

// Get a single document
final snapshot = await scs.database.collection('users').doc('user-123').get();
if (snapshot.exists) {
  print('Name: ${snapshot.data!['name']}');
}

// Update document (partial update)
await scs.database.collection('users').doc('user-123').update({
  'age': 31,
  'profile.bio': 'Senior developer',
});

// Delete document
await scs.database.collection('users').doc('user-123').delete();
```

### Query Operations

```dart
// Simple query with single filter
final activeUsers = await scs.database.collection('users')
    .whereEqualTo('status', 'active')
    .get();

// Multiple filters
final results = await scs.database.collection('users')
    .whereGreaterThanOrEqualTo('age', 18)
    .whereEqualTo('status', 'active')
    .get();

// Ordering and pagination
final posts = await scs.database.collection('posts')
    .whereEqualTo('published', true)
    .orderByDesc('createdAt')
    .limit(10)
    .skip(20)
    .get();

// Using 'in' operator
final featured = await scs.database.collection('posts')
    .whereIn('category', ['tech', 'science', 'news'])
    .get();

// Using 'contains' for array fields
final tagged = await scs.database.collection('posts')
    .whereContains('tags', 'flutter')
    .get();
```

### Query Operators

| Operator | Method | Example |
|----------|--------|---------|
| `==` | `whereEqualTo()` | `.whereEqualTo('status', 'active')` |
| `!=` | `whereNotEqualTo()` | `.whereNotEqualTo('status', 'deleted')` |
| `>` | `whereGreaterThan()` | `.whereGreaterThan('age', 18)` |
| `>=` | `whereGreaterThanOrEqualTo()` | `.whereGreaterThanOrEqualTo('age', 18)` |
| `<` | `whereLessThan()` | `.whereLessThan('price', 100)` |
| `<=` | `whereLessThanOrEqualTo()` | `.whereLessThanOrEqualTo('price', 50)` |
| `in` | `whereIn()` | `.whereIn('status', ['active', 'pending'])` |
| `contains` | `whereContains()` | `.whereContains('tags', 'featured')` |

### Subcollections

```dart
// Access a subcollection
final postsRef = scs.database
    .collection('users')
    .doc('userId')
    .collection('posts');

// Add to subcollection
final post = await postsRef.add({
  'title': 'My First Post',
  'content': 'Hello World!',
  'createdAt': DateTime.now().toIso8601String(),
});

// Query subcollection
final userPosts = await postsRef
    .orderByDesc('createdAt')
    .limit(5)
    .get();

// Nested subcollections (e.g., users/userId/posts/postId/comments)
final commentsRef = scs.database
    .collection('users')
    .doc('userId')
    .collection('posts')
    .doc('postId')
    .collection('comments');

// List subcollections of a document
final subcollections = await scs.database
    .collection('users')
    .doc('userId')
    .listCollections();
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
