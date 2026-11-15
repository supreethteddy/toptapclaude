import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toptap/common/controller/base_controller.dart';
import 'package:toptap/common/manager/branch_io_manager.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/manager/screenshot_manager.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/model/user_model/user_model.dart';

class QrCodeScreenController extends BaseController {
  final GlobalKey screenshotKey = GlobalKey();
  Rx<User?> myUser = Rx(null);
  RxString branchLink = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUserDetail();
  }

  /// Save screenshot to gallery
  Future<void> saveGalleryImage(String type) async {
    XFile? image = await ScreenshotManager.captureScreenshot(screenshotKey);
    if (image == null) {
      Loggers.error('❌ Failed to capture screenshot.');
      return;
    }
    if (type == 'save') {
      try {
        await Gal.putImage(image.path);
        showSnackBar('Image saved successfully.');
        Loggers.success('✅ Image saved at: ');
      } on GalException catch (e) {
        Loggers.error('❌ Failed to save image.$e');
        showSnackBar(e.type.message);
      }
    } else {
      final params = ShareParams(
        files: [XFile(image.path)],
        title: BranchIoManager.instance.getUserTitle(
            fullname: myUser.value?.fullname ?? '',
            username: myUser.value?.username ?? ''),
      );
      try {
        final result = await SharePlus.instance.share(params);
        if (result.status == ShareResultStatus.success) {
          print('Thank you for sharing the picture!');
        }
      } catch (e) {
        Loggers.error('❌ Failed to save image.$e');
      }
    }
  }

  Future<void> fetchUserDetail() async {
    myUser.value = SessionManager.instance.getUser();
    CustomBranchResponse? response = await BranchIoManager.instance
        .generateLink(type: ShareBranchType.user, user: myUser.value);

    if (response != null) {
      branchLink.value = response.link;
    }
  }
}
