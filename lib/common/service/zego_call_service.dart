import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/zego_engine_service.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

/// 1:1 audio / video calls backed by Zego Express.
///
/// This is a drop-in replacement for the old Agora-based call service: it keeps
/// exactly the same public surface (`initializeEngine`, `startAudioCall`,
/// `startVideoCall`, the toggles, the local/remote video-view getters and the
/// `connectionStateStream` / `remoteUserStream` / `callEndedStream` streams) so
/// `CallScreen` only needs to swap the type.
///
/// Both peers log in to the same Zego room (the call channel id) and publish a
/// stream named `call_<channel>_<userId>`. Zego's room-stream callbacks then
/// tell each side about the other's stream, so no token server or per-call
/// signalling id negotiation is required — the Zego app id / app sign from the
/// admin settings are enough (unlike Agora, which required a token server).
class ZegoCallService {
  ZegoExpressEngine get _engine => ZegoExpressEngine.instance;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<int?> _remoteUserController =
      StreamController<int?>.broadcast();
  final StreamController<bool> _callEndedController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStateStream => _connectionController.stream;
  Stream<int?> get remoteUserStream => _remoteUserController.stream;
  Stream<bool> get callEndedStream => _callEndedController.stream;

  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerEnabled = true;
  bool _isInCall = false;
  bool _isVideoCall = false;
  bool _isFrontCamera = true;
  bool _disposed = false;

  int? _remoteUid;
  String _roomId = '';
  String _localStreamId = '';

  int _localViewId = -1;
  Widget? _localView;

  /// Remote canvas views keyed by their Zego stream id (1:1, so at most one).
  final Map<String, int> _remoteViewIds = {};
  Widget? _remoteView;

  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  bool get isInCall => _isInCall;
  int? get remoteUid => _remoteUid;

  int get _myUserId => SessionManager.instance.getUserID();

  /// [appId] is accepted for API compatibility with the old Agora service but
  /// is ignored — Zego credentials come from the admin settings.
  Future<bool> initializeEngine({required String appId}) async {
    final ok = await ZegoEngineService.instance.ensureEngine();
    if (!ok) Loggers.error('ZegoCallService: engine could not be created');
    return ok;
  }

  Future<bool> startAudioCall({
    required String channelId,
    String? token,
  }) =>
      _startCall(channelId: channelId, video: false);

  Future<bool> startVideoCall({
    required String channelId,
    String? token,
  }) =>
      _startCall(channelId: channelId, video: true);

  Future<bool> _startCall({
    required String channelId,
    required bool video,
  }) async {
    try {
      _isVideoCall = video;
      _roomId = channelId;
      _localStreamId = 'call_${channelId}_$_myUserId';

      final ready = await ZegoEngineService.instance.ensureEngine();
      if (!ready) return false;

      _registerEventHandlers();

      // Audio routing: video calls default to the loudspeaker, voice calls to
      // the earpiece.
      _isSpeakerEnabled = video;
      await _engine.setAudioRouteToSpeaker(_isSpeakerEnabled);

      _isMuted = false;
      await _engine.muteMicrophone(false);

      if (video) {
        _isVideoEnabled = true;
        _isFrontCamera = true;
        await _engine.enableCamera(true);
        _engine.useFrontCamera(true);
        await _createLocalPreview();
      } else {
        _isVideoEnabled = false;
        await _engine.enableCamera(false);
      }

      final user =
          ZegoUser('$_myUserId', SessionManager.instance.getUser()?.username ?? '');
      final roomConfig = ZegoRoomConfig.defaultConfig()
        ..isUserStatusNotify = true;

      final login = await _engine.loginRoom(_roomId, user, config: roomConfig);
      if (login.errorCode != 0) {
        Loggers.error('ZegoCallService loginRoom failed: ${login.errorCode}');
        return false;
      }

      await _engine.startPublishingStream(_localStreamId);
      _isInCall = true;
      _safeAdd(_connectionController, true);
      Loggers.success('ZegoCallService: call started in room $_roomId');
      return true;
    } catch (e, s) {
      Loggers.error('ZegoCallService start failed: $e\n$s');
      return false;
    }
  }

  Future<void> _createLocalPreview() async {
    if (_localView != null) return;
    await _engine.createCanvasView((viewId) {
      _localViewId = viewId;
      final canvas = ZegoCanvas(viewId, viewMode: ZegoViewMode.AspectFill);
      _engine.startPreview(canvas: canvas);
    }).then((widget) {
      _localView = widget;
    });
  }

  void _registerEventHandlers() {
    ZegoExpressEngine.onRoomStreamUpdate =
        (roomID, updateType, streamList, extendedData) async {
      if (roomID != _roomId) return;
      if (updateType == ZegoUpdateType.Add) {
        for (final stream in streamList) {
          if (stream.streamID == _localStreamId) continue;
          await _playRemoteStream(stream);
        }
      } else {
        for (final stream in streamList) {
          await _stopRemoteStream(stream.streamID);
        }
      }
    };

    ZegoExpressEngine.onRoomStateUpdate =
        (roomID, state, errorCode, extendedData) {
      if (roomID != _roomId) return;
      Loggers.info('ZegoCallService room state: ${state.name} ($errorCode)');
      _safeAdd(_connectionController, state == ZegoRoomState.Connected);
    };
  }

  Future<void> _playRemoteStream(ZegoStream stream) async {
    _remoteUid = int.tryParse(stream.user.userID);
    try {
      if (_isVideoCall) {
        await _engine.createCanvasView((viewId) {
          _remoteViewIds[stream.streamID] = viewId;
          final canvas = ZegoCanvas(viewId, viewMode: ZegoViewMode.AspectFill);
          _engine.startPlayingStream(stream.streamID, canvas: canvas);
        }).then((widget) {
          _remoteView = widget;
        });
      } else {
        // Audio-only: playing the stream with no canvas still routes the audio.
        await _engine.startPlayingStream(stream.streamID);
      }
      _safeAdd(_remoteUserController, _remoteUid);
    } catch (e, s) {
      Loggers.error('ZegoCallService play remote failed: $e\n$s');
    }
  }

  Future<void> _stopRemoteStream(String streamId) async {
    try {
      await _engine.stopPlayingStream(streamId);
      final viewId = _remoteViewIds.remove(streamId);
      if (viewId != null && viewId != -1) {
        await _engine.destroyCanvasView(viewId);
      }
    } catch (e) {
      Loggers.error('ZegoCallService stop remote failed: $e');
    }
    _remoteView = null;
    _remoteUid = null;
    _safeAdd(_remoteUserController, null);
    // In a 1:1 call the peer leaving means the call is over.
    _safeAdd(_callEndedController, true);
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _engine.muteMicrophone(_isMuted);
  }

  Future<void> toggleVideo() async {
    _isVideoEnabled = !_isVideoEnabled;
    await _engine.enableCamera(_isVideoEnabled);
    if (_isVideoEnabled && _localView == null) {
      await _createLocalPreview();
    }
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerEnabled = !_isSpeakerEnabled;
    await _engine.setAudioRouteToSpeaker(_isSpeakerEnabled);
  }

  Future<void> switchCamera() async {
    _isFrontCamera = !_isFrontCamera;
    await _engine.useFrontCamera(_isFrontCamera);
  }

  Widget? getLocalVideoView({bool forceVideoCall = false}) {
    if (!(_isVideoCall || forceVideoCall)) return null;
    return _localView;
  }

  Widget? getRemoteVideoView({bool forceVideoCall = false}) {
    if (!(_isVideoCall || forceVideoCall)) return null;
    return _remoteView;
  }

  Future<void> endCall() async {
    if (!_isInCall && _roomId.isEmpty) return;
    try {
      await _engine.stopPublishingStream();
    } catch (e) {
      Loggers.error('ZegoCallService stopPublishing failed: $e');
    }
    try {
      await _engine.stopPreview();
    } catch (_) {}
    for (final entry in _remoteViewIds.entries) {
      try {
        await _engine.stopPlayingStream(entry.key);
        if (entry.value != -1) await _engine.destroyCanvasView(entry.value);
      } catch (_) {}
    }
    _remoteViewIds.clear();
    if (_localViewId != -1) {
      try {
        await _engine.destroyCanvasView(_localViewId);
      } catch (_) {}
      _localViewId = -1;
    }
    try {
      await _engine.logoutRoom(_roomId);
    } catch (e) {
      Loggers.error('ZegoCallService logoutRoom failed: $e');
    }
    _clearHandlers();
    _isInCall = false;
    _localView = null;
    _remoteView = null;
    _remoteUid = null;
  }

  void _clearHandlers() {
    ZegoExpressEngine.onRoomStreamUpdate = null;
    ZegoExpressEngine.onRoomStateUpdate = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await endCall();
    await _connectionController.close();
    await _remoteUserController.close();
    await _callEndedController.close();
  }

  void _safeAdd<T>(StreamController<T> controller, T value) {
    if (!_disposed && !controller.isClosed) controller.add(value);
  }
}
