import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/config/agora_config.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/manager/call_state_manager.dart';
import 'package:toptap/common/service/call_signaling_service.dart';
import 'package:toptap/model/user_model/user_model.dart';
import 'package:toptap/screen/call_screen/call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String channelId;
  final bool isVideoCall;
  final String? token;
  final String? callId;
  final User caller;

  const IncomingCallScreen({
    super.key,
    required this.channelId,
    required this.isVideoCall,
    required this.caller,
    this.token,
    this.callId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              _buildAvatar(),
              const SizedBox(height: 24),
              Text(
                widget.caller.username ??
                    widget.caller.fullname ??
                    'Incoming call',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isVideoCall ? 'Video call' : 'Voice call',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Spacer(),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _declineCall,
                        icon: const Icon(Icons.call_end, size: 24),
                        label: const Text('Decline',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _acceptCall,
                        icon: Icon(
                          widget.isVideoCall ? Icons.videocam : Icons.call,
                          size: 24,
                        ),
                        label: const Text('Accept',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acceptCall() async {
    if (widget.callId?.isNotEmpty ?? false) {
      await CallStateManager.instance.acceptCall(widget.callId!);
      await CallSignalingService.instance.updateStatus(
        widget.callId!,
        CallSignalStatus.accepted,
      );
    }
    final effectiveChannel = AgoraConfig.effectiveChannelId(widget.channelId);

    // Navigate to the call screen
    Get.off(() => CallScreen(
          user: widget.caller,
          isVideoCall: widget.isVideoCall,
          channelId: effectiveChannel,
          callId: widget.callId ?? widget.channelId,
          token: widget.token,
        ));
  }

  Future<void> _declineCall() async {
    if (widget.callId?.isNotEmpty ?? false) {
      await CallStateManager.instance.declineCall(
        widget.callId!,
        reason: 'user_declined',
      );
      await CallSignalingService.instance.updateStatus(
        widget.callId!,
        CallSignalStatus.declined,
        reason: 'user_declined',
      );
    }
    Get.back();
  }

  Widget _buildAvatar() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: ClipOval(
        child: (widget.caller.profilePhoto ?? '').isNotEmpty
            ? Image.network(
                widget.caller.profilePhoto!.addBaseURL(),
                fit: BoxFit.cover,
              )
            : Container(
                color: Colors.grey.shade700,
                child: const Icon(Icons.person, color: Colors.white, size: 72),
              ),
      ),
    );
  }
}
