import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/load_more_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/chat/message_data.dart';
import 'package:shortzz/screen/chat_screen/chat_screen_controller.dart';
import 'package:shortzz/screen/chat_screen/message_type_widget/chat_audio_message.dart';
import 'package:shortzz/screen/chat_screen/message_type_widget/chat_g_i_f_message.dart';
import 'package:shortzz/screen/chat_screen/message_type_widget/chat_gift_message.dart';
import 'package:shortzz/screen/chat_screen/message_type_widget/chat_media_message.dart';
import 'package:shortzz/screen/chat_screen/message_type_widget/chat_post_message.dart';
import 'package:shortzz/screen/chat_screen/message_type_widget/chat_story_reply_message.dart';
import 'package:shortzz/screen/chat_screen/message_type_widget/chat_text_message.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';
import 'package:super_context_menu/super_context_menu.dart';

class ChatMessageView extends StatelessWidget {
  final ChatScreenController controller;

  const ChatMessageView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Obx(
      () {
        return LoadMoreWidget(
          loadMore: controller.fetchMoreChatList,
          child: ListView.builder(
            itemCount: controller.chatList.length,
            reverse: true,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              MessageData message = controller.chatList[index];
              bool isMe = message.chatUser?.userId ==
                  SessionManager.instance.getUserID();
              // The list is newest-first (index 0) with `reverse: true`, so
              // the message "below" (more recent / closer to the bottom of
              // the screen) than `message` is at `index - 1`. A message is
              // the last one of its consecutive-sender run when there is no
              // later message, or the later message came from someone else.
              bool isLastOfRun = index == 0 ||
                  controller.chatList[index - 1].userId != message.userId;

              Widget bubbleColumn = Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  ContextMenuWidget(
                    menuProvider: (_) {
                      return Menu(
                        children: [
                          MenuAction(
                              title: LKey.deleteForYou.tr,
                              callback: () =>
                                  controller.onDeleteForYou(message)),
                          if (isMe)
                            MenuAction(
                                title: LKey.unSend.tr,
                                callback: () => controller.onUnSend(message)),
                        ],
                      );
                    },
                    child: Container(
                      decoration: ShapeDecoration(
                          color: scaffoldBackgroundColor(context),
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius(
                                cornerRadius: 15, cornerSmoothing: 1),
                          )),
                      child: switch (message.messageType) {
                        MessageType.image => ChatMediaMessage(
                            isMe: isMe,
                            message: message,
                            controller: controller),
                        MessageType.video => ChatMediaMessage(
                            isMe: isMe,
                            message: message,
                            controller: controller),
                        MessageType.post => ChatPostMessage(
                            message: message, controller: controller),
                        MessageType.audio => ChatAudioMessage(
                            message: message, controller: controller),
                        MessageType.text =>
                          ChatTextMessage(isMe: isMe, message: message),
                        MessageType.gift =>
                          ChatGiftMessage(message: message, isMe: isMe),
                        MessageType.gif => ChatGIFMessage(message: message),
                        MessageType.storyReply => ChatStoryReplyMessage(
                            controller: controller,
                            message: message,
                            isMe: isMe),
                        null => const SizedBox(),
                      },
                    ),
                  ),
                  ChatDateView(message: message)
                ],
              );

              // Only incoming messages carry the sender's avatar, and only
              // on the last bubble of a consecutive run from that sender.
              // Every other incoming bubble gets an equal-width empty space
              // instead, so the bubbles in a run stay aligned.
              const double avatarSize = 34;
              Widget child = bubbleColumn;
              if (!isMe) {
                child = Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    isLastOfRun
                        ? CustomImage(
                            size: const Size(avatarSize, avatarSize),
                            image: message.chatUser?.profile?.addBaseURL(),
                            fullName: message.chatUser?.fullname,
                          )
                        : const SizedBox(width: avatarSize),
                    const SizedBox(width: 8),
                    Flexible(child: bubbleColumn),
                  ],
                );
              }

              return Container(
                padding: const EdgeInsets.only(
                    left: 10, right: 10, top: 7, bottom: 7),
                decoration: ShapeDecoration(
                    shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius(
                            cornerRadius: 15, cornerSmoothing: 1))),
                child: child,
              );
            },
          ),
        );
      },
    ));
  }
}

class ChatDateView extends StatelessWidget {
  final MessageData message;

  const ChatDateView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0, right: 5, top: 3),
      child: Text(
        '${message.id ?? 0}'.chatTimeFormat,
        style: TextStyleCustom.outFitLight300(
            fontSize: 12, color: textLightGrey(context)),
      ),
    );
  }
}

final List<BoxShadow> messageBubbleShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.10),
    offset: const Offset(0, 4),
    blurRadius: 10,
  ),
];
