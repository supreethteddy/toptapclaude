import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/utils/agora_error_handler.dart';
import 'package:toptap/common/utils/network_checker.dart';
import 'package:toptap/common/utils/agora_debug_helper.dart';
import 'package:toptap/common/config/agora_config.dart';

/// Enhanced Agora Call Service with comprehensive error handling
class AgoraCallService {
  static final AgoraCallService _instance = AgoraCallService._internal();
  factory AgoraCallService() => _instance;
  AgoraCallService._internal();

  RtcEngine? _engine;
  bool _isEngineInitialized = false;

  // Call state management
  bool _isInCall = false;
  bool _isVideoCall = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerEnabled = true;
  bool _pendingSpeakerRouteApply = false;
  bool _isHandlingTokenError = false;
  bool _hasHandledTokenErrorForAttempt = false;
  bool _isRecoveringLocalVideo = false;
  bool _awaitingLocalVideoStart = false;
  int _localVideoRecoveryAttempts = 0;
  int? _remoteUid;
  String? _currentChannelId;
  String? _localVideoIssue;

  // Stream controllers for real-time updates
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  final StreamController<int?> _remoteUserController =
      StreamController<int?>.broadcast();
  final StreamController<bool> _callEndedController =
      StreamController<bool>.broadcast();
  final StreamController<String?> _localVideoIssueController =
      StreamController<String?>.broadcast();

  // Getters
  bool get isInCall => _isInCall;
  bool get isVideoCall => _isVideoCall;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  int? get remoteUid => _remoteUid;
  String? get localVideoIssue => _localVideoIssue;

  // Streams
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  Stream<int?> get remoteUserStream => _remoteUserController.stream;
  Stream<bool> get callEndedStream => _callEndedController.stream;
  Stream<String?> get localVideoIssueStream =>
      _localVideoIssueController.stream;

  void _emitConnectionState(bool isConnected) {
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(isConnected);
    }
  }

  void _emitRemoteUser(int? uid) {
    if (!_remoteUserController.isClosed) {
      _remoteUserController.add(uid);
    }
  }

  void _emitCallEnded(bool ended) {
    if (!_callEndedController.isClosed) {
      _callEndedController.add(ended);
    }
  }

  void _emitLocalVideoIssue(String? issue) {
    _localVideoIssue = issue;
    if (!_localVideoIssueController.isClosed) {
      _localVideoIssueController.add(issue);
    }
  }

  void _markLocalVideoHealthy() {
    _awaitingLocalVideoStart = false;
    _localVideoRecoveryAttempts = 0;
    if (_localVideoIssue != null) {
      Loggers.info('Local video capture recovered');
    }
    _emitLocalVideoIssue(null);
  }

  bool _isLikelyLocalVideoFailure(String stateName, String reasonName) {
    return stateName.contains('failed') ||
        reasonName.contains('failed') ||
        reasonName.contains('failure') ||
        reasonName.contains('device') ||
        reasonName.contains('capture') ||
        reasonName.contains('notfound') ||
        reasonName.contains('not_found') ||
        reasonName.contains('notready') ||
        reasonName.contains('not_ready');
  }

  bool _isLikelyLocalVideoActive(String stateName) {
    return stateName.contains('capturing') ||
        stateName.contains('encoding') ||
        stateName.contains('running');
  }

  Future<void> _scheduleLocalVideoStartupCheck() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!_isInCall || !_isVideoCall || !_isVideoEnabled || _engine == null) {
      return;
    }
    if (!_awaitingLocalVideoStart) {
      return;
    }

    Loggers.warning(
      'Local video did not reach capturing state in time; retrying',
    );
    _emitLocalVideoIssue('Camera is taking longer to start. Retrying...');
    await _recoverLocalVideoCapture(reason: 'startup_timeout');
  }

  Future<void> _recoverLocalVideoCapture({
    bool force = false,
    String reason = 'camera_issue',
  }) async {
    if (!_isInCall || !_isVideoCall || !_isVideoEnabled) return;
    if (_engine == null) return;
    if (_isRecoveringLocalVideo) return;
    if (!force && _localVideoRecoveryAttempts >= 4) return;

    _isRecoveringLocalVideo = true;
    _localVideoRecoveryAttempts += 1;
    _awaitingLocalVideoStart = true;

    final int attempt = _localVideoRecoveryAttempts;
    Loggers.warning(
      'Attempting local video recovery (attempt $attempt, reason: $reason)',
    );
    _emitLocalVideoIssue('Camera unavailable. Retrying (attempt $attempt)...');

    try {
      await _engine!.enableVideo();
      await _engine!.enableLocalVideo(true);

      // Auto restart sequence so users do not need manual toggle/switch.
      if (attempt >= 2) {
        try {
          await _engine!.muteLocalVideoStream(true);
          await Future.delayed(const Duration(milliseconds: 180));
        } catch (_) {}
      }

      await _engine!.muteLocalVideoStream(false);
      try {
        await _engine!.startPreview();
      } catch (_) {}

      if (attempt >= 3) {
        try {
          // Flip once and flip back to kick camera pipeline
          // while preserving original lens orientation.
          await _engine!.switchCamera();
          await Future.delayed(const Duration(milliseconds: 220));
          await _engine!.switchCamera();
        } catch (_) {
          // Some devices may not support camera switch in this state.
        }
      }

      await Future.delayed(const Duration(seconds: 2));
      if (_awaitingLocalVideoStart && attempt >= 4) {
        _emitLocalVideoIssue(
          'Camera unavailable. Close other camera apps and tap retry.',
        );
      }
    } catch (e) {
      Loggers.warning('Local video recovery failed: $e');
      if (attempt >= 4) {
        _emitLocalVideoIssue(
          'Camera unavailable. Close other camera apps and tap retry.',
        );
      }
    } finally {
      _isRecoveringLocalVideo = false;
    }
  }

  /// Manually retry local camera capture from UI.
  Future<void> retryLocalVideoCapture() async {
    _localVideoRecoveryAttempts = 0;
    await _recoverLocalVideoCapture(force: true, reason: 'manual_retry');
  }

  bool _isLikelyNetworkIssue(Object error) {
    final errorText = error.toString().toLowerCase();
    return errorText.contains('socketexception') ||
        errorText.contains('network') ||
        errorText.contains('connection') ||
        errorText.contains('timeout') ||
        errorText.contains('timed out') ||
        errorText.contains('failed host lookup') ||
        errorText.contains('unreachable') ||
        errorText.contains('errno');
  }

  int _normalizeAgoraErrorCode(int errorCode) {
    if (errorCode > 0) {
      return -errorCode;
    }
    return errorCode;
  }

  int? _extractAgoraRtcErrorCode(Object error) {
    final match = RegExp(
      r'AgoraRtcException\((-?\d+)',
    ).firstMatch(error.toString());
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  bool _isTokenErrorCode(int errorCode) {
    return [-102, -109, -110].contains(errorCode);
  }

  /// Initialize Agora engine with enhanced error handling
  Future<bool> initializeEngine({required String appId}) async {
    try {
      AgoraDebugHelper.debugPrint(
        '=== AGORA ENGINE INITIALIZATION START ===',
        emoji: '🚀',
      );
      AgoraDebugHelper.logEngineState(_engine, _isEngineInitialized);

      if (_isEngineInitialized) {
        AgoraDebugHelper.debugPrint(
          'Engine already initialized - skipping',
          emoji: '✅',
        );
        return true;
      }

      // Validate App ID with comprehensive checks
      AgoraDebugHelper.debugPrint('Validating App ID...', emoji: '🔍');
      bool isValidAppId = AgoraDebugHelper.validateAppId(appId);
      if (!isValidAppId) {
        AgoraErrorHandler.handleError(-22, context: 'Invalid App ID');
        return false;
      }

      // Check network connectivity
      AgoraDebugHelper.debugPrint(
        'Checking network connectivity...',
        emoji: '🌐',
      );
      bool hasInternet = await NetworkChecker.hasInternetConnection();
      String networkType = await NetworkChecker.getNetworkType();
      bool canReachAgora = await NetworkChecker.canReachAgoraServers();

      AgoraDebugHelper.logNetworkInfo(networkType, hasInternet, canReachAgora);

      if (!hasInternet) {
        AgoraDebugHelper.debugPrint(
          'No internet connection detected',
          emoji: '❌',
        );
        AgoraErrorHandler.handleError(-14, context: 'No internet connection');
        return false;
      }

      // Create Agora engine
      AgoraDebugHelper.debugPrint('Creating Agora RTC engine...', emoji: '🏗️');
      _engine = createAgoraRtcEngine();
      AgoraDebugHelper.debugPrint(
        'Agora RTC engine created successfully',
        emoji: '✅',
      );

      // Initialize engine context
      AgoraDebugHelper.debugPrint(
        'Initializing engine with context...',
        emoji: '⚙️',
      );
      await _engine!.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      AgoraDebugHelper.debugPrint('Engine context initialized', emoji: '✅');

      // Configure audio and video
      AgoraDebugHelper.debugPrint('Enabling video...', emoji: '📹');
      await _engine!.enableVideo();

      // Test video device capability
      try {
        print('📹 Testing video device capability...');
        final devices = await _engine!
            .getVideoDeviceManager()
            .enumerateVideoDevices();
        print('📹 Available video devices: ${devices.length}');
        for (var device in devices) {
          print('📹 Device: ${device.deviceName} (${device.deviceId})');
        }
      } catch (e) {
        print(
          '📹 Video device enumeration failed (may be normal on mobile): $e',
        );
      }

      AgoraDebugHelper.debugPrint('Enabling audio...', emoji: '🎵');
      await _engine!.enableAudio();

      // 🔊 CRITICAL: Set audio profile for optimal call quality
      AgoraDebugHelper.debugPrint('Setting audio profile...', emoji: '🎵');
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );

      // Enable local audio by default
      await _engine!.enableLocalAudio(true);
      print('🔊 Local audio enabled');

      AgoraDebugHelper.debugPrint(
        'Setting video encoder configuration...',
        emoji: '🎯',
      );
      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 480),
          frameRate: 15,
          bitrate: 0,
          orientationMode: OrientationMode.orientationModeAdaptive,
        ),
      );

      // Set up event handlers
      AgoraDebugHelper.debugPrint('Setting up event handlers...', emoji: '🔗');
      _setupEventHandlers();

      _isEngineInitialized = true;
      AgoraDebugHelper.logEngineState(_engine, _isEngineInitialized);
      AgoraDebugHelper.debugPrint(
        '=== ENGINE INITIALIZATION COMPLETE ===',
        emoji: '🎉',
      );

      Loggers.success('Agora engine initialized successfully on $networkType');
      return true;
    } catch (e, stackTrace) {
      AgoraDebugHelper.logError(
        e,
        'Engine Initialization',
        stackTrace: stackTrace,
      );
      Loggers.error('Failed to initialize Agora engine: $e');

      // Handle specific initialization errors
      if (_isLikelyNetworkIssue(e)) {
        AgoraErrorHandler.handleError(
          1,
          context: 'Initialization Error - Check internet connection',
        );
      } else {
        AgoraErrorHandler.handleError(-7, context: 'Engine Initialization');
      }
      return false;
    }
  }

  /// Setup comprehensive event handlers
  void _setupEventHandlers() {
    print('🔗 Setting up Agora event handlers...');

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('🎉 === JOIN CHANNEL SUCCESS ===');
          print('👤 Local UID: ${connection.localUid}');
          print('📺 Channel ID: ${connection.channelId}');
          print('⏱️ Elapsed: ${elapsed}ms');
          print('===============================');
          Loggers.info(
            'Local user ${connection.localUid} joined channel ${connection.channelId}',
          );
          _isHandlingTokenError = false;
          _emitConnectionState(true);
          unawaited(_applySpeakerRouteAfterJoin());
          if (_isVideoCall) {
            unawaited(_scheduleLocalVideoStartupCheck());
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('👥 === REMOTE USER JOINED ===');
          print('👤 Remote UID: $remoteUid');
          print('📺 Channel: ${connection.channelId}');
          print('⏱️ Elapsed: ${elapsed}ms');
          print('============================');
          Loggers.info('Remote user $remoteUid joined');
          _remoteUid = remoteUid;
          _emitRemoteUser(remoteUid);
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              print('👋 === REMOTE USER LEFT ===');
              print('👤 Remote UID: $remoteUid');
              print('📺 Channel: ${connection.channelId}');
              print('❓ Reason: ${reason.name}');
              print('==========================');
              Loggers.info('Remote user $remoteUid left: ${reason.name}');
              if (_remoteUid == remoteUid) {
                _remoteUid = null;
                _emitRemoteUser(null);
                // A one-to-one call is over when its only remote participant
                // leaves. Notify the screen so the remaining party exits too.
                if (_isInCall) {
                  _emitCallEnded(true);
                }
              }
            },
        onError: (ErrorCodeType err, String msg) {
          final int rawCode = err.value();
          final int normalizedCode = _normalizeAgoraErrorCode(rawCode);
          print('💥 === AGORA ERROR ===');
          print('🔢 Error Code: $rawCode');
          print('🔢 Normalized Error Code: $normalizedCode');
          print('📛 Error Name: ${err.name}');
          print('💬 Message: $msg');
          print('🔧 Engine State: $_isEngineInitialized');
          print('📞 In Call: $_isInCall');
          print('📺 Channel: $_currentChannelId');
          print('====================');
          Loggers.error('Agora error: ${err.name} - $msg');

          // Special debugging for token/auth errors
          if (_isTokenErrorCode(normalizedCode)) {
            print('🚨 === ERROR 110 DEBUG INFO ===');
            print('🔢 Error Code: $rawCode');
            print('📛 Error Name: ${err.name}');
            print('💬 Message: $msg');
            print('📺 Current Channel: $_currentChannelId');
            print('📞 Is In Call: $_isInCall');
            print('🔧 Engine Initialized: $_isEngineInitialized');
            print('===========================');
            unawaited(_handleTokenError(context: 'Authentication Error'));
          } else {
            AgoraErrorHandler.handleError(
              normalizedCode,
              context: 'Call Error',
            );
          }
        },
        onConnectionStateChanged:
            (
              RtcConnection connection,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              print('🔄 === CONNECTION STATE CHANGED ===');
              print('🔗 State: ${state.name}');
              print('❓ Reason: ${reason.name}');
              print('📺 Channel: ${connection.channelId}');
              print('👤 Local UID: ${connection.localUid}');
              print('==================================');
              Loggers.info('Connection state: ${state.name} - ${reason.name}');
              if (state == ConnectionStateType.connectionStateFailed) {
                if (reason ==
                    ConnectionChangedReasonType.connectionChangedInvalidToken) {
                  unawaited(_handleTokenError(context: 'Connection Failed'));
                  return;
                }
                print('❌ Connection failed - triggering error handler');
                AgoraErrorHandler.handleError(
                  -112,
                  context: 'Connection Failed',
                );
              }
            },
        onNetworkQuality:
            (
              RtcConnection connection,
              int remoteUid,
              QualityType txQuality,
              QualityType rxQuality,
            ) {
              // Only log if quality is poor to avoid spam
              if (txQuality.index > 3 || rxQuality.index > 3) {
                print('📊 === NETWORK QUALITY ===');
                print('📤 TX Quality: ${txQuality.name} (${txQuality.index})');
                print('📥 RX Quality: ${rxQuality.name} (${rxQuality.index})');
                print('👤 Remote UID: $remoteUid');
                print('=========================');
                Loggers.warning('Poor network quality detected');
              }
            },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          print('🚪 === LEFT CHANNEL ===');
          print('📺 Channel: ${connection.channelId}');
          print('⏱️ Duration: ${stats.duration}s');
          print('📊 TX Bytes: ${stats.txBytes}');
          print('📊 RX Bytes: ${stats.rxBytes}');
          print('======================');
          Loggers.info('Left channel: ${connection.channelId}');
          _emitCallEnded(true);
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          print('⚠️ === TOKEN EXPIRING ===');
          print('🔑 Token: ${token.substring(0, 10)}...');
          print('📺 Channel: ${connection.channelId}');
          print('=======================');
          Loggers.warning('Token will expire soon');
        },
        // 🔊 Audio state debugging callbacks
        onLocalAudioStateChanged:
            (
              RtcConnection connection,
              LocalAudioStreamState state,
              LocalAudioStreamReason reason,
            ) {
              print('🎤 === LOCAL AUDIO STATE ===');
              print('🔊 State: ${state.name}');
              print('❓ Reason: ${reason.name}');
              print('===========================');
              Loggers.info('Local audio: ${state.name} - ${reason.name}');
            },
        onLocalVideoStateChanged:
            (
              VideoSourceType source,
              LocalVideoStreamState state,
              LocalVideoStreamReason reason,
            ) {
              final String stateName = state.name.toLowerCase();
              final String reasonName = reason.name.toLowerCase();
              print('📷 === LOCAL VIDEO STATE ===');
              print('📹 Source: ${source.name}');
              print('🔊 State: ${state.name}');
              print('❓ Reason: ${reason.name}');
              print('===========================');
              Loggers.info(
                'Local video: ${state.name} - ${reason.name} (${source.name})',
              );

              if (_isLikelyLocalVideoActive(stateName)) {
                _markLocalVideoHealthy();
                return;
              }

              if (_isLikelyLocalVideoFailure(stateName, reasonName)) {
                _emitLocalVideoIssue('Camera unavailable. Retrying...');
                unawaited(_recoverLocalVideoCapture(reason: reason.name));
              }
            },
        onRemoteAudioStateChanged:
            (
              RtcConnection connection,
              int remoteUid,
              RemoteAudioState state,
              RemoteAudioStateReason reason,
              int elapsed,
            ) {
              print('🔈 === REMOTE AUDIO STATE ===');
              print('👤 Remote UID: $remoteUid');
              print('🔊 State: ${state.name}');
              print('❓ Reason: ${reason.name}');
              print('============================');
              Loggers.info(
                'Remote audio from $remoteUid: ${state.name} - ${reason.name}',
              );
            },
        onAudioRoutingChanged: (int routing) {
          print('🔊 === AUDIO ROUTING CHANGED ===');
          print('📢 Route: $routing');
          print('===============================');
          Loggers.info('Audio route: $routing');
        },
      ),
    );
    print('✅ Event handlers registered successfully');
  }

  /// Request necessary permissions with enhanced checking
  Future<bool> requestPermissions({bool videoCall = false}) async {
    try {
      print('🔐 === PERMISSION REQUEST START ===');
      print('📹 Video Call: $videoCall');

      List<Permission> permissions = [Permission.microphone];
      if (videoCall) {
        permissions.add(Permission.camera);
      }

      print(
        '📋 Requesting permissions: ${permissions.map((p) => p.toString()).join(', ')}',
      );

      Map<Permission, PermissionStatus> statuses = await permissions.request();

      print('📊 Permission Results:');
      statuses.forEach((permission, status) {
        print('  ${permission.toString()}: ${status.name}');
      });

      bool allGranted = statuses.values.every(
        (status) => status == PermissionStatus.granted,
      );

      if (!allGranted) {
        print('❌ Not all permissions granted');
        print(
          '🚫 Denied permissions: ${statuses.entries.where((e) => e.value != PermissionStatus.granted).map((e) => e.key.toString()).join(', ')}',
        );
        Loggers.error('Permissions not granted: $statuses');
        AgoraErrorHandler.handleError(-9, context: 'Permission Denied');
        return false;
      }

      print('✅ All permissions granted successfully');
      print('=================================');
      Loggers.info('All permissions granted');
      return true;
    } catch (e) {
      print('💥 Permission request failed: $e');
      print('🔍 Error Type: ${e.runtimeType}');
      Loggers.error('Error requesting permissions: $e');
      AgoraErrorHandler.handleError(-9, context: 'Permission Request Failed');
      return false;
    }
  }

  Future<void> _applySpeakerRouteAfterJoin() async {
    if (!_pendingSpeakerRouteApply && !_isInCall) return;
    if (_engine == null) return;
    if (!_isInCall) return;

    for (int i = 0; i < 3; i++) {
      try {
        await Future.delayed(const Duration(milliseconds: 180));
        await _engine!.setEnableSpeakerphone(_isSpeakerEnabled);
        _pendingSpeakerRouteApply = false;
        Loggers.info('Speaker route applied after join: $_isSpeakerEnabled');
        return;
      } catch (e) {
        if (i == 2) {
          Loggers.warning('Unable to apply speaker route after join: $e');
        }
      }
    }
  }

  /// Start audio call with comprehensive error handling
  Future<bool> startAudioCall({
    required String channelId,
    String? token,
  }) async {
    try {
      _hasHandledTokenErrorForAttempt = false;
      AgoraDebugHelper.debugPrint('=== AUDIO CALL START ===', emoji: '🎵');

      // Check token requirements FIRST
      bool tokenRequired = AgoraConfig.isTokenMandatory();
      AgoraDebugHelper.debugPrint(
        'Token authentication required: $tokenRequired',
        emoji: '🔑',
      );

      // Use stable user id as Agora uid; fallback to a non-zero random if missing.
      final int finalUid =
          SessionManager.instance.getUser()?.id ??
          DateTime.now().millisecondsSinceEpoch.remainder(900000000) + 1;

      // Resolve token from runtime payload or local config.
      String? finalToken = AgoraConfig.resolveCallToken(
        runtimeToken: token,
        channelId: channelId,
        uid: finalUid,
      );
      AgoraDebugHelper.debugPrint(
        'Resolved token for uid $finalUid: ${finalToken ?? 'null'}',
        emoji: '🎫',
      );
      finalToken = finalToken?.trim();
      if (finalToken?.isEmpty ?? false) {
        finalToken = null;
      }

      // Validate token requirements
      if (tokenRequired && (finalToken == null || finalToken.isEmpty)) {
        AgoraDebugHelper.debugPrint(
          '❌ ERROR: Token authentication is required but no valid token available',
          emoji: '🚫',
        );
        AgoraDebugHelper.debugPrint(
          '💡 SOLUTION: Provide RTC token from backend or disable Primary Certificate in Agora Console for testing',
          emoji: '💡',
        );
        AgoraErrorHandler.handleError(
          -110,
          context: 'Token authentication required but no valid token',
        );
        return false;
      }

      // Check all requirements
      Map<String, bool> requirements =
          await AgoraDebugHelper.checkCallRequirements(
            appId: AgoraConfig.appId,
            channelId: channelId,
            isVideoCall: false,
            token: finalToken,
          );

      if (!requirements.values.every((v) => v)) {
        AgoraDebugHelper.debugPrint(
          'Requirements not met - cannot start call',
          emoji: '❌',
        );
        return false;
      }

      AgoraDebugHelper.logCallState(
        isInCall: _isInCall,
        isVideoCall: _isVideoCall,
        isMuted: _isMuted,
        isVideoEnabled: _isVideoEnabled,
        isSpeakerEnabled: _isSpeakerEnabled,
        remoteUid: _remoteUid,
        channelId: _currentChannelId,
      );

      if (!_isEngineInitialized) {
        AgoraDebugHelper.debugPrint('Engine not initialized', emoji: '❌');
        AgoraErrorHandler.handleError(-3, context: 'Engine not initialized');
        return false;
      }

      // Check permissions
      AgoraDebugHelper.debugPrint('Checking permissions...', emoji: '🔐');
      await AgoraDebugHelper.logPermissionStatus(isVideoCall: false);
      bool hasPermissions = await requestPermissions(videoCall: false);
      if (!hasPermissions) {
        AgoraDebugHelper.debugPrint('Permissions not granted', emoji: '❌');
        return false;
      }

      // Disable video for audio call
      AgoraDebugHelper.debugPrint(
        'Disabling video for audio call...',
        emoji: '📹',
      );
      await _engine!.disableVideo();
      _awaitingLocalVideoStart = false;
      _emitLocalVideoIssue(null);

      // Configure channel options
      AgoraDebugHelper.debugPrint(
        'Configuring channel media options...',
        emoji: '⚙️',
      );
      ChannelMediaOptions options = const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
      );

      // If already in the same channel, just update media options instead of re-joining
      if (_isInCall && _currentChannelId == channelId) {
        AgoraDebugHelper.debugPrint(
          'Already in channel "$channelId" – updating media options for audio-only',
          emoji: '🔄',
        );
        await _engine!.updateChannelMediaOptions(options);
      } else {
        // If in a different channel, leave first
        if (_isInCall && _currentChannelId != channelId) {
          AgoraDebugHelper.debugPrint(
            'Switching channel: leaving $_currentChannelId before joining $channelId',
            emoji: '🚪',
          );
          try {
            await _engine!.leaveChannel();
            await _engine!.stopPreview();
          } catch (_) {}
          _resetCallState();
        }

        // Join channel
        AgoraDebugHelper.logJoinChannelAttempt(
          channelId: channelId,
          token: finalToken,
          uid: finalUid,
          isVideoCall: false,
        );
        await _engine!.joinChannel(
          token: finalToken ?? '',
          channelId: channelId,
          uid: finalUid,
          options: options,
        );
      }

      // Mark call as active right after successful join request.
      _isInCall = true;
      _isVideoCall = false;
      _currentChannelId = channelId;

      // 🔊 CRITICAL: Enable audio after joining channel
      AgoraDebugHelper.debugPrint('Enabling local audio...', emoji: '🔊');
      await _engine!.enableLocalAudio(true);
      await _engine!.muteLocalAudioStream(_isMuted);

      // Set audio route - use earpiece for voice calls (like phone)
      // Speaker can be toggled later by user
      try {
        await _engine!.setEnableSpeakerphone(_isSpeakerEnabled);
        _pendingSpeakerRouteApply = false;
      } catch (e) {
        _pendingSpeakerRouteApply = true;
        Loggers.warning('Unable to set initial speaker route: $e');
      }

      // Adjust audio profile for voice call quality
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );

      AgoraDebugHelper.debugPrint(
        'Audio configuration complete - Local audio enabled, Speaker: $_isSpeakerEnabled',
        emoji: '✅',
      );

      AgoraDebugHelper.logCallState(
        isInCall: _isInCall,
        isVideoCall: _isVideoCall,
        isMuted: _isMuted,
        isVideoEnabled: _isVideoEnabled,
        isSpeakerEnabled: _isSpeakerEnabled,
        remoteUid: _remoteUid,
        channelId: _currentChannelId,
      );

      AgoraDebugHelper.debugPrint(
        '=== AUDIO CALL SETUP COMPLETE ===',
        emoji: '🎉',
      );
      Loggers.success('Audio call started: $channelId');
      return true;
    } catch (e, stackTrace) {
      AgoraDebugHelper.logError(e, 'Start Audio Call', stackTrace: stackTrace);
      Loggers.error('Error starting audio call: $e');
      _resetCallState();

      final int? rtcCode = _extractAgoraRtcErrorCode(e);
      if (rtcCode != null) {
        AgoraErrorHandler.handleError(
          _normalizeAgoraErrorCode(rtcCode),
          context: 'Start Audio Call',
        );
      } else if (_isLikelyNetworkIssue(e)) {
        AgoraErrorHandler.handleError(1, context: 'Connection Error');
      } else {
        AgoraErrorHandler.handleError(-1, context: 'Start Audio Call');
      }
      return false;
    }
  }

  /// Start video call with comprehensive error handling
  Future<bool> startVideoCall({
    required String channelId,
    String? token,
  }) async {
    try {
      _hasHandledTokenErrorForAttempt = false;
      AgoraDebugHelper.debugPrint('=== VIDEO CALL START ===', emoji: '📹');

      // Check token requirements FIRST
      bool tokenRequired = AgoraConfig.isTokenMandatory();
      AgoraDebugHelper.debugPrint(
        'Token authentication required: $tokenRequired',
        emoji: '🔑',
      );

      // Use stable user id as Agora uid; fallback to a non-zero random if missing.
      final int finalUid =
          SessionManager.instance.getUser()?.id ??
          DateTime.now().millisecondsSinceEpoch.remainder(900000000) + 1;

      // Resolve token from runtime payload or local config.
      String? finalToken = AgoraConfig.resolveCallToken(
        runtimeToken: token,
        channelId: channelId,
        uid: finalUid,
      );
      AgoraDebugHelper.debugPrint(
        'Resolved token for uid $finalUid: ${finalToken ?? 'null'}',
        emoji: '🎫',
      );
      finalToken = finalToken?.trim();
      if (finalToken?.isEmpty ?? false) {
        finalToken = null;
      }

      // Validate token requirements
      if (tokenRequired && (finalToken == null || finalToken.isEmpty)) {
        AgoraDebugHelper.debugPrint(
          '❌ ERROR: Token authentication is required but no valid token available',
          emoji: '🚫',
        );
        AgoraDebugHelper.debugPrint(
          '💡 SOLUTION: Provide RTC token from backend or disable Primary Certificate in Agora Console for testing',
          emoji: '💡',
        );
        AgoraErrorHandler.handleError(
          -110,
          context: 'Token authentication required but no valid token',
        );
        return false;
      }

      // Check all requirements
      Map<String, bool> requirements =
          await AgoraDebugHelper.checkCallRequirements(
            appId: AgoraConfig.appId,
            channelId: channelId,
            isVideoCall: true,
            token: finalToken,
          );

      if (!requirements.values.every((v) => v)) {
        AgoraDebugHelper.debugPrint(
          'Requirements not met - cannot start video call',
          emoji: '❌',
        );
        return false;
      }

      AgoraDebugHelper.logCallState(
        isInCall: _isInCall,
        isVideoCall: _isVideoCall,
        isMuted: _isMuted,
        isVideoEnabled: _isVideoEnabled,
        isSpeakerEnabled: _isSpeakerEnabled,
        remoteUid: _remoteUid,
        channelId: _currentChannelId,
      );

      if (!_isEngineInitialized) {
        AgoraDebugHelper.debugPrint('Engine not initialized', emoji: '❌');
        AgoraErrorHandler.handleError(-3, context: 'Engine not initialized');
        return false;
      }

      // Check permissions (including camera)
      AgoraDebugHelper.debugPrint(
        'Checking permissions (including camera)...',
        emoji: '🔐',
      );
      await AgoraDebugHelper.logPermissionStatus(isVideoCall: true);
      bool hasPermissions = await requestPermissions(videoCall: true);
      if (!hasPermissions) {
        AgoraDebugHelper.debugPrint('Permissions not granted', emoji: '❌');
        return false;
      }

      // Enable video and start preview
      AgoraDebugHelper.debugPrint('Enabling video...', emoji: '📹');
      await _engine!.enableVideo();
      _awaitingLocalVideoStart = true;
      _localVideoRecoveryAttempts = 0;
      _emitLocalVideoIssue('Starting camera...');

      AgoraDebugHelper.debugPrint('Starting camera preview...', emoji: '🎬');
      try {
        await _engine!.startPreview();
      } catch (e) {
        Loggers.warning('Camera preview start failed before join: $e');
        _emitLocalVideoIssue('Camera unavailable. Retrying...');
      }

      // Prefer speakerphone for video calls.
      _isSpeakerEnabled = true;

      // Configure channel options
      AgoraDebugHelper.debugPrint(
        'Configuring channel media options for video...',
        emoji: '⚙️',
      );
      ChannelMediaOptions options = const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      );

      // If already in the same channel, just update media options instead of re-joining (avoids -17)
      if (_isInCall && _currentChannelId == channelId) {
        AgoraDebugHelper.debugPrint(
          'Already in channel "$channelId" – updating media options for video',
          emoji: '🔄',
        );
        await _engine!.updateChannelMediaOptions(options);
      } else {
        // If in a different channel, leave first
        if (_isInCall && _currentChannelId != channelId) {
          AgoraDebugHelper.debugPrint(
            'Switching channel: leaving $_currentChannelId before joining $channelId',
            emoji: '🚪',
          );
          try {
            await _engine!.leaveChannel();
            await _engine!.stopPreview();
          } catch (_) {}
          _resetCallState();
        }

        // Join channel
        AgoraDebugHelper.logJoinChannelAttempt(
          channelId: channelId,
          token: finalToken,
          uid: finalUid,
          isVideoCall: true,
        );
        await _engine!.joinChannel(
          token: finalToken ?? '',
          channelId: channelId,
          uid: finalUid,
          options: options,
        );
      }

      // 🔊 CRITICAL: Enable audio after joining channel for video call too
      _isInCall = true;
      _isVideoCall = true;
      _currentChannelId = channelId;

      AgoraDebugHelper.debugPrint(
        'Enabling local audio for video call...',
        emoji: '🔊',
      );
      await _engine!.enableLocalAudio(true);
      await _engine!.muteLocalAudioStream(_isMuted);

      // Enable local video
      await _engine!.enableLocalVideo(true);
      await _engine!.muteLocalVideoStream(false);

      // Speakerphone for video calls
      try {
        await _engine!.setEnableSpeakerphone(true);
        _isSpeakerEnabled = true;
        _pendingSpeakerRouteApply = false;
      } catch (e) {
        _pendingSpeakerRouteApply = true;
        Loggers.warning('Unable to force speakerphone for video call: $e');
      }

      AgoraDebugHelper.debugPrint(
        'Audio and video configuration complete',
        emoji: '✅',
      );
      unawaited(_scheduleLocalVideoStartupCheck());

      AgoraDebugHelper.logCallState(
        isInCall: _isInCall,
        isVideoCall: _isVideoCall,
        isMuted: _isMuted,
        isVideoEnabled: _isVideoEnabled,
        isSpeakerEnabled: _isSpeakerEnabled,
        remoteUid: _remoteUid,
        channelId: _currentChannelId,
      );

      AgoraDebugHelper.debugPrint(
        '=== VIDEO CALL SETUP COMPLETE ===',
        emoji: '🎉',
      );
      Loggers.success('Video call started: $channelId');
      return true;
    } catch (e, stackTrace) {
      AgoraDebugHelper.logError(e, 'Start Video Call', stackTrace: stackTrace);
      Loggers.error('Error starting video call: $e');
      _resetCallState();

      final int? rtcCode = _extractAgoraRtcErrorCode(e);
      if (rtcCode != null) {
        AgoraErrorHandler.handleError(
          _normalizeAgoraErrorCode(rtcCode),
          context: 'Start Video Call',
        );
      } else if (_isLikelyNetworkIssue(e)) {
        AgoraErrorHandler.handleError(1, context: 'Connection Error');
      } else {
        AgoraErrorHandler.handleError(-1, context: 'Start Video Call');
      }
      return false;
    }
  }

  /// End call with proper cleanup
  Future<void> endCall() async {
    try {
      if (_engine != null && _isInCall) {
        await _engine!.leaveChannel();
        if (_isVideoCall) {
          await _engine!.stopPreview();
        }
      }

      _resetCallState();
      _emitConnectionState(false);
      _emitRemoteUser(null);
      Loggers.info('Call ended successfully');
    } catch (e) {
      Loggers.error('Error ending call: $e');
      _resetCallState();
      _emitConnectionState(false);
      _emitRemoteUser(null);
    }
  }

  /// Toggle mute state
  Future<void> toggleMute() async {
    try {
      final bool nextState = !_isMuted;
      _isMuted = nextState;

      if (_engine != null) {
        await _engine!.muteLocalAudioStream(nextState);
      }
      Loggers.info('Microphone ${_isMuted ? 'muted' : 'unmuted'}');
    } catch (e) {
      Loggers.warning('Unable to apply mute immediately, state queued: $e');
    }
  }

  /// Toggle video
  Future<void> toggleVideo() async {
    try {
      if (_engine != null && _isInCall && _isVideoCall) {
        final bool nextState = !_isVideoEnabled;
        if (nextState) {
          _awaitingLocalVideoStart = true;
          _emitLocalVideoIssue('Starting camera...');
          await _engine!.enableLocalVideo(true);
          await _engine!.muteLocalVideoStream(false);
          try {
            await _engine!.startPreview();
          } catch (_) {}
          unawaited(_scheduleLocalVideoStartupCheck());
        } else {
          _awaitingLocalVideoStart = false;
          _emitLocalVideoIssue(null);
          await _engine!.muteLocalVideoStream(true);
        }
        _isVideoEnabled = nextState;
        Loggers.info('Video ${_isVideoEnabled ? 'enabled' : 'disabled'}');
      }
    } catch (e) {
      Loggers.error('Error toggling video: $e');
    }
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    try {
      final bool nextState = !_isSpeakerEnabled;
      _isSpeakerEnabled = nextState;

      if (_engine != null) {
        await _engine!.setEnableSpeakerphone(nextState);
        _pendingSpeakerRouteApply = false;
      }
      Loggers.info('Speaker ${_isSpeakerEnabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _pendingSpeakerRouteApply = true;
      Loggers.warning('Unable to change speaker route immediately: $e');
    }
  }

  /// Switch camera
  Future<void> switchCamera() async {
    try {
      if (_engine != null && _isInCall && _isVideoCall) {
        await _engine!.switchCamera();
        _awaitingLocalVideoStart = true;
        unawaited(_scheduleLocalVideoStartupCheck());
        Loggers.info('Camera switched');
      }
    } catch (e) {
      Loggers.error('Error switching camera: $e');
    }
  }

  /// Get local video view widget
  /// Pass [forceVideoCall] to override the internal _isVideoCall state check
  Widget? getLocalVideoView({bool forceVideoCall = false}) {
    final isVideoCallActive = forceVideoCall || _isVideoCall;
    if (_engine != null && isVideoCallActive && _isVideoEnabled) {
      print(
        '📹 Creating local video view - Engine: ${_engine != null}, VideoCall: $isVideoCallActive, VideoEnabled: $_isVideoEnabled',
      );
      try {
        return AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine!,
            canvas: const VideoCanvas(uid: 0),
          ),
        );
      } catch (e) {
        print('❌ Error creating local video view: $e');
        return Container(
          color: Colors.red,
          child: Center(
            child: Text(
              'Local Video Error: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
    print(
      '📹 Local video view conditions not met - Engine: ${_engine != null}, VideoCall: $isVideoCallActive, VideoEnabled: $_isVideoEnabled',
    );
    return null;
  }

  /// Get remote video view widget
  /// Pass [forceVideoCall] to override the internal _isVideoCall state check
  Widget? getRemoteVideoView({bool forceVideoCall = false}) {
    final isVideoCallActive = forceVideoCall || _isVideoCall;
    if (_engine != null && isVideoCallActive && _remoteUid != null) {
      print(
        '📹 Creating remote video view for UID: $_remoteUid - Engine: ${_engine != null}, VideoCall: $isVideoCallActive',
      );
      try {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine!,
            canvas: VideoCanvas(uid: _remoteUid!),
            connection: RtcConnection(channelId: _currentChannelId),
          ),
        );
      } catch (e) {
        print('❌ Error creating remote video view for UID $_remoteUid: $e');
        return Container(
          color: Colors.blue,
          child: Center(
            child: Text(
              'Remote Video Error: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
    print(
      '📹 Remote video view conditions not met - Engine: ${_engine != null}, VideoCall: $isVideoCallActive, RemoteUID: $_remoteUid',
    );
    return null;
  }

  /// Reset call state
  void _resetCallState() {
    _isInCall = false;
    _isVideoCall = false;
    _isMuted = false;
    _isVideoEnabled = true;
    _isSpeakerEnabled = true;
    _pendingSpeakerRouteApply = false;
    _isRecoveringLocalVideo = false;
    _awaitingLocalVideoStart = false;
    _localVideoRecoveryAttempts = 0;
    _remoteUid = null;
    _currentChannelId = null;
    _emitLocalVideoIssue(null);
  }

  /// Handle token error (error 110)
  Future<void> _handleTokenError({
    String context = 'Authentication Error',
  }) async {
    if (_hasHandledTokenErrorForAttempt || _isHandlingTokenError) {
      return;
    }
    _hasHandledTokenErrorForAttempt = true;
    _isHandlingTokenError = true;
    Loggers.error('Token error detected - attempting to handle');

    // End current call if in progress
    if (_isInCall) {
      await endCall();
    }

    // Show specific error message for token issue
    AgoraErrorHandler.handleError(-110, context: context);

    // Reset engine state to force reinitialization with new token
    _isEngineInitialized = false;

    // Attempt to reinitialize only if a token is available.
    if (AgoraConfig.hasConfiguredToken()) {
      _attemptTokenRecovery();
      return;
    }
    Loggers.warning('Skipping token recovery - no token configured');
    _isHandlingTokenError = false;
    return;
  }

  /// Attempt to recover from token error
  Future<void> _attemptTokenRecovery() async {
    Loggers.info('Attempting token recovery...');

    try {
      // Dispose current engine
      if (_engine != null) {
        await _engine!.release();
        _engine = null;
      }

      // Wait a moment before reinitializing
      await Future.delayed(const Duration(seconds: 2));

      // Reinitialize with the same app ID
      bool success = await initializeEngine(appId: AgoraConfig.appId);

      if (success) {
        Loggers.success('Token recovery successful - engine reinitialized');
      } else {
        Loggers.error('Token recovery failed - please restart the app');
      }
    } catch (e) {
      Loggers.error('Error during token recovery: $e');
    } finally {
      _isHandlingTokenError = false;
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    try {
      if (_isInCall) {
        await endCall();
      }

      if (_engine != null) {
        await _engine!.release();
        _engine = null;
      }
      _emitConnectionState(false);
      _emitRemoteUser(null);
      _isEngineInitialized = false;
      _resetCallState();
      Loggers.info('Agora service disposed');
    } catch (e) {
      Loggers.error('Error disposing Agora service: $e');
    }
  }
}
