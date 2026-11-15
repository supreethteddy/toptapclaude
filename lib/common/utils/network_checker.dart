import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:toptap/common/manager/logger.dart';

/// Network connectivity checker for Agora calls
class NetworkChecker {
  static final NetworkChecker _instance =
      NetworkChecker._internal();
  factory NetworkChecker() => _instance;
  NetworkChecker._internal();

  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      // Check connectivity status
      final connectivity = Connectivity();
      final connectivityResults =
          await connectivity.checkConnectivity();

      if (connectivityResults
              .contains(ConnectivityResult.none) ||
          connectivityResults.isEmpty) {
        Loggers.error('No network connectivity detected');
        return false;
      }

      // Test actual internet access
      final result =
          await InternetAddress.lookup('google.com');
      if (result.isNotEmpty &&
          result[0].rawAddress.isNotEmpty) {
        Loggers.success('Internet connection verified');
        return true;
      }

      Loggers.error(
          'No internet access - DNS lookup failed');
      return false;
    } catch (e) {
      Loggers.error('Network check failed: $e');
      return false;
    }
  }

  /// Check if device can reach Agora servers
  static Future<bool> canReachAgoraServers() async {
    try {
      // Test connection to Agora's edge servers
      final List<String> agoraHosts = [
        'webrtc-ap-southeast-1.agoraio.cn',
        'webrtc-ap-southeast-1.sd-rtn.com',
        'api.agora.io'
      ];

      for (String host in agoraHosts) {
        try {
          final result = await InternetAddress.lookup(host);
          if (result.isNotEmpty) {
            Loggers.success(
                'Can reach Agora server: $host');
            return true;
          }
        } catch (e) {
          Loggers.warning(
              'Cannot reach Agora server $host: $e');
          continue;
        }
      }

      Loggers.error('Cannot reach any Agora servers');
      return false;
    } catch (e) {
      Loggers.error('Agora server check failed: $e');
      return false;
    }
  }

  /// Get network type information
  static Future<String> getNetworkType() async {
    try {
      final connectivity = Connectivity();
      final connectivityResults =
          await connectivity.checkConnectivity();

      if (connectivityResults
          .contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      } else if (connectivityResults
          .contains(ConnectivityResult.mobile)) {
        return 'Mobile Data';
      } else if (connectivityResults
          .contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      } else if (connectivityResults
          .contains(ConnectivityResult.bluetooth)) {
        return 'Bluetooth';
      } else if (connectivityResults
              .contains(ConnectivityResult.none) ||
          connectivityResults.isEmpty) {
        return 'No Connection';
      } else {
        return 'Unknown';
      }
    } catch (e) {
      Loggers.error('Failed to get network type: $e');
      return 'Unknown';
    }
  }

  /// Comprehensive network diagnostic
  static Future<Map<String, dynamic>>
      runNetworkDiagnostic() async {
    Map<String, dynamic> diagnostic = {};

    try {
      diagnostic['hasInternet'] =
          await hasInternetConnection();
      diagnostic['networkType'] = await getNetworkType();
      diagnostic['canReachAgora'] =
          await canReachAgoraServers();
      diagnostic['timestamp'] =
          DateTime.now().toIso8601String();

      Loggers.info('Network diagnostic: $diagnostic');
      return diagnostic;
    } catch (e) {
      Loggers.error('Network diagnostic failed: $e');
      return {
        'hasInternet': false,
        'networkType': 'Unknown',
        'canReachAgora': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
