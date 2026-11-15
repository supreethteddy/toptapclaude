import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:toptap/common/manager/logger.dart';

/// Agora specific error codes and handling
class AgoraErrorHandler {
  static const Map<int, String> errorCodes = {
    1: 'General error - Please check your internet connection and try again',
    -1: 'General error - Please check your internet connection and try again',
    -2: 'Invalid argument',
    -3: 'Not ready (engine not initialized)',
    -4: 'Not supported',
    -5: 'Refused operation',
    -6: 'Buffer too small',
    -7: 'Not initialized',
    -8: 'Invalid state',
    -9: 'No permission',
    -10: 'Timed out',
    -11: 'Canceled',
    -12: 'Too often',
    -13: 'Bind socket failed',
    -14: 'Network unavailable',
    -15: 'No buffer available',
    -17: 'Join channel rejected',
    -18: 'Leave channel rejected',
    -19: 'Already in use',
    -20: 'Abort',
    -21: 'Resource limited',
    -22: 'Invalid App ID',
    -101: 'Invalid channel name',
    -102: 'Invalid token',
    -109: 'Token expired',
    -110:
        'Token expired or invalid. Configure RTC token from backend, or disable Primary Certificate in Agora Console for testing.',
    -111: 'Connection interrupted',
    -112: 'Connection lost',
    -113: 'Not in channel',
    -114: 'Size too large',
    -115: 'Bitrate limited',
    -116: 'Too many data streams',
    -117: 'Stream decryption failed',
    -118: 'Watermark parameter invalid',
    -119: 'Watermark path invalid',
    -120: 'Watermark png invalid',
    -121: 'Watermark info invalid',
    -122: 'Watermark ARGB invalid',
    -123: 'Watermark read failed',
    -124: 'Encrypted stream not allowed published',
    -125: 'License expired',
    -157: 'Invalid user account',
    -134: 'Client is banned by server',
    -1001: 'Load media engine failed',
    -1002: 'Start call after media engine startup failed',
    -1003: 'Start camera failed',
    -1004: 'Start video rendering failed',
    -1005: 'ADM general error',
    -1006: 'ADM Java resource error',
    -1007: 'ADM sample rate error',
    -1008: 'ADM init playout error',
    -1009: 'ADM start playout error',
    -1010: 'ADM stop playout error',
    -1011: 'ADM init recording error',
    -1012: 'ADM start recording error',
    -1013: 'ADM stop recording error',
    -1015: 'ADM runtime playout error',
    -1017: 'ADM runtime recording error',
    -1018: 'ADM record audio failed',
    -1020: 'ADM init loopback error',
    -1021: 'ADM start loopback error',
    -1359: 'No recording device',
    -1360: 'No playout device',
    -1501: 'VDM camera not authorized',
    -1600: 'VCM unknown error',
    -1601: 'VCM encoder init error',
    -1602: 'VCM encoder encode error',
    -1603: 'VCM encoder set error',
  };

  /// Get human readable error message
  static String getErrorMessage(int errorCode) {
    return errorCodes[errorCode] ??
        'Unknown error (Code: $errorCode)';
  }

  /// Handle Agora errors with user-friendly messages
  static void handleError(int errorCode,
      {String? context}) {
    String message = getErrorMessage(errorCode);
    String fullMessage =
        context != null ? '$context: $message' : message;

    Loggers.error('Agora Error [$errorCode]: $fullMessage');

    // Show user-friendly error based on error type
    if (_isTokenError(errorCode)) {
      _showTokenErrorDialog(errorCode);
    } else if (_isCriticalError(errorCode)) {
      _showCriticalErrorDialog(fullMessage);
    } else if (_isNetworkError(errorCode)) {
      _showNetworkErrorSnackbar();
    } else if (_isPermissionError(errorCode)) {
      _showPermissionErrorDialog();
    } else {
      _showGeneralErrorSnackbar(message);
    }
  }

  /// Check if error is token related
  static bool _isTokenError(int errorCode) {
    return [
      -109, // Token expired
      -110, // Token expired or invalid
      -102, // Invalid token
    ].contains(errorCode);
  }

  /// Check if error is critical and requires immediate attention
  static bool _isCriticalError(int errorCode) {
    return [
      -22, // Invalid App ID
      -3, // Not ready
      -7, // Not initialized
      -125, // License expired
    ].contains(errorCode);
  }

  /// Check if error is network related
  static bool _isNetworkError(int errorCode) {
    return [
      -14, // Network unavailable
      -111, // Connection interrupted
      -112, // Connection lost
    ].contains(errorCode);
  }

  /// Check if error is permission related
  static bool _isPermissionError(int errorCode) {
    return [
      -9, // No permission
      -1501, // Camera not authorized
      -1359, // No recording device
      -1360, // No playout device
    ].contains(errorCode);
  }

  /// Show critical error dialog
  static void _showCriticalErrorDialog(String message) {
    Get.dialog(
      AlertDialog(
        title: const Text('Critical Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Show token error dialog with specific actions
  static void _showTokenErrorDialog(int errorCode) {
    String title = 'Authentication Error';
    String message = '';

    if (errorCode == -110) {
      message =
          'Invalid Agora token. Your Agora project likely requires token authentication. Configure RTC token from backend, or disable Primary Certificate in Agora Console for testing.';
    } else if (errorCode == -109) {
      message =
          'Your session has expired. Please restart the app and try again.';
    } else {
      message =
          'Authentication failed. Please check your connection and try again.';
    }

    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              // Force app restart or token refresh
              _handleTokenRefresh();
            },
            child: const Text('Restart App'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Handle token refresh or app restart
  static void _handleTokenRefresh() {
    // You can implement token refresh logic here
    // For now, we'll show a message to restart the app
    Get.snackbar(
      'Restart Required',
      'Please close and restart the app to continue',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  /// Show network error snackbar
  static void _showNetworkErrorSnackbar() {
    Get.snackbar(
      'Network Error',
      'Please check your internet connection and try again',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  /// Show permission error dialog
  static void _showPermissionErrorDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
            'This app needs camera and microphone permissions for calls. Please enable them in settings.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              // You can add navigation to app settings here
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  /// Show general error snackbar
  static void _showGeneralErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
}

/// Connection quality indicator
enum ConnectionQuality {
  excellent,
  good,
  fair,
  poor,
  veryPoor,
  unknown,
}

class ConnectionQualityManager {
  static ConnectionQuality getQualityFromStats(
      int quality) {
    switch (quality) {
      case 1:
        return ConnectionQuality.excellent;
      case 2:
        return ConnectionQuality.good;
      case 3:
        return ConnectionQuality.fair;
      case 4:
        return ConnectionQuality.poor;
      case 5:
        return ConnectionQuality.veryPoor;
      default:
        return ConnectionQuality.unknown;
    }
  }

  static Color getQualityColor(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return Colors.green;
      case ConnectionQuality.good:
        return Colors.lightGreen;
      case ConnectionQuality.fair:
        return Colors.yellow;
      case ConnectionQuality.poor:
        return Colors.orange;
      case ConnectionQuality.veryPoor:
        return Colors.red;
      case ConnectionQuality.unknown:
        return Colors.grey;
    }
  }

  static String getQualityText(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return 'Excellent';
      case ConnectionQuality.good:
        return 'Good';
      case ConnectionQuality.fair:
        return 'Fair';
      case ConnectionQuality.poor:
        return 'Poor';
      case ConnectionQuality.veryPoor:
        return 'Very Poor';
      case ConnectionQuality.unknown:
        return 'Unknown';
    }
  }
}
