import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math' as math;
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/live_ring_avatar.dart';
import 'package:shortzz/model/post_story/music/music_model.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/screen/reels_screen/reel/reel_page_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class SideBarList extends StatelessWidget {
  final ReelController controller;
  final GlobalKey likeKey;

  const SideBarList(
      {super.key,
      required this.controller,
      required this.likeKey});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Post reel = controller.reelData.value;
      final isPlaceholder = reel.id == -1;
      Music? music = reel.music;
      if (music?.addedBy == 0) {
        music?.user = reel.user;
      } else {
        music?.user = null;
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            LiveRingAvatar(
              userId: reel.user?.id,
              child: CustomImage(
                image: reel.user?.profilePhoto?.addBaseURL(),
                fullName: reel.user?.fullname,
                size: const Size(40, 40),
                strokeWidth: 1.5,
                onTap: () => controller.onUserTap(reel.user),
              ),
            ),
            const SizedBox(height: 7.5),
            IconWithLabel(
                likeKey: likeKey,
                onTap: () {
                  isPlaceholder
                      ? () {}
                      : controller.onLikeTap();
                },
                image: (reel.isLiked ?? false)
                    ? AssetRes.icFillHeart
                    : AssetRes.icHeart,
                text: isPlaceholder
                    ? '1'
                    : (reel.likes ?? 0).toString()),
            if (reel.canComment == 1)
              IconWithLabel(
                onTap: isPlaceholder
                    ? () {}
                    : controller.onCommentTap,
                image: AssetRes.icComment,
                text: isPlaceholder
                    ? '1'
                    : (reel.comments ?? 0).toString(),
              ),
            IconWithLabel(
              onTap: isPlaceholder
                  ? () {}
                  : controller.onSaved,
              image: (reel.isSaved ?? false)
                  ? AssetRes.icFillBookmark
                  : AssetRes.icPostBookmark,
              text: isPlaceholder
                  ? '1'
                  : (reel.saves ?? 0).toString(),
            ),
            IconWithLabel(
              onTap: isPlaceholder
                  ? () {}
                  : controller.onShareTap,
              image: AssetRes.icShare,
              text: isPlaceholder
                  ? '1'
                  : (reel.shares ?? 0).toString(),
            ),
            // Visibility(
            //   visible: controller.reelData.value.user?.id !=
            //       SessionManager.instance.getUserID(),
            //   child:
            //       IconWithGift(onTap: controller.onGiftTap),
            // ),
            Visibility(
              visible: music != null,
              child: IconWithMusic(
                  onAudioTap: () =>
                      controller.onAudioTap(music),
                  music: music),
            ),
          ],
        ),
      );
    });
  }
}

// class IconWithGift extends StatelessWidget {
//   final VoidCallback onTap;

//   const IconWithGift({super.key, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       child: Container(
//         height: 37,
//         width: 37,
//         margin: const EdgeInsets.symmetric(vertical: 7.5),
//         padding: const EdgeInsets.all(7),
//         decoration: BoxDecoration(
//           color: whitePure(context),
//           shape: BoxShape.circle,
//         ),
//         child: GradientIcon(
//             child: Image.asset(AssetRes.icGift,
//                 width: 22, height: 22)),
//       ),
//     );
//   }
// }

class IconWithMusic extends StatefulWidget {
  final VoidCallback onAudioTap;
  final Music? music;

  const IconWithMusic(
      {super.key, required this.onAudioTap, this.music});

  @override
  State<IconWithMusic> createState() =>
      _IconWithMusicState();
}

class _IconWithMusicState extends State<IconWithMusic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Color animation between theme gradient colors with reverse
    _colorAnimation = ColorTween(
      begin:
          const Color.fromRGBO(202, 42, 36, 1), // redColor
      end:
          const Color.fromRGBO(55, 224, 4, 1), // greenColor
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onAudioTap,
      child: Container(
        height: 50,
        width: 50,
        margin: const EdgeInsets.only(top: 7.5),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: whitePure(context),
            shape: BoxShape.circle),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Calculate alternating colors for gradient effect
            final redColor = Color.fromRGBO(202, 42, 36, 1);
            final greenColor =
                Color.fromRGBO(55, 224, 4, 1);
            final currentColor =
                _colorAnimation.value ?? redColor;
            final oppositeColor = _controller.value > 0.5
                ? redColor
                : greenColor;

            return Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: DottedBorder(
                options: OvalDottedBorderOptions(
                  strokeWidth: 2.0,
                  gradient: LinearGradient(
                    colors: [
                      currentColor,
                      oppositeColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Image.asset(
                    AssetRes.icmusicicon,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class IconWithLabel extends StatelessWidget {
  final VoidCallback onTap;
  final String image;
  final String text;
  final Color? iconColor;
  final Key? likeKey;

  const IconWithLabel({
    super.key,
    required this.onTap,
    required this.image,
    required this.text,
    this.iconColor,
    this.likeKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.5),
      child: Column(
        children: [
          InkWell(
              onTap: onTap,
              key: likeKey,
              child: Image.asset(image,
                  width: 34, height: 30, color: iconColor)),
          if (text.isNotEmpty)
            Text(
              text,
              style: TextStyleCustom.outFitMedium500(
                      fontSize: 13,
                      color: whitePure(context))
                  .copyWith(
                shadows: <Shadow>[
                  Shadow(
                    offset: const Offset(0.0, 1.0),
                    blurRadius: 3.0,
                    color: textLightGrey(context),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}
