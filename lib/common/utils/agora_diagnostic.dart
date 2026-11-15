import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:toptap/common/utils/network_checker.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/config/agora_config.dart';

/// Agora Call Diagnostic Tool
class AgoraCallDiagnostic {
  /// Run comprehensive diagnostic for Agora call troubleshooting
  static Future<void> runDiagnostic(
      {int? specificError}) async {
    try {
      Loggers.info('=== AGORA CALL DIAGNOSTIC START ===');
      if (specificError != null) {
        Loggers.info(
            'Specific error being diagnosed: $specificError');
      }

      // 1. Network Connectivity Check
      Map<String, dynamic> networkDiag =
          await NetworkChecker.runNetworkDiagnostic();
      Loggers.info('Network Diagnostic: $networkDiag');

      // 2. App ID Validation
      String appId = AgoraConfig.appId;
      bool validAppId = appId.isNotEmpty &&
          appId != "YOUR_AGORA_APP_ID" &&
          appId.length > 10;
      Loggers.info(
          'App ID Valid: $validAppId (Length: ${appId.length})');

      // 3. Device Capabilities Check
      Map<String, dynamic> deviceCapabilities =
          await _checkDeviceCapabilities();

      // 4. Video-specific checks
      Map<String, dynamic> videoChecks =
          await _checkVideoCapabilities();

      // 5. Error 110 specific checks
      Map<String, dynamic> error110Checks = {};
      if (specificError == -110 || specificError == 110) {
        error110Checks = await _checkError110Specifics();
      }

      // 6. Generate recommendations
      List<String> recommendations =
          _generateRecommendations(
              networkDiag,
              validAppId,
              specificError,
              error110Checks,
              deviceCapabilities,
              videoChecks);

      // 7. Show diagnostic dialog
      _showDiagnosticDialog(
          networkDiag,
          validAppId,
          recommendations,
          specificError,
          error110Checks,
          deviceCapabilities,
          videoChecks);

      Loggers.info('=== AGORA CALL DIAGNOSTIC END ===');
    } catch (e) {
      Loggers.error('Diagnostic failed: $e');
      Get.snackbar('Diagnostic Error',
          'Failed to run diagnostic: $e');
    }
  }

  /// Specific checks for error 110
  static Future<Map<String, dynamic>>
      _checkError110Specifics() async {
    Map<String, dynamic> checks = {};

    try {
      // Check system time
      DateTime now = DateTime.now();
      checks['system_time'] = now.toIso8601String();
      checks['timestamp'] = now.millisecondsSinceEpoch;

      // Check if app ID looks valid
      String appId = AgoraConfig.appId;
      checks['app_id_format'] = {
        'length': appId.length,
        'has_numbers': appId.contains(RegExp(r'[0-9]')),
        'has_letters': appId.contains(RegExp(r'[a-zA-Z]')),
        'is_placeholder': appId == "YOUR_AGORA_APP_ID",
      };

      // Check network stability
      bool canReachAgora =
          await NetworkChecker.canReachAgoraServers();
      checks['agora_reachable'] = canReachAgora;

      // Check for multiple rapid calls (rate limiting)
      checks['potential_rate_limit'] =
          'Check if too many calls in short time';

      Loggers.info('Error 110 specific checks: $checks');
    } catch (e) {
      Loggers.error('Error 110 checks failed: $e');
      checks['error'] = e.toString();
    }

    return checks;
  }

  static Future<Map<String, dynamic>>
      _checkDeviceCapabilities() async {
    Map<String, dynamic> capabilities = {};

    try {
      // Check microphone permission
      var micStatus = await Permission.microphone.status;
      capabilities['microphone_permission'] =
          micStatus.isGranted;

      // Check camera permission
      var cameraStatus = await Permission.camera.status;
      capabilities['camera_permission'] =
          cameraStatus.isGranted;

      // Check notification permission
      var notificationStatus =
          await Permission.notification.status;
      capabilities['notification_permission'] =
          notificationStatus.isGranted;

      Loggers.info('Device capabilities: $capabilities');
    } catch (e) {
      Loggers.error('Device capability check failed: $e');
      capabilities['error'] = e.toString();
    }

    return capabilities;
  }

  static Future<Map<String, dynamic>>
      _checkVideoCapabilities() async {
    Map<String, dynamic> videoCapabilities = {};

    try {
      // Test basic video functionality
      videoCapabilities['camera_available'] =
          true; // Assume true for now

      // Check if camera permission is granted
      var cameraStatus = await Permission.camera.status;
      videoCapabilities['camera_permission_granted'] =
          cameraStatus.isGranted;

      // Check if we can request camera permission
      if (!cameraStatus.isGranted) {
        videoCapabilities['can_request_camera'] =
            await Permission
                .camera.shouldShowRequestRationale;
      }

      Loggers.info(
          'Video capabilities: $videoCapabilities');
    } catch (e) {
      Loggers.error('Video capability check failed: $e');
      videoCapabilities['error'] = e.toString();
    }

    return videoCapabilities;
  }

  static List<String> _generateRecommendations(
    Map<String, dynamic> networkDiag,
    bool validAppId,
    int? specificError,
    Map<String, dynamic> error110Checks,
    Map<String, dynamic> deviceCapabilities,
    Map<String, dynamic> videoChecks,
  ) {
    List<String> recommendations = [];

    // Error 110 specific recommendations
    if (specificError == -110 || specificError == 110) {
      recommendations.add(
          '🔐 ERROR 110: Authentication/Token Issue Detected');
      recommendations
          .add('🔄 Try restarting the app completely');
      recommendations
          .add('⏰ Check if your device time is correct');

      if (error110Checks['agora_reachable'] == false) {
        recommendations.add(
            '🌐 Cannot reach Agora servers - check firewall');
      }

      var appIdFormat = error110Checks['app_id_format'];
      if (appIdFormat != null &&
          appIdFormat['is_placeholder'] == true) {
        recommendations.add(
            '🔑 App ID is still placeholder - needs real Agora App ID');
      }

      recommendations.add('📱 Force close app and restart');
      recommendations.add('🔗 Check network stability');
      recommendations.add('⚡ Try airplane mode on/off');
    }

    if (!networkDiag['hasInternet']) {
      recommendations
          .add('🌐 Enable mobile data or connect to WiFi');
      recommendations.add(
          '📡 Check if your internet connection is working');
    }

    if (!networkDiag['canReachAgora']) {
      recommendations.add(
          '🚫 Your network may be blocking Agora servers');
      recommendations.add(
          '🔓 Try switching between WiFi and mobile data');
      recommendations.add(
          '🌍 Check if you\'re in a region where Agora is available');
    }

    if (!validAppId) {
      recommendations
          .add('🔑 App ID configuration issue detected');
      recommendations
          .add('⚙️ Contact support to verify Agora App ID');
    }

    // Video permission checks
    if (deviceCapabilities['camera_permission'] == false) {
      recommendations.add(
          '📷 Camera permission required for video calls');
      recommendations.add(
          '⚙️ Go to Settings > Apps > Permissions > Camera');
    }

    if (deviceCapabilities['microphone_permission'] ==
        false) {
      recommendations.add(
          '🎤 Microphone permission required for calls');
      recommendations.add(
          '⚙️ Go to Settings > Apps > Permissions > Microphone');
    }

    if (videoChecks['camera_permission_granted'] == false) {
      recommendations
          .add('📹 Video calls need camera access');
      recommendations.add(
          '🔄 Restart app after granting camera permission');
    }

    if (networkDiag['networkType'] == 'Mobile Data') {
      recommendations.add(
          '📱 Mobile data detected - ensure good signal strength');
      recommendations.add(
          '🔄 Try switching to WiFi for better stability');
    }

    // General recommendations for error 001
    recommendations.add('🔄 Close and reopen the app');
    recommendations.add('📱 Restart your device');
    recommendations
        .add('🕐 Wait a few minutes and try again');

    return recommendations;
  }

  static void _showDiagnosticDialog(
    Map<String, dynamic> networkDiag,
    bool validAppId,
    List<String> recommendations,
    int? specificError,
    Map<String, dynamic> error110Checks,
    Map<String, dynamic> deviceCapabilities,
    Map<String, dynamic> videoChecks,
  ) {
    Get.dialog(
      AlertDialog(
        title: Text(
          specificError != null
              ? 'Error $specificError Diagnostic Results'
              : 'Call Diagnostic Results',
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error 110 specific status
              if (specificError == -110 ||
                  specificError == 110) ...[
                const Text('Error 110 Checks:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
                const SizedBox(height: 4),
                _buildStatusRow(
                    'System Time',
                    error110Checks['system_time'] ??
                        'Unknown',
                    isInfo: true),
                _buildStatusRow(
                    'Agora Reachable',
                    error110Checks['agora_reachable'] ??
                        false),
                if (error110Checks['app_id_format'] != null)
                  _buildStatusRow(
                      'App ID Valid',
                      !(error110Checks['app_id_format']
                              ['is_placeholder'] ??
                          true)),
                const SizedBox(height: 12),
              ],

              // Network Status
              const Text('Network Status:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _buildStatusRow('Internet Connection',
                  networkDiag['hasInternet'] ?? false),
              _buildStatusRow('Network Type',
                  networkDiag['networkType'] ?? 'Unknown',
                  isInfo: true),
              _buildStatusRow('Agora Servers',
                  networkDiag['canReachAgora'] ?? false),
              _buildStatusRow(
                  'App Configuration', validAppId),

              const SizedBox(height: 12),

              // Device Capabilities
              const Text('Device Capabilities:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _buildStatusRow(
                  'Camera Permission',
                  deviceCapabilities['camera_permission'] ??
                      false),
              _buildStatusRow(
                  'Microphone Permission',
                  deviceCapabilities[
                          'microphone_permission'] ??
                      false),

              const SizedBox(height: 12),

              // Video Capabilities
              const Text('Video Capabilities:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _buildStatusRow(
                  'Camera Access',
                  videoChecks[
                          'camera_permission_granted'] ??
                      false),

              const SizedBox(height: 16),
              const Text('Recommendations:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // Recommendations
              ...recommendations.map((rec) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: 4),
                    child: Text('• $rec',
                        style:
                            const TextStyle(fontSize: 12)),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              runDiagnostic(); // Re-run diagnostic
            },
            child: const Text('Re-test'),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatusRow(String label, dynamic value,
      {bool isInfo = false}) {
    Color color;
    IconData icon;
    String displayValue;

    if (isInfo) {
      color = Colors.blue;
      icon = Icons.info;
      displayValue = value.toString();
    } else if (value == true) {
      color = Colors.green;
      icon = Icons.check_circle;
      displayValue = 'OK';
    } else {
      color = Colors.red;
      icon = Icons.error;
      displayValue = 'Failed';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13))),
          Text(displayValue,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
