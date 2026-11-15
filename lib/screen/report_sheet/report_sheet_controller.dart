import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/controller/base_controller.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/service/api/post_service.dart';
import 'package:toptap/common/service/api/user_service.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/general/settings_model.dart';
import 'package:toptap/model/general/status_model.dart';
import 'package:toptap/screen/report_sheet/report_sheet.dart';

class ReportSheetController extends BaseController {
  List<ReportReason> reports =
      SessionManager.instance.getSettings()?.reportReason ?? [];
  Rx<ReportReason?> selectedValue = Rx(null);
  int reportId;
  ReportType reportType;

  TextEditingController descriptionController = TextEditingController();

  ReportSheetController(this.reportId, this.reportType);

  @override
  void onReady() {
    super.onReady();
    selectedValue.value = reports.isNotEmpty ? reports.first : null;
  }

  void onReportSubmit() {
    if (descriptionController.text.isEmpty) {
      return showSnackBar(LKey.provideReportReason.tr);
    }
    if (reportId == -1) {
      return Loggers.error('Invalid Post Id : $reportId');
    }
    if (reportType == ReportType.post) {
      _reportPost();
    } else {
      _reportUser();
    }
  }

  void _reportPost() async {
    showLoader();
    try {
      StatusModel model = await PostService.instance.reportPost(
          postId: reportId,
          reason: selectedValue.value?.title ?? '',
          description: descriptionController.text.trim());

      if (Get.isBottomSheetOpen == true) {
        Get.back();
      }
      if (model.status == true) {
        showSnackBar(LKey.reportSubmitted.tr);
      } else {
        showSnackBar(model.message?.tr.capitalizeFirst);
      }
    } catch (e) {
      Loggers.error('Report post failed: $e');
      showSnackBar(LKey.somethingWentWrong.tr);
    } finally {
      stopLoader();
    }
  }

  void _reportUser() async {
    showLoader();
    try {
      StatusModel model = await UserService.instance.reportPost(
          userId: reportId,
          reason: selectedValue.value?.title ?? '',
          description: descriptionController.text.trim());

      if (Get.isBottomSheetOpen == true) {
        Get.back();
      }
      if (model.status == true) {
        showSnackBar(LKey.reportSubmitted.tr);
      } else {
        showSnackBar(model.message?.tr.capitalizeFirst);
      }
    } catch (e) {
      Loggers.error('Report user failed: $e');
      showSnackBar(LKey.somethingWentWrong.tr);
    } finally {
      stopLoader();
    }
  }
}
