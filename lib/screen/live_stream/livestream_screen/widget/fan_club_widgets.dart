import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/bottom_sheet_top_view.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/members_sheet.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Compact banner shown to viewers when the host has Fan Club turned on for
/// this LIVE. Free, one-tap join — no payment involved. Renders nothing for
/// the host, or once [hasFanClub] is off.
class FanClubBanner extends StatelessWidget {
  final LivestreamScreenController controller;

  const FanClubBanner({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isHost || controller.liveData.value.hasFanClub != true) {
        return const SizedBox.shrink();
      }
      final isMember = controller.isFanClubMember.value;
      final perks = controller.liveData.value.fanClubPerks;
      return InkWell(
        onTap: isMember ? null : controller.joinFanClub,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: (isMember ? ColorRes.green1 : Colors.orange)
                    .withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.diamond_outlined,
                  size: 14,
                  color: isMember ? ColorRes.green1 : Colors.orange),
              const SizedBox(width: 4),
              Text(
                isMember ? LKey.joinedFanClub.tr : LKey.joinFanClub.tr,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
              if (!isMember &&
                  perks != null &&
                  perks.isNotEmpty) ...[
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: Text(
                    perks,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

/// Host-only, read-only list of everyone who's joined this host's Fan Club
/// (persists across every LIVE, same storage pattern as ManageModerators).
class FanClubMembersSheet extends StatelessWidget {
  final LivestreamScreenController controller;

  const FanClubMembersSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: AppBar().preferredSize.height * 2),
      decoration: ShapeDecoration(
        color: whitePure(context),
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 30, cornerSmoothing: 1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetTopView(title: LKey.fanClub.tr, sideBtnVisibility: false),
          Flexible(
            child: FutureBuilder<QuerySnapshot>(
              future: controller.fanClubRef.get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final ids = snapshot.data!.docs
                    .map((doc) => int.tryParse(doc.id))
                    .whereType<int>()
                    .toList();
                final users = ids
                    .map((id) => controller.firestoreController.users
                        .firstWhereOrNull((user) => user.userId == id))
                    .whereType<AppUser>()
                    .toList();
                return NoDataView(
                  showShow: users.isEmpty,
                  title: LKey.fanClubEmptyTitle.tr,
                  description: LKey.fanClubEmptyDescription.tr,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: users.length,
                    itemBuilder: (context, index) => MemberProfileCard(
                        user: users[index], widget: const SizedBox()),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
