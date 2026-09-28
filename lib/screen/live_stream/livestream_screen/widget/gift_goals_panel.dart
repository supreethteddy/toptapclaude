import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/bottom_sheet_top_view.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Lists every active Gift Goal for the current LIVE, with a progress bar per
/// goal and (host-only) Pin / Remove actions, plus a way to add a new one.
/// Mirrors TikTok's "Gift goal" panel of several simultaneous, pinnable
/// per-gift targets.
class GiftGoalsPanel extends StatelessWidget {
  final LivestreamScreenController controller;

  const GiftGoalsPanel({super.key, required this.controller});

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
          BottomSheetTopView(
              title: LKey.giftGoals.tr, sideBtnVisibility: false),
          Flexible(
            child: Obx(() {
              final goals = controller.liveData.value.giftGoals ?? [];
              return NoDataView(
                showShow: goals.isEmpty,
                title: LKey.giftGoalsEmptyTitle.tr,
                description: LKey.giftGoalsEmptyDescription.tr,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shrinkWrap: true,
                  itemCount: goals.length,
                  itemBuilder: (context, index) =>
                      _GiftGoalTile(controller: controller, goal: goals[index]),
                ),
              );
            }),
          ),
          if (controller.isHost)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Obx(() {
                final canAdd = controller.canAddGiftGoal;
                return InkWell(
                  onTap: canAdd
                      ? () => Get.bottomSheet(
                            _AddGiftGoalSheet(controller: controller),
                            isScrollControlled: true,
                          )
                      : () => controller.showSnackBar(
                          LKey.giftGoalLimitReached.tr),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: canAdd
                          ? themeAccentSolid(context)
                          : bgLightGrey(context),
                      shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius(
                              cornerRadius: 10, cornerSmoothing: 1)),
                    ),
                    child: Text(
                      LKey.addGiftGoal.tr,
                      style: TextStyleCustom.outFitMedium500(
                          color: whitePure(context), fontSize: 15),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _GiftGoalTile extends StatelessWidget {
  final LivestreamScreenController controller;
  final GiftGoal goal;

  const _GiftGoalTile({required this.controller, required this.goal});

  @override
  Widget build(BuildContext context) {
    final gift = (SessionManager.instance.getSettings()?.gifts ?? [])
        .firstWhereOrNull((g) => g.id == goal.giftId);
    final progress = goal.targetCount > 0
        ? (goal.currentCount / goal.targetCount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        color: bgLightGrey(context),
        shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
                cornerRadius: 14, cornerSmoothing: 1)),
      ),
      child: Row(
        children: [
          CustomImage(
              size: const Size(48, 48),
              image: gift?.image?.addBaseURL(),
              radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${goal.currentCount}/${goal.targetCount}',
                        style: TextStyleCustom.outFitMedium500(
                            color: adaptiveTextColor(context), fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(
                        '${goal.contributorIds.length} ${LKey.contributors.tr}',
                        style: TextStyleCustom.outFitLight300(
                            color: textLightGrey(context), fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: whitePure(context).withValues(alpha: .3),
                    color: goal.isCompleted
                        ? ColorRes.green1
                        : themeAccentSolid(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (controller.isHost)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => controller.pinGiftGoal(goal.id),
                  child: Icon(Icons.push_pin,
                      size: 20,
                      color: goal.isPinned
                          ? themeAccentSolid(context)
                          : textLightGrey(context)),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => controller.removeGiftGoal(goal.id),
                  child: Icon(Icons.close,
                      size: 18, color: textLightGrey(context)),
                ),
              ],
            )
          else if (goal.isPinned)
            Icon(Icons.push_pin, size: 18, color: themeAccentSolid(context)),
        ],
      ),
    );
  }
}

class _AddGiftGoalSheet extends StatefulWidget {
  final LivestreamScreenController controller;

  const _AddGiftGoalSheet({required this.controller});

  @override
  State<_AddGiftGoalSheet> createState() => _AddGiftGoalSheetState();
}

class _AddGiftGoalSheetState extends State<_AddGiftGoalSheet> {
  Gift? selectedGift;
  final targetController = TextEditingController(text: '10');

  @override
  void dispose() {
    targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gifts = SessionManager.instance.getSettings()?.gifts ?? [];

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
          BottomSheetTopView(
              title: LKey.selectAGift.tr, sideBtnVisibility: false),
          SizedBox(
            height: 200,
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: gifts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisExtent: 90,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8),
              itemBuilder: (context, index) {
                final gift = gifts[index];
                final isSelected = gift.id == selectedGift?.id;
                return InkWell(
                  onTap: () => setState(() => selectedGift = gift),
                  child: Container(
                    decoration: ShapeDecoration(
                      color: bgLightGrey(context),
                      shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius(
                              cornerRadius: 8, cornerSmoothing: 1),
                          side: BorderSide(
                              color: isSelected
                                  ? themeAccentSolid(context)
                                  : Colors.transparent,
                              width: 2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomImage(
                            image: gift.image?.addBaseURL(),
                            size: const Size(40, 40),
                            radius: 0),
                        Text((gift.coinPrice ?? 0).numberFormat,
                            style: TextStyleCustom.outFitLight300(
                                fontSize: 11,
                                color: textLightGrey(context))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(LKey.targetCount.tr,
                    style: TextStyleCustom.outFitMedium500(
                        color: adaptiveTextColor(context))),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: InkWell(
              onTap: selectedGift == null
                  ? null
                  : () {
                      final target = int.tryParse(targetController.text) ?? 0;
                      if (target <= 0) return;
                      widget.controller.addGiftGoal(selectedGift!, target);
                      Get.back();
                    },
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: selectedGift == null
                      ? bgLightGrey(context)
                      : themeAccentSolid(context),
                  shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 10, cornerSmoothing: 1)),
                ),
                child: Text(
                  LKey.create.tr,
                  style: TextStyleCustom.outFitMedium500(
                      color: whitePure(context), fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact, always-visible indicator for the currently pinned Gift Goal.
/// Tapping it (host or audience) opens the full [GiftGoalsPanel]. Renders
/// nothing if no goal is pinned, so it's safe to drop into any LIVE top view.
class PinnedGiftGoalChip extends StatelessWidget {
  final LivestreamScreenController controller;

  const PinnedGiftGoalChip({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final goals = controller.liveData.value.giftGoals ?? [];
      final pinned = goals.firstWhereOrNull((goal) => goal.isPinned);
      if (pinned == null) return const SizedBox.shrink();

      final gift = (SessionManager.instance.getSettings()?.gifts ?? [])
          .firstWhereOrNull((g) => g.id == pinned.giftId);
      final progress = pinned.targetCount > 0
          ? (pinned.currentCount / pinned.targetCount).clamp(0.0, 1.0)
          : 0.0;

      return InkWell(
        onTap: () => Get.bottomSheet(
          GiftGoalsPanel(controller: controller),
          isScrollControlled: true,
        ),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: (pinned.isCompleted ? ColorRes.green1 : Colors.orange)
                    .withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (gift?.image != null)
                CustomImage(
                    size: const Size(18, 18),
                    image: gift!.image?.addBaseURL(),
                    radius: 0)
              else
                const Icon(Icons.card_giftcard, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              SizedBox(
                width: 40,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    color: pinned.isCompleted
                        ? ColorRes.green1
                        : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${pinned.currentCount}/${pinned.targetCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
