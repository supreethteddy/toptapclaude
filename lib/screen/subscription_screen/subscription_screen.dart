import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/common/widget/gradient_text.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/subscription_screen/subscription_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class SubscriptionScreen extends StatelessWidget {
  final Function(User? user)? onUpdateUser;

  const SubscriptionScreen({super.key, this.onUpdateUser});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SubscriptionScreenController(onUpdateUser));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: CustomBackButton(
                padding: EdgeInsets.all(10),
              ),
            ),
            Expanded(
                child: SingleChildScrollView(
              child: Column(
                children: [
                  GradientText(LKey.plus.tr,
                      gradient: StyleRes.themeGradient,
                      style:
                          TextStyleCustom.unboundedExtraBold800(fontSize: 44)),
                  const SizedBox(height: 10),
                  Text(LKey.subscribeToPlus.tr,
                      style: TextStyleCustom.outFitRegular400(
                          fontSize: 18, color: textLightGrey(context)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BuildIconWithText(
                          icon: AssetRes.icNoAds, title: LKey.noAds.tr),
                      const SizedBox(width: 10),
                      BuildIconWithText(
                          icon: AssetRes.icBlueTick,
                          title: LKey.getVerified.tr),
                    ],
                  ),
                  Obx(
                    () => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Column(
                        children: List.generate(
                          controller.packages.length,
                          (index) {
                            ProductDetails package = controller.packages[index];

                            return Obx(() {
                              bool isSelected = controller
                                      .selectedPackage.value?.id ==
                                  package.id;
                              return InkWell(
                                onTap: () =>
                                    controller.onSubscriptionTap(package),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7.5),
                                  width: double.infinity,
                                  decoration: ShapeDecoration(
                                      shape: SmoothRectangleBorder(
                                        borderRadius: SmoothBorderRadius(
                                            cornerRadius: 10,
                                            cornerSmoothing: 1),
                                        side: BorderSide(
                                          color: isSelected
                                              ? Colors.transparent
                                              : textLightGrey(context)
                                                  .withValues(alpha: .2),
                                        ),
                                      ),
                                      color: isSelected
                                          ? null
                                          : bgLightGrey(context),
                                      gradient: isSelected
                                          ? StyleRes.themeGradient
                                          : null,
                                      shadows: isSelected
                                          ? [
                                              BoxShadow(
                                                  color: disableGrey(context),
                                                  blurRadius: 10)
                                            ]
                                          : null),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15, vertical: 15),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          spacing: 5,
                                          children: [
                                            Text(
                                              package.getDetail.title,
                                              style: TextStyleCustom
                                                  .unboundedMedium500(
                                                      fontSize: 15,
                                                      color: isSelected
                                                          ? whitePure(context)
                                                          : textLightGrey(
                                                              context)),
                                            ),
                                            if (package.getDetail.description
                                                .isNotEmpty)
                                              Text(
                                                package.getDetail.description,
                                                style: TextStyleCustom
                                                  .outFitRegular400(
                                                      color: isSelected
                                                          ? whitePure(context)
                                                          : textLightGrey(
                                                              context)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        package.price,
                                        style:
                                            TextStyleCustom.outFitExtraBold800(
                                                fontSize: 24,
                                                color: isSelected
                                                    ? whitePure(context)
                                                    : textLightGrey(context)),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  TextButtonCustom(
                      onTap: controller.onMakePurchase,
                      title: LKey.subscribeNow.tr,
                      backgroundColor: textDarkGrey(context),
                      titleColor: whitePure(context)),
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 20.0, right: 20.0, top: 40),
                    child: Text(
                      LKey.subscriptionTerms.tr,
                      style: TextStyleCustom.outFitLight300(
                          fontSize: 13, color: textLightGrey(context)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: AppBar().preferredSize.height / 2.5),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class BuildIconWithText extends StatelessWidget {
  final String icon;
  final String title;

  const BuildIconWithText({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(cornerRadius: 30),
            side: BorderSide(color: bgGrey(context))),
        color: bgMediumGrey(context),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            icon,
            height: 22,
            width: 28,
            alignment: AlignmentDirectional.centerStart,
          ),
          Text(
            title,
            style: TextStyleCustom.outFitRegular400(
                fontSize: 15, color: textDarkGrey(context)),
          )
        ],
      ),
    );
  }
}

/// Presentation helpers for store subscription products. The billing period
/// is inferred from the product id (…_weekly / …_monthly / …_yearly).
extension StoreProductDetail on ProductDetails {
  SubscriptionDetail get getDetail {
    final lower = id.toLowerCase();
    String cleanTitle() {
      // Google Play appends "(App name)" to titles.
      final t = title.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').trim();
      return t.isEmpty ? id : t;
    }

    if (lower.contains('lifetime')) {
      return SubscriptionDetail(title: LKey.lifetime.tr, description: description);
    }
    if (lower.contains('year') || lower.contains('annual')) {
      return SubscriptionDetail(
          title: LKey.annual.tr,
          description: LKey.subscriptionDescription.trParams(
              {'price': calculatePrice(12), 'unit_label': LKey.annually.tr}));
    }
    if (lower.contains('6month') || lower.contains('six')) {
      return SubscriptionDetail(
          title: LKey.sixMonth.tr,
          description: LKey.subscriptionDescription.trParams(
              {'price': calculatePrice(6), 'unit_label': LKey.semiAnnually.tr}));
    }
    if (lower.contains('3month') || lower.contains('quarter')) {
      return SubscriptionDetail(
          title: LKey.threeMonth.tr,
          description: LKey.subscriptionDescription.trParams(
              {'price': calculatePrice(3), 'unit_label': LKey.threeMonths.tr}));
    }
    if (lower.contains('week')) {
      return SubscriptionDetail(
          title: LKey.weekly.tr, description: LKey.giveItATry.tr);
    }
    if (lower.contains('month')) {
      return SubscriptionDetail(title: LKey.monthly.tr, description: '');
    }
    return SubscriptionDetail(title: cleanTitle(), description: description);
  }

  String calculatePrice(int months) {
    if (months <= 1) return '';
    final perMonth = rawPrice / months;
    return '$currencySymbol${perMonth.toStringAsFixed(2)}';
  }
}

class SubscriptionDetail {
  String title;
  String description;

  SubscriptionDetail({this.title = '', this.description = ''});
}
