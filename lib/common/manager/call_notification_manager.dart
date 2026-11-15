import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:toptap/common/manager/call_state_manager.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/service/call_signaling_service.dart';
import 'package:toptap/model/user_model/user_model.dart';
import 'package:toptap/screen/call_screen/enhanced_incoming_call_screen.dart';
import 'package:toptap/screen/call_screen/call_screen.dart';

/// Enhanced Call Notification Manager
/// Handles incoming call notifications with full-screen UI, ringtones, and proper lifecycle management
class CallNotificationManager {
  CallNotificationManager._();
  static final CallNotificationManager instance = CallNotificationManager._();

  // Notification plugin instance (injected from FirebaseNotificationManager)
  FlutterLocalNotificationsPlugin? _notificationPlugin;

  // Call state management
  final Rx<CallNotificationState> _currentState =
      CallNotificationState.idle.obs;
  final RxMap<String, IncomingCallData> _activeIncomingCalls =
      <String, IncomingCallData>{}.obs;

  // Timers and resources
  Timer? _ringtoneTimer;
  Timer? _callTimeoutTimer;
  bool _isInitialized = false;

  // Getters
  CallNotificationState get currentState => _currentState.value;
  Map<String, IncomingCallData> get activeIncomingCalls => _activeIncomingCalls;
  bool get hasActiveIncomingCall => _activeIncomingCalls.isNotEmpty;
  bool get isInitialized => _isInitialized;

  FlutterLocalNotificationsPlugin get _notificationsPlugin {
    _notificationPlugin ??= FlutterLocalNotificationsPlugin();
    return _notificationPlugin!;
  }

  void configureNotificationPlugin(FlutterLocalNotificationsPlugin plugin) {
    _notificationPlugin = plugin;
  }

  /// Initialize the call notification manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Loggers.info('📞 Initializing Call Notification Manager...');

      // Initialize notification plugin
      await _initializeNotifications();

      // Setup notification channels for calls
      await _createNotificationChannels();

      _isInitialized = true;
      Loggers.success(
          '📞 ✅ Call Notification Manager initialized successfully');
    } catch (e) {
      Loggers.error('📞 ❌ Failed to initialize Call Notification Manager: $e');
      rethrow;
    }
  }

  /// Initialize notification plugin with proper settings
  Future<void> _initializeNotifications() async {
    if (_notificationPlugin != null) {
      return;
    }
    // Android initialization
    const androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosInitializationSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  /// Create notification channels for different call types
  Future<void> _createNotificationChannels() async {
    // Incoming call channel (high priority)
    const incomingCallChannel = AndroidNotificationChannel(
      'incoming_call_channel',
      'Incoming Calls',
      description: 'Notifications for incoming voice and video calls',
      importance: Importance.max,
      enableLights: true,
      ledColor: Colors.green,
      enableVibration: true,
      playSound: true,
      // Using default system ringtone - no custom sound needed
    );

    // Call in progress channel
    const activeCallChannel = AndroidNotificationChannel(
      'active_call_channel',
      'Active Calls',
      description: 'Notifications for ongoing calls',
      importance: Importance.low,
      enableLights: false,
      enableVibration: false,
      playSound: false,
    );

    // Register channels
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(incomingCallChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(activeCallChannel);
  }

  /// Show incoming call notification
  Future<void> showIncomingCall({
    required String callId,
    required User caller,
    required String channelId,
    required bool isVideoCall,
    String? token,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      Loggers.info(
          '📞 Showing incoming ${isVideoCall ? 'video' : 'voice'} call from ${caller.fullname}');

      // Create call data
      final callData = IncomingCallData(
        callId: callId,
        caller: caller,
        channelId: channelId,
        isVideoCall: isVideoCall,
        token: token,
        timestamp: DateTime.now(),
      );

      // Store active call and record in state manager
      _activeIncomingCalls[callId] = callData;
      _currentState.value = CallNotificationState.incomingCall;

      // Record call in state manager
      await CallStateManager.instance.recordIncomingCall(
        callId: callId,
        caller: caller,
        channelId: channelId,
        isVideoCall: isVideoCall,
        token: token,
      );

      // Enable wake lock to keep screen on
      await WakelockPlus.enable();

      // Set timeout timer before any awaited navigation/UI work.
      _callTimeoutTimer?.cancel();
      _callTimeoutTimer = Timer(timeout, () async {
        Loggers.info('📞 Call timeout for $callId');
        await CallStateManager.instance.missCall(callId, reason: 'timeout');
        declineCall(callId, reason: 'timeout');
      });

      // Start ringtone
      await _startRingtone();

      // Show full-screen notification for Android 10+
      await _showFullScreenNotification(callData);

      // Show enhanced incoming call screen if app is in foreground
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_showIncomingCallScreen(callData));
      }
    } catch (e) {
      Loggers.error('📞 ❌ Error showing incoming call: $e');
    }
  }

  /// Show full-screen notification for incoming call
  Future<void> _showFullScreenNotification(IncomingCallData callData) async {
    try {
      final caller = callData.caller;
      final isVideo = callData.isVideoCall;
      final localProfilePhoto =
          _localNotificationImagePath(caller.profilePhoto);

      // Create big picture for caller photo
      BigPictureStyleInformation? bigPictureStyle;
      if (localProfilePhoto != null) {
        try {
          bigPictureStyle = BigPictureStyleInformation(
            FilePathAndroidBitmap(localProfilePhoto),
            largeIcon: FilePathAndroidBitmap(localProfilePhoto),
            contentTitle: caller.fullname ?? 'Incoming Call',
            summaryText: isVideo ? 'Video Call' : 'Voice Call',
          );
        } catch (_) {
          // Fallback if image loading fails
        }
      }

      final androidDetails = AndroidNotificationDetails(
        'incoming_call_channel',
        'Incoming Calls',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        usesChronometer: false,
        colorized: true,
        color: isVideo ? Colors.blue : Colors.green,
        largeIcon: caller.profilePhoto?.isNotEmpty == true
            ? const DrawableResourceAndroidBitmap('@mipmap/ic_launcher')
            : const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: bigPictureStyle,
        actions: [
          AndroidNotificationAction(
            'DECLINE_CALL_${callData.callId}',
            'Decline',
            // Using Android system icon - no custom drawable needed
            cancelNotification: true,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'ACCEPT_CALL_${callData.callId}',
            isVideo ? 'Video' : 'Answer',
            // Using Android system icon - no custom drawable needed
            cancelNotification: true,
            showsUserInterface: true,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
        // Using default iOS system sound
        categoryIdentifier: 'incoming_call',
        interruptionLevel: InterruptionLevel.critical,
      );

      await _notificationsPlugin.show(
        callData.callId.hashCode,
        caller.fullname ?? 'Incoming Call',
        isVideo ? 'Incoming video call' : 'Incoming voice call',
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        payload: jsonEncode(callData.toJson()),
      );

      Loggers.success('📞 ✅ Full-screen notification displayed');
    } catch (e) {
      Loggers.error('📞 ❌ Error showing full-screen notification: $e');
    }
  }

  String? _localNotificationImagePath(String? path) {
    final value = path?.trim() ?? '';
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      return uri.scheme == 'file' ? uri.toFilePath() : null;
    }

    return File(value).isAbsolute ? value : null;
  }

  /// Show incoming call screen
  Future<void> _showIncomingCallScreen(IncomingCallData callData) async {
    try {
      await Get.to(
        () => EnhancedIncomingCallScreen(callData: callData),
        fullscreenDialog: true,
        preventDuplicates: true,
        opaque: false,
      );
    } catch (e) {
      Loggers.error('📞 ❌ Error showing incoming call screen: $e');
    }
  }

  /// Start ringtone for incoming call
  Future<void> _startRingtone() async {
    try {
      // Cancel any existing ringtone
      await _stopRingtone();

      // Play ringtone (loop) - using simple notification sound for now
      // Note: flutter_ringtone_player might need additional setup
      // For now, we rely on notification channel sound

      Loggers.info('📞 🔊 Ringtone started via notification');
    } catch (e) {
      Loggers.error('📞 ❌ Error starting ringtone: $e');
    }
  }

  /// Stop ringtone
  Future<void> _stopRingtone() async {
    try {
      // Stop any playing sounds
      _ringtoneTimer?.cancel();
      _ringtoneTimer = null;
      Loggers.info('📞 🔇 Ringtone stopped');
    } catch (e) {
      Loggers.error('📞 ❌ Error stopping ringtone: $e');
    }
  }

  /// Accept incoming call
  Future<void> acceptCall(String callId) async {
    try {
      final callData = _activeIncomingCalls[callId];
      if (callData == null) {
        Loggers.warning('📞 ⚠️ No active call found for ID: $callId');
        return;
      }

      Loggers.info('📞 ✅ Accepting call: $callId');

      // Update call state
      await CallStateManager.instance.acceptCall(callId);
      await CallSignalingService.instance.updateStatus(
        callId,
        CallSignalStatus.accepted,
      );

      // Stop ringtone and cleanup
      await _stopRingtone();
      await _cleanupCall(callId);

      // Navigate to call screen
      await _navigateToCallScreen(callData);

      // Update state
      _currentState.value = CallNotificationState.inCall;
    } catch (e) {
      Loggers.error('📞 ❌ Error accepting call: $e');
    }
  }

  /// Decline incoming call
  Future<void> declineCall(String callId,
      {String reason = 'user_declined'}) async {
    try {
      final callData = _activeIncomingCalls[callId];
      if (callData == null) {
        Loggers.warning('📞 ⚠️ No active call found for ID: $callId');
        return;
      }

      Loggers.info('📞 ❌ Declining call: $callId (reason: $reason)');

      // Update call state
      await CallStateManager.instance.declineCall(callId, reason: reason);
      await CallSignalingService.instance.updateStatus(
        callId,
        reason == 'timeout'
            ? CallSignalStatus.missed
            : CallSignalStatus.declined,
        reason: reason,
      );

      // Stop ringtone and cleanup
      await _stopRingtone();
      await _cleanupCall(callId);

      // Update state
      if (_activeIncomingCalls.isEmpty) {
        _currentState.value = CallNotificationState.idle;
      }
    } catch (e) {
      Loggers.error('📞 ❌ Error declining call: $e');
    }
  }

  /// Navigate to call screen
  Future<void> _navigateToCallScreen(IncomingCallData callData) async {
    try {
      // Directly navigate without deferred import to avoid runtime errors on accept
      await Get.off(() => CallScreen(
            user: callData.caller,
            isVideoCall: callData.isVideoCall,
            channelId: callData.channelId,
            callId: callData.callId,
            token: callData.token,
          ));
    } catch (e) {
      Loggers.error('📞 ❌ Error navigating to call screen: $e');
    }
  }

  /// Cleanup call resources
  Future<void> _cleanupCall(String callId) async {
    try {
      // Remove from active calls
      _activeIncomingCalls.remove(callId);

      // Cancel notification
      await _notificationsPlugin.cancel(callId.hashCode);

      // Cancel timers
      _callTimeoutTimer?.cancel();
      _callTimeoutTimer = null;

      // Disable wake lock if no more calls
      if (_activeIncomingCalls.isEmpty) {
        await WakelockPlus.disable();
      }

      Loggers.info('📞 🧹 Cleaned up call resources for: $callId');
    } catch (e) {
      Loggers.error('📞 ❌ Error cleaning up call: $e');
    }
  }

  /// Public bridge for action handling from FirebaseNotificationManager.
  void handleNotificationActionPayload(String? payload, String? actionId) {
    _handleNotificationAction(payload, actionId);
  }

  /// Handle notification actions (Accept/Decline)
  void _handleNotificationAction(String? payload, String? actionId) {
    try {
      if (payload == null || actionId == null) return;

      final callData = IncomingCallData.fromJson(jsonDecode(payload));

      if (actionId.startsWith('ACCEPT_CALL_')) {
        acceptCall(callData.callId);
      } else if (actionId.startsWith('DECLINE_CALL_')) {
        declineCall(callData.callId, reason: 'notification_declined');
      }
    } catch (e) {
      Loggers.error('📞 ❌ Error handling notification action: $e');
    }
  }

  /// Dispose and cleanup
  Future<void> dispose() async {
    try {
      // Stop all ringtones
      await _stopRingtone();

      // Cancel all timers
      _callTimeoutTimer?.cancel();

      // Cleanup all active calls
      for (final callId in _activeIncomingCalls.keys.toList()) {
        await _cleanupCall(callId);
      }

      // Disable wake lock
      await WakelockPlus.disable();

      _isInitialized = false;
      Loggers.info('📞 🗑️ Call Notification Manager disposed');
    } catch (e) {
      Loggers.error('📞 ❌ Error disposing Call Notification Manager: $e');
    }
  }
}

/// Call notification states
enum CallNotificationState {
  idle,
  incomingCall,
  inCall,
  callEnded,
}

/// Incoming call data model
class IncomingCallData {
  final String callId;
  final User caller;
  final String channelId;
  final bool isVideoCall;
  final String? token;
  final DateTime timestamp;

  IncomingCallData({
    required this.callId,
    required this.caller,
    required this.channelId,
    required this.isVideoCall,
    this.token,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'callId': callId,
        'caller': caller.toJson(),
        'channelId': channelId,
        'isVideoCall': isVideoCall,
        'token': token,
        'timestamp': timestamp.toIso8601String(),
      };

  factory IncomingCallData.fromJson(Map<String, dynamic> json) =>
      IncomingCallData(
        callId: json['callId'] ?? '',
        caller: User.fromJson(json['caller'] ?? {}),
        channelId: json['channelId'] ?? '',
        isVideoCall: json['isVideoCall'] ?? false,
        token: json['token'],
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      );
}

/// Helper function for dynamic imports
Future<dynamic> import(String library) async {
  // This is a placeholder for dynamic imports
  // In production, you'd implement proper dynamic loading
  throw UnimplementedError('Dynamic import not implemented');
}
