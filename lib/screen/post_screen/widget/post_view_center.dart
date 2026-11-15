import 'package:dismissible_page/dismissible_page.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:readmore/readmore.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/service/navigation/navigate_with_controller.dart';
import 'package:toptap/common/service/url_extractor/parsers/base_parser.dart';
import 'package:toptap/common/widget/custom_bg_circle_button.dart';
import 'package:toptap/common/widget/custom_image.dart';
import 'package:toptap/common/widget/custom_page_indicator.dart';
import 'package:toptap/common/widget/double_tap_detector.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/post_story/post_model.dart';
import 'package:toptap/model/user_model/user_model.dart';
import 'package:toptap/screen/hashtag_screen/hashtag_screen.dart';
import 'package:toptap/screen/image_view_screen/image_view_screen.dart';
import 'package:toptap/screen/post_screen/single_post_screen.dart';
import 'package:toptap/screen/reels_screen/reels_screen.dart';
import 'package:toptap/utilities/app_res.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/font_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class PostViewCenter extends StatelessWidget {
  final Post post;
  final void Function()? onHeartAnimationEnd;
  final Function(TapDownDetails) onDoubleTap;

  const PostViewCenter(
      {super.key,
      required this.post,
      this.onHeartAnimationEnd,
      required this.onDoubleTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Get.to(() => SinglePostScreen(
            post: post, isFromNotification: false));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((post.description ?? '').isNotEmpty)
            PostTextView(
                description: post.descriptionWithUserName,
                mentionUsers: post.mentionedUsers ?? [],
                metadata: post.metaData),
          if ((post.images ?? []).isNotEmpty)
            PostImageView(
              post: post,
              onDoubleTap: onDoubleTap,
              onHeartAnimationEnd: onHeartAnimationEnd,
            ),
          if ((post.video ?? '').isNotEmpty)
            PostVideoView(
              post: post,
              onDoubleTap: onDoubleTap,
              onHeartAnimationEnd: onHeartAnimationEnd,
            )
        ],
      ),
    );
  }
}

class PostTextView extends StatefulWidget {
  final String? description;
  final List<User> mentionUsers;
  final Color? basicTextColor;
  final Color? hashtagTextColor;
  final Color? mentionTextColor;
  final double? basicTextOpacity;
  final UrlMetadata? metadata;

  const PostTextView(
      {super.key,
      required this.description,
      required this.mentionUsers,
      this.basicTextColor,
      this.hashtagTextColor,
      this.mentionTextColor,
      this.basicTextOpacity,
      this.metadata});

  @override
  State<PostTextView> createState() => _PostTextViewState();
}

class _PostTextViewState extends State<PostTextView> {
  final RxBool isCollapsed = true.obs;
  late final ValueNotifier<bool> _collapsedNotifier;

  @override
  void initState() {
    super.initState();
    // Bridge GetX reactive to ValueNotifier for third-party package compatibility
    _collapsedNotifier = ValueNotifier(isCollapsed.value);

    // Keep them in sync
    isCollapsed.listen((value) {
      _collapsedNotifier.value = value;
    });

    _collapsedNotifier.addListener(() {
      isCollapsed.value = _collapsedNotifier.value;
    });
  }

  @override
  void dispose() {
    _collapsedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TextStyle collapsedStyle =
        TextStyleCustom.outFitLight300(
            fontSize: 15,
            color: widget.basicTextColor ??
                textLightGrey(context),
            opacity: .8);

    return InkWell(
      onTap: () {
        isCollapsed.value = !isCollapsed.value;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReadMoreText(
            widget.description ?? '',
            isCollapsed: _collapsedNotifier,
            trimMode: TrimMode.Line,
            trimLines: AppRes.trimLine,
            colorClickableText: Colors.pink,
            trimCollapsedText: LKey.more.tr,
            trimExpandedText: ' ${LKey.less.tr}',
            lessStyle: collapsedStyle,
            moreStyle: collapsedStyle,
            style: TextStyleCustom.outFitRegular400(
                color: widget.basicTextColor ??
                    textDarkGrey(context),
                fontSize: 15,
                opacity: widget.basicTextOpacity),
            annotations: [
              Annotation(
                regExp: AppRes.hashTagRegex,
                spanBuilder: (
                        {required String text,
                        TextStyle? textStyle}) =>
                    TextSpan(
                        text: text,
                        style: textStyle?.copyWith(
                          color: widget.hashtagTextColor ??
                              themeAccentSolid(context),
                          fontFamily:
                              FontRes.outFitMedium500,
                          fontSize: 15,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Get.to(
                                () => HashtagScreen(
                                    hashtag: text),
                                preventDuplicates: false);
                          }),
              ),
              Annotation(
                regExp: AppRes.urlRegex,
                spanBuilder: (
                        {required String text,
                        TextStyle? textStyle}) =>
                    TextSpan(
                        text: text,
                        style: textStyle?.copyWith(
                          color: themeAccentSolid(context),
                          fontFamily:
                              FontRes.outFitMedium500,
                          fontSize: 15,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            await text.lunchUrl;
                          }),
              ),
              Annotation(
                regExp: AppRes.userNameRegex,
                spanBuilder: (
                    {required String text,
                    TextStyle? textStyle}) {
                  return TextSpan(
                    text: text,
                    style: textStyle?.copyWith(
                      color: widget.mentionTextColor ??
                          blueFollow(context),
                      fontFamily: FontRes.outFitMedium500,
                      fontSize: 15,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        String id =
                            text.replaceAll('@', '');
                        User? mentionUser = widget
                            .mentionUsers
                            .firstWhereOrNull((element) =>
                                element.username == id);
                        if (mentionUser != null) {
                          NavigationService.shared
                              .openProfileScreen(
                                  mentionUser);
                        }
                      },
                  );
                },
              ),
            ],
          ),
          if (widget.metadata != null)
            InkWell(
              onTap: () {
                widget.metadata?.url?.lunchUrl;
              },
              child: Container(
                height: 80,
                margin: const EdgeInsets.symmetric(
                    vertical: 10),
                decoration: ShapeDecoration(
                  shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 9,
                          cornerSmoothing: 1),
                      side: BorderSide(
                          color: bgGrey(context))),
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    Container(
                      height: 80,
                      width: 80,
                      decoration: ShapeDecoration(
                        shape: const SmoothRectangleBorder(
                          borderRadius:
                              SmoothBorderRadius.horizontal(
                                  left: SmoothRadius(
                                      cornerRadius: 8,
                                      cornerSmoothing: 1)),
                        ),
                        color: bgGrey(context),
                      ),
                      alignment: Alignment.center,
                      child: CustomImage(
                        size: const Size(70, 70),
                        image: widget.metadata?.image,
                        isShowPlaceHolder: true,
                        placeHolderImage:
                            AssetRes.icLinkPlaceholder,
                      ),
                    ),
                    Expanded(
                        child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.metadata?.title ?? '',
                          style: TextStyleCustom
                              .outFitRegular400(
                                  color:
                                      textDarkGrey(context),
                                  fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.metadata?.host != null)
                          Text(
                            widget.metadata?.host ?? '',
                            style: TextStyleCustom
                                .outFitRegular400(
                                    color: textLightGrey(
                                        context),
                                    fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ))
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}

class PostImageView extends StatelessWidget {
  final Post post;
  final double height;
  final EdgeInsets? margin;
  final double? radius;
  final Function(TapDownDetails)? onDoubleTap;
  final void Function()? onHeartAnimationEnd;

  const PostImageView(
      {super.key,
      required this.post,
      this.height = 300,
      this.margin,
      this.radius,
      this.onHeartAnimationEnd,
      this.onDoubleTap});

  @override
  Widget build(BuildContext context) {
    RxInt selectedIndex = 0.obs;
    PageController controller = PageController();
    GlobalKey uniqueTag = GlobalKey();
    return DoubleTapDetector(
      onDoubleTap: (details) {
        if (onDoubleTap != null) {
          onDoubleTap?.call(details);
        }
      },
      child: Container(
        margin: margin ??
            const EdgeInsets.only(right: 10.0, top: 10),
        constraints: BoxConstraints(
            maxHeight: height,
            minHeight: height,
            maxWidth: MediaQuery.of(context).size.width,
            minWidth: MediaQuery.of(context).size.width),
        child: ClipSmoothRect(
          radius: SmoothBorderRadius(
              cornerRadius: radius ?? 8,
              cornerSmoothing: 1),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              PageView.builder(
                controller: controller,
                onPageChanged: (value) {
                  selectedIndex.value = value;
                },
                itemCount: (post.images ?? []).length,
                itemBuilder: (context, index) {
                  Images? image = post.images?[index];
                  return Hero(
                    tag: '${uniqueTag}_${image?.image}',
                    child: CustomImage(
                        size: Size(
                            MediaQuery.of(context)
                                .size
                                .width,
                            300),
                        image: image?.image?.addBaseURL(),
                        radius: 0,
                        isShowPlaceHolder: true,
                        cornerSmoothing: 1),
                  );
                },
              ),
              if ((post.images ?? []).length > 1)
                CustomPageIndicator(
                    length: (post.images ?? []).length,
                    selectedIndex: selectedIndex),
              Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: InkWell(
                  onTap: () {
                    context.pushTransparentRoute(
                        ImageViewScreen(
                      images: post.images ?? [],
                      selectedIndex: selectedIndex.value,
                      onChanged: (position) {
                        controller.jumpToPage(position);
                      },
                      tag: '$uniqueTag',
                    ));
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CustomBgCircleButton(
                        image: AssetRes.icExpand,
                        size: Size(30, 30)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class PostVideoView extends StatelessWidget {
  final Post? post;
  final EdgeInsets? margin;
  final double? radius;
  final Function(TapDownDetails)? onDoubleTap;
  final void Function()? onHeartAnimationEnd;

  const PostVideoView(
      {super.key,
      required this.post,
      this.onHeartAnimationEnd,
      this.onDoubleTap,
      this.margin,
      this.radius});

  @override
  Widget build(BuildContext context) {
    return DoubleTapDetector(
      onDoubleTap: (details) {
        if (onDoubleTap != null) {
          onDoubleTap?.call(details);
        }
      },
      onTap: () {
        Get.to(() =>
            ReelsScreen(reels: [post!].obs, position: 0));
      },
      child: Container(
        margin: margin ??
            const EdgeInsets.only(right: 10.0, top: 10),
        constraints: BoxConstraints(
            maxHeight: 211,
            minHeight: 211,
            maxWidth: MediaQuery.of(context).size.width,
            minWidth: MediaQuery.of(context).size.width),
        child: ClipSmoothRect(
          radius: SmoothBorderRadius(
              cornerRadius: radius ?? 10,
              cornerSmoothing: 1),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomImage(
                size: const Size(double.infinity, 211),
                fit: BoxFit.cover,
                radius: radius ?? 10,
                cornerSmoothing: 1,
                image: post?.thumbnail?.addBaseURL(),
              ),
              Container(
                height: 35,
                width: 35,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: textDarkGrey(context)
                        .withValues(alpha: .4)),
                alignment: Alignment.center,
                child: Image.asset(AssetRes.icPlay,
                    width: 20, height: 20),
              )
            ],
          ),
        ),
      ),
    );
  }
}
