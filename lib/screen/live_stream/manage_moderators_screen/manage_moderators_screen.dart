import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/common/widget/custom_search_text_field.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/moderation_log_entry.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/members_sheet.dart';
import 'package:shortzz/screen/live_stream/manage_moderators_screen/manage_moderators_screen_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ManageModeratorsScreen extends StatelessWidget {
  final String roomID;

  const ManageModeratorsScreen({super.key, required this.roomID});

  @override
  Widget build(BuildContext context) {
    final controller =
        Get.put(ManageModeratorsScreenController(roomID), tag: roomID);

    return Scaffold(
      backgroundColor: adaptiveBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            _Header(controller: controller),
            const SizedBox(height: 16),
            CustomSearchTextField(
              onChanged: controller.onSearchChange,
              backgroundColor: adaptiveBackground(context),
              borderSide: BorderSide(color: adaptiveBorderColor(context)),
            ),
            Expanded(
              child: Obx(() {
                final users = controller.filteredUsers;
                return NoDataView(
                  showShow: users.isEmpty,
                  title: LKey.moderatorListEmptyTitle.tr,
                  description: LKey.moderatorListEmptyDescription.tr,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isModerator = controller.isModerator(user.userId);
                      return Column(
                        children: [
                          MemberProfileCard(
                            user: user,
                            widget: TextBorderButton(
                              text: (isModerator ? LKey.remove : LKey.add).tr,
                              onTap: () => isModerator
                                  ? controller.removeModerator(user)
                                  : controller.addModerator(user),
                            ),
                          ),
                          if (isModerator)
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 58, right: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      LKey.canManageGuests.tr,
                                      style: TextStyleCustom.outFitRegular400(
                                        fontSize: 13,
                                        color: textLightGrey(context),
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: controller
                                        .canManageGuestsFor(user.userId),
                                    onChanged: (value) => controller
                                        .toggleCanManageGuests(user, value),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              }),
            ),
            _ModerationLogSection(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ManageModeratorsScreenController controller;

  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          CustomBackButton(
            color: adaptiveTextColor(context),
            width: 18,
            height: 18,
            padding: const EdgeInsets.all(15),
          ),
          Expanded(
            child: Center(
              child: Obx(() => Text(
                    '${LKey.manageModerators.tr} '
                    '(${controller.liveController.liveModerators.length}/'
                    '${AppRes.maxLivestreamModerators})',
                    style: TextStyleCustom.outFitBold700(
                        color: adaptiveTextColor(context), fontSize: 16),
                  )),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Client spec 14.5: "record moderation actions in the audit log" — a
/// simple, collapsed-by-default read-only list of the last 50 actions this
/// session, not a full dedicated screen.
class _ModerationLogSection extends StatelessWidget {
  final ManageModeratorsScreenController controller;

  const _ModerationLogSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final entries = controller.logEntries;
      return ExpansionTile(
        title: Text(LKey.moderationLog.tr,
            style: TextStyleCustom.outFitMedium500(fontSize: 14)),
        children: [
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(LKey.moderationLogEmpty.tr,
                  style: TextStyleCustom.outFitRegular400(
                      fontSize: 13, color: textLightGrey(context))),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: entries.length,
                itemBuilder: (context, index) => _LogRow(entry: entries[index]),
              ),
            ),
        ],
      );
    });
  }
}

class _LogRow extends StatelessWidget {
  final ModerationLogEntry entry;

  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final actor = entry.actorUsername ?? '#${entry.actorId ?? ''}';
    final target = entry.targetUsername ??
        (entry.targetId != null ? '#${entry.targetId}' : null);
    final action = (entry.action ?? '').replaceAll('_', ' ');
    final line = target != null ? '$actor $action ($target)' : '$actor $action';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(line,
          style: TextStyleCustom.outFitRegular400(
              fontSize: 13, color: textLightGrey(context))),
    );
  }
}
