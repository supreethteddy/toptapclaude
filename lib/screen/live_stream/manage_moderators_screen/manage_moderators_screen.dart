import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/common/widget/custom_search_text_field.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/members_sheet.dart';
import 'package:shortzz/screen/live_stream/manage_moderators_screen/manage_moderators_screen_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ManageModeratorsScreen extends StatelessWidget {
  const ManageModeratorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ManageModeratorsScreenController());

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
              borderSide:
                  BorderSide(color: adaptiveBorderColor(context)),
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
                      final isModerator =
                          controller.isModerator(user.userId);
                      return MemberProfileCard(
                        user: user,
                        widget: TextBorderButton(
                          text: (isModerator ? LKey.remove : LKey.add).tr,
                          onTap: () => isModerator
                              ? controller.removeModerator(user)
                              : controller.addModerator(user),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
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
                    '(${controller.moderatorIds.length}/'
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
