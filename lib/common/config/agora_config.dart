// Note: No imports required for this config; removed unused imports to silence analyzer warnings.

/// Agora Configuration Constants
/// Replace these values with your actual Agora App ID and other settings
class AgoraConfig {
  // ✅ NEW APP ID - No certificate required
  static const String appId =
      "9a8340f679264eee911400f21d6c42c3";

      // static const String appId =f7bc5b1b34f74247a32aca28f54788e5
      // "c0d00a01ab0d4111826a7ebc87c4c0ad";

  // ❌ NO CERTIFICATE - Token authentication NOT required
  static const String appCertificate = "";

  // No temp token needed since there's no certificate
  static String manualTempToken = "";

  // If your Agora Console project has Primary Certificate enabled,
  // keep this false and provide a valid RTC token.
  // Set to true only when token authentication is disabled in Console.
  static const bool allowTokenlessCallsForTesting = true;

  // Fixed test channel support (set to true to force a predictable channel during testing)
  // ❌ DISABLED: Must use dynamic channel from notification so caller/receiver join same channel
  static const bool useFixedTestChannel = false;
  static const String fixedTestChannel = 'TopTap Channel';

  // Returns the channel ID the app will actually use
  static String effectiveChannelId(String provided) =>
      useFixedTestChannel ? fixedTestChannel : provided;

  /// Generate a temporary token for testing (requires app certificate)
  /// For production, implement a proper token server
  static String? generateTestToken(
      String channelId, int uid) {
    // 1) If a manual temp token is provided, use it directly
    if (manualTempToken.trim().isNotEmpty) {
      print(
          "🧪 Using manual temp token from config for channel: $channelId");
      return manualTempToken.trim();
    }

    // No certificate = no token needed
    if (appCertificate.isEmpty) {
      print("✅ No App Certificate - token not required");
      return null;
    }

    // ⚠️ IMPORTANT: You have an App Certificate configured!
    // This means token authentication is REQUIRED.
    // Options:
    // 1. Go to Agora Console → Project → Security → DISABLE "Primary Certificate"
    //    This allows testing without tokens.
    // 2. Generate temp token in Console and paste into manualTempToken above
    // 3. Implement a proper token server for production

    if (appCertificate != "YOUR_AGORA_APP_CERTIFICATE" &&
        appCertificate.isNotEmpty) {
      print(
          "⚠️ App Certificate is configured - token auth may be required");
      print("💡 If calls fail with error 110, either:");
      print(
          "   1. DISABLE 'Primary Certificate' in Agora Console, OR");
      print(
          "   2. Generate temp token and paste into AgoraConfig.manualTempToken");
      // Return null to try without token - will fail if token auth is enabled in Console
      return null;
    }

    print("✅ No App Certificate - using null token");
    return null;
  }

  /// Resolve call token from runtime payload or local test config.
  static String? resolveCallToken(
      {String? runtimeToken,
      required String channelId,
      required int uid}) {
    final runtime = runtimeToken?.trim() ?? '';
    if (runtime.isNotEmpty) {
      return runtime;
    }
    return generateTestToken(channelId, uid)?.trim();
  }

  /// True when a token is configured locally (manual or app-certificate based flow).
  static bool hasConfiguredToken() {
    final token = manualTempToken.trim();
    return token.isNotEmpty;
  }

  /// Whether current call attempt must include a token.
  /// [detectedByAgora] should be true after receiving errInvalidToken once.
  static bool isTokenMandatory(
      {bool detectedByAgora = false}) {
    if (detectedByAgora) return true;
    if (isTokenRequired()) return true;
    return !allowTokenlessCallsForTesting;
  }

  /// Check if token authentication is likely required
  static bool isTokenRequired() {
    // Token is required if app certificate is set AND no manual token provided
    return appCertificate != "YOUR_AGORA_APP_CERTIFICATE" &&
        appCertificate.isNotEmpty &&
        manualTempToken.trim().isEmpty;
  }

  // Channel settings
  static const int defaultUid =
      0; // 0 means auto-assign UID
  static const int tokenExpirationTime =
      3600; // 1 hour in seconds

  // Call settings
  static const int maxCallDuration =
      3600; // 1 hour in seconds
  static const bool enableAudioRouting = true;
  static const bool enableEchoCancellation = true;
  static const bool enableNoiseSuppression = true;

  // Video settings
  static const int defaultVideoWidth = 640;
  static const int defaultVideoHeight = 480;
  static const int defaultVideoFrameRate = 15;
  static const int defaultVideoBitrate = 400; // kbps

  /// Generate channel ID for a call between two users
  static String generateChannelId(int userId1, int userId2,
      {String? prefix}) {
    List<int> userIds = [userId1, userId2];
    userIds
        .sort(); // Ensure consistent channel ID regardless of caller order

    String timestamp =
        DateTime.now().millisecondsSinceEpoch.toString();
    String baseId =
        '${userIds[0]}_${userIds[1]}_$timestamp';

    if (prefix != null) {
      return '${prefix}_$baseId';
    }

    return baseId;
  }

  /// Get test channel ID for development
  static String getTestChannelId() {
    return 'test_channel_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get current channel for testing - shows what channel will be used
  static String getCurrentTestChannel() {
    if (useFixedTestChannel) {
      return fixedTestChannel;
    } else {
      return "Dynamic channel (app-generated)";
    }
  }

  /// Display current configuration for debugging
  static void printTestConfiguration() {
    print('🔧 AGORA TEST CONFIGURATION:');
    print('   📱 App ID: ${appId.substring(0, 8)}...');
    print(
        '   🔐 Token Auth: ${manualTempToken.isEmpty ? "DISABLED" : "ENABLED"}');
    print('   📺 Fixed Channel: $useFixedTestChannel');
    print('   📺 Test Channel: ${getCurrentTestChannel()}');
    print(
        '   🎯 Expected Token: ${generateTestToken(fixedTestChannel, 0)}');
    print(
        '   💡 For two-device testing: Both phones must join the same channel');
    print(
        '   🚨 If stuck "waiting": Check Agora Console - Primary Certificate must be DISABLED');
  }
}

/// Instructions for Agora Setup:
/// 
/// 1. Create an Agora account at https://console.agora.io/
/// 2. Create a new project in the Agora Console
/// 3. Get your App ID from the project settings
/// 4. Replace "YOUR_AGORA_APP_ID" with your actual App ID
/// 5. For production, implement token generation using App Certificate
/// 6. Update the Firebase settings to store call metadata
/// 
/// Optional: Token Server Setup for Production
/// - Tokens provide additional security for production apps
/// - You can build a token server or use Agora's token generator
/// - For testing, you can use null tokens (less secure)
