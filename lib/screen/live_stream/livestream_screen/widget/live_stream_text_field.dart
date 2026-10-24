import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/gift_sheet/send_gift_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LiveStreamTextFieldView extends StatelessWidget {
  final bool isAudience;
  final LivestreamScreenController controller;

  const LiveStreamTextFieldView({
    super.key,
    required this.isAudience,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Livestream stream = controller.liveData.value;
      bool isTextEmpty = controller.isTextEmpty.value;
      bool commentsEnabled = stream.commentsEnabled;
      bool isBattleON = stream.type == LivestreamType.battle;
      bool isGiftIconVisible =
          controller.streamViews.firstWhereOrNull(
            (view) => view.streamId == controller.myUserId.toString(),
          ) ==
          null;

      List<AppUser> users = stream.getAllUsers(
        controller.firestoreController.users,
      );

      return Container(
        height: 43,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: ShapeDecoration(
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: 30,
              cornerSmoothing: 1,
            ),
            side: BorderSide(color: whitePure(context).withValues(alpha: .18)),
          ),
          color: whitePure(context).withValues(alpha: .15),
        ),
        child: TextField(
          controller: controller.textCommentController,
          readOnly: !commentsEnabled,
          onChanged: (value) {
            controller.isTextEmpty.value = value.isEmpty ? true : false;
          },
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            hintText: !commentsEnabled
                ? 'Comments are off'
                : isAudience
                ? '${LKey.writeHere.tr}..'
                : LKey.whatDoYouThink.tr,
            hintStyle: TextStyleCustom.outFitLight300(
              color: whitePure(context),
              fontSize: 17,
              opacity: .42,
            ),
            contentPadding: const EdgeInsets.only(left: 10, right: 10),
            prefixIconConstraints: const BoxConstraints(),
            prefixIcon: commentsEnabled
                ? _EmojiPickerButton(controller: controller)
                : null,
            suffixIconConstraints: const BoxConstraints(),
            suffixIcon: TextFieldSuffixIcon(
              controller: controller,
              isBattleOn: isBattleON,
              isAudience: isAudience,
              isTextEmpty: isTextEmpty,
              isGiftIconVisible: isGiftIconVisible,
              users: users,
            ),
          ),
          style: TextStyleCustom.outFitRegular400(
            color: whitePure(context),
            fontSize: 17,
          ),
          cursorColor: whitePure(context).withValues(alpha: .6),
          onTapOutside: (event) =>
              FocusManager.instance.primaryFocus?.unfocus(),
        ),
      );
    });
  }
}

class TextFieldSuffixIcon extends StatelessWidget {
  final bool isTextEmpty;
  final bool isAudience;
  final bool isBattleOn;
  final bool isGiftIconVisible;
  final List<AppUser> users;
  final LivestreamScreenController controller;

  const TextFieldSuffixIcon({
    super.key,
    required this.isTextEmpty,
    required this.isAudience,
    required this.isBattleOn,
    required this.controller,
    required this.isGiftIconVisible,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    final bool showSendButton = !isBattleOn || !isGiftIconVisible;

    return AnimatedContainer(
      width: isTextEmpty && isAudience ? 100 : 80,
      alignment: AlignmentDirectional.centerEnd,
      duration: const Duration(milliseconds: 100),
      child: !isTextEmpty
          ? _sendButton(context)
          : showSendButton && isTextEmpty && !isAudience
          ? _sendButton(context)
          : isBattleOn && isAudience
          ? _sendButton(context)
          : !isTextEmpty
          ? _sendButton(context)
          : GiftIcon(
              onTap: () =>
                  controller.onGiftTap(GiftType.livestream, users: users),
            ),
    );
  }

  Widget _sendButton(BuildContext context) {
    // Figma "Live1": green send-arrow icon instead of plain "Send" text.
    return InkWell(
      onTap: controller.onTextCommentSend,
      child: Container(
        height: 37,
        width: 37,
        margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 3),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: ColorRes.green1,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.send_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

/// Emoji icon inside the comment field (matches the reference's footer) —
/// opens emoji_picker_flutter in a bottom sheet, wired directly to
/// textCommentController so selecting an emoji inserts it the same way
/// typing would; no new send path, onTextCommentSend already reads from
/// this same controller.
class _EmojiPickerButton extends StatelessWidget {
  final LivestreamScreenController controller;

  const _EmojiPickerButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        Get.bottomSheet(
          SizedBox(
            height: 300,
            child: EmojiPicker(
              textEditingController: controller.textCommentController,
              // The package inserts into textCommentController itself, but
              // that's a programmatic TextEditingController write, not a
              // TextField user-input event -- the TextField's own
              // onChanged (which drives isTextEmpty, deciding send-button
              // vs gift-icon in the suffix) never fires for it, so sync it
              // here explicitly.
              onEmojiSelected: (category, emoji) {
                controller.isTextEmpty.value =
                    controller.textCommentController.text.isEmpty;
              },
              onBackspacePressed: () {
                controller.isTextEmpty.value =
                    controller.textCommentController.text.isEmpty;
              },
              config: Config(
                height: 300,
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: adaptiveBackground(context),
                ),
              ),
            ),
          ),
          backgroundColor: adaptiveBackground(context),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Icon(
          Icons.emoji_emotions_outlined,
          color: whitePure(context).withValues(alpha: .7),
          size: 20,
        ),
      ),
    );
  }
}

class GiftIcon extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? bgColor;

  const GiftIcon({super.key, this.onTap, this.bgColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 37,
        width: 37,
        margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 3),
        decoration: BoxDecoration(
          gradient: bgColor == null ? StyleRes.themeGradient : null,
          color: bgColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Image.asset(
          AssetRes.icGift,
          height: 20,
          width: 20,
          color: whitePure(context),
        ),
      ),
    );
  }
}
