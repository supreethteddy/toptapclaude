import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:toptap/common/manager/firebase_notification_manager.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/service/api/api_service.dart';
import 'package:toptap/common/service/utils/params.dart';
import 'package:toptap/common/service/utils/web_service.dart';
import 'package:toptap/model/misc/activity_notification_model.dart';
import 'package:toptap/model/misc/admin_notification_model.dart';
import 'package:toptap/utilities/app_res.dart';
import 'package:toptap/utilities/const_res.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  Future<List<AdminNotificationData>> fetchAdminNotifications({
    int? lastItemId,
  }) async {
    AdminNotificationModel response = await ApiService.instance.call(
      url: WebService.notification.fetchAdminNotifications,
      fromJson: AdminNotificationModel.fromJson,
      param: {
        Params.limit: AppRes.paginationLimit,
        Params.lastItemId: lastItemId,
      },
    );
    if (response.status == true) {
      return response.data ?? [];
    }
    return [];
  }

  Future<List<ActivityNotification>> fetchActivityNotifications({
    int? lastItemId,
  }) async {
    ActivityNotificationModel response = await ApiService.instance.call(
      url: WebService.notification.fetchActivityNotifications,
      fromJson: ActivityNotificationModel.fromJson,
      param: {
        Params.limit: AppRes.paginationLimit,
        Params.lastItemId: lastItemId,
      },
    );
    if (response.status == true) {
      return response.data ?? [];
    } else {
      return [];
    }
  }

  Future<bool> pushNotification({
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? token,
    String? topic,
    num? deviceType,
    String? authorizationToken,
  }) async {
    bool isIOS = deviceType == 1;

    Map<String, dynamic> messageData = {
      "apns": {
        "headers": {
          "apns-priority": "10",
          //  Required for visible alerts
          // "apns-priority": "5" // Used only for silent background notifications
        },
        "payload": {
          "aps": {
            "sound": "default",
            "content-available": 1,
            if (type == NotificationType.call) ...{
              "alert": {"title": title, "body": body},
              "category": "incoming_call",
            },
          },
        },
      },
      "data": {
        "title": title,
        "body": body,
        'type': type.type,
        if (data != null) "notification_data": jsonEncode(data),
      },
    };
    if (!isIOS && type != NotificationType.call) {
      messageData["notification"] = {"body": body, "title": title};
    }
    if (!isIOS && type == NotificationType.call) {
      messageData["android"] = {"priority": "high", "ttl": "45s"};
    }
    if (token != null) {
      messageData["token"] = token;
    }
    if (topic != null) {
      messageData["topic"] = topic;
    }

    Map<String, dynamic> inputData = {"message": messageData};
    try {
      http.Response response = await http.post(
        Uri.parse(WebService.notification.pushNotificationToSingleUser),
        headers: {
          Params.apikey: apiKey,
          Params.authToken:
              authorizationToken ?? SessionManager.instance.getAuthToken(),
        },
        body: json.encode(inputData),
      );
      Loggers.success('Notification response : ${response.body}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        Loggers.error(
          'Notification push failed with status: ${response.statusCode}',
        );
        return false;
      }

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final result = decoded['result'];
          if (result == true) {
            return true;
          }
          Loggers.error(
            'Notification push API returned unsuccessful result: $result',
          );
          return false;
        }
      } catch (_) {
        // Some environments may return non-JSON content; treat HTTP success as success.
        return true;
      }

      return true;
    } catch (e) {
      Loggers.error(e);
      return false;
    }
  }
}
