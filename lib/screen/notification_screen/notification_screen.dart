import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/common/widget/custom_tab_switcher.dart';
import 'package:toptap/common/widget/load_more_widget.dart';
import 'package:toptap/common/widget/loader_widget.dart';
import 'package:toptap/common/widget/no_data_widget.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/misc/activity_notification_model.dart';
import 'package:toptap/model/misc/admin_notification_model.dart';
import 'package:toptap/screen/notification_screen/notification_screen_controller.dart';
import 'package:toptap/screen/notification_screen/widget/activity_notification_page.dart';
import 'package:toptap/screen/notification_screen/widget/system_notification_page.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class NotificationScreen extends StatelessWidget {
  final bool showBackButton;

  const NotificationScreen({super.key, this.showBackButton = false});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NotificationScreenController());
    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(
              title: LKey.notifications.tr,
              showBackButton: showBackButton,
              titleStyle: TextStyleCustom.unboundedSemiBold600(
                  fontSize: 15, color: textDarkGrey(context)),
              widget: CustomTabSwitcher(
                  items: [(LKey.activity.tr), (LKey.system.tr)],
                  selectedIndex: controller.selectedTabIndex,
                  margin:
                      const EdgeInsets.only(left: 15, right: 15, bottom: 15),
                  onTap: (index) {
                    controller.onTabChange(index);
                    controller.pageController.animateToPage(index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.linear);
                  })),
          Expanded(
            child: SafeArea(
              top: false,
              child: Obx(() {
                return PageView(
                  controller: controller.pageController,
                  onPageChanged: controller.onTabChange,
                  children: [
                    /// Activity Notifications Page
                    _NotificationListWrapper<ActivityNotification>(
                        isLoading: controller.isActivityNotification.value,
                        isEmpty: controller.activityNotifications.isEmpty,
                        items: controller.activityNotifications,
                        itemBuilder: (context, data) =>
                            ActivityNotificationPage(
                                data: data, controller: controller),
                        loadMore: controller.fetchActivityNotifications),

                    /// Admin Notifications Page
                    _NotificationListWrapper<AdminNotificationData>(
                      isLoading: controller.isAdminNotification.value,
                      isEmpty: controller.adminNotifications.isEmpty,
                      items: controller.adminNotifications,
                      itemBuilder: (context, data) =>
                          SystemNotificationPage(data: data),
                      loadMore: controller.fetchAdminNotification,
                    ),
                  ],
                );
              }),
            ),
          )
        ],
      ),
    );
  }
}

class _NotificationListWrapper<T> extends StatelessWidget {
  final bool isLoading;
  final bool isEmpty;
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final Future<void> Function() loadMore;

  const _NotificationListWrapper({
    required this.isLoading,
    required this.isEmpty,
    required this.items,
    required this.itemBuilder,
    required this.loadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && isEmpty) {
      return const LoaderWidget();
    }

    return NoDataView(
      showShow: isEmpty,
      child: LoadMoreWidget(
        loadMore: loadMore,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (context, index) {
            return itemBuilder(context, items[index]);
          },
        ),
      ),
    );
  }
}
