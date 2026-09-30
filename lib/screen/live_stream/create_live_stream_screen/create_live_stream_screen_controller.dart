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

class CreateLiveStreamScreenController extends BaseController {
  RxBool isRestricted = false.obs;
  RxBool hasLiveGoal = false.obs;
  RxString liveGoalTitle = ''.obs;
  RxInt liveGoalTargetAmount = 0.obs;
  RxString liveGoalType = 'followers'.obs; // followers, likes, gifts, duration
  Rx<BroadcastMode> broadcastMode = BroadcastMode.camera.obs;
  RxBool hasFanClub = false.obs;
  RxString fanClubPerks = ''.obs;
  bool isFrontCamera = true;

  // Beautify (whiten/rosy/smooth/sharpen) and Effects (color enhancement) —
  // both call into Zego's native pre-publish pipeline, so unlike a Flutter
  // overlay on the local preview, these are actually visible to viewers.
  RxBool isBeautifyOn = false.obs;
  RxInt whitenIntensity = 50.obs;
  RxInt rosyIntensity = 50.obs;
  RxInt smoothIntensity = 50.obs;
  RxInt sharpenIntensity = 50.obs;
  RxBool isColorEnhancementOn = false.obs;
  RxDouble colorEnhancementIntensity = 0.5.obs;
  FirebaseFirestore db = FirebaseFirestore.instance;
  ZegoExpressEngine zegoEngine = ZegoExpressEngine.instance;

  // DeepAR filters for LIVE (Android only — see DeepArZegoBridge.kt). Off by
  // default: everyone keeps using Zego's own camera + native beauty sliders
  // above until a filter other than "None" is explicitly picked, so this
  // never touches the already-working default path.
  final DeepArControllerPlus deepArController = DeepArControllerPlus();
  final Rx<DeepARFilters> selectedLiveFilter = Rx(deepArNoneEffect);
  RxBool isDeepArLiveActive = false.obs;
  bool _isDeepArLiveBusy = false;
  static const MethodChannel _deepArZegoBridgeChannel =
      MethodChannel('toptap/deepar_zego_bridge');

  bool get _hasDeepArLicenseForCurrentPlatform => Platform.isAndroid
      ? (_setting?.deeparAndroidKey?.trim().isNotEmpty ?? false)
      : (_setting?.deeparIOSKey?.trim().isNotEmpty ?? false);

  /// Same merge logic as CameraScreenController.availableDeepArFilters (the
  /// post/story camera) — local bundled presets plus anything the admin has
  /// uploaded via Setting.deepARFilters, deduplicated by filter file.
  List<DeepARFilters> get availableLiveFilters {
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

  Setting? get _setting => SessionManager.instance.getSettings();
  Rx<Widget?> localView = Rx(null);
  RxInt localViewID = RxInt(-1);
  TextEditingController titleController = TextEditingController();
  Future<void>? _previewInitFuture;

  @override
  void onInit() {
    super.onInit();
    // Pause the background home-feed reels so their audio does not keep playing
    // behind the camera preview / LIVE screen.
    ReelsScreenController.pauseHomeFeed();
    initZegoEngine();
  }

  @override
  void onClose() {
    super.onClose();
    // When the user actually goes live, the host screen REUSES this camera
    // preview canvas (passed as hostPreview). Destroying it here — as
    // stopPreview() does via destroyCanvasView — blacks out the host's own
    // video on the live screen. So only tear the preview down (and resume the
    // background feed) when we are cancelling out of create-live instead.
    if (LivestreamScreenController.activeRoomIds.isEmpty) {
      stopPreview();
      ReelsScreenController.resumeHomeFeed();
      // Only torn down when cancelling out of create-live, for the same
      // reason as stopPreview() above — if we actually went live, the host
      // screen keeps relying on DeepAR feeding Zego's custom capture for
      // the rest of the stream.
      if (isDeepArLiveActive.value) {
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
  Future<void> onLiveFilterSelected(DeepARFilters filter) async {
    if (_isDeepArLiveBusy) return;
    if (filter.id == deepArNoneEffect.id) {
      await _disableDeepArLive();
      return;
    }
    if (!Platform.isAndroid) {
      showSnackBar('Filters during LIVE are only available on Android right now.');
      return;
    }
    if (!_hasDeepArLicenseForCurrentPlatform) {
      showSnackBar('Filters are not configured for this app yet.');
      return;
    }
    await _enableDeepArLive(filter);
  }

  Future<void> _enableDeepArLive(DeepARFilters filter) async {
    _isDeepArLiveBusy = true;
    showLoader();
    try {
      if (!deepArController.isInitialized) {
        final result = await deepArController.initialize(
          androidLicenseKey: _setting?.deeparAndroidKey,
          iosLicenseKey: _setting?.deeparIOSKey,
          resolution: Resolution.high,
        );
        if (!result.success) {
          showSnackBar('Could not start filters: ${result.message}');
          return;
        }
      }

      final filterPath = filter.filterFile ?? '';
      if (filterPath.isNotEmpty) {
        await deepArController.switchEffect(filterPath);
      } else {
        await deepArController.switchEffectWithSlot(slot: 'effect', path: 'none');
      }

      final size = deepArController.imageSize;
      if (size == null) {
        showSnackBar('Could not start filters: unknown camera size.');
        return;
      }

      // Stop Zego's own camera before custom-capture frames start arriving
      // — see enableCustomVideoCapture's documented call order.
      await zegoEngine.enableCamera(false);
      await deepArController.enableRawFrameOutput(
          width: size.width.toInt(), height: size.height.toInt());
      await _deepArZegoBridgeChannel.invokeMethod('start');

      selectedLiveFilter.value = filter;
      isDeepArLiveActive.value = true;
    } catch (e) {
      Loggers.error('Failed to enable DeepAR for LIVE: $e');
      showSnackBar('Could not start filters. Staying on the normal camera.');
      await _disableDeepArLive();
    } finally {
      stopLoader();
      _isDeepArLiveBusy = false;
    }
  }

  Future<void> _disableDeepArLive() async {
    selectedLiveFilter.value = deepArNoneEffect;
    if (!isDeepArLiveActive.value) return;
    isDeepArLiveActive.value = false;
    try {
      await _deepArZegoBridgeChannel.invokeMethod('stop');
    } catch (e) {
      Loggers.error('Failed to stop DeepAR/Zego bridge: $e');
    }
    // Hand the camera back to Zego's own capture.
    await zegoEngine.enableCamera(true);
  }

  void toggleBeautify(bool enable) {
    isBeautifyOn.value = enable;
    zegoEngine.enableEffectsBeauty(enable);
    if (enable) _applyBeautyParam();
  }

  void setBeautyParam({
    int? whiten,
    int? rosy,
    int? smooth,
    int? sharpen,
  }) {
    if (whiten != null) whitenIntensity.value = whiten;
    if (rosy != null) rosyIntensity.value = rosy;
    if (smooth != null) smoothIntensity.value = smooth;
    if (sharpen != null) sharpenIntensity.value = sharpen;
    if (isBeautifyOn.value) _applyBeautyParam();
  }

  void _applyBeautyParam() {
    zegoEngine.setEffectsBeautyParam(ZegoEffectsBeautyParam(
      whitenIntensity.value,
      rosyIntensity.value,
      smoothIntensity.value,
      sharpenIntensity.value,
    ));
  }

  void onBeautifyTap() {
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
                    Text(LKey.beautify.tr,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Switch(
                      value: isBeautifyOn.value,
                      onChanged: toggleBeautify,
                    ),
                  ],
                ),
                _beautySlider(LKey.whiten.tr, whitenIntensity.value,
                    (v) => setBeautyParam(whiten: v.round())),
                _beautySlider(LKey.rosy.tr, rosyIntensity.value,
                    (v) => setBeautyParam(rosy: v.round())),
                _beautySlider(LKey.smooth.tr, smoothIntensity.value,
                    (v) => setBeautyParam(smooth: v.round())),
                _beautySlider(LKey.sharpen.tr, sharpenIntensity.value,
                    (v) => setBeautyParam(sharpen: v.round())),
              ],
            )),
      ),
      isScrollControlled: true,
    );
  }

  Widget _beautySlider(
      String label, int value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
            width: 70,
            child:
                Text(label, style: const TextStyle(color: Colors.white70))),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            activeColor: Colors.orange,
            onChanged: !isBeautifyOn.value ? null : onChanged,
          ),
        ),
      ],
    );
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

    if (titleController.text.trim().isEmpty) {
      Loggers.info('Title is empty');
      return showSnackBar(LKey.enterLiveStreamTitle.tr);
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
            description: titleController.text.trim(),
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
            description: titleController.text.trim(),
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
      DocumentReference userStateRef =
          livestreamRef.collection(FirebaseConst.userState).doc('$userId');

      WriteBatch batch = db.batch();

      final livestreamData = livestream.toJson();
      livestreamData[FirebaseConst.lastHeartbeatAt] = time;
      batch.set(livestreamRef, livestreamData);
      batch.set(usersRef, livestreamUser.toJson());
      batch.set(userStateRef, livestreamUserState.toJson());

      Loggers.info('Batch operations prepared, committing...');

      // Commit batch operation
      await batch.commit();

      Loggers.success('Livestream started successfully!');

      // Navigate to live stream host screen
      Widget? hostPreview = isDeepArLiveActive.value
          ? DeepArPreviewPlus(deepArController)
          : localView.value;
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
