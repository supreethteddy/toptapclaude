import 'package:get/get.dart';
import 'package:toptap/common/controller/base_controller.dart';
import 'package:toptap/common/service/api/notification_service.dart';
import 'package:toptap/model/misc/activity_notification_model.dart';
import 'package:toptap/model/user_model/user_model.dart';

class ActivityScreenController extends BaseController {
  RxList<ActivityNotification> activities =
      <ActivityNotification>[].obs;
  RxBool isLoading = false.obs;
  RxBool isLoadingMore = false.obs;
  int page = 1;
  bool hasMoreData = true;

  @override
  void onInit() {
    super.onInit();
    fetchActivities();
  }

  Future<void> fetchActivities(
      {bool isRefresh = false}) async {
    if (isRefresh) {
      page = 1;
      hasMoreData = true;
      activities.clear();
    }

    if (!hasMoreData) return;

    if (page == 1) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      // Get lastItemId from the last activity if available
      int? lastItemId;
      if (activities.isNotEmpty) {
        lastItemId = activities.last.id;
      }

      List<ActivityNotification> response =
          await NotificationService.instance
              .fetchActivityNotifications(
                  lastItemId: lastItemId);

      if (response.isNotEmpty) {
        activities.addAll(response);
      } else {
        hasMoreData = false;
      }
    } catch (e) {
      showSnackBar('$e');
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> refreshActivities() async {
    return fetchActivities(isRefresh: true);
  }

  void loadMoreActivities() {
    if (!isLoading.value &&
        !isLoadingMore.value &&
        hasMoreData) {
      fetchActivities();
    }
  }

  void onUserTap(User? user) {
    if (user != null) {
      Get.toNamed('/profile', arguments: {'user': user});
    }
  }

  void onPostTap(ActivityNotification? data) {
    if (data?.data?.post != null) {
      Get.toNamed('/post',
          arguments: {'post': data!.data!.post});
    }
  }

  void onDescriptionTap(ActivityNotification data) {
    onPostTap(data);
  }
}
