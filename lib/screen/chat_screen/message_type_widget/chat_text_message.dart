import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/model/chat/message_data.dart';
import 'package:toptap/utilities/color_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class ChatTextMessage extends StatelessWidget {
  final bool isMe;
  final MessageData message;

  const ChatTextMessage({super.key, required this.isMe, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      constraints: BoxConstraints(maxWidth: Get.width / 1.3),
      decoration: ShapeDecoration(
          shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(cornerRadius: 10, cornerSmoothing: 1),
              side: BorderSide.none),
          color: isMe ? ColorRes.textgreenColor : ColorRes.themeGradient1),
      child: Text(
        message.textMessage ?? '',
        style: TextStyleCustom.outFitRegular400(color: whitePure(context), fontSize: 16),
      ),
    );
  }
}
