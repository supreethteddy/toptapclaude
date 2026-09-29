import 'dart:io';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/functions/debounce_action.dart';
import 'package:shortzz/common/manager/branch_io_manager.dart';
import 'package:shortzz/common/widget/bottom_sheet_top_view.dart';
import 'package:shortzz/common/widget/custom_divider.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/screen/share_sheet_widget/share_sheet_widget_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ShareSheetWidget extends StatelessWidget {
  final VoidCallback onMoreTap;
  final String link;
  final bool isDownloadShow;
  final Post? post;
  final ShareBranchType type;
  final String title;
  final Function()? onCallBack;

  const ShareSheetWidget(
      {super.key,
      required this.onMoreTap,
      required this.link,
      this.isDownloadShow = false,
      this.post,
      required this.type,
      this.onCallBack,
      required this.title});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ShareSheetWidgetController(
        post, onCallBack, title));

    return Wrap(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              key: controller.screenShotKey,
              child: Column(
                children: [
                  Obx(
                    () => controller
                            .waterMarkPath.value.isEmpty
                        ? const SizedBox()
                        : Image.file(
                            File(controller
                                .waterMarkPath.value),
                            fit: BoxFit.contain,
                            height: 50,
                            width: 100,
                          ),
                  ),
                  Text(
                    '@${post?.user?.username ?? AppRes.appName}',
                    style: TextStyleCustom.unboundedBold700(
                            color: whitePure(context),
                            fontSize: 15)
                        .copyWith(shadows: [
                      const Shadow(
                          color: Colors.black,
                          blurRadius: 20)
                    ]),
                  ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.only(
                  top: AppBar().preferredSize.height * 2.5),
              decoration: ShapeDecoration(
                shape: const SmoothRectangleBorder(
                    borderRadius:
                        SmoothBorderRadius.vertical(
                            top: SmoothRadius(
                                cornerRadius: 40,
                                cornerSmoothing: 1))),
                color: scaffoldBackgroundColor(context),
              ),
              child: Column(
                children: [
                  BottomSheetTopView(
                      title: LKey.sharePost.tr),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20.0, horizontal: 18),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(link,
                                style: TextStyleCustom
                                    .outFitRegular400(
                                        color: textDarkGrey(
                                            context),
                                        fontSize: 16))),
                        const SizedBox(width: 20),
                        CustomAssetWithBgButton(
                            image: AssetRes.icCopy,
                            boxSize: 46,
                            iconSize: 22,
                            radius: 10,
                            onTap: () async {
                              Get.back();
                              await link.copyText;

                              DebounceAction.shared.call(
                                  () {
                                controller
                                    .increaseShareCount(
                                        post?.id);
                              }, milliseconds: 1000);
                            })
                      ],
                    ),
                  ),
                  const CustomDivider(),
                  if (type == ShareBranchType.post)
                    Obx(() {
                      List<ChatThread> users =
                          controller.chatsUsers;
                      bool isSelectedListEmpty = controller
                          .selectedConversation.isEmpty;
                      if (users.isEmpty) {
                        return const SizedBox();
                      }
                      return Column(
                        children: [
                          Padding(
                              padding: const EdgeInsets
                                  .symmetric(
                                  vertical: 20.0),
                              child: Center(
                                child: Wrap(
                                  spacing: 20,
                                  runSpacing: 10,
                                  direction:
                                      Axis.horizontal,
                                  children: List.generate(
                                    users.take(8).length,
                                    (index) {
                                      ChatThread
                                          chatConversation =
                                          users[index];
                                      AppUser? chatUser =
                                          chatConversation
                                              .chatUser;
                                      bool isSelected = controller
                                          .selectedConversation
                                          .contains(
                                              chatConversation);
                                      if (index == 7) {
                                        return InkWell(
                                            onTap: controller
                                                .onMoreTap,
                                            child:
                                                Container(
                                              height: 62,
                                              width: 75,
                                              decoration: BoxDecoration(
                                                  color: bgGrey(
                                                      context),
                                                  shape: BoxShape
                                                      .circle),
                                              alignment:
                                                  const Alignment(
                                                      .05,
                                                      0),
                                              child: Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  color: textDarkGrey(
                                                      context)),
                                            ));
                                      }
                                      return InkWell(
                                        onTap: () => controller
                                            .onUserTap(
                                                chatConversation),
                                        child: SizedBox(
                                          width: 74,
                                          height: 84,
                                          child: Column(
                                            children: [
                                              Stack(
                                                alignment:
                                                    AlignmentDirectional
                                                        .bottomEnd,
                                                children: [
                                                  Align(
                                                      alignment: Alignment
                                                          .center,
                                                      child: CustomImage(
                                                          size: const Size(62, 62),
                                                          image: chatUser?.profile?.addBaseURL(),
                                                          fullName: chatUser?.fullname)),
                                                  if (isSelected)
                                                    Positioned(
                                                      right:
                                                          5,
                                                      child:
                                                          Align(
                                                        alignment:
                                                            AlignmentDirectional.bottomEnd,
                                                        child:
                                                            Container(
                                                          height: 21,
                                                          width: 21,
                                                          decoration: BoxDecoration(shape: BoxShape.circle, color: whitePure(context), border: Border.all(color: whitePure(context), width: 1)),
                                                          alignment: Alignment.center,
                                                          child: Image.asset(AssetRes.icCheckCircle, color: themeAccentSolid(context)),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              Expanded(
                                                child: Text(
                                                    chatUser?.username ??
                                                        '',
                                                    style: TextStyleCustom.outFitRegular400(
                                                        color: textDarkGrey(
                                                            context),
                                                        fontSize:
                                                            14),
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                    maxLines:
                                                        1),
                                              )
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )),
                          TextButtonCustom(
                            onTap: isSelectedListEmpty
                                ? () {}
                                : () => controller
                                    .onSendChat(post),
                            title: LKey.send.tr,
                            backgroundColor: textDarkGrey(
                                    context)
                                .withValues(
                                    alpha:
                                        isSelectedListEmpty
                                            ? .4
                                            : 1),
                            titleColor: whitePure(context),
                            margin:
                                const EdgeInsets.symmetric(
                                    horizontal: 20),
                            borderSide: BorderSide(
                                color: whitePure(context)
                                    .withValues(
                                        alpha:
                                            isSelectedListEmpty
                                                ? .4
                                                : 1),
                                width: 1),
                          )
                        ],
                      );
                    }),
                  SizedBox(
                    height: 168,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        children: [
                          ShareGridItem(
                            image: AssetRes.icCopy,
                            label: LKey.copyLink.tr,
                            onTap: () async {
                              Get.back();
                              await link.copyText;
                              DebounceAction.shared.call(() {
                                controller
                                    .increaseShareCount(post?.id);
                              }, milliseconds: 1000);
                            },
                          ),
                          ShareGridItem(
                            image: AssetRes.icWhatsapp,
                            label: LKey.whatsapp.tr,
                            onTap: () => controller
                                .onShareSheetBottomBtnTap(
                                    ShareOption.whatsapp, link,
                                    post: post),
                          ),
                          ShareGridItem(
                            image: AssetRes.icInstagram,
                            label: LKey.instagram.tr,
                            onTap: () => controller
                                .onShareSheetBottomBtnTap(
                                    ShareOption.instagram, link,
                                    post: post),
                          ),
                          ShareGridItem(
                            image: AssetRes.icTelegram,
                            label: LKey.telegram.tr,
                            onTap: () => controller
                                .onShareSheetBottomBtnTap(
                                    ShareOption.telegram, link,
                                    post: post),
                          ),
                          ShareGridItem(
                            image: AssetRes.icFacebook,
                            label: LKey.facebook.tr,
                            applyTint: false,
                            onTap: () => controller
                                .onShareSheetBottomBtnTap(
                                    ShareOption.facebook, link,
                                    post: post),
                          ),
                          if (isDownloadShow)
                            ShareGridItem(
                              image: AssetRes.icDownload,
                              label: LKey.download.tr,
                              onTap: () => controller
                                  .onShareSheetBottomBtnTap(
                                      ShareOption.download, link,
                                      post: post),
                            ),
                          if (type == ShareBranchType.post &&
                              post != null)
                            ShareGridItem(
                              image: AssetRes.icReport,
                              label: LKey.report.tr,
                              onTap: () => controller
                                  .onShareSheetBottomBtnTap(
                                      ShareOption.report, link,
                                      post: post),
                            ),
                          ShareGridItem(
                            image: AssetRes.icMore,
                            label: LKey.more.tr,
                            onTap: onMoreTap,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ShareGridItem extends StatelessWidget {
  final String image;
  final String label;
  final VoidCallback onTap;
  final bool applyTint;

  const ShareGridItem(
      {super.key,
      required this.image,
      required this.label,
      required this.onTap,
      this.applyTint = true});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 58,
              width: 58,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                  color: bgGrey(context),
                  shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 18, cornerSmoothing: 1))),
              child: Image.asset(image,
                  height: 28,
                  width: 28,
                  color: applyTint ? textDarkGrey(context) : null),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyleCustom.outFitRegular400(
                  fontSize: 12, color: textDarkGrey(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomAssetWithBgButton extends StatelessWidget {
  final String image;
  final double boxSize;
  final double iconSize;
  final double radius;
  final VoidCallback? onTap;

  const CustomAssetWithBgButton(
      {super.key,
      required this.image,
      required this.boxSize,
      required this.iconSize,
      this.radius = 15,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: boxSize,
        width: boxSize,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
            color: bgGrey(context),
            shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(
                    cornerRadius: 10, cornerSmoothing: 1))),
        child: Image.asset(image,
            height: iconSize,
            width: iconSize,
            color: textDarkGrey(context)),
      ),
    );
  }
}

enum ShareOption {
  download,
  whatsapp,
  share,
  instagram,
  telegram,
  facebook,
  report,
  more,
  copy;

  String value(String link) {
    switch (this) {
      case ShareOption.whatsapp:
        return "whatsapp://send?text=$link";
      case ShareOption.instagram:
        return "instagram://sharesheet?text=$link";
      case ShareOption.telegram:
        return "https://t.me/share/url?url=${Uri.encodeComponent(link)}";
      case ShareOption.facebook:
        return "https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(link)}";
      case ShareOption.download:
      case ShareOption.share:
      case ShareOption.report:
      case ShareOption.more:
      case ShareOption.copy:
        return '';
    }
  }
}

enum ShareType { videoPost, imagePost, textPost, reelPost }
