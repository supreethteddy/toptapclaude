import 'package:flutter/services.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class ZegoEngineService {
  ZegoEngineService._();

  static final ZegoEngineService instance = ZegoEngineService._();

  /// Client-provided Zego credentials (2026-09-14). These take precedence over
  /// the backend `tbl_settings` values because the live backend still serves the
  /// old template credentials, which fail Zego authentication (error 1001005 —
  /// "AppSign is incorrect"). When the backend settings are updated to a valid
  /// pair these constants can be cleared to defer to the server again.
  static const int _overrideAppId = 1814460474;
  static const String _overrideAppSign =
      '8d968dc628a7d485b9448fd4a7baeb4ea00475e7eb6955b66f797069eabc0cc8';

  Future<void>? _createEngineFuture;
  bool _isEngineCreated = false;

  Future<bool> ensureEngine() async {
    if (_isEngineCreated) return true;

    _createEngineFuture ??= _createEngine();

    try {
      await _createEngineFuture;
      _isEngineCreated = true;
      return true;
    } catch (e, stackTrace) {
      _createEngineFuture = null;
      Loggers.error('Create Zego Engine failed: $e\n$stackTrace');
      return false;
    }
  }

  Future<void> _createEngine() async {
    Setting? appSetting = SessionManager.instance.getSettings();
    final int? serverAppId = int.tryParse(appSetting?.zegoAppId ?? '');
    final String serverAppSign = (appSetting?.zegoAppSign ?? '').trim();

    // Prefer the bundled override when set; otherwise fall back to the backend.
    final int appId = _overrideAppId != 0 ? _overrideAppId : (serverAppId ?? 0);
    final String appSign =
        _overrideAppSign.isNotEmpty ? _overrideAppSign : serverAppSign;

    if (appId == 0 || appSign.isEmpty) {
      throw StateError('Zego credentials are missing from settings.');
    }

    try {
      await ZegoExpressEngine.createEngineWithProfile(
        ZegoEngineProfile(
          appId,
          ZegoScenario.Default,
          appSign: appSign,
        ),
      );
    } on MissingPluginException catch (e) {
      throw StateError('Zego plugin is not available: ${e.message}');
    }
  }
}
