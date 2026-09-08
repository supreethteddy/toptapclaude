import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class BaseController extends FullLifeCycleController {
  RxBool isLoading = false.obs;
  static final share = BaseController();

  void showLoader({bool barrierDismissible = true}) async {
    if (isLoading.value) return;
    isLoading.value = true;
    await Get.dialog(const LoaderWidget(),
        barrierDismissible: barrierDismissible);
    isLoading.value = false;
  }

  void stopLoader() {
    if (Get.isDialogOpen == true) {
      final overlayContext =
          Get.overlayContext ?? Get.context ?? Get.key.currentContext;
      if (overlayContext != null) {
        Navigator.of(overlayContext, rootNavigator: true).pop();
      }
    }
  }

  void showSnackBar(String? title) {
    if (Get.isSnackbarOpen) {
      return;
    }

    // Only upper-case the first letter; GetX's capitalizeFirst lower-cases the
    // rest, which turned "PK" into "pk" and "LIVE" into "live".
    final raw = (title ?? '').trim();
    final message = raw.isEmpty
        ? ''
        : (raw[0].toUpperCase() + raw.substring(1)).tr;
    if (message.isEmpty) {
      return;
    }

    final getOverlayContext = Get.overlayContext;
    final overlay = getOverlayContext != null
        ? Overlay.maybeOf(getOverlayContext, rootOverlay: true)
        : null;

    if (overlay != null) {
      Get.rawSnackbar(
        backgroundColor: blackPure(getOverlayContext!),
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.all(15),
        borderRadius: 10,
        isDismissible: true,
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.TOP,
        messageText: Text(message,
            style: TextStyleCustom.outFitRegular400(
                color: whitePure(getOverlayContext),
                fontSize: 17)),
      );
      return;
    }

    final rootContext = Get.key.currentContext ?? Get.context;
    final messenger =
        rootContext != null ? ScaffoldMessenger.maybeOf(rootContext) : null;
    if (rootContext == null || messenger == null) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message,
            style: TextStyleCustom.outFitRegular400(
                color: whitePure(rootContext), fontSize: 17)),
        backgroundColor: blackPure(rootContext),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ));
  }

  void stopSnackBar() {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar().catchError((_) {});
    }
  }
}
