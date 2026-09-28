import 'package:flutter/services.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class ZegoEngineService {
  ZegoEngineService._();

  static final ZegoEngineService instance = ZegoEngineService._();

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
    final int appId = int.tryParse(appSetting?.zegoAppId ?? '') ?? 0;
    final String appSign = (appSetting?.zegoAppSign ?? '').trim();

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
