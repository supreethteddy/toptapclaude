import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/find_opponent_screen/find_opponent_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class FindOpponentScreen extends StatelessWidget {
  final LivestreamScreenController myLive;

  const FindOpponentScreen({super.key, required this.myLive});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FindOpponentScreenController(myLive));

    return Scaffold(
      backgroundColor: adaptiveBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
                      child: Text(
                        LKey.findOpponent.tr,
                        style: TextStyleCustom.outFitBold700(
                            color: adaptiveTextColor(context), fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoaderWidget();
                }
                final candidates = controller.candidates;
                return NoDataView(
                  showShow: candidates.isEmpty,
                  title: LKey.findOpponentEmptyTitle.tr,
                  description: LKey.findOpponentEmptyDescription.tr,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: candidates.length,
                    itemBuilder: (context, index) => _OpponentCard(
                        controller: controller, stream: candidates[index]),
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

class _OpponentCard extends StatelessWidget {
  final FindOpponentScreenController controller;
  final Livestream stream;

  const _OpponentCard({required this.controller, required this.stream});

  @override
  Widget build(BuildContext context) {
    AppUser? host = stream.getHostUser(controller.firestoreController.users);
    int headcount = 1 + (stream.coHostIds?.length ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        color: bgLightGrey(context),
        shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(cornerRadius: 14, cornerSmoothing: 1)),
      ),
      child: Row(
        children: [
          CustomImage(
            size: const Size(48, 48),
            image: host?.profile?.addBaseURL(),
            fullName: host?.fullname,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FullNameWithBlueTick(
                  username: host?.username,
                  isVerify: host?.isVerify,
                  fontColor: adaptiveTextColor(context),
                  fontSize: 14,
                  iconSize: 16,
                ),
                Text(
                  '${(stream.watchingCount ?? 0).numberFormat} ${LKey.viewers.tr}'
                  '${headcount > 1 ? ' · 2v2' : ''}',
                  style: TextStyleCustom.outFitLight300(
                      color: textLightGrey(context), fontSize: 12),
                ),
              ],
            ),
          ),
          Obx(() {
            final invited = controller.invitedHostIds.contains(stream.hostId);
            return InkWell(
              onTap: invited ? null : () => controller.challenge(stream),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: invited ? bgLightGrey(context) : ColorRes.likeRed,
                  shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 20, cornerSmoothing: 1),
                      side: invited
                          ? BorderSide(color: adaptiveBorderColor(context))
                          : BorderSide.none),
                ),
                child: Text(
                  invited ? LKey.battleInviteSent.tr : LKey.challenge.tr,
                  style: TextStyleCustom.outFitMedium500(
                      color:
                          invited ? textLightGrey(context) : Colors.white,
                      fontSize: 13),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
