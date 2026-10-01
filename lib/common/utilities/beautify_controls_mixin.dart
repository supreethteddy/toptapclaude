import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

/// TikTok's Beauty tab has 8 categories; only Smooth/Brighten/Contrast/
/// Foundation map onto the 4 real Zego beauty params this app has
/// (smooth/whiten/sharpen/rosy respectively). Shape/Eye/Nose/Tooth need
/// per-region face reshaping that neither Zego's beauty API nor the
/// vendored DeepAR plugin (no liquify/face-mesh API — whole-effect-file
/// swaps only) can do here, so they're shown for layout parity but marked
/// coming-soon rather than silently omitted or faked.
enum BeautifyCategory {
  smooth(LKey.smooth, Icons.blur_on),
  shape(LKey.shape, Icons.face_retouching_natural, isComingSoon: true),
  eye(LKey.eye, Icons.remove_red_eye_outlined, isComingSoon: true),
  nose(LKey.nose, Icons.air, isComingSoon: true),
  contrast(LKey.contrast, Icons.contrast),
  foundation(LKey.foundation, Icons.format_paint),
  brighten(LKey.brighten, Icons.wb_sunny_outlined),
  tooth(LKey.tooth, Icons.sentiment_satisfied_outlined, isComingSoon: true);

  final String labelKey;
  final IconData icon;
  final bool isComingSoon;

  const BeautifyCategory(this.labelKey, this.icon, {this.isComingSoon = false});
}

/// Zego's beauty params (whiten/rosy/smooth/sharpen) + the TikTok-style
/// tabbed panel to control them, shared between CreateLiveStreamScreenController
/// (set up before going live) and LivestreamScreenController (adjusted while
/// already live) - both call into the same ZegoExpressEngine.instance
/// singleton, so either controller mixing this in reaches the same stream.
mixin BeautifyControlsMixin on BaseController {
  ZegoExpressEngine get zegoEngine;

  RxBool isBeautifyOn = false.obs;
  RxInt whitenIntensity = 50.obs;
  RxInt rosyIntensity = 50.obs;
  RxInt smoothIntensity = 50.obs;
  RxInt sharpenIntensity = 50.obs;

  // TikTok-style Beauty tab: only 4 of these 8 categories have a real
  // effect behind them (Zego doesn't expose per-region face reshaping, and
  // there's no liquify/face-mesh API in the vendored DeepAR plugin either —
  // see BeautifyCategory.isComingSoon), so the rest are shown, matching the
  // reference layout, but marked "coming soon" instead of silently missing.
  RxInt selectedBeautifyTab = 0.obs; // 0 = Beauty, 1 = Makeup
  Rx<BeautifyCategory> selectedBeautifyCategory = BeautifyCategory.smooth.obs;

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

  int? _intensityForCategory(BeautifyCategory category) {
    switch (category) {
      case BeautifyCategory.smooth:
        return smoothIntensity.value;
      case BeautifyCategory.brighten:
        return whitenIntensity.value;
      case BeautifyCategory.contrast:
        return sharpenIntensity.value;
      case BeautifyCategory.foundation:
        return rosyIntensity.value;
      case BeautifyCategory.shape:
      case BeautifyCategory.eye:
      case BeautifyCategory.nose:
      case BeautifyCategory.tooth:
        return null;
    }
  }

  void _setIntensityForCategory(BeautifyCategory category, int value) {
    switch (category) {
      case BeautifyCategory.smooth:
        setBeautyParam(smooth: value);
        break;
      case BeautifyCategory.brighten:
        setBeautyParam(whiten: value);
        break;
      case BeautifyCategory.contrast:
        setBeautyParam(sharpen: value);
        break;
      case BeautifyCategory.foundation:
        setBeautyParam(rosy: value);
        break;
      case BeautifyCategory.shape:
      case BeautifyCategory.eye:
      case BeautifyCategory.nose:
      case BeautifyCategory.tooth:
        break;
    }
  }

  void onBeautifyTap() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Obx(() {
          final tab = selectedBeautifyTab.value;
          return Column(
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
              const SizedBox(height: 8),
              Row(
                children: [
                  _beautifyTabButton(LKey.beauty.tr, 0),
                  const SizedBox(width: 20),
                  _beautifyTabButton(LKey.makeup.tr, 1),
                ],
              ),
              const SizedBox(height: 16),
              if (tab == 0) ..._buildBeautyTabContent() else _buildMakeupTabContent(),
            ],
          );
        }),
      ),
      isScrollControlled: true,
    );
  }

  Widget _beautifyTabButton(String label, int index) {
    final isSelected = selectedBeautifyTab.value == index;
    return InkWell(
      onTap: () => selectedBeautifyTab.value = index,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 20,
            color: isSelected ? Colors.orange : Colors.transparent,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBeautyTabContent() {
    final category = selectedBeautifyCategory.value;
    final intensity = _intensityForCategory(category);
    return [
      if (category.isComingSoon)
        SizedBox(
          height: 44,
          child: Center(
            child: Text(LKey.comingSoon.tr,
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ),
        )
      else
        _beautySlider(
          category.labelKey.tr,
          intensity ?? 0,
          (v) => _setIntensityForCategory(category, v.round()),
        ),
      const SizedBox(height: 8),
      SizedBox(
        height: 76,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: BeautifyCategory.values.length,
          itemBuilder: (context, index) {
            final item = BeautifyCategory.values[index];
            final isSelected = item == category;
            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: InkWell(
                onTap: () {
                  selectedBeautifyCategory.value = item;
                  if (item.isComingSoon) {
                    showSnackBar(LKey.comingSoon.tr);
                  }
                },
                child: Opacity(
                  opacity: item.isComingSoon ? 0.4 : 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2A2A2A),
                          border: Border.all(
                            color: isSelected ? Colors.orange : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(item.icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.labelKey.tr,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildMakeupTabContent() {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          LKey.makeupComingSoonDescription.tr,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ),
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
}
