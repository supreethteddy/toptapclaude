import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/user_model/links_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/edit_profile_screen/widget/add_edit_link_sheet.dart';
import 'package:shortzz/screen/edit_profile_screen/widget/phone_codes_screen_controller.dart';
import 'package:shortzz/screen/edit_profile_screen/widget/profile_image_picker_sheet.dart';
import 'package:shortzz/screen/feed_screen/feed_screen_controller.dart';
import 'package:shortzz/screen/edit_profile_screen/widget/profile_image_viewer.dart';

class EditProfileScreenController extends BaseController {
  final phoneController =
      Get.put(PhoneCodesScreenController());
  RxList<Link> links = <Link>[].obs;
  Rx<User?> userData = Rx(null);
  Rx<XFile?> fileProfileImage = Rx(null);
  Map<String, bool> usernameCache =
      {}; // Cache for username availability
  Timer? _debounce;
  RxBool isValidUserName = true.obs;
  TextEditingController fullNameController =
      TextEditingController();
  TextEditingController usernameController =
      TextEditingController();
  TextEditingController bioController =
      TextEditingController();
  TextEditingController emailController =
      TextEditingController();
  TextEditingController phoneNumberController =
      TextEditingController();

  Setting? get setting =>
      SessionManager.instance.getSettings();

  Function(User? user)? onUpdateUser;
  final bool isProfileCompletionRequired;
  final String lockedEmail;

  EditProfileScreenController(
    this.onUpdateUser, {
    this.isProfileCompletionRequired = false,
    this.lockedEmail = '',
  });

  @override
  void onInit() {
    super.onInit();
    initUserData();
  }

  @override
  void onClose() {
    super.onClose();
    _debounce?.cancel();
  }

  void initUserData() async {
    userData.value = SessionManager.instance.getUser();
    final resolvedEmail = _resolveLockedEmail();

    fullNameController = TextEditingController(
        text: userData.value?.fullname ?? '');
    usernameController = TextEditingController(
        text: userData.value?.username ?? '');
    bioController = TextEditingController(
        text: userData.value?.bio ?? '');
    emailController = TextEditingController(
        text: resolvedEmail);
    phoneNumberController = TextEditingController(
        text: userData.value?.userMobileNo);
    links.value = userData.value?.links ?? [];

    if (resolvedEmail.isNotEmpty &&
        (userData.value?.userEmail?.trim().isEmpty ?? true)) {
      userData.value = userData.value?.copyWith(
        userEmail: resolvedEmail,
      );
      SessionManager.instance.setUser(userData.value);
    }
  }

  String _resolveLockedEmail() {
    final passedEmail = lockedEmail.trim();
    if (GetUtils.isEmail(passedEmail)) return passedEmail;

    final profileEmail = userData.value?.userEmail?.trim() ?? '';
    if (GetUtils.isEmail(profileEmail)) return profileEmail;

    final identity = userData.value?.identity?.trim() ?? '';
    if (GetUtils.isEmail(identity)) return identity;

    final firebaseEmail =
        auth.FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
    if (GetUtils.isEmail(firebaseEmail)) return firebaseEmail;

    return '';
  }

  void onChangeProfileImage() {
    // Show profile image picker sheet with camera and gallery options
    Get.bottomSheet(
      ProfileImagePickerSheet(
        onImageSelected: (XFile selectedFile) async {
          try {
            // Clean up previous image file if it exists
            if (fileProfileImage.value != null) {
              final previousFile =
                  File(fileProfileImage.value!.path);
              if (await previousFile.exists()) {
                await previousFile.delete();
                Loggers.info(
                    '🗑️ Previous image file deleted');
              }
            }

            // Set the new image file
            fileProfileImage.value = selectedFile;

            // Log file size for debugging
            final fileSize = await selectedFile.length();
            Loggers.info(
                "✅ Selected image size: ${(fileSize / 1024).toStringAsFixed(2)} KB");

            // Provide user feedback
            Get.snackbar(
              'Image Selected',
              'Profile image updated successfully',
              duration: const Duration(seconds: 2),
              backgroundColor:
                  Colors.green.withOpacity(0.8),
              colorText: Colors.white,
            );
          } catch (e) {
            Loggers.error(
                '❌ Error handling selected image: $e');
            Get.snackbar(
              'Error',
              'Failed to process selected image',
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red.withOpacity(0.8),
              colorText: Colors.white,
            );
          }
        },
      ),
      isScrollControlled: true,
    );
  }

  void onViewProfileImage() {
    // Check if there's a local image file or network image to show
    if (fileProfileImage.value != null) {
      // Show local image file
      Get.to(
        () => ProfileImageViewer(
          localImageFile: fileProfileImage.value,
          fullName: userData.value?.fullname,
        ),
        transition: Transition.fade,
        duration: const Duration(milliseconds: 300),
      );
    } else if (userData.value?.profilePhoto != null &&
        userData.value!.profilePhoto!.isNotEmpty) {
      // Show network image
      Get.to(
        () => ProfileImageViewer(
          networkImageUrl: userData.value?.profilePhoto,
          fullName: userData.value?.fullname,
        ),
        transition: Transition.fade,
        duration: const Duration(milliseconds: 300),
      );
    } else {
      // No image to show
      Get.snackbar(
        'No Image',
        'No profile image to display',
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.grey.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  void onSaveTap() async {
    if (fullNameController.text.trim().isEmpty) {
      return showSnackBar(LKey.fullNameEmpty.tr);
    }
    // Nickname/username is optional at sign-up (client spec: settable now
    // or later) -- only validate format/availability when the user
    // actually chose one. An empty field here means "keep the
    // backend-assigned default username", never "blank it out" -- see the
    // userName: null guard below, since the backend unconditionally
    // overwrites on any non-null value, even an empty string.
    if (usernameController.text.trim().isNotEmpty &&
        !isValidUserName.value) {
      return showSnackBar(LKey.validUsernameEmpty.tr);
    }
    // Bio, email, phone number and profile picture are all optional at
    // sign-up too (client spec) -- only full name blocks initial
    // registration; everything else is completable later from here.

    showLoader();

    User? updatedUser =
        await UserService.instance.updateUserDetails(
      fullname: fullNameController.text.trim(),
      userName: usernameController.text.trim().isEmpty
          ? null
          : usernameController.text.trim(),
      bio: bioController.text.trim(),
      email: emailController.text.trim(),
      profilePhoto: fileProfileImage.value,
      phoneNumber: phoneNumberController.text.trim(),
      // selectedCode can still be null here now that phone number is no
      // longer a required field reached only after its async country-code
      // lookup settles -- guard the crash, same as country/countryCode
      // below already do.
      mobileCountryCode:
          phoneController.selectedCode.value != null
              ? int.parse(phoneController
                  .selectedCode.value!.phoneCode
                  .replaceAll('+', ''))
              : null,
      country:
          phoneController.selectedCode.value?.countryName,
      countryCode:
          phoneController.selectedCode.value?.countryCode,
    );

    stopLoader();

    if (updatedUser == null) return;

    userData.value = updatedUser; // ✅ update observable
    onUpdateUser?.call(updatedUser); // ✅ notify caller

    if (Get.isRegistered<FeedScreenController>()) {
      final controller = Get.find<FeedScreenController>();
      controller.myUser.value = updatedUser;
    }

    // Clean up temporary image file
    if (fileProfileImage.value != null) {
      try {
        final tempFile = File(fileProfileImage.value!.path);
        if (await tempFile.exists()) {
          await tempFile.delete();
          Loggers.info(
              '🗑️ Temporary image file cleaned up');
        }
      } catch (e) {
        Loggers.warning(
            '⚠️ Failed to clean up temporary file: $e');
      }
    }

    // isProfileCompletionRequired's caller navigates away itself via
    // onUpdateUser (now always satisfied once full name is set, see
    // ProfileCompletionHelper) -- this screen was reached via Get.offAll,
    // so there's nothing behind it to pop back to.
    if (!isProfileCompletionRequired) {
      Get.back();
    }
  }

  // void onSaveTap() async {
  //   if (fullNameController.text.trim().isEmpty) {
  //     return showSnackBar(LKey.fullNameEmpty.tr);
  //   }
  //   if (usernameController.text.trim().isEmpty) {
  //     return showSnackBar(LKey.usernameEmpty.tr);
  //   }
  //   if (!isValidUserName.value) {
  //     return showSnackBar(LKey.validUsernameEmpty.tr);
  //   }
  //   showLoader();
  //   User? updateUserData = await UserService.instance.updateUserDetails(
  //       fullname: fullNameController.text.trim(),
  //       userName: usernameController.text.trim(),
  //       bio: bioController.text.trim(),
  //       email: emailController.text.trim(),
  //       profilePhoto: fileProfileImage.value,
  //       phoneNumber: phoneNumberController.text.trim(),
  //       mobileCountryCode: int.parse(
  //           phoneController.selectedCode.value!.phoneCode.replaceAll('+', '')),
  //       country: phoneController.selectedCode.value?.countryName,
  //       countryCode: phoneController.selectedCode.value?.countryCode);
  //   stopLoader();
  //   if (userData == null) return;
  //   onUpdateUser?.call(updateUserData);
  //   if (Get.isRegistered<FeedScreenController>()) {
  //     final controller = Get.find<FeedScreenController>();
  //     controller.myUser.value =   updateUserData;
  //   }
  //   if (fileProfileImage.value != null) {
  //     File(fileProfileImage.value?.path ?? '').delete();
  //   }
  //   Get.back();
  // }

  void checkUsernameAvailability(String value) {
    final username =
        value.trim(); // Use passed value and trim it once

    // Validate for spaces
    if (username.contains(' ')) {
      isValidUserName.value = false;
      return;
    }

    // Check cache first
    if (usernameCache.containsKey(username)) {
      isValidUserName.value = usernameCache[username]!;
      return;
    }

    // Check against the current user's username
    final currentUser =
        SessionManager.instance.getUser()?.username;
    if (username.isNotEmpty &&
        currentUser?.toLowerCase() ==
            username.toLowerCase()) {
      isValidUserName.value = true;
      usernameCache[username] = true; // Cache the result
      return;
    }
    if (!GetUtils.isUsername(username)) {
      isValidUserName.value = true;
      return;
    }

    // Handle debounce
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 500), () async {
      final model = await UserService.instance
          .checkUsernameAvailability(userName: username);
      final isAvailable = model.status ?? true;
      isValidUserName.value = isAvailable;
      usernameCache[username] =
          isAvailable; // Cache the result
    });
  }

  onLinkAddEditDelete(Link link, LinkType type) {
    switch (type) {
      case LinkType.add:
        links.add(link);
      case LinkType.edit:
        links[links.indexWhere(
            (element) => element.id == link.id)] = link;
      case LinkType.delete:
        links.removeWhere(
            (element) => element.id == link.id);
    }
    userData.value?.links = links;
    onUpdateUser?.call(userData.value);
  }

  void handleLinkAction(LinkType value, Link link) {
    switch (value) {
      case LinkType.edit:
        Get.bottomSheet(
            AddEditLinksSheet(
                onLinksUpdate: (link) {
                  onLinkAddEditDelete(link, LinkType.edit);
                },
                type: LinkType.edit,
                link: link),
            isScrollControlled: true);
      case LinkType.delete:
        Get.bottomSheet(
            ConfirmationSheet(
              title: LKey.deleteLinkTitle.tr,
              description: LKey.deleteLinkDescription.tr,
              onTap: () async {
                showLoader();
                LinksModel value = await UserService
                    .instance
                    .addEditDeleteUserLink(
                        linkType: LinkType.delete,
                        linkId: link.id?.toInt());
                stopLoader();
                if (value.status ?? false) {
                  onLinkAddEditDelete(
                      link, LinkType.delete);
                }
                // ApiService
              },
            ),
            isScrollControlled: true);
      case LinkType.add:
    }
  }

  void openAddEditLinkSheet() {
    int limit = setting?.maxUserLinks ?? 0;
    if (links.length >= limit) {
      return showSnackBar(LKey.maxUserLinkAddDescription
          .trParams({'limit': limit.toString()}));
    }
    Get.bottomSheet(
        AddEditLinksSheet(
            onLinksUpdate: (link) =>
                onLinkAddEditDelete(link, LinkType.add),
            type: LinkType.add),
        isScrollControlled: true);
  }
}
