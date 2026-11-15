import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/service/url_extractor/parsers/base_parser.dart';
import 'package:toptap/common/widget/custom_bg_circle_button.dart';
import 'package:toptap/common/widget/custom_image.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/screen/create_feed_screen/create_feed_screen_controller.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class UrlMetaDataCard extends StatefulWidget {
  final CreateFeedScreenController controller;

  const UrlMetaDataCard({super.key, required this.controller});

  @override
  State<UrlMetaDataCard> createState() => _UrlMetaDataCardState();
}

class _UrlMetaDataCardState extends State<UrlMetaDataCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  UrlMetadata? previousMetadata;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.8, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playForwardAnimation() {
    if (mounted && _controller.status != AnimationStatus.forward) {
      _controller.reset();
      _controller.forward();
    }
  }

  void _playReverseAnimation() {
    if (mounted && _controller.status != AnimationStatus.reverse) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final metadata = widget.controller.commentHelper.metaData.value;

      // Animation trigger logic
      if (metadata != previousMetadata) {
        if (metadata != null) {
          _playForwardAnimation();
        } else {
          _playReverseAnimation();
        }
        previousMetadata = metadata;
      }

      // Hide completely if metadata is null and animation is finished
      if (metadata == null || _controller.isDismissed) {
        return const SizedBox();
      }

      return ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: () {
            metadata.url?.lunchUrl;
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: whitePure(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    CustomImage(
                      image: metadata.image,
                      size: const Size(double.infinity, 150),
                      fit: BoxFit.cover,
                      radius: 10,
                    ),
                    InkWell(
                      onTap: () {
                        widget.controller.commentHelper.onClosePreview();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: CustomBgCircleButton(
                          image: AssetRes.icClose1,
                          bgColor: textDarkGrey(context),
                          size: const Size(25, 25),
                        ),
                      ),
                    ),
                  ],
                ),
                if (metadata.host != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 5),
                    child: Text(
                      '${LKey.from.tr} ${metadata.host}',
                      style: TextStyleCustom.outFitRegular400(
                        fontSize: 15,
                        color: textLightGrey(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
