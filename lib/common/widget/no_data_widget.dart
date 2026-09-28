import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class NoDataView extends StatelessWidget {
  const NoDataView(
      {super.key,
      this.title,
      this.description,
      this.child,
      this.showShow = true,
      this.bgColor,
      this.safeAreaTop = false,
      this.iconAsset});

  final String? title;
  final String? description;
  final Widget? child;
  final bool showShow;
  final Color? bgColor;
  final bool safeAreaTop;

  /// Optional icon asset shown above the [title]. When null (the default),
  /// nothing is rendered in its place and layout is unchanged.
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (showShow)
          SafeArea(
              top: safeAreaTop,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 3,
                  children: [
                    if (iconAsset != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Image.asset(
                          iconAsset!,
                          width: 70,
                          height: 70,
                          color: ColorRes.textgreenColor,
                        ),
                      ),
                    Center(
                      child: Text(
                        (title ?? LKey.noData).tr,
                        style: TextStyleCustom.unboundedSemiBold600(
                            color: textLightGrey(context), fontSize: 17),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Text((description ?? LKey.noContentMessage).tr,
                        style: TextStyleCustom.outFitLight300(
                          color: textLightGrey(context),
                        ),
                        textAlign: TextAlign.center),
                  ],
                ),
              )),
        if (child != null) child!
      ],
    );
  }
}

class NoDataWidgetWithScroll extends StatelessWidget {
  final String title;
  final String description;

  const NoDataWidgetWithScroll(
      {super.key, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NoDataView(safeAreaTop: true, title: title, description: description),
        SingleChildScrollView(
          child: SizedBox(width: double.infinity, height: Get.height),
        ),
      ],
    );
  }
}
