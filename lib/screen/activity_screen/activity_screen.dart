import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/common/widget/loader_widget.dart';
import 'package:toptap/screen/activity_screen/activity_screen_controller.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';
import 'package:toptap/utilities/asset_res.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ActivityScreenController());

    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(title: 'Activity'),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const LoaderWidget();
              }

              // Show empty state for now since this screen is in development
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(AssetRes.icNotification_1,
                        height: 64, width: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Activity Center',
                      style:
                          TextStyleCustom.outFitMedium500(
                        fontSize: 18,
                        color: textDarkGrey(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0),
                      child: Text(
                        'Track your account activity and interactions with other users',
                        textAlign: TextAlign.center,
                        style: TextStyleCustom
                            .outFitRegular400(
                          fontSize: 14,
                          color: textLightGrey(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed:
                          controller.refreshActivities,
                      child: const Text('Refresh Activity'),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
