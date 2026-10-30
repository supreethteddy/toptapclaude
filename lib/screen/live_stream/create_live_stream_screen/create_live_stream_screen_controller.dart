import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deepar_flutter_plus/deepar_flutter_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/extensions/user_extension.dart';
import 'package:shortzz/common/utilities/beautify_controls_mixin.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/zego_engine_service.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/config/deepar/local_deepar_filters.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/host/livestream_host_screen.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/utilities/firebase_const.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class CreateLiveStreamScreenController extends BaseController
    with BeautifyControlsMixin {
  RxBool isRestricted = false.obs;
  RxBool hasLiveGoal = false.obs;
  RxString liveGoalTitle = ''.obs;
  RxInt liveGoalTargetAmount = 0.obs;
  RxString liveGoalType = 'followers'.obs; // followers, likes, gifts, duration
  Rx<BroadcastMode> broadcastMode = BroadcastMode.camera.obs;
  RxBool hasFanClub = false.obs;
  RxString fanClubPerks = ''.obs;
  bool isFrontCamera = true;

  // Effects (color enhancement) calls into Zego's native pre-publish
  // pipeline, so unlike a Flutter overlay on the local preview, it's
  // actually visible to viewers. Beautify (whiten/rosy/smooth/sharpen)
  // lives on BeautifyControlsMixin, shared with LivestreamScreenController
  // so the same controls work both before and during a LIVE stream.
  RxBool isColorEnhancementOn = false.obs;
  RxDouble colorEnhancementIntensity = 0.5.obs;

  FirebaseFirestore db = FirebaseFirestore.instance;
  @override
  ZegoExpressEngine zegoEngine = ZegoExpressEngine.instance;

  // DeepAR filters for LIVE (Android only — see DeepArZegoBridge.kt). Off by
  // default: everyone keeps using Zego's own camera + native beauty sliders
  // above until a filter other than "None" is explicitly picked, so this
  // never touches the already-working default path.
  //
  // static: the native DeepAR plugin is a singleton for the app's whole
  // process lifetime (one DeepArPlugin per FlutterEngine), but this
  // controller is recreated fresh every time the user (re)opens this
  // screen. A non-static field meant each fresh controller got a new
  // DeepArControllerPlus with isInitialized == false even when the native
  // side still held a live instance from a previous visit (because leaving
  // the screen only *starts* an unawaited destroy()) -- the new object had
  // no way to know that, so its initialize() skipped straight to creating
  // another native instance instead of awaiting the one still being torn
  // down, racing two calls into the same native plugin and blocking
  // Android's main thread long enough to ANR. Sharing one object across
  // every visit lets DeepArControllerPlus's own destroy-before-reinit
  // guard (see deep_ar_controller_plus.dart) actually see and await that
  // in-flight teardown.
  static final DeepArControllerPlus deepArController = DeepArControllerPlus();
  // Whether enableRawFrameOutput() (DeepAR setOffscreenRendering) has been
  // called on the CURRENT native DeepAR instance. Static for the same
  // reason deepArController is; reset whenever a fresh initialize() runs.
  static bool _deepArOffscreenEnabled = false;
  // See the setVideoConfig/invokeMethod('start', ...) call sites below.
  static const int _deepArLiveFps = 24;
  // static alongside deepArController/localViewID: both the pre-live
  // setup screen and the actual LIVE host screen's filter picker share
  // this state and must agree on it (see onLiveFilterSelected below,
  // now static and called directly from LiveStreamBottomView too).
  static final Rx<DeepARFilters> selectedLiveFilter = Rx(deepArNoneEffect);
  static RxBool isDeepArLiveActive = false.obs;
  static bool _isDeepArLiveBusy = false;
  static const MethodChannel _deepArZegoBridgeChannel =
      MethodChannel('toptap/deepar_zego_bridge');

  static bool get _hasDeepArLicenseForCurrentPlatform => Platform.isAndroid
      ? (_setting?.deeparAndroidKey?.trim().isNotEmpty ?? false)
      : (_setting?.deeparIOSKey?.trim().isNotEmpty ?? false);

  /// Same merge logic as CameraScreenController.availableDeepArFilters (the
  /// post/story camera) — local bundled presets plus anything the admin has
  /// uploaded via Setting.deepARFilters, deduplicated by filter file.
  static List<DeepARFilters> get availableLiveFilters {
    final Map<String, DeepARFilters> uniqueMap = {};
    void addFilter(DeepARFilters filter) {
      final key = (filter.filterFile?.isNotEmpty == true)
          ? filter.filterFile!
          : '${filter.id}_${filter.title}';
      uniqueMap.putIfAbsent(key, () => filter);
    }

    addFilter(deepArNoneEffect);
    for (final filter in _setting?.deepARFilters ?? []) {
      addFilter(filter);
    }
    for (final filter in localDeepArBeautyFilters) {
      if (filter.id == deepArNoneEffect.id) continue;
      addFilter(filter);
    }
    return uniqueMap.values.toList(growable: false);
  }

  Rx<User?> get myUser => SessionManager.instance.getUser().obs;

  static Setting? get _setting => SessionManager.instance.getSettings();
  Rx<Widget?> localView = Rx(null);
  // static for the same reason as deepArController above -- the LIVE
  // host screen's filter picker restarts Zego's preview on this exact
  // canvas (see _startZegoPreviewOnExistingCanvas), and that canvas is
  // the one originally created on this (possibly already-disposed)
  // controller's behalf.
  static RxInt localViewID = RxInt(-1);
  Future<void>? _previewInitFuture;

  @override
  void onInit() {
    super.onInit();
    // Pause the background home-feed reels so their audio does not keep playing
    // behind the camera preview / LIVE screen.
    ReelsScreenController.pauseHomeFeed('createLive');
    initZegoEngine();
  }

  @override
  void onClose() {
    super.onClose();
    // Always pairs with onInit()'s pauseHomeFeed() — ReelsScreenController
    // ref-counts pause/resume calls itself (_overlayPauseDepth), so this is
    // safe to call unconditionally even when we went live: the host
    // screen's own onInit() already called pauseHomeFeed() too, and the
    // feed only actually resumes once every outstanding pause has a
    // matching resume (i.e. once the host screen closes as well).
    ReelsScreenController.resumeHomeFeed('createLive');
    // When the user actually goes live, the host screen REUSES this camera
    // preview canvas (passed as hostPreview). Destroying it here — as
    // stopPreview() does via destroyCanvasView — blacks out the host's own
    // video on the live screen. So only tear the preview down when we are
    // cancelling out of create-live instead.
    if (LivestreamScreenController.activeRoomIds.isEmpty) {
      stopPreview();
      // Only torn down when cancelling out of create-live, for the same
      // reason as stopPreview() above — if we actually went live, the host
      // screen keeps relying on DeepAR feeding Zego's custom capture for
      // the rest of the stream.
      //
      // Gate on isInitialized, not isDeepArLiveActive: switching back to
      // "None" sets isDeepArLiveActive false but deliberately leaves the
      // native DeepAR instance alive (so re-picking a filter is a fast
      // switchEffect() instead of a full re-init). If the user then backs
      // out of this screen with "None" selected, isDeepArLiveActive is
      // already false here and that still-alive native instance would leak
      // -- never destroyed. The next fresh visit to this screen then has
      // to tear down that stale, possibly still camera-touching instance
      // from inside the new initialize() call, racing Zego for the camera
      // and reproducing the same ANR this file already works around above.
      if (deepArController.isInitialized) {
        unawaited(_deepArZegoBridgeChannel.invokeMethod('stop'));
        unawaited(deepArController.destroy());
      }
    }
  }

  Future<bool> requestPermission() async {
    Loggers.info("requestPermission...");
    try {
      PermissionStatus microphoneStatus = await Permission.microphone.request();
      if (microphoneStatus != PermissionStatus.granted) {
        Loggers.error('Error: Microphone permission not granted!!!');
        return false;
      }
    } on Exception catch (error) {
      Loggers.error("[ERROR], request microphone permission exception, $error");
      return false;
    }

    try {
      PermissionStatus cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        Loggers.error('[Error]: Camera permission not granted!!!');
        return false;
      }
    } on Exception catch (error) {
      Loggers.error("[ERROR], request camera permission exception, $error");
      return false;
    }

    return true;
  }

  Future<void> initZegoEngine() async {
    bool isPermissionGranted = await requestPermission();
    if (isPermissionGranted) {
      bool isEngineReady = await ZegoEngineService.instance.ensureEngine();
      if (!isEngineReady) {
        showSnackBar('Unable to initialize live stream. Please try again.');
        return;
      }
      zegoEngine = ZegoExpressEngine.instance;
      await initializeCameraPreview();
    } else {
      Get.bottomSheet(ConfirmationSheet(
          title: LKey.cameraMicrophonePermissionTitle.tr,
          description: LKey.cameraMicrophonePermissionDescription.tr,
          onTap: openAppSettings));
    }
  }

  Future<void> initializeCameraPreview() async {
    if (localView.value != null) return;
    if (_previewInitFuture != null) {
      await _previewInitFuture;
      return;
    }

    _previewInitFuture = _initializeCameraPreview();
    try {
      await _previewInitFuture;
    } finally {
      _previewInitFuture = null;
    }
  }

  Future<void> _initializeCameraPreview() async {
    try {
      showLoader();
      // Must run before startPreview/startPublishingStream, or it never takes
      // effect — see setBeautify/setColorEnhancement below, which is why this
      // has to happen here rather than lazily when Beautify/Effects is opened.
      await zegoEngine.startEffectsEnv();

      // Enable the front camera and un-mute audio streams
      await zegoEngine.enableCamera(true);
      await zegoEngine.mutePublishStreamAudio(false);
      zegoEngine.muteMicrophone(false);

      // Use the front camera for the main publishing channel
      zegoEngine.useFrontCamera(true, channel: ZegoPublishChannel.Main);

      // Create a canvas view for local video preview
      await zegoEngine.createCanvasView((viewID) async {
        localViewID.value = viewID;
        Loggers.info('LOCAL VIEW ID : $localViewID');

        // Set up the preview canvas with aspect fill mode
        ZegoCanvas previewCanvas =
            ZegoCanvas(viewID, viewMode: ZegoViewMode.AspectFill);
        zegoEngine.startPreview(canvas: previewCanvas);
      }).then((canvasViewWidget) {
        // Assign the preview widget to a reactive variable
        localView.value = canvasViewWidget;
      });
    } catch (e, stackTrace) {
      // Log any errors during the preview setup
      Loggers.error('Failed to initialize camera preview: $e\n$stackTrace');
    } finally {
      stopLoader();
    }
  }

  void toggleCamera() {
    isFrontCamera = !isFrontCamera;
    zegoEngine.useFrontCamera(isFrontCamera, channel: ZegoPublishChannel.Main);
  }

  /// Picking a filter switches the whole capture pipeline from Zego's own
  /// camera to DeepAR's (Android only) — see DeepArZegoBridge.kt for why
  /// that has to happen at the native level rather than in Flutter. Picking
  /// "None" reverses it, handing the camera back to Zego untouched.
  ///
  /// static: called from both this screen's own Effects sheet (pre-LIVE)
  /// and LiveStreamBottomView's "Filters" entry (while actually LIVE, see
  /// _showMoreOptions in live_stream_bottom_view.dart) -- same shared
  /// deepArController/isDeepArLiveActive/localViewID either way, so this
  /// has to be reachable without an instance of this controller, which
  /// onClose() may well have already torn down by the time the user is on
  /// the live host screen. showLoader/stopLoader/showSnackBar come from
  /// BaseController.share, the same static singleton instance those mixin
  /// methods are themselves backed by, so this is pixel-identical UX to
  /// calling them on a real controller instance.
  static Future<void> onLiveFilterSelected(DeepARFilters filter) async {
    if (_isDeepArLiveBusy) return;
    // "None" only means "hand the camera back to Zego's own capture" when
    // DeepAR was never activated this screen visit -- that's the only case
    // where Zego's own camera is actually the one live right now. Once a
    // real filter has been picked, DeepAR's native camera session stays
    // open underneath for fast re-switching (see the fast path in
    // _enableDeepArLive), so handing the camera back to Zego's
    // enableCamera(true) at that point means asking Zego to open hardware
    // DeepAR is still holding -- the exact two-owners-one-camera problem
    // this whole feature was built to avoid, just in the other direction.
    // Confirmed on-device: picking a filter then switching back to None
    // froze the preview. Once DeepAR is already active, "None" instead
    // goes through the same effect-switch fast path as any other filter
    // (see _applyDeepArEffect) -- DeepAR keeps rendering the unprocessed
    // camera feed through the existing Zego custom-capture pipeline rather
    // than Zego's own camera ever reopening mid-session.
    if (filter.id == deepArNoneEffect.id && !isDeepArLiveActive.value) {
      await _disableDeepArLive();
      return;
    }
    if (!Platform.isAndroid) {
      BaseController.share.showSnackBar(
          'Filters during LIVE are only available on Android right now.');
      return;
    }
    if (!_hasDeepArLicenseForCurrentPlatform) {
      BaseController.share.showSnackBar('Filters are not configured for this app yet.');
      return;
    }
    await _enableDeepArLive(filter);
  }

  static Future<void> _enableDeepArLive(DeepARFilters filter) async {
    _isDeepArLiveBusy = true;
    BaseController.share.showLoader();
    try {
      // Already in DeepAR mode: just swap the effect and stop. Re-running
      // the full handoff below (camera off, preview restart, a second
      // setOffscreenRendering, bridge start) is not just wasted work --
      // on-device, the second setOffscreenRendering call stopped DeepAR's
      // frameAvailable callback outright (the bridge's frame counter froze
      // at that exact moment), leaving Zego's canvas stuck on the last
      // frame. This is also what makes switching filters mid-LIVE cheap.
      if (isDeepArLiveActive.value && deepArController.isInitialized) {
        await _applyDeepArEffect(filter);
        selectedLiveFilter.value = filter;
        return;
      }

      // Release Zego's own camera hold FIRST, before DeepAR ever touches the
      // camera. deepArController.initialize() calls down into
      // startCameraAndroid(), which opens the physical camera directly —
      // while actually LIVE, Zego has held that same camera open and
      // actively capturing since go-live, so initializing DeepAR before
      // this point hands two different native layers the same camera
      // device at once. That's a native-level resource conflict Flutter's
      // own try/catch here can't intercept, matching "selecting a filter
      // crashes the app and restarts" rather than a catchable error — see
      // DeepArZegoBridge.kt's own documented call-order requirement.
      // Harmless to call before Zego's camera was ever enabled too (the
      // pre-live filter-setup screen, before Start Live).
      await ZegoExpressEngine.instance.enableCamera(false);
      // enableCamera(false) stops Zego's camera capture; its local preview
      // (startPreview in _initializeCameraPreview) is stopped separately.
      // Deliberately the engine call, NOT this controller's stopPreview()
      // wrapper -- that one also destroyCanvasView()s the local canvas and
      // nulls localView, and we need that exact canvas back a few lines
      // down to render DeepAR's frames via Zego's custom video capture.
      ZegoExpressEngine.instance.stopPreview();

      if (!deepArController.isInitialized) {
        // zegoEngine.enableCamera(false) resolving only means Zego has been
        // told to release the camera, not that the physical device is free
        // yet. deepArController.initialize() opens that same camera
        // synchronously on Android's main thread (DeepArPlugin.
        // initializeDeepAR -> cleanupNativeResources ->
        // runOnDeepArThreadBlocking), so if Zego hasn't actually let go,
        // DeepAR's native call blocks the main thread waiting for a camera
        // handle someone else still holds -- an ANR, not a catchable Dart
        // exception. Reproduced on-device (two /data/anr dumps logged at
        // the exact moment of a filter tap). This grace delay gives the
        // native camera HAL time to finish the release first.
        await Future.delayed(const Duration(milliseconds: 500));
        _deepArOffscreenEnabled = false;
        final result = await deepArController.initialize(
          androidLicenseKey: _setting?.deeparAndroidKey,
          iosLicenseKey: _setting?.deeparIOSKey,
          resolution: Resolution.high,
        );
        if (!result.success) {
          BaseController.share.showSnackBar('Could not start filters: ${result.message}');
          await _restoreZegoCameraPreview();
          return;
        }
        // camera_screen_controller.dart (the pre-existing, working DeepAR
        // usage elsewhere in the app) always calls switchEffectWithSlot
        // with the "none" effect once, right after initialize() succeeds,
        // before ever showing its own DeepArPreviewPlus. This file skipped
        // straight to the user's actually-selected filter on first init
        // instead -- confirmed on-device that doing so leaves the preview
        // permanently blank (white) even though initialize(), the camera
        // open, and every frame-analysis callback all report success with
        // no error anywhere. DeepAR's own render pipeline apparently needs
        // this first no-op switchEffect call to prime itself before it
        // will actually paint into the output surface.
        await deepArController.switchEffectWithSlot(slot: 'effect', path: 'none');
      }

      await _applyDeepArEffect(filter);

      final size = deepArController.imageSize;
      if (size == null) {
        BaseController.share.showSnackBar('Could not start filters: unknown camera size.');
        await _restoreZegoCameraPreview();
        return;
      }

      // Offscreen rendering size. imageSize is reported as the sensor
      // preset (landscape, e.g. 1280x720) but LIVE is portrait-locked and
      // DeepAR's own render surface is set up portrait (initializeDeepAR
      // swaps width/height), so render the offscreen frames portrait too
      // or Zego receives a landscape frame of a portrait scene.
      // Once per native DeepAR instance only -- see the fast path above.
      if (!_deepArOffscreenEnabled) {
        final shortSide = size.width < size.height ? size.width : size.height;
        final longSide = size.width < size.height ? size.height : size.width;
        await deepArController.enableRawFrameOutput(
            width: shortSide.toInt(), height: longSide.toInt());
        _deepArOffscreenEnabled = true;
        // DeepAR pushes offscreen frames as fast as the camera delivers
        // them (~45-50fps on this device, unthrottled) while Zego's
        // publish encoder defaults to a scenario-driven ~15fps. Zego's own
        // docs: the configured fps and the fps of frames passed to
        // sendCustomVideoCaptureRawData must match or playback distorts.
        // Set an explicit encode fps here (once, alongside the other
        // one-time offscreen setup) and pass the same number to the
        // native bridge below so it throttles pushes to match, instead of
        // forwarding every camera frame into an encoder tuned for a third
        // of that rate.
        await ZegoExpressEngine.instance.setVideoConfig(
          ZegoVideoConfig.preset(ZegoVideoConfigPreset.Preset360P)
            ..fps = _deepArLiveFps,
        );
      }
      // Enables Zego custom video capture (RAW_DATA) and registers the
      // frame listener. Zego only applies enableCustomVideoCapture to a
      // preview/publish that starts AFTER it was enabled -- the preview
      // started in _initializeCameraPreview() predates it, which is why
      // the canvas stayed black here before: Zego kept previewing its own
      // (now disabled) camera and ignored the pushed frames.
      await _deepArZegoBridgeChannel.invokeMethod('start', {'fps': _deepArLiveFps});
      // enableCamera(false) above was only to make Zego release the physical
      // camera before DeepAR opened it. It also switches off Zego's video
      // capture module as a whole -- and with it disabled, Zego never starts
      // the custom-capture session either: confirmed on-device, the bridge's
      // onStart callback never fired after startPreview, so not a single
      // frame was accepted. With custom capture enabled Zego no longer
      // touches the hardware camera, so turning capture back on here is
      // safe for DeepAR and is what lets Zego actually consume its frames.
      await ZegoExpressEngine.instance.enableCamera(true);
      _startZegoPreviewOnExistingCanvas();

      selectedLiveFilter.value = filter;
      isDeepArLiveActive.value = true;
    } catch (e) {
      Loggers.error('Failed to enable DeepAR for LIVE: $e');
      BaseController.share.showSnackBar('Could not start filters. Staying on the normal camera.');
      await _disableDeepArLive();
    } finally {
      BaseController.share.stopLoader();
      _isDeepArLiveBusy = false;
    }
  }

  static Future<void> _disableDeepArLive() async {
    selectedLiveFilter.value = deepArNoneEffect;
    if (!isDeepArLiveActive.value) return;
    isDeepArLiveActive.value = false;
    try {
      await _deepArZegoBridgeChannel.invokeMethod('stop');
    } catch (e) {
      Loggers.error('Failed to stop DeepAR/Zego bridge: $e');
    }
    // Hand the camera back to Zego's own capture. Same rule as enabling:
    // the preview has to be restarted after custom capture is switched
    // off for Zego to go back to its own camera on this canvas.
    await _restoreZegoCameraPreview();
  }

  static Future<void> _applyDeepArEffect(DeepARFilters filter) async {
    // deepArNoneEffect's own filterFile is the sentinel string 'none', not
    // actually empty, so the id check has to come first -- the old
    // isNotEmpty-only check tried to switchEffect('none') as if it were a
    // real asset path, which fails to load rather than clearing the effect
    // the way switchEffectWithSlot(path: 'none') is actually meant to.
    final filterPath = filter.filterFile ?? '';
    if (filter.id != deepArNoneEffect.id && filterPath.isNotEmpty) {
      await deepArController.switchEffect(filterPath);
    } else {
      await deepArController.switchEffectWithSlot(slot: 'effect', path: 'none');
    }
  }

  /// (Re)starts Zego's local preview on the canvas this screen already
  /// created in _initializeCameraPreview(). Zego's custom-video-capture
  /// setting (on or off) is only picked up by a preview started after it
  /// changed, so both the DeepAR enable and disable paths end with this.
  static void _startZegoPreviewOnExistingCanvas() {
    if (localViewID.value == -1) return;
    ZegoExpressEngine.instance.startPreview(
      canvas: ZegoCanvas(localViewID.value, viewMode: ZegoViewMode.AspectFill),
    );
  }

  /// Puts Zego back on its own camera + preview (used when disabling a
  /// filter, and on every failure path while enabling one).
  static Future<void> _restoreZegoCameraPreview() async {
    ZegoExpressEngine.instance.stopPreview();
    await ZegoExpressEngine.instance.enableCamera(true);
    _startZegoPreviewOnExistingCanvas();
  }

  void onEffectsTap() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(LKey.effects.tr,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Switch(
                      value: isColorEnhancementOn.value,
                      onChanged: toggleColorEnhancement,
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                        width: 110,
                        child: Text(LKey.colorEnhancement.tr,
                            style:
                                const TextStyle(color: Colors.white70))),
                    Expanded(
                      child: Slider(
                        value: colorEnhancementIntensity.value,
                        min: 0,
                        max: 1,
                        activeColor: Colors.orange,
                        onChanged: !isColorEnhancementOn.value
                            ? null
                            : setColorEnhancementIntensity,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(LKey.filters.tr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  isDeepArLiveActive.value
                      ? (selectedLiveFilter.value.title ?? LKey.none.tr)
                      : LKey.none.tr,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 92,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableLiveFilters.length,
                    itemBuilder: (context, index) {
                      final filter = availableLiveFilters[index];
                      final isSelected = filter.id == selectedLiveFilter.value.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          onTap: () => onLiveFilterSelected(filter),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 56,
                                width: 56,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.orange
                                        : Colors.white24,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  color: Colors.white12,
                                ),
                                child: _liveFilterThumbnail(filter.image),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  filter.title ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: isSelected
                                          ? Colors.orange
                                          : Colors.white70,
                                      fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )),
      ),
      isScrollControlled: true,
    );
  }

  Widget _liveFilterThumbnail(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return const Icon(Icons.block, color: Colors.white38, size: 28);
    }
    final uri = Uri.tryParse(imagePath);
    final isNetwork = uri != null && uri.hasScheme && uri.host.isNotEmpty;
    return isNetwork
        ? Image.network(imagePath, fit: BoxFit.cover)
        : Image.asset(imagePath, fit: BoxFit.cover);
  }

  void toggleColorEnhancement(bool enable) {
    isColorEnhancementOn.value = enable;
    _applyColorEnhancement();
  }

  void setColorEnhancementIntensity(double value) {
    colorEnhancementIntensity.value = value;
    if (isColorEnhancementOn.value) _applyColorEnhancement();
  }

  void _applyColorEnhancement() {
    zegoEngine.enableColorEnhancement(
      isColorEnhancementOn.value,
      ZegoColorEnhancementParams(
        colorEnhancementIntensity.value,
        1.0, // Protect natural skin tone at full strength.
        0.0,
      ),
    );
  }

  /// Switches between broadcasting with the camera on (default) and
  /// voice-chat (audio only). Camera preview stays initialized either way —
  /// we just stop feeding it to Zego's publish stream — so switching back to
  /// Device camera is instant. Mobile gaming isn't wired up here; the UI
  /// shows it disabled until native screen-capture support exists.
  Future<void> setBroadcastMode(BroadcastMode mode) async {
    if (mode == BroadcastMode.gaming || broadcastMode.value == mode) return;
    broadcastMode.value = mode;
    await zegoEngine.enableCamera(mode == BroadcastMode.camera);
  }

  void onCloseTap() {
    Get.back();
    stopPreview();
  }

  Future<void> stopPreview() async {
    zegoEngine.stopPreview();
    if (localViewID.value != -1) {
      await zegoEngine.destroyCanvasView(localViewID.value);
      localViewID.value = -1;
      localView.value = null;
    }
  }

  void onLiveGoalTap() {
    if (hasLiveGoal.value) {
      // If already has goal, show confirmation to remove
      Get.dialog(
        AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Remove Live Goal?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Do you want to remove your current live goal?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                hasLiveGoal.value = false;
                liveGoalTitle.value = '';
                liveGoalTargetAmount.value = 0;
                Get.back();
              },
              child: Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      // Show live goal setup sheet
      _showLiveGoalSheet();
    }
  }

  void _showLiveGoalSheet() {
    final goalTitleController = TextEditingController();
    final targetAmountController = TextEditingController();
    RxString selectedGoalType = 'followers'.obs;

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.flag, color: Colors.orange, size: 24),
                SizedBox(width: 12),
                Text(
                  'Set Live Goal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Goal Title
            Text(
              'Goal Title',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: goalTitleController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g., Reach 100 new followers',
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),

            SizedBox(height: 20),

            // Goal Type
            Text(
              'Goal Type',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Obx(() => Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedGoalType.value,
                      dropdownColor: Colors.grey[800],
                      isExpanded: true,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      style: TextStyle(color: Colors.white),
                      icon:
                          Icon(Icons.keyboard_arrow_down, color: Colors.white),
                      items: [
                        DropdownMenuItem(
                          value: 'followers',
                          child: Row(
                            children: [
                              Icon(Icons.person_add,
                                  color: Colors.blue, size: 20),
                              SizedBox(width: 8),
                              Text('New Followers'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'likes',
                          child: Row(
                            children: [
                              Icon(Icons.favorite, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Likes'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'gifts',
                          child: Row(
                            children: [
                              Icon(Icons.card_giftcard,
                                  color: Colors.purple, size: 20),
                              SizedBox(width: 8),
                              Text('Gifts Received'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'duration',
                          child: Row(
                            children: [
                              Icon(Icons.timer, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Text('Live Duration (minutes)'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          selectedGoalType.value = value;
                        }
                      },
                    ),
                  ),
                )),

            SizedBox(height: 20),

            // Target Amount
            Text(
              'Target Amount',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: targetAmountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter target number',
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),

            SizedBox(height: 30),

            // Set Goal Button
            GestureDetector(
              onTap: () {
                final title = goalTitleController.text.trim();
                final target = int.tryParse(targetAmountController.text.trim());
                if (title.isNotEmpty && target != null && target > 0) {
                  liveGoalTitle.value = title;
                  liveGoalTargetAmount.value = target;
                  liveGoalType.value = selectedGoalType.value;
                  hasLiveGoal.value = true;
                  Get.back();
                  Get.snackbar(
                    'Live Goal Set!',
                    'Your live goal has been set successfully',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                    duration: Duration(seconds: 2),
                  );
                } else {
                  Get.snackbar(
                    'Error',
                    'Enter a goal title and a target greater than zero.',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.deepOrange],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Set Goal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> shareGoingLive() async {
    await SharePlus.instance.share(
      ShareParams(text: LKey.shareGoingLiveText.tr, subject: 'TopTap LIVE'),
    );
  }

  /// TopTap has no ad platform to back a real paid "Promote" like TikTok's,
  /// so this is an honest stand-in: it drives the same free, organic reach
  /// lever that's actually available — inviting more people to watch.
  void onPromoteTap() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange),
                const SizedBox(width: 12),
                Text(LKey.promoteLiveTitle.tr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Text(LKey.promoteLiveDescription.tr,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Get.back();
                shareGoingLive();
              },
              child: Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(LKey.share.tr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onSettingsTap() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(LKey.liveSettings.tr,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Obx(() => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(LKey.restrictUserRequests.tr,
                      style: const TextStyle(color: Colors.white)),
                  value: isRestricted.value,
                  onChanged: (value) => isRestricted.value = value,
                )),
          ],
        ),
      ),
    );
  }

  void onFanClubTap() {
    final perksController = TextEditingController(text: fanClubPerks.value);
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.diamond_outlined, color: Colors.orange),
                const SizedBox(width: 12),
                Text(LKey.fanClub.tr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Obx(() => Switch(
                      value: hasFanClub.value,
                      onChanged: (value) => hasFanClub.value = value,
                    )),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: perksController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: LKey.fanClubPerksHint.tr,
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                fanClubPerks.value = perksController.text.trim();
                Get.back();
              },
              child: Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(LKey.done.tr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> onStartLive() async {
    Loggers.info('=== STARTING LIVE STREAM PROCESS ===');

    // The cached user can be stale (followers gained since login), so refresh
    // it before applying the minimum-followers rule.
    final minFollowers = _setting?.minFollowersForLive ?? 0;
    if (minFollowers > 0 && (myUser.value?.followerCount ?? 0) < minFollowers) {
      try {
        await UserService.instance
            .fetchUserDetails(userId: SessionManager.instance.getUserID());
      } catch (e) {
        Loggers.warning('Could not refresh user before LIVE: $e');
      }
    }

    if ((myUser.value?.followerCount ?? 0) < minFollowers) {
      Loggers.info('Follower count check failed');
      showSnackBar(LKey.minFollowersNeededToGoLive
          .trParams({'count': '${_setting?.minFollowersForLive}'}));
      return;
    }

    User? user = myUser.value;
    if (user == null) {
      Loggers.error('User Not found. Cannot start live stream.');
      return;
    }
    int userId = user.id ?? -1;

    if (userId == -1) {
      Loggers.error('Wrong User ID is $userId');
      return;
    }

    if (localView.value == null && !isDeepArLiveActive.value) {
      Loggers.info('Local view is null, checking camera initialization...');
      await initZegoEngine();
      if (localView.value == null && !isDeepArLiveActive.value) {
        showSnackBar('Local View not found');
        return;
      }
    }

    Loggers.info('All pre-checks passed, creating livestream...');

    // Create Livestream model
    int time = DateTime.now().millisecondsSinceEpoch;

    try {
      Loggers.info(
          'Creating livestream model with goal data: hasGoal=${hasLiveGoal.value}, title=${liveGoalTitle.value}');

      // Try creating without live goal first to test
      Livestream livestream;
      try {
        livestream = user.livestream(
            type: LivestreamType.livestream,
            time: time,
            restrictToJoin: isRestricted.value ? 1 : 0,
            hostViewId: localViewID.value,
            hasLiveGoal: hasLiveGoal.value,
            liveGoalTitle: hasLiveGoal.value ? liveGoalTitle.value : null,
            liveGoalType: hasLiveGoal.value ? liveGoalType.value : null,
            liveGoalTargetAmount:
                hasLiveGoal.value ? liveGoalTargetAmount.value : null,
            broadcastMode: broadcastMode.value,
            hasFanClub: hasFanClub.value,
            fanClubPerks:
                hasFanClub.value && fanClubPerks.value.isNotEmpty
                    ? fanClubPerks.value
                    : null);
      } catch (e) {
        Loggers.error('Error creating livestream with goals: $e');
        // Fallback: create without live goal parameters
        livestream = user.livestream(
            type: LivestreamType.livestream,
            time: time,
            restrictToJoin: isRestricted.value ? 1 : 0,
            hostViewId: localViewID.value,
            broadcastMode: broadcastMode.value);
      }

      Loggers.info('Livestream model created successfully');

      // Create LivestreamUser model
      AppUser livestreamUser = user.appUser;
      Loggers.info('LivestreamUser model created');

      // Create LivestreamUser model
      LivestreamUserState livestreamUserState =
          user.streamState(
              time: time,
              stateType: LivestreamUserType.host,
              isVideoOn: broadcastMode.value != BroadcastMode.voice);

      Loggers.info('LivestreamUserState model created');
      Loggers.info('Starting live stream...');
      Loggers.info('Livestream Model: ${livestream.toJson()}');
      Loggers.info('Livestream User Model: ${livestreamUser.toJson()}');

      // Show loader before Firestore operations
      showLoader();
      Loggers.info('Loader shown, starting Firestore operations...');

      DocumentReference livestreamRef =
          db.collection(FirebaseConst.liveStreams).doc('$userId');
      DocumentReference usersRef =
          db.collection(FirebaseConst.appUsers).doc('$userId');
      CollectionReference userStateCollection =
          livestreamRef.collection(FirebaseConst.userState);
      DocumentReference userStateRef = userStateCollection.doc('$userId');

      // This room's id is this host's own user id, so every stream they
      // ever start reuses the exact same userState subcollection path.
      // deleteStreamOnFirebase() clears it on a clean Stop, but a crash,
      // force-close, or the OS killing the app while live skips that —
      // leaving old viewers' state docs sitting there. The next stream
      // then finds a viewer's doc "already exists" on their very first
      // join, silently skipping the fresh-join branch (no "joined"
      // announcement, no initial state write) even though it's actually
      // their first time in this brand new stream. Clearing any leftovers
      // before this stream's own doc is written guarantees a clean start
      // regardless of how the previous stream ended.
      final staleStates = await userStateCollection.get();
      Loggers.info(
          'Clearing ${staleStates.docs.length} leftover userState doc(s) from a previous stream before going live.');

      WriteBatch batch = db.batch();
      for (final doc in staleStates.docs) {
        batch.delete(doc.reference);
      }

      final livestreamData = livestream.toJson();
      livestreamData[FirebaseConst.lastHeartbeatAt] = time;
      batch.set(livestreamRef, livestreamData);
      batch.set(usersRef, livestreamUser.toJson());
      batch.set(userStateRef, livestreamUserState.toJson());

      Loggers.info('Batch operations prepared, committing...');

      // Commit batch operation
      await batch.commit();

      Loggers.success('Livestream started successfully!');

      // Navigate to live stream host screen. Always Zego's own canvas: with
      // a LIVE filter active, DeepAR renders offscreen and feeds Zego's
      // custom video capture, and this canvas is what renders those frames
      // (see _enableDeepArLive). DeepAR's own DeepArPreviewPlus texture is
      // stale in that mode -- on-device it showed a frozen half-black /
      // half-white frame on this very screen.
      Widget? hostPreview = localView.value;
      Loggers.info('Navigating to host screen...');

      Get.off(() => LivestreamHostScreen(
          hostPreview: hostPreview, livestream: livestream, isHost: true));
    } catch (e, stackTrace) {
      Loggers.error('Failed to start live stream: $e');
      Loggers.error('StackTrace: $stackTrace');
      showSnackBar('Failed to start live stream: $e');
    } finally {
      stopLoader(); // Ensure loader stops in all cases
      Loggers.info('Loader stopped');
    }
  }

  // Debug method to test live goal creation
  void testLiveGoalCreation() {
    try {
      User? user = myUser.value;
      if (user == null) {
        Loggers.error('No user found for testing');
        return;
      }

      int time = DateTime.now().millisecondsSinceEpoch;

      Livestream testStream = user.livestream(
        type: LivestreamType.livestream,
        time: time,
        description: "Test Stream",
        hasLiveGoal: true,
        liveGoalTitle: "Test Goal",
        liveGoalType: "likes",
        liveGoalTargetAmount: 100,
      );

      Loggers.info(
          'Test livestream created successfully: ${testStream.toJson()}');
      showSnackBar('Live goal test passed!');
    } catch (e) {
      Loggers.error('Live goal test failed: $e');
      showSnackBar('Live goal test failed: $e');
    }
  }
}
