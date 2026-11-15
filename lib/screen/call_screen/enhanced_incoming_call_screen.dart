import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/manager/call_notification_manager.dart';
import 'package:toptap/common/manager/logger.dart';

/// Enhanced incoming call screen with modern UI and animations
class EnhancedIncomingCallScreen extends StatefulWidget {
  final IncomingCallData callData;

  const EnhancedIncomingCallScreen({
    super.key,
    required this.callData,
  });

  @override
  State<EnhancedIncomingCallScreen> createState() =>
      _EnhancedIncomingCallScreenState();
}

class _EnhancedIncomingCallScreenState extends State<EnhancedIncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _rotateController;

  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;

  Timer? _callDurationTimer;
  Duration _callDuration = Duration.zero;

  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startCallDurationTimer();
    _hapticFeedback();

    // Set system UI overlay style for full-screen
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    Loggers.info('📞 🎭 Enhanced incoming call screen displayed');
  }

  void _initializeAnimations() {
    // Pulse animation for call button
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Slide animation for action buttons
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    // Rotate animation for decline button
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotateController,
      curve: Curves.easeInOut,
    ));

    // Scale animation for caller avatar
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    // Start animations
    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  void _startCallDurationTimer() {
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = Duration(seconds: timer.tick);
        });
      }
    });
  }

  void _hapticFeedback() {
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _rotateController.dispose();
    _callDurationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: _buildBackgroundDecoration(),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        _buildCallerInfo(),
                        const SizedBox(height: 30),
                        _buildCallTypeIndicator(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                _buildActionButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: widget.callData.isVideoCall
            ? [
                Colors.blue.shade900.withOpacity(0.95),
                Colors.blue.shade700.withOpacity(0.9),
                Colors.blue.shade500.withOpacity(0.85),
              ]
            : [
                Colors.green.shade900.withOpacity(0.95),
                Colors.green.shade700.withOpacity(0.9),
                Colors.green.shade500.withOpacity(0.85),
              ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.callData.isVideoCall ? 'Video Call' : 'Voice Call',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            _formatCallDuration(_callDuration),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallerInfo() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        children: [
          _buildCallerAvatar(),
          const SizedBox(height: 24),
          _buildCallerName(),
          const SizedBox(height: 8),
          _buildCallerStatus(),
        ],
      ),
    );
  }

  Widget _buildCallerAvatar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse rings
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 200 * _pulseAnimation.value,
              height: 200 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
            );
          },
        ),

        // Second pulse ring (delayed)
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 160 * _pulseAnimation.value,
              height: 160 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
            );
          },
        ),

        // Main avatar
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 4,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: _buildCallerImage(),
          ),
        ),
      ],
    );
  }

  Widget _buildCallerImage() {
    if (widget.callData.caller.profilePhoto?.isNotEmpty == true) {
      return CachedNetworkImage(
        imageUrl: widget.callData.caller.profilePhoto!.addBaseURL(),
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade300,
          child: const Icon(
            Icons.person,
            size: 60,
            color: Colors.grey,
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade300,
          child: const Icon(
            Icons.person,
            size: 60,
            color: Colors.grey,
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.grey.shade300,
        child: const Icon(
          Icons.person,
          size: 60,
          color: Colors.grey,
        ),
      );
    }
  }

  Widget _buildCallerName() {
    return Text(
      widget.callData.caller.fullname ?? 'Unknown Caller',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildCallerStatus() {
    return Text(
      'Incoming call...',
      style: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildCallTypeIndicator() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.callData.isVideoCall ? Icons.videocam : Icons.call,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.callData.isVideoCall ? 'Video Call' : 'Voice Call',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDeclineButton(),
            _buildAcceptButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeclineButton() {
    return GestureDetector(
      onTap: _isProcessingAction ? null : _onDeclineCall,
      child: RotationTransition(
        turns: _rotateAnimation,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.5),
                spreadRadius: 4,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.call_end,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptButton() {
    return GestureDetector(
      onTap: _isProcessingAction ? null : _onAcceptCall,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.1,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.5),
                    spreadRadius: 4,
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                widget.callData.isVideoCall ? Icons.videocam : Icons.call,
                color: Colors.white,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onAcceptCall() async {
    if (_isProcessingAction) return;

    setState(() {
      _isProcessingAction = true;
    });

    try {
      HapticFeedback.mediumImpact();
      Loggers.info('📞 ✅ User accepted call: ${widget.callData.callId}');

      // Accept call through notification manager
      await CallNotificationManager.instance.acceptCall(widget.callData.callId);
    } catch (e) {
      Loggers.error('📞 ❌ Error accepting call: $e');

      if (mounted) {
        Get.snackbar(
          'Call Error',
          'Failed to accept call. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _onDeclineCall() async {
    if (_isProcessingAction) return;

    setState(() {
      _isProcessingAction = true;
    });

    try {
      HapticFeedback.heavyImpact();
      _rotateController.forward();

      Loggers.info('📞 ❌ User declined call: ${widget.callData.callId}');

      // Decline call through notification manager
      await CallNotificationManager.instance.declineCall(
        widget.callData.callId,
        reason: 'user_declined',
      );

      // Close this screen
      if (mounted) {
        Get.back();
      }
    } catch (e) {
      Loggers.error('📞 ❌ Error declining call: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  String _formatCallDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
