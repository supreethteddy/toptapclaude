import 'package:get/get.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/utils/settings_error_handler.dart';

class NotificationSettingsScreenController extends GetxController {
  // General Notifications
  RxBool pushNotifications = true.obs;
  RxBool soundEnabled = true.obs;
  RxBool vibrationEnabled = true.obs;

  // Activity Notifications
  RxBool likesNotifications = true.obs;
  RxBool commentsNotifications = true.obs;
  RxBool followersNotifications = true.obs;
  RxBool mentionsNotifications = true.obs;

  // Live & Social Notifications
  RxBool liveNotifications = true.obs;
  RxBool giftsNotifications = true.obs;
  RxBool messagesNotifications = true.obs;

  // Marketing Notifications
  RxBool promotionalNotifications = false.obs;
  RxBool updatesNotifications = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadNotificationSettings();
  }

  // Load notification settings from storage
  void _loadNotificationSettings() {
    try {
      final storage = SessionManager.instance.storage;

      // General notifications
      pushNotifications.value = storage.read('push_notifications') ?? true;
      soundEnabled.value = storage.read('sound_enabled') ?? true;
      vibrationEnabled.value = storage.read('vibration_enabled') ?? true;

      // Activity notifications
      likesNotifications.value = storage.read('likes_notifications') ?? true;
      commentsNotifications.value =
          storage.read('comments_notifications') ?? true;
      followersNotifications.value =
          storage.read('followers_notifications') ?? true;
      mentionsNotifications.value =
          storage.read('mentions_notifications') ?? true;

      // Live & Social notifications
      liveNotifications.value = storage.read('live_notifications') ?? true;
      giftsNotifications.value = storage.read('gifts_notifications') ?? true;
      messagesNotifications.value =
          storage.read('messages_notifications') ?? true;

      // Marketing notifications
      promotionalNotifications.value =
          storage.read('promotional_notifications') ?? false;
      updatesNotifications.value =
          storage.read('updates_notifications') ?? true;
    } catch (e) {
      print('Error loading notification settings: $e');
      SettingsErrorHandler.handleError(e,
          customMessage: 'Failed to load notification settings'.tr);
    }
  }

  // Save notification setting to storage
  void _saveNotificationSetting(String key, bool value) {
    try {
      SessionManager.instance.storage.write(key, value);
    } catch (e) {
      print('Error saving notification setting $key: $e');
      SettingsErrorHandler.handleError(e,
          customMessage: 'Failed to save setting'.tr);
    }
  }

  // General notification toggles
  void togglePushNotifications(bool value) {
    pushNotifications.value = value;
    _saveNotificationSetting('push_notifications', value);
  }

  void toggleSound(bool value) {
    soundEnabled.value = value;
    _saveNotificationSetting('sound_enabled', value);
  }

  void toggleVibration(bool value) {
    vibrationEnabled.value = value;
    _saveNotificationSetting('vibration_enabled', value);
  }

  // Activity notification toggles
  void toggleLikes(bool value) {
    likesNotifications.value = value;
    _saveNotificationSetting('likes_notifications', value);
  }

  void toggleComments(bool value) {
    commentsNotifications.value = value;
    _saveNotificationSetting('comments_notifications', value);
  }

  void toggleFollowers(bool value) {
    followersNotifications.value = value;
    _saveNotificationSetting('followers_notifications', value);
  }

  void toggleMentions(bool value) {
    mentionsNotifications.value = value;
    _saveNotificationSetting('mentions_notifications', value);
  }

  // Live & Social notification toggles
  void toggleLive(bool value) {
    liveNotifications.value = value;
    _saveNotificationSetting('live_notifications', value);
  }

  void toggleGifts(bool value) {
    giftsNotifications.value = value;
    _saveNotificationSetting('gifts_notifications', value);
  }

  void toggleMessages(bool value) {
    messagesNotifications.value = value;
    _saveNotificationSetting('messages_notifications', value);
  }

  // Marketing notification toggles
  void togglePromotional(bool value) {
    promotionalNotifications.value = value;
    _saveNotificationSetting('promotional_notifications', value);
  }

  void toggleUpdates(bool value) {
    updatesNotifications.value = value;
    _saveNotificationSetting('updates_notifications', value);
  }

  // Get notification settings summary for display
  Map<String, bool> getNotificationSummary() {
    return {
      'push_notifications': pushNotifications.value,
      'sound_enabled': soundEnabled.value,
      'vibration_enabled': vibrationEnabled.value,
      'likes_notifications': likesNotifications.value,
      'comments_notifications': commentsNotifications.value,
      'followers_notifications': followersNotifications.value,
      'mentions_notifications': mentionsNotifications.value,
      'live_notifications': liveNotifications.value,
      'gifts_notifications': giftsNotifications.value,
      'messages_notifications': messagesNotifications.value,
      'promotional_notifications': promotionalNotifications.value,
      'updates_notifications': updatesNotifications.value,
    };
  }

  // Reset all notifications to default
  void resetToDefault() {
    pushNotifications.value = true;
    soundEnabled.value = true;
    vibrationEnabled.value = true;
    likesNotifications.value = true;
    commentsNotifications.value = true;
    followersNotifications.value = true;
    mentionsNotifications.value = true;
    liveNotifications.value = true;
    giftsNotifications.value = true;
    messagesNotifications.value = true;
    promotionalNotifications.value = false;
    updatesNotifications.value = true;

    _saveAllSettings();
  }

  void _saveAllSettings() {
    try {
      final storage = SessionManager.instance.storage;

      storage.write('push_notifications', pushNotifications.value);
      storage.write('sound_enabled', soundEnabled.value);
      storage.write('vibration_enabled', vibrationEnabled.value);
      storage.write('likes_notifications', likesNotifications.value);
      storage.write('comments_notifications', commentsNotifications.value);
      storage.write('followers_notifications', followersNotifications.value);
      storage.write('mentions_notifications', mentionsNotifications.value);
      storage.write('live_notifications', liveNotifications.value);
      storage.write('gifts_notifications', giftsNotifications.value);
      storage.write('messages_notifications', messagesNotifications.value);
      storage.write(
          'promotional_notifications', promotionalNotifications.value);
      storage.write('updates_notifications', updatesNotifications.value);
    } catch (e) {
      print('Error saving all notification settings: $e');
    }
  }
}
