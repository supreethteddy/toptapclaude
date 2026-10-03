import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/manager/incoming_call_watcher.dart';
import 'package:shortzz/common/manager/live_invite_watcher.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/auth_screen/login_screen.dart';

class SettingsScreenController extends BaseController {
  Rx<User?> myUser = Rx<User?>(null);
  Rx<Setting?> settings = Rx<Setting?>(null);
  Rx<WhoCanSeePost> selectedWhoCanSeePost = WhoCanSeePost.values.first.obs;
  RxBool isUpdateApiCalled = false.obs;

  @override
  void onInit() {
    super.onInit();
    initData();
  }

  void initData() {
    myUser.value = SessionManager.instance.getUser();
    settings.value = SessionManager.instance.getSettings();
    if (myUser.value?.whoCanViewPost == 0) {
      selectedWhoCanSeePost.value = WhoCanSeePost.values.first;
    } else {
      selectedWhoCanSeePost.value = WhoCanSeePost.values[1];
    }

    // For refresh user data only
    UserService.instance.fetchUserDetails();
  }

  void onChangedWhoCanSeePost(WhoCanSeePost? value) async {
    isUpdateApiCalled.value = true;

    selectedWhoCanSeePost.value = value ?? WhoCanSeePost.values.first;
    await UserService.instance.updateUserDetails(whoCanSeePost: value?.value);
    isUpdateApiCalled.value = false;
  }

  onChangedToggle(bool value, SettingToggle settingToggle) async {
    isUpdateApiCalled.value = true;
    await UserService.instance.updateUserDetails(
        notifyPostLike:
            settingToggle == SettingToggle.notifyPostLike ? value : null,
        notifyPostComment:
            settingToggle == SettingToggle.notifyPostComment ? value : null,
        notifyFollow:
            settingToggle == SettingToggle.notifyFollow ? value : null,
        notifyMention:
            settingToggle == SettingToggle.notifyMention ? value : null,
        notifyGiftReceived:
            settingToggle == SettingToggle.notifyGiftReceived ? value : null,
        notifyChat: settingToggle == SettingToggle.notifyChat ? value : null,
        receiveMessage:
            settingToggle == SettingToggle.receiveMessage ? value : null,
        showMyFollowing:
            settingToggle == SettingToggle.showMyFollowings ? value : null);
    isUpdateApiCalled.value = false;
    // For update user value
    myUser.value = SessionManager.instance.getUser();
  }

  void onDeleteAccount() {
    Get.bottomSheet(ConfirmationSheet(
        onTap: () async {
          showLoader(barrierDismissible: true);
          StatusModel model = await UserService.instance.deleteMyAccount();
          stopLoader();
          if (model.status == true) {
            FirebaseFirestoreController.instance.deleteUser(myUser.value?.id);
            SessionManager.instance.clear();
            deleteCurrentUser();
            Get.offAll(() => const LoginScreen());
          } else {
            showSnackBar(model.message);
          }
        },
        description: LKey.deleteAccountMessage.tr,
        description2: LKey.proceedConfirmation.tr,
        title: LKey.deleteYourAccount.tr));
  }

  Future<void> deleteCurrentUser() async {
    try {
      auth.User? user = auth.FirebaseAuth.instance.currentUser;

      if (user != null) {
        await user.delete(); // Deletes the account
        print("User account deleted successfully.");
      } else {
        print("No user is signed in.");
      }
    } on auth.FirebaseAuthException catch (e) {
      stopLoader();
      if (e.code == 'requires-recent-login') {
        print('⚠️ The user must re-authenticate before deleting their account.');
        Get.snackbar(
          'Re-authentication Required'.tr,
          'Please re-authenticate to delete your account.'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.1),
          colorText: Colors.orange,
          duration: const Duration(seconds: 3),
        );
        reAuthenticateAndDelete(myUser.value?.identity ?? '');
      } else {
        print('❌ Error: ${e.message}');
        Get.snackbar(
          'Error'.tr,
          e.message ?? 'An error occurred while deleting account.'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      stopLoader();
      print('❌ Unexpected error: $e');
      Get.snackbar(
        'Error'.tr,
        'An unexpected error occurred. Please try again.'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> reAuthenticateAndDelete(String email) async {
    try {
      showLoader();
      auth.User? user = auth.FirebaseAuth.instance.currentUser;

      if (user != null) {
        String? password = SessionManager.instance.getPassword();
        if (password == null) {
          stopLoader();
          Get.snackbar(
            'Error'.tr,
            'Password not found. Please login again.'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withOpacity(0.1),
            colorText: Colors.red,
            duration: const Duration(seconds: 3),
          );
          return;
        }
        
        auth.AuthCredential credential =
            auth.EmailAuthProvider.credential(email: email, password: password);

        await user.reauthenticateWithCredential(credential);
        await user.delete();

        print("User re-authenticated and deleted.");
        Get.snackbar(
          'Success'.tr,
          'Account deleted successfully.'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withOpacity(0.1),
          colorText: Colors.green,
          duration: const Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          'Error'.tr,
          'User not found. Please login again.'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print("Error during re-authentication: $e");
      Get.snackbar(
        'Error'.tr,
        'Failed to re-authenticate. Please try again.'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
        duration: const Duration(seconds: 3),
      );
    } finally {
      stopLoader();
    }
  }

  void onLogout() {
    Get.bottomSheet(ConfirmationSheet(
      onTap: () async {
        showLoader();
        try {
          StatusModel result = await UserService.instance.logoutUser();
          if (result.status == true) {
            await GoogleSignIn().signOut();
            SessionManager.instance.clear();
            // Neither watcher checks session on its own; leaving them
            // running would ring the next account logged in on this device
            // with the previous user's calls/invites.
            IncomingCallWatcher.instance.stop();
            LiveInviteWatcher.instance.stop();
            Get.snackbar(
              'Success'.tr,
              'Logged out successfully.'.tr,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.green.withOpacity(0.1),
              colorText: Colors.green,
              duration: const Duration(seconds: 2),
            );
            Get.offAll(() => const LoginScreen());
          } else {
            Get.snackbar(
              'Error'.tr,
              result.message ?? 'Failed to logout. Please try again.'.tr,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red.withOpacity(0.1),
              colorText: Colors.red,
              duration: const Duration(seconds: 3),
            );
          }
        } catch (e) {
          print('Logout error: $e');
          Get.snackbar(
            'Error'.tr,
            'Network error occurred. Please check your connection.'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withOpacity(0.1),
            colorText: Colors.red,
            duration: const Duration(seconds: 3),
          );
        } finally {
          stopLoader();
        }
      },
      description: LKey.logoutConfirmation.tr,
      description2: LKey.proceedConfirmation.tr,
      title: LKey.logoutTitle.tr,
    ));
  }
}

enum WhoCanSeePost {
  everyone,
  followersOnly;

  String get title {
    switch (this) {
      case WhoCanSeePost.everyone:
        return LKey.everyone.tr;
      case WhoCanSeePost.followersOnly:
        return LKey.followersOnly.tr;
    }
  }

  String get value {
    switch (this) {
      case WhoCanSeePost.everyone:
        return '0';
      case WhoCanSeePost.followersOnly:
        return '1';
    }
  }
}

enum SettingToggle {
  showMyFollowings,
  receiveMessage,
  notifyPostLike,
  notifyPostComment,
  notifyFollow,
  notifyMention,
  notifyGiftReceived,
  notifyChat;
}
