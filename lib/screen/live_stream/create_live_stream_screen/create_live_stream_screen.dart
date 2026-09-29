import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/live_stream/create_live_stream_screen/create_live_stream_screen_controller.dart';

class CreateLiveStreamScreen extends StatelessWidget {
  const CreateLiveStreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CreateLiveStreamScreenController());
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background - User profile or camera preview (exact TopTap style)
          Obx(
            () {
              User? user = controller.myUser.value;
              bool showCamera =
                  controller.broadcastMode.value == BroadcastMode.camera;
              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                      Colors.black,
                    ],
                  ),
                ),
                child: (showCamera ? controller.localView.value : null) ??
                    ((user?.profilePhoto ?? '').isNotEmpty
                        ? Image.network(
                            user!.profilePhoto!.addBaseURL(),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey[900],
                              child: const Icon(Icons.person,
                                  size: 100, color: Colors.white54),
                            ),
                          )
                        : Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.person,
                                size: 100, color: Colors.white54),
                          )),
              );
            },
          ),

          // Bottom gradient overlay (exact TopTap style)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar with close button (exact TopTap style)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: controller.onCloseTap,
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom content area (exact TopTap style)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Camera flip button (small icon+label, matching the
                      // Music/Live Goal row style)
                      _buildFeatureButton(
                        icon: Icons.flip_camera_ios,
                        label: 'Flip',
                        onTap: controller.toggleCamera,
                      ),

                      const SizedBox(height: 20),

                      // Stream title input with enhanced design (exact TopTap style)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: controller.titleController,
                          onTapOutside: (event) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            hintText: LKey.enterLiveStreamTitle.tr,
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 17,
                              fontWeight: FontWeight.w300,
                            ),
                            prefixIcon: Icon(
                              Icons.title,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                          ),
                          maxLines: 2,
                          minLines: 1,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Enhanced feature options row (exact TopTap style)
                      // NOTE: "Music" stays disabled here intentionally. Its
                      // onTap was never wired to real functionality (just an
                      // empty stub), and there is no music-for-livestream
                      // backend support in this app — the same Music button
                      // is independently commented out in the camera
                      // recording screen (lib/screen/camera_screen/camera_screen.dart)
                      // for the same reason. Re-enabling it would require new
                      // backend/engine capability, which is out of scope for
                      // this cosmetic pass.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Obx(() => _buildFeatureButton(
                                icon: Icons.auto_fix_high,
                                label: LKey.beautify.tr,
                                isActive: controller.isBeautifyOn.value,
                                onTap: controller.onBeautifyTap,
                              )),
                          Obx(() => _buildFeatureButton(
                                icon: Icons.auto_awesome,
                                label: LKey.effects.tr,
                                isActive: controller.isColorEnhancementOn.value,
                                onTap: controller.onEffectsTap,
                              )),
                          _buildFeatureButton(
                            icon: Icons.settings_outlined,
                            label: LKey.settings.tr,
                            onTap: controller.onSettingsTap,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // _buildFeatureButton(
                          //   icon: Icons.music_note,
                          //   label: 'Music',
                          //   onTap: () {
                          //     // Handle music functionality
                          //   },
                          // ),
                          Obx(() => _buildFeatureButton(
                                icon: Icons.flag,
                                label: 'Live Goal',
                                isActive: controller.hasLiveGoal.value,
                                onTap: controller.onLiveGoalTap,
                              )),
                          Obx(() => _buildFeatureButton(
                                icon: Icons.diamond_outlined,
                                label: LKey.fanClub.tr,
                                isActive: controller.hasFanClub.value,
                                onTap: controller.onFanClubTap,
                              )),
                          _buildFeatureButton(
                            icon: Icons.ios_share,
                            label: LKey.share.tr,
                            onTap: controller.shareGoingLive,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFeatureButton(
                            icon: Icons.local_fire_department,
                            label: LKey.promote.tr,
                            onTap: controller.onPromoteTap,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Broadcast source (matches TikTok's Device camera /
                      // Voice chat / Mobile gaming row). Mobile gaming needs
                      // native screen-capture support, so it's shown but
                      // disabled for now.
                      Obx(() => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildBroadcastModeOption(
                                icon: Icons.videocam,
                                label: LKey.deviceCamera.tr,
                                mode: BroadcastMode.camera,
                                current: controller.broadcastMode.value,
                                onTap: () => controller
                                    .setBroadcastMode(BroadcastMode.camera),
                              ),
                              _buildBroadcastModeOption(
                                icon: Icons.mic,
                                label: LKey.voiceChat.tr,
                                mode: BroadcastMode.voice,
                                current: controller.broadcastMode.value,
                                onTap: () => controller
                                    .setBroadcastMode(BroadcastMode.voice),
                              ),
                              _buildBroadcastModeOption(
                                icon: Icons.sports_esports_outlined,
                                label: LKey.mobileGaming.tr,
                                mode: BroadcastMode.gaming,
                                current: controller.broadcastMode.value,
                                enabled: false,
                                onTap: () =>
                                    controller.showSnackBar(LKey.comingSoon.tr),
                              ),
                            ],
                          )),

                      const SizedBox(height: 20),

                      // Live Goal Display (when set)
                      Obx(() {
                        if (controller.hasLiveGoal.value) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.flag,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Live Goal Set',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  controller.liveGoalTitle.value,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Target: ${controller.liveGoalTargetAmount.value} ${_getGoalTypeLabel(controller.liveGoalType.value)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),

                      const SizedBox(height: 20),

                      // Restrict user requests feature (in TopTap style)
                      Obx(() {
                        bool isChecked = controller.isRestricted.value;
                        return GestureDetector(
                          onTap: () {
                            controller.isRestricted.value = !isChecked;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isChecked
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.7),
                                      width: 2,
                                    ),
                                  ),
                                  child: isChecked
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.black,
                                          size: 14,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  LKey.restrictUserRequests.tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      // const Spacer(),

                      const SizedBox(height: 30),

                      // Enhanced Go LIVE button (exact TopTap style)
                      GestureDetector(
                        onTap: controller.onStartLive,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.shade600,
                                Colors.red.shade700,
                                Colors.red.shade800,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.live_tv,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                LKey.startLive.tr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGoalTypeLabel(String goalType) {
    switch (goalType) {
      case 'followers':
        return 'new followers';
      case 'likes':
        return 'likes';
      case 'gifts':
        return 'gifts';
      case 'duration':
        return 'minutes';
      default:
        return '';
    }
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.orange.withOpacity(0.3)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isActive ? Colors.orange : Colors.white.withOpacity(0.25),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.orange : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.orange : Colors.white,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastModeOption({
    required IconData icon,
    required String label,
    required BroadcastMode mode,
    required BroadcastMode current,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    bool isSelected = mode == current;
    Color color = !enabled
        ? Colors.white.withOpacity(0.3)
        : (isSelected ? Colors.orange : Colors.white.withOpacity(0.7));
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
