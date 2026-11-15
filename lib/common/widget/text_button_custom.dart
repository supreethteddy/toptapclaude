// import 'package:figma_squircle_updated/figma_squircle.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:toptap/utilities/text_style_custom.dart';
// import 'package:toptap/utilities/theme_res.dart';

// class TextButtonCustom extends StatelessWidget {
//   final String title;
//   final Color? titleColor;
//   final Color? backgroundColor;
//   final VoidCallback onTap;
//   final double? horizontalMargin;
//   final double? btnHeight;
//   final double? btnWidth;
//   final double? fontSize;
//   final EdgeInsets? padding;
//   final EdgeInsets? margin;
//   final double? radius;
//   final BorderSide? borderSide;

//   const TextButtonCustom(
//       {super.key,
//       required this.onTap,
//       required this.title,
//       this.titleColor,
//       this.backgroundColor,
//       this.horizontalMargin,
//       this.btnHeight,
//       this.padding,
//       this.fontSize,
//       this.radius,
//       this.borderSide,
//       this.btnWidth,
//       this.margin});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin:
//           margin ?? EdgeInsets.symmetric(horizontal: horizontalMargin ?? 15),
//       child: InkWell(
//         onTap: onTap,
//         child: Container(
//           height: btnHeight ?? 57,
//           width: btnWidth,
//           padding: padding,
//           alignment: Alignment.center,
//           decoration: ShapeDecoration(
//               shape: SmoothRectangleBorder(
//                   borderRadius: SmoothBorderRadius(
//                       cornerRadius: radius ?? 10, cornerSmoothing: 1),
//                   side: borderSide ?? BorderSide.none),
//               color: backgroundColor ?? whitePure(context)),
//           child: Text(
//             title.capitalize ?? '',
//             style: TextStyleCustom.outFitRegular400(
//                 color: titleColor ?? textDarkGrey(context),
//                 fontSize: fontSize ?? 17),
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/utilities/color_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class TextButtonCustom extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final Color? backgroundColor;
  final VoidCallback onTap;
  final double? horizontalMargin;
  final double? btnHeight;
  final double? btnWidth;
  final double? fontSize;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? radius;
  final BorderSide? borderSide;

  const TextButtonCustom({
    super.key,
    required this.onTap,
    required this.title,
    this.titleColor,
    this.backgroundColor,
    this.horizontalMargin,
    this.btnHeight,
    this.padding,
    this.fontSize,
    this.radius,
    this.borderSide,
    this.btnWidth,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ??
          EdgeInsets.symmetric(
              horizontal: horizontalMargin ?? 15),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: btnHeight ?? 57,
          width: btnWidth,
          padding: padding,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            gradient: backgroundColor == null
                ? const LinearGradient(
                    colors: [
                      ColorRes.likeRed,
                      ColorRes.orange,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: backgroundColor,
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: radius ?? 10,
                cornerSmoothing: 1,
              ),
              side: borderSide ?? BorderSide.none,
            ),
          ),
          child: Text(
            title.capitalize ?? '',
            style: TextStyleCustom.outFitExtraBold800(
              color: titleColor ?? whitePure(context),
              fontSize: fontSize ?? 20,
            ),
          ),
        ),
      ),
    );
  }
}

class TextButtonCustomforloginandsingup
    extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final Color? backgroundColor;
  final VoidCallback onTap;
  final double? horizontalMargin;
  final double? btnHeight;
  final double? btnWidth;
  final double? fontSize;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? radius;
  final BorderSide? borderSide;

  const TextButtonCustomforloginandsingup({
    super.key,
    required this.onTap,
    required this.title,
    this.titleColor,
    this.backgroundColor,
    this.horizontalMargin,
    this.btnHeight,
    this.padding,
    this.fontSize,
    this.radius,
    this.borderSide,
    this.btnWidth,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    // final bool isDarkMode =
    //     Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin ??
          EdgeInsets.symmetric(
              horizontal: horizontalMargin ?? 15),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: btnHeight ?? 57,
          width: btnWidth,
          padding: padding,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: ColorRes.textredColor,
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: radius ?? 10,
                cornerSmoothing: 1,
              ),
              side: borderSide ?? BorderSide.none,
            ),
            // color: Theme.of(context).brightness ==
            //         Brightness.dark
            //     ? Colors.white
            //     : Colors.black,
          ),
          child: Text(
            title.capitalize ?? '',
            style: TextStyleCustom.outFitExtraBold800(
              color: adaptiveTextColor(context),
              fontSize: fontSize ?? 20,
            ),
          ),
        ),
      ),
    );
  }
}

class TextButtonCustomforuserprofileandfollowersprofile
    extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final Color? backgroundColor;
  final VoidCallback onTap;
  final double? horizontalMargin;
  final double? btnHeight;
  final double? btnWidth;
  final double? fontSize;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? radius;
  final BorderSide? borderSide;

  const TextButtonCustomforuserprofileandfollowersprofile({
    super.key,
    required this.onTap,
    required this.title,
    this.titleColor,
    this.backgroundColor,
    this.horizontalMargin,
    this.btnHeight,
    this.padding,
    this.fontSize,
    this.radius,
    this.borderSide,
    this.btnWidth,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    // final bool isDarkMode =
    //     Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin ??
          EdgeInsets.symmetric(
              horizontal: horizontalMargin ?? 15),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: btnHeight ?? 57,
          width: btnWidth,
          padding: padding,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            // color: ColorRes.textredColor,
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: radius ?? 10,
                cornerSmoothing: 1,
              ),
              side: BorderSide(
                  color: adaptiveBorderColor(context)),
            ),
          ),
          child: Text(
            title.capitalize ?? '',
            style: TextStyleCustom.outFitExtraBold800(
              color: ColorRes.textgreenColor,
              fontSize: fontSize ?? 20,
            ),
          ),
        ),
      ),
    );
  }
}
