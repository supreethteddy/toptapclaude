import 'package:get/get.dart';
import 'package:shortzz/common/config/agora_config.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/notification_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/call_signaling_service.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';

/// Enhanced Call Manager with error handling and state management
class CallManager extends GetxController {
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal() {
    _ensureInitialized();
  }

  // Observable states
  final RxBool isInitialized = false.obs;
  final RxBool isInCall = false.obs;
  final RxString callStatus = 'ready'.obs;
  final RxString errorMessage = ''.obs;
  Future<void>? _initializationFuture;

  @override
  void onInit() {
    super.onInit();
    _ensureInitialized();
  }

  Future<void> _ensureInitialized() {
    _initializationFuture ??= _initializeService();
    return _initializationFuture!;
  }

  Future<void> _initializeService() async {
    try {
      // Validate Agora App ID
      if (AgoraConfig.appId == "YOUR_AGORA_APP_ID" ||
          AgoraConfig.appId.isEmpty) {
        throw Exception('Please configure your Agora App ID in AgoraConfig');
      }

      isInitialized.value = true;
      callStatus.value = 'ready';
      Loggers.success('Call Manager initialized successfully');
    } catch (e) {
      errorMessage.value = e.toString();
      callStatus.value = 'error';
      Loggers.error('Call Manager initialization failed: $e');
    }
  }

  /// Start voice call with comprehensive error handling
  Future<bool> startVoiceCall({
    required int userId1,
    required int userId2,
    String? token,
    String? channelId,
    bool shareTokenWithCallee = false,
  }) async {
    try {
      if (!isInitialized.value) {
        await _ensureInitialized();
      }
      if (!isInitialized.value) {
        throw Exception('Call service not initialized');
      }

      callStatus.value = 'connecting';
      Loggers.info('📞 Starting voice call: User $userId1 → User $userId2');

      final String finalChannelId = channelId ??
          AgoraConfig.generateChannelId(userId1, userId2, prefix: 'voice');
      final String? providedToken = token?.trim();
      final String? callerToken =
          (providedToken?.isNotEmpty ?? false) ? providedToken : null;

      await CallSignalingService.instance.createCall(
        callId: finalChannelId,
        callerId: userId1,
        calleeId: userId2,
        isVideo: false,
      );

      // For now, simulate success and optionally push incoming-call notification
      await Future.delayed(const Duration(milliseconds: 300));

      Loggers.info('📞 Sending voice call notification to user: $userId2');
      final bool pushSent = await _sendIncomingCallPush(
        isVideo: false,
        channelId: finalChannelId,
        token: shareTokenWithCallee ? callerToken : null,
        calleeId: userId2,
      );
      if (!pushSent) {
        // The FCM ring to the callee failed (backend push not configured, or
        // the callee has no device token). Do NOT abort the call: the call
        // session doc is already written, so the callee is still rung in-app by
        // IncomingCallWatcher (Firestore) when their app is open, and the caller
        // must still be able to enter the room and wait for them to answer.
        Loggers.warning(
            '📞 Call push to callee failed; continuing via in-app signalling');
      }

      isInCall.value = true;
      callStatus.value = 'connected';
      Loggers.success('📞 Voice call started: $finalChannelId (push=$pushSent)');
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      callStatus.value = 'error';
      Loggers.error('📞 Voice call failed: $e');
      return false;
    }
  }

  /// Start video call with comprehensive error handling
  Future<bool> startVideoCall({
    required int userId1,
    required int userId2,
    String? token,
    String? channelId,
    bool shareTokenWithCallee = false,
  }) async {
    try {
      if (!isInitialized.value) {
        await _ensureInitialized();
      }
      if (!isInitialized.value) {
        throw Exception('Call service not initialized');
      }

      callStatus.value = 'connecting';
      Loggers.info('📹 Starting video call: User $userId1 → User $userId2');

      final String finalChannelId = channelId ??
          AgoraConfig.generateChannelId(userId1, userId2, prefix: 'video');
      final String? providedToken = token?.trim();
      final String? callerToken =
          (providedToken?.isNotEmpty ?? false) ? providedToken : null;

      await CallSignalingService.instance.createCall(
        callId: finalChannelId,
        callerId: userId1,
        calleeId: userId2,
        isVideo: true,
      );

      // For now, simulate success and optionally push incoming-call notification
      await Future.delayed(const Duration(milliseconds: 300));

      Loggers.info('📹 Sending video call notification to user: $userId2');
      final bool pushSent = await _sendIncomingCallPush(
        isVideo: true,
        channelId: finalChannelId,
        token: shareTokenWithCallee ? callerToken : null,
        calleeId: userId2,
      );
      if (!pushSent) {
        // See startVoiceCall: a failed FCM ring must not abort the call. The
        // callee is also rung in-app via IncomingCallWatcher (Firestore).
        Loggers.warning(
            '📹 Call push to callee failed; continuing via in-app signalling');
      }

      isInCall.value = true;
      callStatus.value = 'connected';
      Loggers.success('📹 Video call started: $finalChannelId (push=$pushSent)');
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      callStatus.value = 'error';
      Loggers.error('📹 Video call failed: $e');
      return false;
    }
  }

  // Enhanced helper to trigger an incoming call push with detailed logging
  Future<bool> _sendIncomingCallPush({
    required bool isVideo,
    required String channelId,
    String? token,
    required int calleeId,
  }) async {
    try {
      Loggers.info(
          '📞 Preparing to send ${isVideo ? 'video' : 'voice'} call notification...');

      UserService? userService;
      try {
        userService = Get.find<UserService>();
      } catch (_) {
        userService = UserService.instance;
      }

      Loggers.info('📞 Fetching callee details for user: $calleeId');
      final callee = await userService.fetchUserDetails(userId: calleeId);

      if (callee?.deviceToken == null || (callee!.deviceToken ?? '').isEmpty) {
        Loggers.error('📞 ❌ Callee device token is empty or null');
        return false;
      }

      Loggers.info(
          '📞 ✅ Callee device token found: ${callee.deviceToken?.substring(0, 20)}...');

      final me = SessionManager.instance.getUser();
      if (me == null) {
        Loggers.error('📞 ❌ Current user not found in session');
        return false;
      }

      Loggers.info('📞 ✅ Caller info: ${me.fullname} (ID: ${me.id})');

      final data = {
        'callId': channelId,
        'channelId': channelId,
        'isVideo': isVideo ? 1 : 0,
        'token': token,
        'caller': me.toJson(),
      };

      Loggers.info('📞 Sending notification with payload: ${data.toString()}');

      final bool pushSuccess =
          await NotificationService.instance.pushNotification(
        type: NotificationType.call,
        title: me.fullname ?? 'Incoming call',
        body: isVideo ? 'Video call' : 'Voice call',
        data: data,
        token: callee.deviceToken,
        deviceType: callee.device,
      );
      if (!pushSuccess) {
        Loggers.error('📞 ❌ Push API reported failure for call notification');
        return false;
      }

      Loggers.success('📞 ✅ Call notification sent successfully');
      return true;
    } catch (e) {
      Loggers.error('📞 ❌ Failed to send call push: $e');
      return false;
    }
  }

  /// End call with cleanup
  Future<void> endCall() async {
    try {
      isInCall.value = false;
      callStatus.value = 'ready';
      errorMessage.value = '';
      Loggers.info('Call ended successfully');
    } catch (e) {
      Loggers.error('Error ending call: $e');
    }
  }

  /// Clear error messages
  void clearError() {
    errorMessage.value = '';
  }
}
