import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/audience/widget/live_stream_user_info_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Host-only quick moderation menu for one on-stage participant, opened from
/// the "⋮" button on their tile in the LIVE grid — mute/camera/role/remove
/// in one tap each, instead of leaving the grid to hunt through the Members
/// sheet's tabs for the same actions. Reads live state reactively (not the
/// [state] snapshot it was opened with) so toggling mic/camera here updates
/// the sheet immediately rather than looking unresponsive until it's
/// reopened. "Check full profile" still routes to the existing
/// [LiveStreamUserInfoSheet] rather than duplicating it here.
class LiveParticipantQuickActionsSheet extends StatelessWidget {
  final AppUser user;
  final LivestreamUserState state;
  final LivestreamScreenController controller;

  const LiveParticipantQuickActionsSheet({
    super.key,
    required this.user,
    required this.state,
    required this.controller,
  });

  LivestreamUserState _liveState() =>
      controller.liveUsersStates.firstWhereOrNull(
            (element) => element.userId == state.userId,
          ) ??
      state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: adaptiveBackground(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  CustomImage(
                    size: const Size(40, 40),
                    image: user.profile?.addBaseURL(),
                    fullName: user.fullname,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.username ?? '',
                            style: TextStyleCustom.outFitSemiBold600(
                                fontSize: 15)),
                        Obx(() {
                          // In-room co-host is retired -- everyone on stage
                          // besides the host is a Guest now. The coHost
                          // branch only exists to label a pre-migration
                          // legacy doc honestly rather than silently
                          // mislabeling it.
                          final live = _liveState();
                          return Text(
                            live.type == LivestreamUserType.coHost
                                ? '${LKey.coHosts.tr} (legacy)'
                                : LKey.guest.tr,
                            style: TextStyleCustom.outFitRegular400(
                                fontSize: 12, color: textLightGrey(context)),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Obx(() {
              final live = _liveState();
              return ListTile(
                leading: Icon(live.isMuted ? Icons.mic_off : Icons.mic),
                title: Text(live.isMuted ? 'Unmute' : 'Mute'),
                onTap: () => controller.coHostAudioToggle(live),
              );
            }),
            Obx(() {
              final live = _liveState();
              return ListTile(
                leading: Icon(
                    live.isVideoOn ? Icons.videocam : Icons.videocam_off),
                title: Text(
                    live.isVideoOn ? 'Turn camera off' : 'Turn camera on'),
                onTap: () => controller.coHostVideoToggle(live),
              );
            }),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(LKey.checkProfile.tr),
              onTap: () {
                Get.back();
                Get.bottomSheet(
                  LiveStreamUserInfoSheet(
                      isAudience: false, liveUser: user, controller: controller),
                  isScrollControlled: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined,
                  color: ColorRes.likeRed),
              title: Text(LKey.removeFromStream.tr,
                  style: const TextStyle(color: ColorRes.likeRed)),
              onTap: () {
                Get.back();
                controller.coHostDelete(_liveState());
              },
            ),
          ],
        ),
      ),
    );
  }
}
