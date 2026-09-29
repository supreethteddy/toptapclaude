import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/call_manager.dart';
import 'package:shortzz/common/service/zego_call_service.dart';
import 'package:shortzz/common/service/call_signaling_service.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/common/config/agora_config.dart';
import 'package:shortzz/common/utils/agora_diagnostic.dart';
import 'package:shortzz/common/utils/agora_debug_helper.dart';

class CallScreen extends StatefulWidget {
  final User user;
  final bool isVideoCall;
  final String channelId;
  final String? callId;
  final String? token;

  const CallScreen({
    super.key,
    required this.user,
    required this.isVideoCall,
    required this.channelId,
    this.callId,
    this.token,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final ZegoCallService _callService = ZegoCallService();
  bool _isConnected = false;
  bool _hasRemoteUser = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerEnabled = true;
  late String _channelId; // effective channel
  String _runtimeToken = '';
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<int?>? _remoteUserSubscription;
  StreamSubscription<bool>? _callEndedSubscription;
  StreamSubscription<CallSignalStatus?>? _signalSubscription;
  bool _isEndingCall = false;
  bool _isErrorDialogVisible = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // ✅ Use effective channel ID (respects fixed test channel setting)
    _channelId = AgoraConfig.effectiveChannelId(widget.channelId);
    _runtimeToken = widget.token ?? '';
    _listenForRemoteCallState();
    _initializeCall();
    _setupListeners();
  }

  void _listenForRemoteCallState() {
    final callId = widget.callId ?? widget.channelId;
    _signalSubscription = CallSignalingService.instance.watch(callId).listen(
      (status) {
        if (!mounted || _isDisposed || _isEndingCall) return;
        if (status == CallSignalStatus.declined ||
            status == CallSignalStatus.missed ||
            status == CallSignalStatus.failed ||
            status == CallSignalStatus.ended) {
          final message = switch (status) {
            CallSignalStatus.declined => 'Call declined',
            CallSignalStatus.missed => 'Call was not answered',
            CallSignalStatus.failed => 'Could not reach this user',
            _ => 'Call ended',
          };
          Get.snackbar('Call', message);
          _endCall();
        }
      },
      onError: (Object error) {
        AgoraDebugHelper.debugPrint('Call signalling listener failed: $error');
      },
    );
  }

  Future<void> _initializeCall() async {
    try {
      // Debug: Log call initialization details
      AgoraDebugHelper.debugPrint('=== CALL SCREEN INITIALIZATION START ===',
          emoji: '🚀');
      AgoraDebugHelper.debugPrint('App ID: ${AgoraConfig.appId}');
      AgoraDebugHelper.debugPrint('Channel ID: $_channelId');
      AgoraDebugHelper.debugPrint(
          'Token: ${_runtimeToken.isEmpty ? "null (no token)" : "Provided/Runtime"}');
      AgoraDebugHelper.debugPrint('Is Video Call: ${widget.isVideoCall}');
      AgoraDebugHelper.debugPrint('User ID: ${widget.user.id ?? "Unknown"}');

      // Check all requirements before starting
      Map<String, bool> requirements =
          await AgoraDebugHelper.checkCallRequirements(
        appId: AgoraConfig.appId,
        channelId: _channelId,
        isVideoCall: widget.isVideoCall,
        token: _runtimeToken.isEmpty ? null : _runtimeToken,
      );

      if (!requirements.values.every((v) => v)) {
        AgoraDebugHelper.debugPrint('Call requirements not met - aborting',
            emoji: '❌');
        _showErrorAndExit(
            'Call requirements not met. Check permissions and network.');
        return;
      }

      // Initialize Agora with App ID from config
      AgoraDebugHelper.debugPrint('Initializing Agora engine...', emoji: '🔧');
      bool initialized =
          await _callService.initializeEngine(appId: AgoraConfig.appId);
      if (!initialized) {
        AgoraDebugHelper.debugPrint('Engine initialization failed', emoji: '❌');
        _showErrorAndExit('Failed to initialize call engine');
        return;
      }
      AgoraDebugHelper.debugPrint('Engine initialized successfully',
          emoji: '✅');

      // Small delay to ensure engine is ready
      AgoraDebugHelper.debugPrint('Waiting for engine to be ready...',
          emoji: '⏳');
      await Future.delayed(const Duration(milliseconds: 500));

      // Start the call
      AgoraDebugHelper.debugPrint('Starting call...', emoji: '📞');
      bool callStarted;
      if (widget.isVideoCall) {
        AgoraDebugHelper.debugPrint('Starting video call...', emoji: '📹');
        callStarted = await _callService.startVideoCall(
          channelId: _channelId,
          token: _runtimeToken.isEmpty ? null : _runtimeToken,
        );
      } else {
        AgoraDebugHelper.debugPrint('Starting audio call...', emoji: '🎵');
        callStarted = await _callService.startAudioCall(
          channelId: _channelId,
          token: _runtimeToken.isEmpty ? null : _runtimeToken,
        );
      }

      if (!callStarted) {
        AgoraDebugHelper.debugPrint('Call start failed', emoji: '❌');
        _showErrorAndExit('Failed to start call');
        return;
      }

      // Trigger UI rebuild now that call is started
      if (mounted) {
        setState(() {
          _isMuted = _callService.isMuted;
          _isVideoEnabled = _callService.isVideoEnabled;
          _isSpeakerEnabled = _callService.isSpeakerEnabled;
        });
      }

      AgoraDebugHelper.debugPrint('=== CALL INITIALIZATION COMPLETE ===',
          emoji: '🎉');
      AgoraDebugHelper.debugPrint('Call started successfully');
      AgoraDebugHelper.debugPrint('Channel: $_channelId');
      AgoraDebugHelper.debugPrint('Video: ${widget.isVideoCall}');
    } catch (e, stackTrace) {
      AgoraDebugHelper.logError(e, 'Call Screen Initialization',
          stackTrace: stackTrace);
      _showErrorAndExit('Call initialization failed: $e');
    }
  }

  void _setupListeners() {
    AgoraDebugHelper.debugPrint('=== SETTING UP CALL LISTENERS ===',
        emoji: '🔗');

    _connectionSubscription =
        _callService.connectionStateStream.listen((isConnected) {
      AgoraDebugHelper.debugPrint('Connection state changed: $isConnected',
          emoji: '🔗');
      if (!mounted) return;
      setState(() {
        _isConnected = isConnected;
      });
    });

    _remoteUserSubscription = _callService.remoteUserStream.listen((remoteUid) {
      AgoraDebugHelper.debugPrint('Remote user state changed: $remoteUid',
          emoji: '👥');
      if (!mounted) return;
      setState(() {
        _hasRemoteUser = remoteUid != null;
      });
      if (remoteUid != null) {
        AgoraDebugHelper.debugPrint('Remote user joined: $remoteUid',
            emoji: '🎉');
      } else {
        AgoraDebugHelper.debugPrint('Remote user left', emoji: '👋');
      }
    });

    _callEndedSubscription = _callService.callEndedStream.listen((ended) {
      AgoraDebugHelper.debugPrint('Call ended stream: $ended', emoji: '🔚');
      if (!mounted || _isDisposed || _isEndingCall) return;
      if (ended) {
        AgoraDebugHelper.debugPrint('Call ended - exiting screen', emoji: '📞');
        if (_callService.isInCall) {
          _endCall();
        } else {
          _popCallScreen();
        }
      }
    });

    AgoraDebugHelper.debugPrint('Call listeners set up successfully',
        emoji: '✅');
  }

  void _showErrorAndExit(String message) {
    if (!mounted || _isErrorDialogVisible) return;
    _isErrorDialogVisible = true;
    Get.dialog(
      AlertDialog(
        title: const Text('Call Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (message.contains('110') ||
                message.toLowerCase().contains('token'))
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Error 110 usually indicates a token or authentication issue. Try restarting the call.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _closeCurrentDialog();
              _popCallScreen();
            },
            child: const Text('Exit'),
          ),
          if (message.contains('110') ||
              message.toLowerCase().contains('token'))
            ElevatedButton(
              onPressed: () {
                _closeCurrentDialog();
                _retryCall(); // Retry the call
              },
              child: const Text('Retry'),
            ),
          ElevatedButton(
            onPressed: () {
              _closeCurrentDialog();
              // Pass error 110 to diagnostic if it's a token error
              int? errorCode = message.contains('110') ? -110 : null;
              AgoraCallDiagnostic.runDiagnostic(specificError: errorCode);
            },
            child: const Text('Diagnose'),
          ),
        ],
      ),
    ).whenComplete(() {
      _isErrorDialogVisible = false;
    });
  }

  Future<void> _retryCall() async {
    print('=== RETRYING CALL DUE TO ERROR 110 ===');

    // Force dispose and reinitialize
    await _callService.dispose();
    await Future.delayed(const Duration(seconds: 1));

    // Retry initialization
    await _initializeCall();
  }

  void _closeCurrentDialog() {
    _isErrorDialogVisible = false;
    if (!mounted || _isDisposed) return;
    final navigator = Get.key.currentState;
    if ((Get.isDialogOpen ?? false) &&
        navigator != null &&
        navigator.canPop()) {
      navigator.pop();
    }
  }

  void _popCallScreen() {
    _isErrorDialogVisible = false;
    if (!mounted || _isDisposed) return;

    final route = ModalRoute.of(context);
    if (route == null) return;
    final navigator = route.navigator;
    if (navigator == null) return;

    // A notification action or snackbar may have placed another route above
    // this one, so pop back down to this route first (a no-op if it's already
    // current), then pop it normally. Reproduced bug: this used to call
    // navigator.removeRoute(route) directly, which bypasses Navigator's usual
    // pop bookkeeping — ending one call, then immediately starting a second
    // one, left the caller's next Get.to() silently do nothing (the callee
    // still rang correctly, since that path doesn't touch the caller's
    // Navigator at all). popUntil + pop uses only standard Navigator/GetX
    // paths and doesn't have that problem.
    navigator.popUntil((r) => r == route);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _endCall() {
    if (_isEndingCall) return;
    _isEndingCall = true;
    _isErrorDialogVisible = false;
    unawaited(_endCallInternal());
  }

  Future<void> _endCallInternal() async {
    print('🔚 === ENDING CALL ===');
    print('📞 Was in call: $_isConnected');
    print('👥 Had remote user: $_hasRemoteUser');
    print('===================');

    try {
      await CallSignalingService.instance.updateStatus(
        widget.callId ?? widget.channelId,
        CallSignalStatus.ended,
      );
      await _callService.endCall();
      await CallManager().endCall();
      print('✅ Call service ended');
      _popCallScreen();
      print('✅ Navigated back');
    } finally {
      _isEndingCall = false;
    }
  }

  void _toggleMute() async {
    print('🔇 === TOGGLE MUTE ===');
    print('🎤 Current mute state: $_isMuted');

    await _callService.toggleMute();
    if (!mounted || _isDisposed) return;
    setState(() {
      _isMuted = _callService.isMuted;
    });

    print('🎤 New mute state: $_isMuted');
    print('==================');
  }

  void _toggleVideo() async {
    if (widget.isVideoCall) {
      print('📹 === TOGGLE VIDEO ===');
      print('📹 Current video state: $_isVideoEnabled');

      await _callService.toggleVideo();
      if (!mounted || _isDisposed) return;
      setState(() {
        _isVideoEnabled = _callService.isVideoEnabled;
      });

      print('📹 New video state: $_isVideoEnabled');
      print('===================');
    }
  }

  void _toggleSpeaker() async {
    print('🔊 === TOGGLE SPEAKER ===');
    print('🔊 Current speaker state: $_isSpeakerEnabled');

    await _callService.toggleSpeaker();
    if (!mounted || _isDisposed) return;
    setState(() {
      _isSpeakerEnabled = _callService.isSpeakerEnabled;
    });

    print('🔊 New speaker state: $_isSpeakerEnabled');
    print('=====================');
  }

  void _switchCamera() async {
    if (widget.isVideoCall) {
      print('🔄 === SWITCH CAMERA ===');
      await _callService.switchCamera();
      print('✅ Camera switched');
      print('===================');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug video view state - pass widget.isVideoCall to force video call mode
    final localVideoView =
        _callService.getLocalVideoView(forceVideoCall: widget.isVideoCall);
    final remoteVideoView =
        _callService.getRemoteVideoView(forceVideoCall: widget.isVideoCall);

    print(
        '🖥️ BUILD: LocalVideo: ${localVideoView != null}, RemoteVideo: ${remoteVideoView != null}, RemoteUID: ${_callService.remoteUid}, HasRemote: $_hasRemoteUser, VideoEnabled: $_isVideoEnabled');

    // Log current UI state
    AgoraDebugHelper.logVideoViewsState(
      localVideoView != null,
      remoteVideoView != null,
      _callService.remoteUid,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video layout: show remote if present, otherwise local preview full screen
            if (widget.isVideoCall) ...[
              Positioned.fill(
                child: _hasRemoteUser
                    ? (remoteVideoView ?? _buildAvatarView())
                    : (localVideoView ?? _buildAvatarView()),
              ),
            ] else
              _buildAvatarView(),

            // Local video view (small corner view)
            if (widget.isVideoCall && _isVideoEnabled) ...[
              Positioned(
                top: 50,
                right: 20,
                width: 120,
                height: 160,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: localVideoView ??
                        Container(
                          color: Colors.grey,
                          child: const Center(
                            child: Text('No Video',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                  ),
                ),
              ),
            ],

            // Debug info overlay (only in debug mode)
            // REMOVED FOR PRODUCTION - uncomment for debugging
            // if (kDebugMode)
            //   Positioned(
            //     top: 10,
            //     left: 10,
            //     child: Container(...),
            //   ),

            // Top user info
            Positioned(
              top: 20,
              left: 20,
              right: 140, // Leave space for local video
              child: _buildUserInfo(),
            ),

            // Bottom controls
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _buildCallControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade900,
            Colors.purple.shade900,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildUserAvatar(),
          const SizedBox(height: 20),
          Text(
            widget.user.username ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _getCallStatusText(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: ClipOval(
        child: widget.user.profilePhoto != null &&
                widget.user.profilePhoto!.isNotEmpty
            ? Image.network(
                widget.user.profilePhoto!.addBaseURL(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey.shade600,
      child: const Icon(
        Icons.person,
        size: 80,
        color: Colors.white,
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.user.username ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getCallStatusText(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getCallStatusText() {
    if (!_isConnected) {
      return 'Connecting...';
    } else if (!_hasRemoteUser) {
      return 'Waiting for answer...';
    } else {
      return 'Connected';
    }
  }

  Widget _buildCallControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            onTap: _toggleMute,
            backgroundColor: _isMuted ? Colors.red : Colors.white24,
          ),

          // Speaker button (audio calls only)
          if (!widget.isVideoCall)
            _buildControlButton(
              icon: _isSpeakerEnabled ? Icons.volume_up : Icons.volume_down,
              onTap: _toggleSpeaker,
              backgroundColor: _isSpeakerEnabled ? Colors.blue : Colors.white24,
            ),

          // Video toggle button (video calls only)
          if (widget.isVideoCall)
            _buildControlButton(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              onTap: _toggleVideo,
              backgroundColor: _isVideoEnabled ? Colors.blue : Colors.red,
            ),

          // Camera switch button (video calls only)
          if (widget.isVideoCall)
            _buildControlButton(
              icon: Icons.flip_camera_ios,
              onTap: _switchCamera,
              backgroundColor: Colors.white24,
            ),

          // End call button
          _buildControlButton(
            icon: Icons.call_end,
            onTap: _endCall,
            backgroundColor: Colors.red,
            size: 60,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color backgroundColor,
    double size = 50,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _connectionSubscription?.cancel();
    _remoteUserSubscription?.cancel();
    _callEndedSubscription?.cancel();
    _signalSubscription?.cancel();
    if (_callService.isInCall) {
      unawaited(_callService.endCall());
    }
    unawaited(CallManager().endCall());
    super.dispose();
  }
}
