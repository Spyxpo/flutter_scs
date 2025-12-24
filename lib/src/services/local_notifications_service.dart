import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Configuration for notification channels (Android only).
///
/// Notification channels group notifications by type and allow users
/// to customize notification behavior per channel.
class NotificationChannel {
  /// Unique identifier for the channel.
  final String id;

  /// Display name of the channel shown in system settings.
  final String name;

  /// Description of the channel shown in system settings.
  final String? description;

  /// Importance level determining notification behavior.
  final Importance importance;

  /// Whether to play a sound when notification arrives.
  final bool playSound;

  /// Whether to vibrate when notification arrives.
  final bool enableVibration;

  /// Whether to show a badge on the app icon.
  final bool showBadge;

  const NotificationChannel({
    required this.id,
    required this.name,
    this.description,
    this.importance = Importance.defaultImportance,
    this.playSound = true,
    this.enableVibration = true,
    this.showBadge = true,
  });
}

/// Configuration for local notifications initialization.
class LocalNotificationsConfig {
  /// Android app icon resource name (without extension).
  /// Default is 'app_icon'.
  final String androidIcon;

  /// iOS request alert permission.
  final bool requestAlertPermission;

  /// iOS request badge permission.
  final bool requestBadgePermission;

  /// iOS request sound permission.
  final bool requestSoundPermission;

  /// Default notification channel for Android.
  final NotificationChannel? defaultChannel;

  /// Additional notification channels for Android.
  final List<NotificationChannel> channels;

  const LocalNotificationsConfig({
    this.androidIcon = 'app_icon',
    this.requestAlertPermission = true,
    this.requestBadgePermission = true,
    this.requestSoundPermission = true,
    this.defaultChannel,
    this.channels = const [],
  });
}

/// Data class for notification payload.
///
/// Contains the notification data received when a notification
/// is tapped or received.
class NotificationPayload {
  /// Title of the notification.
  final String? title;

  /// Body text of the notification.
  final String? body;

  /// Custom payload data attached to the notification.
  final String? payload;

  /// Unique identifier of the notification.
  final int? id;

  const NotificationPayload({
    this.title,
    this.body,
    this.payload,
    this.id,
  });

  factory NotificationPayload.fromResponse(NotificationResponse response) {
    return NotificationPayload(
      id: response.id,
      payload: response.payload,
    );
  }
}

/// Service for managing local notifications in Flutter apps.
///
/// Provides easy-to-use methods for showing, scheduling, and managing
/// local notifications on both Android and iOS platforms.
///
/// Example usage:
/// ```dart
/// final notifications = LocalNotificationsService();
///
/// // Initialize with default config
/// await notifications.initialize();
///
/// // Show a simple notification
/// await notifications.show(
///   id: 1,
///   title: 'Hello',
///   body: 'This is a test notification',
/// );
///
/// // Schedule a notification
/// await notifications.schedule(
///   id: 2,
///   title: 'Reminder',
///   body: 'Your scheduled reminder',
///   scheduledDate: DateTime.now().add(Duration(hours: 1)),
/// );
///
/// // Listen for notification taps
/// notifications.onNotificationTap.listen((payload) {
///   print('Notification tapped: ${payload.payload}');
/// });
/// ```
class LocalNotificationsService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<NotificationPayload> _notificationTapController =
      StreamController<NotificationPayload>.broadcast();

  final StreamController<NotificationPayload> _notificationReceivedController =
      StreamController<NotificationPayload>.broadcast();

  bool _isInitialized = false;
  LocalNotificationsConfig? _config;

  /// Stream of notification tap events.
  Stream<NotificationPayload> get onNotificationTap =>
      _notificationTapController.stream;

  /// Stream of notification received events (foreground only on iOS).
  Stream<NotificationPayload> get onNotificationReceived =>
      _notificationReceivedController.stream;

  /// Whether the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Initialize the local notifications service.
  ///
  /// Must be called before using any other methods.
  /// Typically called in your app's main() function or initialization.
  Future<bool> initialize([LocalNotificationsConfig? config]) async {
    if (_isInitialized) return true;

    // Initialize timezone data for scheduling
    tz_data.initializeTimeZones();

    _config = config ?? const LocalNotificationsConfig();

    // Android initialization settings
    final androidSettings = AndroidInitializationSettings(_config!.androidIcon);

    // iOS/macOS initialization settings
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: _config!.requestAlertPermission,
      requestBadgePermission: _config!.requestBadgePermission,
      requestSoundPermission: _config!.requestSoundPermission,
      notificationCategories: [],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    final result = await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _backgroundNotificationHandler,
    );

    if (result == true) {
      _isInitialized = true;

      // Create Android notification channels
      if (!kIsWeb && Platform.isAndroid) {
        await _createAndroidChannels();
      }
    }

    return result ?? false;
  }

  Future<void> _createAndroidChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Create default channel
    final defaultChannel = _config?.defaultChannel ??
        const NotificationChannel(
          id: 'default',
          name: 'Default',
          description: 'Default notification channel',
          importance: Importance.defaultImportance,
        );

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        defaultChannel.id,
        defaultChannel.name,
        description: defaultChannel.description,
        importance: defaultChannel.importance,
        playSound: defaultChannel.playSound,
        enableVibration: defaultChannel.enableVibration,
        showBadge: defaultChannel.showBadge,
      ),
    );

    // Create additional channels
    for (final channel in _config?.channels ?? []) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          channel.id,
          channel.name,
          description: channel.description,
          importance: channel.importance,
          playSound: channel.playSound,
          enableVibration: channel.enableVibration,
          showBadge: channel.showBadge,
        ),
      );
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    _notificationTapController.add(NotificationPayload.fromResponse(response));
  }

  @pragma('vm:entry-point')
  static void _backgroundNotificationHandler(NotificationResponse response) {
    // Handle background notification response
    // This runs in a separate isolate
  }

  /// Request notification permissions.
  ///
  /// Returns true if permissions were granted.
  /// On Android 13+, this requests POST_NOTIFICATIONS permission.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission() ?? false;
    }

    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await iosPlugin?.requestPermissions(
            alert: _config?.requestAlertPermission ?? true,
            badge: _config?.requestBadgePermission ?? true,
            sound: _config?.requestSoundPermission ?? true,
          ) ??
          false;
    }

    return false;
  }

  /// Show an immediate notification.
  ///
  /// [id] - Unique identifier for the notification.
  /// [title] - The notification title.
  /// [body] - The notification body text.
  /// [payload] - Optional data to be delivered when notification is tapped.
  /// [channelId] - Android channel ID (defaults to 'default').
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'default',
  }) async {
    _ensureInitialized();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Schedule a notification for a specific time.
  ///
  /// [id] - Unique identifier for the notification.
  /// [title] - The notification title.
  /// [body] - The notification body text.
  /// [scheduledDate] - When to show the notification.
  /// [payload] - Optional data to be delivered when notification is tapped.
  /// [channelId] - Android channel ID (defaults to 'default').
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String channelId = 'default',
  }) async {
    _ensureInitialized();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _convertToTZDateTime(scheduledDate),
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule a repeating notification.
  ///
  /// [id] - Unique identifier for the notification.
  /// [title] - The notification title.
  /// [body] - The notification body text.
  /// [repeatInterval] - How often to repeat (daily, weekly, etc.).
  /// [payload] - Optional data to be delivered when notification is tapped.
  /// [channelId] - Android channel ID (defaults to 'default').
  Future<void> periodicallyShow({
    required int id,
    required String title,
    required String body,
    required RepeatInterval repeatInterval,
    String? payload,
    String channelId = 'default',
  }) async {
    _ensureInitialized();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.periodicallyShow(
      id,
      title,
      body,
      repeatInterval,
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancel a specific notification.
  Future<void> cancel(int id) async {
    _ensureInitialized();
    await _plugin.cancel(id);
  }

  /// Cancel all notifications.
  Future<void> cancelAll() async {
    _ensureInitialized();
    await _plugin.cancelAll();
  }

  /// Get all pending (scheduled) notifications.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    _ensureInitialized();
    return await _plugin.pendingNotificationRequests();
  }

  /// Get all active (shown) notifications.
  Future<List<ActiveNotification>> getActiveNotifications() async {
    _ensureInitialized();
    return await _plugin.getActiveNotifications();
  }

  /// Check if the app was launched from a notification.
  ///
  /// Returns the notification details if launched from a notification,
  /// or null otherwise.
  Future<NotificationPayload?> getNotificationAppLaunchDetails() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true &&
        details?.notificationResponse != null) {
      return NotificationPayload.fromResponse(details!.notificationResponse!);
    }
    return null;
  }

  String _getChannelName(String channelId) {
    if (channelId == 'default') return 'Default';
    final channel = _config?.channels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => NotificationChannel(id: channelId, name: channelId),
    );
    return channel?.name ?? channelId;
  }

  String? _getChannelDescription(String channelId) {
    if (channelId == 'default') return 'Default notification channel';
    final channel = _config?.channels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => NotificationChannel(id: channelId, name: channelId),
    );
    return channel?.description;
  }

  /// Convert DateTime to TZDateTime for scheduling.
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'LocalNotificationsService has not been initialized. '
        'Call initialize() before using any other methods.',
      );
    }
  }

  /// Dispose of the service and release resources.
  void dispose() {
    _notificationTapController.close();
    _notificationReceivedController.close();
  }
}
