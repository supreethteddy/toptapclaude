import 'package:flutter/material.dart';
import 'package:toptap/common/widget/custom_back_button.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class CustomAppBar extends StatelessWidget {
  final String title;
  final Widget? widget;
  final Widget? rowWidget;
  final bool showBackButton;
  final String? subTitle;
  final TextStyle? titleStyle;
  final Color? bgColor;
  final Color? iconColor;

  const CustomAppBar(
      {super.key,
      required this.title,
      this.widget,
      this.subTitle,
      this.titleStyle,
      this.bgColor,
      this.iconColor,
      this.showBackButton = true,
      this.rowWidget});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: bgColor ?? bgLightGrey(context),
      child: SafeArea(
        bottom: false,
        child: Column(
          spacing: widget != null ? 10 : 0,
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (showBackButton)
                  CustomBackButton(
                    color: iconColor,
                    width: 18,
                    height: 18,
                    padding: const EdgeInsets.all(15),
                  )
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: titleStyle ??
                            TextStyleCustom.unboundedMedium500(
                                color: textDarkGrey(context)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subTitle != null)
                        Text(
                          subTitle ?? '',
                          style: TextStyleCustom.outFitLight300(
                            color: textLightGrey(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                rowWidget ?? const SizedBox(width: 48)
              ],
            ),
            widget ?? const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
