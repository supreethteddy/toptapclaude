import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/screen/settings_screen/localization_screen/localization_screen_controller.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class LocalizationScreen extends StatelessWidget {
  const LocalizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocalizationScreenController>(
      init: LocalizationScreenController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: bgLightGrey(context),
          body: Column(
            children: [
              CustomAppBar(title: "Language".tr),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (controller.languages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.language,
                            size: 64,
                            color: textLightGrey(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No languages available".tr,
                            style: TextStyleCustom.outFitRegular400(
                              fontSize: 16,
                              color: textLightGrey(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    itemCount: controller.languages.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 1),
                    itemBuilder: (context, index) {
                      final language = controller.languages[index];
                      final isSelected = controller.selectedLanguageCode.value == language.code;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0),
                        decoration: BoxDecoration(
                          color: bgLightGrey(context),
                          border: Border(
                            bottom: BorderSide(
                              color: textLightGrey(context).withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected 
                                  ? themeAccentSolid(context).withOpacity(0.1)
                                  : textLightGrey(context).withOpacity(0.1),
                            ),
                            child: Center(
                              child: Text(
                                language.code?.toUpperCase().substring(0, 2) ?? 'EN',
                                style: TextStyleCustom.outFitSemiBold600(
                                  fontSize: 14,
                                  color: isSelected 
                                      ? themeAccentSolid(context)
                                      : textDarkGrey(context),
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            language.localizedTitle ?? language.title ?? 'Unknown',
                            style: TextStyleCustom.outFitMedium500(
                              fontSize: 16,
                              color: textDarkGrey(context),
                            ),
                          ),
                          subtitle: language.title != language.localizedTitle
                              ? Text(
                                  language.title ?? '',
                                  style: TextStyleCustom.outFitRegular400(
                                    fontSize: 14,
                                    color: textLightGrey(context),
                                  ),
                                )
                              : null,
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: themeAccentSolid(context),
                                  size: 24,
                                )
                              : Icon(
                                  Icons.radio_button_unchecked,
                                  color: textLightGrey(context),
                                  size: 24,
                                ),
                          onTap: () => controller.selectLanguage(language),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
