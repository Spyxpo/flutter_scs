# Changelog

All notable changes to the SCS Flutter SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-20

### Added
- Initial release of SCS Flutter SDK
- Authentication module with register, login, logout, and session management
- Stream-based auth state changes with `authStateChanges`
- Session persistence and restoration
- Database module with document CRUD operations and subcollections
- Query builder with filters, ordering, and pagination
- Storage module with file and bytes upload/download
- Realtime Database with WebSocket synchronization and streams
- Cloud Messaging for push notifications with topic support
- Remote Config for dynamic app configuration
- Cloud Functions invocation with HttpsCallable support
- Machine Learning APIs for text recognition (OCR) and image labeling
- AI Services for chat and text completion

### Features
- Async/await API design
- Stream-based real-time updates
- Automatic session persistence
- Cross-platform support (iOS, Android, Web, Desktop)
- ScsException for typed error handling
- JSON config initialization support
