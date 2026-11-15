import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/custom_back_button.dart';
import 'package:toptap/common/widget/custom_divider.dart';
import 'package:toptap/common/widget/custom_drop_down.dart';
import 'package:toptap/common/widget/privacy_policy_text.dart';
import 'package:toptap/common/widget/text_button_custom.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/screen/report_sheet/report_sheet_controller.dart';
import 'package:toptap/utilities/app_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

enum ReportType { post, user }

class ReportSheet extends StatelessWidget {
  final int? id;
  final ReportType reportType;

  const ReportSheet(
      {super.key, this.id, required this.reportType});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
        ReportSheetController(id ?? -1, reportType));
    final isDarkMode =
        Theme.of(context).brightness == Brightness.dark;
    final descriptionBgColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.06)
        : bgLightGrey(context);
    final descriptionBorderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.transparent;
    final title = LKey.reportPost
            .trParams({
              'reportType': reportType == ReportType.post
                  ? LKey.post.tr
                  : LKey.user.tr,
            })
            .capitalize ??
        '';

    return Container(
      decoration: ShapeDecoration(
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(
                  cornerRadius: 40, cornerSmoothing: 1)),
        ),
        color: scaffoldBackgroundColor(context),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin:
                  const EdgeInsets.only(top: 10, bottom: 9),
              child: Column(
                children: [
                  const CustomDivider(
                    width: 130,
                    height: 1,
                  ),
                  Container(
                    height: 58,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        CustomBackButton(
                          width: 18,
                          height: 18,
                          padding: const EdgeInsets.all(8),
                          onTap: () {
                            final navigator =
                                Navigator.maybeOf(context);
                            if (navigator != null &&
                                navigator.canPop()) {
                              navigator.maybePop();
                              return;
                            }
                            if (Get.key.currentState
                                    ?.canPop() ??
                                false) {
                              Get.back();
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyleCustom
                                .unboundedMedium500(
                                    color:
                                        textDarkGrey(context),
                                    fontSize: 18),
                          ),
                        ),
                        const SizedBox(
                          width: 36,
                          height: 36,
                        ),
                      ],
                    ),
                  ),
                  const CustomDivider(height: 1),
                ],
              ),
            ),
            Expanded(
                child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 10),
                    child: Text(
                      LKey.reason.tr,
                      style: TextStyleCustom.outFitRegular400(
                          fontSize: 17,
                          color: textDarkGrey(context)),
                    ),
                  ),
                  Obx(
                    () {
                      final selected =
                          controller.selectedValue.value;
                      final reportList = controller.reports;
                      if (reportList.isEmpty) {
                        return Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15.0),
                          color: bgLightGrey(context),
                          width: double.infinity,
                          alignment: AlignmentDirectional
                              .centerStart,
                          child: Text(
                              AppRes.emptyReportReason,
                              style: TextStyleCustom
                                  .outFitLight300(
                                fontSize: 17,
                                color: textLightGrey(context),
                              )),
                        );
                      }
                      return CustomDropDownBtn(
                        items: reportList,
                        selectedValue: reportList.firstWhere(
                            (e) => e.id == selected?.id,
                            orElse: () => reportList.first),
                        onChanged: (value) {
                          if (value != null) {
                            controller.selectedValue.value =
                                value;
                          }
                        },
                        getTitle: (p0) => p0.title ?? '',
                        height: 50,
                        width: double.infinity,
                        isExpanded: true,
                        menuMaxHeight: 200,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5),
                        bgColor: bgLightGrey(context),
                        style:
                            TextStyleCustom.outFitLight300(
                                fontSize: 17,
                                color: textLightGrey(
                                    context)),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 10),
                    child: Text(
                      LKey.description.tr,
                      style: TextStyleCustom.outFitRegular400(
                          fontSize: 17,
                          color: textDarkGrey(context)),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20),
                    decoration: ShapeDecoration(
                      color: descriptionBgColor,
                      shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius(
                            cornerRadius: 14,
                            cornerSmoothing: 1),
                        side: BorderSide(
                          color: descriptionBorderColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: TextField(
                        controller: controller
                            .descriptionController,
                        onTapOutside: (event) =>
                            FocusManager.instance.primaryFocus
                                ?.unfocus(),
                        textCapitalization:
                            TextCapitalization.sentences,
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            constraints: const BoxConstraints(
                                minHeight: 170,
                                maxHeight: 170),
                            contentPadding:
                                const EdgeInsets.all(15),
                            hintText:
                                LKey.descriptionHere.tr,
                            hintStyle: TextStyleCustom
                                .outFitLight300(
                                    fontSize: 17,
                                    color: textLightGrey(
                                        context))),
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        style: TextStyleCustom
                            .outFitLight300(
                                fontSize: 17,
                                color: textLightGrey(
                                    context))),
                  ),
                  const SizedBox(height: 30),
                  TextButtonCustom(
                    onTap: controller.onReportSubmit,
                    title: LKey.submit.tr,
                    backgroundColor: textDarkGrey(context),
                    titleColor: whitePure(context),
                    borderSide: BorderSide(
                        color: whitePure(context), width: 1),
                  ),
                  SizedBox(
                      height: AppBar().preferredSize.height),
                  const PrivacyPolicyText()
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
