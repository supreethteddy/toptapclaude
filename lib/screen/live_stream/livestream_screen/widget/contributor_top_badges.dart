import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/haptic_manager.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/contributor_rank_entry.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';

/// Small overlapping avatar badges for the top 3 contributors of this LIVE
/// session (Figma "Live1"), shown in the top bar next to the viewer count.
/// Tapping the row opens the full [ContributorRankingSheet], same as tapping
/// the daily-ranking chip opens [LiveRankingSheet].
class ContributorTopBadges extends StatelessWidget {
  final LivestreamScreenController controller;
  final double avatarSize;

  const ContributorTopBadges({
    super.key,
    required this.controller,
    this.avatarSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final List<ContributorRankEntry> top = controller.topContributors;
      if (top.isEmpty) return const SizedBox.shrink();

      const double overlap = 0.6;
      final double step = avatarSize * overlap;
      final double width = avatarSize + step * (top.length - 1);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticManager.shared.light();
          controller.openContributorRankingSheet();
        },
        child: SizedBox(
          height: avatarSize,
          width: width,
          child: Stack(
            // Painted back-to-front so the #1 contributor's avatar (index 0)
            // ends up on top of the overlapping stack.
            children: [
              for (int i = top.length - 1; i >= 0; i--)
                Positioned(
                  left: i * step,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: CustomImage(
                      size: Size(avatarSize - 2, avatarSize - 2),
                      image: top[i].user?.profile?.addBaseURL(),
                      fullName: top[i].user?.fullname,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}
