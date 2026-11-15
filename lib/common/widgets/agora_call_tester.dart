import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/service/agora_call_service.dart';
import 'package:toptap/common/config/agora_config.dart';
import 'package:toptap/common/utils/agora_debug_helper.dart';
import 'package:toptap/screen/call_screen/call_screen.dart';
import 'package:toptap/screen/call_screen/incoming_call_screen.dart';
import 'package:toptap/model/user_model/user_model.dart';

/// Comprehensive Agora Call Testing Widget
class AgoraCallTester extends StatefulWidget {
  const AgoraCallTester({Key? key}) : super(key: key);

  @override
  State<AgoraCallTester> createState() =>
      _AgoraCallTesterState();
}

class _AgoraCallTesterState extends State<AgoraCallTester> {
  final AgoraCallService _callService = AgoraCallService();
  bool _isEngineInitialized = false;
  String _testStatus = 'Ready to test';
  List<String> _testLogs = [];

  void _addLog(String message) {
    setState(() {
      _testLogs.add(
          '${DateTime.now().toString().substring(11, 19)}: $message');
    });
    // Keep only last 20 logs
    if (_testLogs.length > 20) {
      _testLogs.removeAt(0);
    }
  }

  Future<void> _testEngineInitialization() async {
    _addLog('🧪 Testing Engine Initialization...');
    setState(() {
      _testStatus = 'Testing engine initialization...';
    });

    try {
      // Test App ID validation
      bool isValidAppId =
          AgoraDebugHelper.validateAppId(AgoraConfig.appId);
      _addLog('🔑 App ID Valid: $isValidAppId');

      // Test engine initialization
      bool success = await _callService.initializeEngine(
          appId: AgoraConfig.appId);

      setState(() {
        _isEngineInitialized = success;
        _testStatus = success
            ? '✅ Engine initialized successfully'
            : '❌ Engine initialization failed';
      });

      _addLog(success
          ? '✅ Engine initialization: SUCCESS'
          : '❌ Engine initialization: FAILED');
    } catch (e) {
      _addLog('💥 Engine initialization error: $e');
      setState(() {
        _testStatus = '❌ Engine initialization error';
      });
    }
  }

  Future<void> _testAudioCall() async {
    if (!_isEngineInitialized) {
      _addLog(
          '❌ Engine not initialized. Please test initialization first.');
      return;
    }

    _addLog('🧪 Testing Audio Call...');
    setState(() {
      _testStatus = 'Testing audio call...';
    });

    try {
      String testChannelId =
          'test_audio_${DateTime.now().millisecondsSinceEpoch}';
      _addLog('📺 Test Channel: $testChannelId');

      // Check requirements
      Map<String, bool> requirements =
          await AgoraDebugHelper.checkCallRequirements(
        appId: AgoraConfig.appId,
        channelId: testChannelId,
        isVideoCall: false,
      );

      bool allMet = requirements.values.every((v) => v);
      _addLog(
          '📋 Requirements check: ${allMet ? "PASSED" : "FAILED"}');

      if (!allMet) {
        requirements.forEach((key, value) {
          if (!value) _addLog('❌ Failed: $key');
        });
        setState(() {
          _testStatus = '❌ Audio call requirements not met';
        });
        return;
      }

      // Test audio call start
      bool success = await _callService.startAudioCall(
          channelId: testChannelId);

      if (success) {
        _addLog('✅ Audio call started successfully');
        setState(() {
          _testStatus = '✅ Audio call test passed';
        });

        // End call after 3 seconds
        Future.delayed(const Duration(seconds: 3),
            () async {
          await _callService.endCall();
          _addLog('🔚 Test audio call ended');
        });
      } else {
        _addLog('❌ Audio call failed to start');
        setState(() {
          _testStatus = '❌ Audio call test failed';
        });
      }
    } catch (e) {
      _addLog('💥 Audio call test error: $e');
      setState(() {
        _testStatus = '❌ Audio call test error';
      });
    }
  }

  Future<void> _testVideoCall() async {
    if (!_isEngineInitialized) {
      _addLog(
          '❌ Engine not initialized. Please test initialization first.');
      return;
    }

    _addLog('🧪 Testing Video Call...');
    setState(() {
      _testStatus = 'Testing video call...';
    });

    try {
      String testChannelId =
          'test_video_${DateTime.now().millisecondsSinceEpoch}';
      _addLog('📺 Test Channel: $testChannelId');

      // Check requirements
      Map<String, bool> requirements =
          await AgoraDebugHelper.checkCallRequirements(
        appId: AgoraConfig.appId,
        channelId: testChannelId,
        isVideoCall: true,
      );

      bool allMet = requirements.values.every((v) => v);
      _addLog(
          '📋 Requirements check: ${allMet ? "PASSED" : "FAILED"}');

      if (!allMet) {
        requirements.forEach((key, value) {
          if (!value) _addLog('❌ Failed: $key');
        });
        setState(() {
          _testStatus = '❌ Video call requirements not met';
        });
        return;
      }

      // Test video call start
      bool success = await _callService.startVideoCall(
          channelId: testChannelId);

      if (success) {
        _addLog('✅ Video call started successfully');
        setState(() {
          _testStatus = '✅ Video call test passed';
        });

        // End call after 3 seconds
        Future.delayed(const Duration(seconds: 3),
            () async {
          await _callService.endCall();
          _addLog('🔚 Test video call ended');
        });
      } else {
        _addLog('❌ Video call failed to start');
        setState(() {
          _testStatus = '❌ Video call test failed';
        });
      }
    } catch (e) {
      _addLog('💥 Video call test error: $e');
      setState(() {
        _testStatus = '❌ Video call test error';
      });
    }
  }

  void _testIncomingCall(bool isVideoCall) {
    _addLog(
        '🧪 Testing incoming ${isVideoCall ? "video" : "audio"} call');

    // Create a mock caller for testing
    User mockCaller = User(
      id: 999,
      username: 'test_caller',
      fullname: 'Test Caller',
      profilePhoto:
          null, // Use null instead of placeholder URL
    );

    String testChannel = AgoraConfig.useFixedTestChannel
        ? AgoraConfig.fixedTestChannel
        : 'test_incoming_${DateTime.now().millisecondsSinceEpoch}';

    _addLog(
        '📞 Opening incoming call screen for: $testChannel');

    Get.to(() => IncomingCallScreen(
          channelId: testChannel,
          isVideoCall: isVideoCall,
          token: AgoraConfig.manualTempToken.isNotEmpty
              ? AgoraConfig.manualTempToken
              : null,
          caller: mockCaller,
        ));
  }

  void _openFullCallScreen(bool isVideoCall) {
    if (!_isEngineInitialized) {
      _addLog(
          '❌ Engine not initialized. Please test initialization first.');
      return;
    }

    String channelId =
        'full_test_${DateTime.now().millisecondsSinceEpoch}';
    _addLog(
        '🚀 Opening full call screen: ${isVideoCall ? "Video" : "Audio"}');

    // Create dummy user
    User testUser = User(
      id: 123,
      // Add other required User fields here
    );

    Get.to(() => CallScreen(
          user: testUser,
          isVideoCall: isVideoCall,
          channelId: channelId,
          token: null,
        ));
  }

  void _clearLogs() {
    setState(() {
      _testLogs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agora Call Tester'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _testStatus.contains('✅')
                  ? Colors.green[100]
                  : _testStatus.contains('❌')
                      ? Colors.red[100]
                      : Colors.blue[100],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _testStatus,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _testEngineInitialization,
                  icon: const Icon(Icons.settings),
                  label: const Text('Test Engine Init'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue),
                ),
                ElevatedButton.icon(
                  onPressed: _testAudioCall,
                  icon: const Icon(Icons.mic),
                  label: const Text('Test Audio Call'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green),
                ),
                ElevatedButton.icon(
                  onPressed: _testVideoCall,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Test Video Call'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _openFullCallScreen(false),
                  icon: const Icon(Icons.phone),
                  label: const Text('Full Audio Test'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _openFullCallScreen(true),
                  icon: const Icon(Icons.video_call),
                  label: const Text('Full Video Test'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red),
                ),
                ElevatedButton.icon(
                  onPressed: () => _testIncomingCall(false),
                  icon: const Icon(Icons.phone_callback),
                  label: const Text('Test Incoming Audio'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal),
                ),
                ElevatedButton.icon(
                  onPressed: () => _testIncomingCall(true),
                  icon:
                      const Icon(Icons.video_call_rounded),
                  label: const Text('Test Incoming Video'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo),
                ),
                ElevatedButton.icon(
                  onPressed: _clearLogs,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Logs'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Logs Section
            const Text(
              'Test Logs:',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _testLogs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _testLogs[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _callService.dispose();
    super.dispose();
  }
}
