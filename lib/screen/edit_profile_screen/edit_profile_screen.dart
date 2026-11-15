// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:toptap/common/extensions/string_extension.dart';
// import 'package:toptap/common/widget/custom_app_bar.dart';
// import 'package:toptap/common/widget/custom_image.dart';
// import 'package:toptap/common/widget/text_button_custom.dart';
// import 'package:toptap/common/widget/text_field_custom.dart';
// import 'package:toptap/languages/languages_keys.dart';
// import 'package:toptap/model/user_model/user_model.dart';
// import 'package:toptap/screen/edit_profile_screen/edit_profile_screen_controller.dart';
// import 'package:toptap/screen/edit_profile_screen/widget/build_link_view.dart';
// import 'package:toptap/utilities/asset_res.dart';
// import 'package:toptap/utilities/text_style_custom.dart';
// import 'package:toptap/utilities/theme_res.dart';

// class EditProfileScreen extends StatelessWidget {
//   final Function(User? user)? onUpdateUser;

//   const EditProfileScreen({super.key, this.onUpdateUser});

//   @override
//   Widget build(BuildContext context) {
//     final controller =
//         Get.put(EditProfileScreenController(onUpdateUser));
//     return Scaffold(
//       body: Column(
//         children: [
//           CustomAppBar(title: LKey.editProfile.tr),
//           Expanded(
//             child: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment:
//                     CrossAxisAlignment.start,
//                 children: [
//                   Container(
//                     height: 49,
//                     margin: const EdgeInsets.symmetric(
//                         vertical: 3),
//                     alignment:
//                         AlignmentDirectional.centerStart,
//                     color: bgLightGrey(context),
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 20),
//                     child: Text(
//                       '${LKey.userId.tr} : ${controller.userData.value?.id}',
//                       style: TextStyleCustom.outFitLight300(
//                           fontSize: 17,
//                           color: textLightGrey(context)),
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 20.0),
//                     child: Text(LKey.profileImage.tr,
//                         style: TextStyleCustom
//                             .outFitRegular400(
//                                 fontSize: 17,
//                                 color:
//                                     textDarkGrey(context))),
//                   ),
//                   Container(
//                     height: 100,
//                     width: double.infinity,
//                     margin: const EdgeInsets.only(
//                         top: 8, bottom: 12),
//                     decoration: BoxDecoration(
//                         color: bgLightGrey(context)),
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 20),
//                     alignment:
//                         AlignmentDirectional.centerStart,
//                     child: InkWell(
//                       onTap:
//                           controller.onChangeProfileImage,
//                       child: Stack(
//                         children: [
//                           Obx(
//                             () => controller
//                                         .fileProfileImage
//                                         .value !=
//                                     null
//                                 ? ClipOval(
//                                     child: Image.file(
//                                         File(controller
//                                                 .fileProfileImage
//                                                 .value
//                                                 ?.path ??
//                                             ''),
//                                         height: 86,
//                                         width: 86,
//                                         fit: BoxFit.cover))
//                                 : CustomImage(
//                                     size:
//                                         const Size(86, 86),
//                                     image: controller
//                                         .userData
//                                         .value
//                                         ?.profilePhoto
//                                         ?.addBaseURL(),
//                                     fullName: controller
//                                         .userData
//                                         .value
//                                         ?.fullname,
//                                   ),
//                           ),
//                           Positioned(
//                             right: 0,
//                             bottom: 0,
//                             child: Container(
//                               height: 26,
//                               width: 26,
//                               decoration: BoxDecoration(
//                                   color:
//                                       textDarkGrey(context),
//                                   shape: BoxShape.circle),
//                               child: Center(
//                                 child: Image.asset(
//                                     AssetRes.icEdit_1,
//                                     width: 22,
//                                     height: 22,
//                                     color:
//                                         whitePure(context)),
//                               ),
//                             ),
//                           )
//                         ],
//                       ),
//                     ),
//                   ),
//                   TextFieldCustom(
//                     controller:
//                         controller.fullNameController,
//                     title: LKey.fullName.tr,
//                   ),
//                   Obx(() {
//                     return TextFieldCustom(
//                       controller:
//                           controller.usernameController,
//                       title: LKey.username.tr,
//                       onChanged: controller
//                           .checkUsernameAvailability,
//                       isError:
//                           !controller.isValidUserName.value,
//                     );
//                   }),
//                   TextFieldCustom(
//                       controller: controller.bioController,
//                       title: LKey.bio.tr,
//                       height: 100),
//                   TextFieldCustom(
//                     controller: controller.emailController,
//                     title: LKey.email.tr,
//                     keyboardType:
//                         TextInputType.emailAddress,
//                   ),
//                   TextFieldCustom(
//                       controller:
//                           controller.phoneNumberController,
//                       title: LKey.phoneNumber.tr,
//                       isPrefixIconShow: true),
//                   BuildLinkView(controller: controller)
//                 ],
//               ),
//             ),
//           ),
//           SafeArea(
//             top: false,
//             minimum:
//                 const EdgeInsets.symmetric(vertical: 20),
//             child: TextButtonCustom(
//               onTap: controller.onSaveTap,
//               title: LKey.save.tr,
//               backgroundColor: textDarkGrey(context),
//               titleColor: adaptiveTextColor(context),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/common/widget/custom_image.dart';
import 'package:toptap/common/widget/text_button_custom.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/user_model/user_model.dart';
import 'package:toptap/screen/edit_profile_screen/edit_profile_screen_controller.dart';
import 'package:toptap/screen/edit_profile_screen/widget/build_link_view.dart';
import 'package:toptap/screen/edit_profile_screen/widget/phone_codes_screen.dart';
import 'package:toptap/screen/edit_profile_screen/widget/phone_codes_screen_controller.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/color_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class EditProfileScreen extends StatelessWidget {
  final Function(User? user)? onUpdateUser;
  final bool isProfileCompletionRequired;
  final String lockedEmail;

  const EditProfileScreen({
    super.key,
    this.onUpdateUser,
    this.isProfileCompletionRequired = false,
    this.lockedEmail = '',
  });

  @override
  Widget build(BuildContext context) {
    final controller =
        Get.put(EditProfileScreenController(
      onUpdateUser,
      isProfileCompletionRequired: isProfileCompletionRequired,
      lockedEmail: lockedEmail,
    ));
    final phoneController =
        Get.put(PhoneCodesScreenController());

    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(title: LKey.editProfile.tr),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Profile Image Section
                  _buildProfileImageSection(
                      controller, context),
                  const SizedBox(height: 32),
                  // Form Fields
                  _buildFormFields(
                      controller, phoneController, context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Save Button
          _buildSaveButton(controller, context),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection(
      EditProfileScreenController controller,
      BuildContext context) {
    return Center(
      child: Stack(
        children: [
          // Profile Image with View functionality
          GestureDetector(
            onTap: controller.onViewProfileImage,
            child: Hero(
              tag:
                  'profile_image_${controller.userData.value?.profilePhoto ?? controller.fileProfileImage.value?.path}',
              child: Obx(
                () => controller.fileProfileImage.value !=
                        null
                    ? ClipOval(
                        child: Image.file(
                          File(controller.fileProfileImage
                                  .value?.path ??
                              ''),
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                        ),
                      )
                    : CustomImage(
                        size: const Size(120, 120),
                        image: controller.userData.value
                                ?.profilePhoto
                                ?.addBaseURL() ??
                            '',
                        fullName: controller
                                .userData.value?.fullname
                                ?.toString() ??
                            '',
                      ),
              ),
            ),
          ),
          // Edit button
          Positioned(
            right: 4,
            bottom: 4,
            child: GestureDetector(
              onTap: controller.onChangeProfileImage,
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: textDarkGrey(context),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context)
                        .scaffoldBackgroundColor,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    AssetRes.icEdit_1,
                    width: 18,
                    height: 18,
                    color: whitePure(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(
      EditProfileScreenController controller,
      PhoneCodesScreenController phoneController,
      BuildContext context) {
    return Column(
      children: [
        // Full Name
        _buildEditableField(
          context,
          label: LKey.fullName.tr,
          controller: controller.fullNameController,
          hintText: LKey.fullName.tr,
        ),
        const SizedBox(height: 20),
        // Username
        _buildEditableField(
          context,
          label: LKey.username.tr,
          controller: controller.usernameController,
          hintText: LKey.username.tr,
          onChanged: controller.checkUsernameAvailability,
          isError: controller.isValidUserName,
        ),
        const SizedBox(height: 20),
        // Bio
        _buildEditableField(
          context,
          label: LKey.bio.tr,
          controller: controller.bioController,
          hintText: LKey.bio.tr,
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        // Email
        _buildEditableField(
          context,
          label: LKey.email.tr,
          controller: controller.emailController,
          hintText: LKey.email.tr,
          keyboardType: TextInputType.emailAddress,
          readOnly: true,
        ),
        const SizedBox(height: 20),
        // Phone Number with Country Code
        _buildPhoneNumberField(
          context,
          controller: controller,
          phoneController: phoneController,
        ),
        const SizedBox(height: 20),
        // Links
        _buildLinksSection(controller, context),
      ],
    );
  }

  Widget _buildPhoneNumberField(
    BuildContext context, {
    required EditProfileScreenController controller,
    required PhoneCodesScreenController phoneController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LKey.phoneNumber.tr,
          style: TextStyleCustom.outFitMedium500(
            fontSize: 14,
            color: const Color.fromRGBO(55, 224, 4, 1)
                .withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Row(
            children: [
              // Country Code Button
              GestureDetector(
                onTap: () {
                  Get.to(() => const PhoneCodesScreen());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color:
                            adaptiveBorderColor(context)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    phoneController.selectedCode.value
                            ?.phoneCode ??
                        '+1',
                    style: TextStyleCustom.outFitRegular400(
                      fontSize: 16,
                      color: adaptiveTextColor(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Phone Number Field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            adaptiveBorderColor(context)),
                  ),
                  child: TextField(
                    controller:
                        controller.phoneNumberController,
                    keyboardType: TextInputType.phone,
                    style: TextStyleCustom.outFitRegular400(
                      fontSize: 16,
                      color: adaptiveTextColor(context),
                    ),
                    decoration: InputDecoration(
                      hintText: LKey.phoneNumber.tr,
                      hintStyle:
                          TextStyleCustom.outFitRegular400(
                        fontSize: 16,
                        color: ColorRes.likeRed,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.phone,
                        color: ColorRes.likeRed,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    RxBool? isError,
    bool isPrefixIconShow = false,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyleCustom.outFitMedium500(
            fontSize: 14,
            color: const Color.fromRGBO(55, 224, 4, 1)
                .withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        isError != null
            ? Obx(() => _buildTextField(
                  context,
                  controller: controller,
                  hintText: hintText,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  isError: !isError.value,
                  isPrefixIconShow: isPrefixIconShow,
                  maxLines: maxLines,
                  readOnly: readOnly,
                ))
            : _buildTextField(
                context,
                controller: controller,
                hintText: hintText,
                keyboardType: keyboardType,
                onChanged: onChanged,
                isPrefixIconShow: isPrefixIconShow,
                maxLines: maxLines,
                readOnly: readOnly,
              ),
      ],
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    bool isError = false,
    bool isPrefixIconShow = false,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError
              ? Colors.red
              : adaptiveBorderColor(context),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: readOnly ? null : onChanged,
        maxLines: maxLines,
        readOnly: readOnly,
        style: TextStyleCustom.outFitRegular400(
          fontSize: 16,
          color: adaptiveTextColor(context),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyleCustom.outFitRegular400(
            fontSize: 16,
            color: ColorRes.likeRed,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          prefixIcon: isPrefixIconShow
              ? const Icon(
                  Icons.phone,
                  color: ColorRes.likeRed,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildLinksSection(
      EditProfileScreenController controller,
      BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LKey.links.tr,
          style: TextStyleCustom.outFitMedium500(
            fontSize: 14,
            color: ColorRes.textlightGreenColor,
          ),
        ),
        const SizedBox(height: 8),
        BuildLinkView(controller: controller),
      ],
    );
  }

  Widget _buildSaveButton(
      EditProfileScreenController controller,
      BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: TextButtonCustom(
            onTap: controller.onSaveTap,
            title: LKey.save.tr,
            backgroundColor: adaptiveBackground(context),
            titleColor: adaptiveTextColor(context),
          ),
        ),
      ),
    );
  }
}

// Good Structure for EditProfileScreen

// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:toptap/common/extensions/string_extension.dart';
// import 'package:toptap/common/widget/custom_app_bar.dart';
// import 'package:toptap/common/widget/custom_image.dart';
// import 'package:toptap/common/widget/text_button_custom.dart';
// import 'package:toptap/common/widget/text_field_custom.dart';
// import 'package:toptap/languages/languages_keys.dart';
// import 'package:toptap/model/user_model/user_model.dart';
// import 'package:toptap/screen/edit_profile_screen/edit_profile_screen_controller.dart';
// import 'package:toptap/screen/edit_profile_screen/widget/build_link_view.dart';
// import 'package:toptap/utilities/asset_res.dart';
// import 'package:toptap/utilities/color_res.dart';
// import 'package:toptap/utilities/text_style_custom.dart';
// import 'package:toptap/utilities/theme_res.dart';

// class EditProfileScreen extends StatelessWidget {
//   final Function(User? user)? onUpdateUser;

//   const EditProfileScreen({super.key, this.onUpdateUser});

//   @override
//   Widget build(BuildContext context) {
//     final controller =
//         Get.put(EditProfileScreenController(onUpdateUser));

//     return Scaffold(
//       body: Column(
//         children: [
//           CustomAppBar(title: LKey.editProfile.tr),

//           Expanded(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(
//                   horizontal: 20),
//               child: Column(
//                 children: [
//                   const SizedBox(height: 24),

//                   // Profile Image Section
//                   _buildProfileImageSection(
//                       controller, context),

//                   const SizedBox(height: 32),

//                   // Form Fields
//                   _buildFormFields(controller, context),

//                   const SizedBox(height: 32),
//                 ],
//               ),
//             ),
//           ),

//           // Save Button
//           _buildSaveButton(controller, context),
//         ],
//       ),
//     );
//   }

//   Widget _buildProfileImageSection(
//       EditProfileScreenController controller,
//       BuildContext context) {
//     return Center(
//       child: InkWell(
//         onTap: controller.onChangeProfileImage,
//         borderRadius: BorderRadius.circular(60),
//         child: Stack(
//           children: [
//             Obx(
//               () =>
//                   controller.fileProfileImage.value != null
//                       ? ClipOval(
//                           child: Image.file(
//                             File(controller.fileProfileImage
//                                     .value?.path ??
//                                 ''),
//                             height: 120,
//                             width: 120,
//                             fit: BoxFit.cover,
//                           ),
//                         )
//                       : CustomImage(
//                           size: const Size(120, 120),
//                           image: controller.userData.value
//                                   ?.profilePhoto
//                                   ?.addBaseURL() ??
//                               '',
//                           fullName: controller
//                                   .userData.value?.fullname
//                                   ?.toString() ??
//                               '',
//                         ),
//             ),
//             Positioned(
//               right: 4,
//               bottom: 4,
//               child: Container(
//                 height: 36,
//                 width: 36,
//                 decoration: BoxDecoration(
//                   color: textDarkGrey(context),
//                   shape: BoxShape.circle,
//                   border: Border.all(
//                     color: Theme.of(context)
//                         .scaffoldBackgroundColor,
//                     width: 3,
//                   ),
//                 ),
//                 child: Center(
//                   child: Image.asset(
//                     AssetRes.icEdit_1,
//                     width: 18,
//                     height: 18,
//                     color: whitePure(context),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildFormFields(
//       EditProfileScreenController controller,
//       BuildContext context) {
//     return Column(
//       children: [
//         // User ID (Read-only)
//         // _buildReadOnlyField(
//         //   context,
//         //   label: LKey.userId.tr,
//         //   value:
//         //       controller.userData.value?.id?.toString() ??
//         //           '',
//         // ),

//         // const SizedBox(height: 20),

//         // Full Name
//         _buildEditableField(
//           context,
//           label: LKey.fullName.tr,
//           controller: controller.fullNameController,
//           hintText: LKey.fullName.tr,
//         ),

//         const SizedBox(height: 20),

//         // Username
//         _buildEditableField(
//           context,
//           label: LKey.username.tr,
//           controller: controller.usernameController,
//           hintText: LKey.username.tr,
//           onChanged: controller.checkUsernameAvailability,
//           isError: controller.isValidUserName,
//         ),

//         const SizedBox(height: 20),

//         // Bio
//         _buildEditableField(
//           context,
//           label: LKey.bio.tr,
//           controller: controller.bioController,
//           hintText: LKey.bio.tr,
//           maxLines: 3,
//         ),

//         const SizedBox(height: 20),

//         // Email
//         _buildEditableField(
//           context,
//           label: LKey.email.tr,
//           controller: controller.emailController,
//           hintText: LKey.email.tr,
//           keyboardType: TextInputType.emailAddress,
//         ),

//         const SizedBox(height: 20),

//         // Phone Number
//         _buildEditableField(
//           context,
//           label: LKey.phoneNumber.tr,
//           controller: controller.phoneNumberController,
//           hintText: LKey.phoneNumber.tr,
//           isPrefixIconShow: true,
//         ),

//         const SizedBox(height: 20),

//         // Links
//         _buildLinksSection(controller, context),
//       ],
//     );
//   }

//   // Widget _buildReadOnlyField(BuildContext context,
//   //     {required String label, required String value}) {
//   //   return Column(
//   //     crossAxisAlignment: CrossAxisAlignment.start,
//   //     children: [
//   //       Text(
//   //         label,
//   //         style: TextStyleCustom.outFitMedium500(
//   //           fontSize: 14,
//   //           color: textLightGrey(context),
//   //         ),
//   //       ),
//   //       const SizedBox(height: 8),
//   //       Container(
//   //         width: double.infinity,
//   //         padding: const EdgeInsets.symmetric(
//   //             horizontal: 16, vertical: 12),
//   //         decoration: BoxDecoration(
//   //           color: textLightGrey(context).withOpacity(0.1),
//   //           borderRadius: BorderRadius.circular(8),
//   //           border: Border.all(
//   //             color:
//   //                 textLightGrey(context).withOpacity(0.3),
//   //           ),
//   //         ),
//   //         child: Text(
//   //           value,
//   //           style: TextStyleCustom.outFitRegular400(
//   //             fontSize: 16,
//   //             color: textDarkGrey(context),
//   //           ),
//   //         ),
//   //       ),
//   //     ],
//   //   );
//   // }

//   Widget _buildEditableField(
//     BuildContext context, {
//     required String label,
//     required TextEditingController controller,
//     required String hintText,
//     TextInputType? keyboardType,
//     Function(String)? onChanged,
//     RxBool? isError,
//     bool isPrefixIconShow = false,
//     int maxLines = 1,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: TextStyleCustom.outFitMedium500(
//             fontSize: 14,
//             color: const Color.fromRGBO(55, 224, 4, 1)
//                 .withOpacity(0.5),
//           ),
//         ),
//         const SizedBox(height: 8),
//         isError != null
//             ? Obx(() => _buildTextField(
//                   context,
//                   controller: controller,
//                   hintText: hintText,
//                   keyboardType: keyboardType,
//                   onChanged: onChanged,
//                   isError: !isError.value,
//                   isPrefixIconShow: isPrefixIconShow,
//                   maxLines: maxLines,
//                 ))
//             : _buildTextField(
//                 context,
//                 controller: controller,
//                 hintText: hintText,
//                 keyboardType: keyboardType,
//                 onChanged: onChanged,
//                 isPrefixIconShow: isPrefixIconShow,
//                 maxLines: maxLines,
//               ),
//       ],
//     );
//   }

//   Widget _buildTextField(
//     BuildContext context, {
//     required TextEditingController controller,
//     required String hintText,
//     TextInputType? keyboardType,
//     Function(String)? onChanged,
//     bool isError = false,
//     bool isPrefixIconShow = false,
//     int maxLines = 1,
//   }) {
//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(
//           color: isError
//               ? Colors.red
//               : adaptiveBorderColor(context),
//         ),
//       ),
//       child: TextField(
//         controller: controller,
//         keyboardType: keyboardType,
//         onChanged: onChanged,
//         maxLines: maxLines,
//         style: TextStyleCustom.outFitRegular400(
//           fontSize: 16,
//           color: adaptiveTextColor(context),
//         ),
//         decoration: InputDecoration(
//           hintText: hintText,
//           hintStyle: TextStyleCustom.outFitRegular400(
//             fontSize: 16,
//             color: ColorRes.likeRed,
//           ),
//           border: InputBorder.none,
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 12,
//           ),
//           prefixIcon: isPrefixIconShow
//               ? const Icon(
//                   Icons.phone,
//                   color: ColorRes.likeRed,
//                 )
//               : null,
//         ),
//       ),
//     );
//   }

//   Widget _buildLinksSection(
//       EditProfileScreenController controller,
//       BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           LKey.links.tr,
//           style: TextStyleCustom.outFitMedium500(
//             fontSize: 14,
//             color: ColorRes.textlightGreenColor,
//           ),
//         ),
//         const SizedBox(height: 8),
//         BuildLinkView(controller: controller),
//       ],
//     );
//   }

//   Widget _buildSaveButton(
//       EditProfileScreenController controller,
//       BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       child: SafeArea(
//         top: false,
//         child: SizedBox(
//           width: double.infinity,
//           child: TextButtonCustom(
//             onTap: controller.onSaveTap,
//             title: LKey.save.tr,
//             backgroundColor: adaptiveBackground(context),
//             titleColor: adaptiveTextColor(context),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class TextFieldCustom extends StatelessWidget {
//   final TextEditingController? controller;
//   final String title;
//   final String? hintText;
//   final double? height;
//   final bool isError;
//   final bool isPrefixIconShow;
//   final TextInputType? keyboardType;
//   final Function(String)? onChanged;
//   final InputBorder? inputBorder;

//   const TextFieldCustom({
//     super.key,
//     this.controller,
//     this.title = '',
//     this.hintText,
//     this.height,
//     this.isError = false,
//     this.isPrefixIconShow = false,
//     this.keyboardType,
//     this.onChanged,
//     this.inputBorder,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         if (title.isNotEmpty)
//           Text(
//             title,
//             style: TextStyleCustom.outFitRegular400(
//                 color: adaptiveTextColor(context),
//                 fontSize: 16),
//           ),
//         SizedBox(height: height ?? 48),
//         TextField(
//           // onTap: () {
//           //   BuildLinkView(controller: controller);
//           // },
//           controller: controller,
//           decoration: InputDecoration(
//             hintText: hintText,
//             border:
//                 inputBorder ?? const OutlineInputBorder(),
//             enabledBorder:
//                 inputBorder ?? const OutlineInputBorder(),
//             focusedBorder:
//                 inputBorder ?? const OutlineInputBorder(),
//             errorText: isError ? 'Invalid input' : null,
//             prefixIcon: isPrefixIconShow
//                 ? const Icon(Icons.phone)
//                 : null,
//           ),
//           keyboardType: keyboardType,
//           onChanged: onChanged,
//         ),
//       ],
//     );
//   }
// }

// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:toptap/common/extensions/string_extension.dart';
// import 'package:toptap/common/widget/custom_app_bar.dart';
// import 'package:toptap/common/widget/custom_image.dart';
// import 'package:toptap/common/widget/text_button_custom.dart';
// import 'package:toptap/common/widget/text_field_custom.dart';
// import 'package:toptap/languages/languages_keys.dart';
// import 'package:toptap/model/user_model/user_model.dart';
// import 'package:toptap/screen/edit_profile_screen/edit_profile_screen_controller.dart';
// import 'package:toptap/screen/edit_profile_screen/widget/build_link_view.dart';
// import 'package:toptap/utilities/asset_res.dart';
// import 'package:toptap/utilities/color_res.dart';
// import 'package:toptap/utilities/text_style_custom.dart';
// import 'package:toptap/utilities/theme_res.dart';

// class EditProfileScreen extends StatelessWidget {
//   final Function(User? user)? onUpdateUser;

//   const EditProfileScreen({super.key, this.onUpdateUser});

//   @override
//   Widget build(BuildContext context) {
//     final controller =
//         Get.put(EditProfileScreenController(onUpdateUser));

//     return Scaffold(
//       body: Column(
//         children: [
//           CustomAppBar(title: LKey.editProfile.tr),

//           // Profile Image at Top Center
//           Container(
//             margin:
//                 const EdgeInsets.symmetric(vertical: 14),
//             alignment: Alignment.center,
//             child: InkWell(
//               onTap: controller.onChangeProfileImage,
//               borderRadius: BorderRadius.circular(60),
//               child: Stack(
//                 children: [
//                   Obx(
//                     () =>
//                         controller.fileProfileImage.value !=
//                                 null
//                             ? ClipOval(
//                                 child: Image.file(
//                                   File(controller
//                                           .fileProfileImage
//                                           .value
//                                           ?.path ??
//                                       ''),
//                                   height: 120,
//                                   width: 120,
//                                   fit: BoxFit.cover,
//                                 ),
//                               )
//                             : CustomImage(
//                                 size: const Size(120, 120),
//                                 image: controller.userData
//                                         .value?.profilePhoto
//                                         ?.addBaseURL() ??
//                                     '',
//                                 fullName: controller
//                                         .userData
//                                         .value
//                                         ?.fullname
//                                         ?.toString() ??
//                                     '',
//                               ),
//                   ),
//                   Positioned(
//                     right: 4,
//                     bottom: 4,
//                     child: Container(
//                       height: 36,
//                       width: 36,
//                       decoration: BoxDecoration(
//                         color: ColorRes.textLightGrey,
//                         shape: BoxShape.circle,
//                         border: Border.all(
//                           color: adaptiveTextColor(context),
//                           width: 3,
//                         ),
//                       ),
//                       child: Center(
//                         child: Image.asset(
//                           AssetRes.icEdit_1,
//                           width: 18,
//                           height: 18,
//                           color: adaptiveTextColor(context),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           // Side-by-Side Layout
//           Expanded(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(
//                   horizontal: 20),
//               child: Column(
//                 children: [
//                   // User ID
//                   // _buildFormRow(
//                   //   context,
//                   //   label: '${LKey.userId.tr}:',
//                   //   child: Container(
//                   //     alignment: Alignment.centerLeft,
//                   //     height: 48,
//                   //     child: Text(
//                   //       controller.userData.value?.id
//                   //               ?.toString() ??
//                   //           '',
//                   //       style: TextStyleCustom
//                   //           .outFitRegular400(
//                   //         fontSize: 16,
//                   //         color: textDarkGrey(context),
//                   //       ),
//                   //     ),
//                   //   ),
//                   // ),

//                   // const SizedBox(height: 16),

//                   // Full Name
//                   _buildFormRow(
//                     context,
//                     label: LKey.fullName.tr,
//                     child: TextFieldCustom(
//                       controller:
//                           controller.fullNameController,
//                       title: '',
//                       hintText: LKey.fullName.tr,
//                       inputBorder:
//                           _buildInputBorder(context),
//                     ),
//                   ),

//                   const SizedBox(height: 16),

//                   // Username
//                   _buildFormRow(
//                     context,
//                     label: LKey.username.tr,
//                     child: Obx(() {
//                       return TextFieldCustom(
//                         controller:
//                             controller.usernameController,
//                         title: '',
//                         hintText: LKey.username.tr,
//                         onChanged: controller
//                             .checkUsernameAvailability,
//                         isError: !controller
//                             .isValidUserName.value,
//                         inputBorder: _buildInputBorder(
//                             context,
//                             isError: !controller
//                                 .isValidUserName.value),
//                       );
//                     }),
//                   ),

//                   const SizedBox(height: 16),

//                   // Bio
//                   _buildFormRow(
//                     context,
//                     label: LKey.bio.tr,
//                     child: TextFieldCustom(
//                       controller: controller.bioController,
//                       title: '',
//                       hintText: LKey.bio.tr,
//                       height: 80,
//                       inputBorder:
//                           _buildInputBorder(context),
//                     ),
//                   ),

//                   const SizedBox(height: 16),

//                   // Email
//                   _buildFormRow(
//                     context,
//                     label: LKey.email.tr,
//                     child: TextFieldCustom(
//                       controller:
//                           controller.emailController,
//                       title: '',
//                       hintText: LKey.email.tr,
//                       keyboardType:
//                           TextInputType.emailAddress,
//                       inputBorder:
//                           _buildInputBorder(context),
//                     ),
//                   ),

//                   const SizedBox(height: 10),

//                   // Phone Number
//                   _buildFormRow(
//                     context,
//                     label: LKey.phoneNumber.tr,
//                     child: TextFieldCustom(
//                       controller:
//                           controller.phoneNumberController,
//                       title: '',
//                       hintText: LKey.phoneNumber.tr,
//                       isPrefixIconShow: true,
//                       inputBorder:
//                           _buildInputBorder(context),
//                     ),
//                   ),

//                   const SizedBox(height: 16),

//                   // Links
//                   _buildFormRow(
//                     context,
//                     label: LKey.links.tr,
//                     child: BuildLinkView(
//                         controller: controller),
//                     crossAxisAlignment:
//                         CrossAxisAlignment.start,
//                   ),

//                   const SizedBox(height: 32),
//                 ],
//               ),
//             ),
//           ),

//           // Save Button
//           Container(
//             padding: const EdgeInsets.all(20),
//             child: SafeArea(
//               top: false,
//               child: SizedBox(
//                 width: double.infinity,
//                 child: TextButtonCustom(
//                   onTap: controller.onSaveTap,
//                   title: LKey.save.tr,
//                   backgroundColor:
//                       adaptiveBackground(context),
//                   titleColor: adaptiveTextColor(context),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFormRow(
//     BuildContext context, {
//     required String label,
//     required Widget child,
//     CrossAxisAlignment crossAxisAlignment =
//         CrossAxisAlignment.center,
//   }) {
//     return Row(
//       crossAxisAlignment: crossAxisAlignment,
//       children: [
//         // Left side - Label
//         SizedBox(
//           width: MediaQuery.of(context).size.width * 0.3,
//           child: Text(
//             label,
//             style: TextStyleCustom.outFitMedium500(
//               fontSize: 14,
//               color: ColorRes.textlightGreenColor,
//             ),
//           ),
//         ),

//         const SizedBox(width: 16),

//         // Right side - Editable field
//         Expanded(child: child),
//       ],
//     );
//   }

//   InputBorder _buildInputBorder(BuildContext context,
//       {bool isError = false}) {
//     return OutlineInputBorder(
//       borderRadius: BorderRadius.circular(8),
//       borderSide: BorderSide(
//         color: isError
//             ? Colors.red
//             : adaptiveBorderColor(context),
//         width: 1,
//       ),
//     );
//   }
// }

// class TextFieldCustom extends StatelessWidget {
//   final TextEditingController? controller;
//   final String title;
//   final String? hintText;
//   final double? height;
//   final bool isError;
//   final bool isPrefixIconShow;
//   final TextInputType? keyboardType;
//   final Function(String)? onChanged;
//   final InputBorder? inputBorder;

//   const TextFieldCustom({
//     super.key,
//     this.controller,
//     this.title = '',
//     this.hintText,
//     this.height,
//     this.isError = false,
//     this.isPrefixIconShow = false,
//     this.keyboardType,
//     this.onChanged,
//     this.inputBorder,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         if (title.isNotEmpty)
//           Text(
//             title,
//             style: TextStyleCustom.outFitRegular400(
//                 fontSize: 16),
//           ),
//         SizedBox(height: height ?? 48),
//         TextField(
//           controller: controller,
//           keyboardType: keyboardType,
//           onChanged: onChanged,
//           maxLines:
//               height != null && height! > 48 ? null : 1,
//           style: TextStyleCustom.outFitRegular400(
//             fontSize: 16,
//             color: adaptiveTextColor(context),
//           ),
//           decoration: InputDecoration(
//             hintText: hintText,
//             hintStyle: TextStyleCustom.outFitRegular400(
//               fontSize: 16,
//               color: textLightGrey(context),
//             ),
//             border:
//                 inputBorder ?? const OutlineInputBorder(),
//             enabledBorder:
//                 inputBorder ?? const OutlineInputBorder(),
//             focusedBorder:
//                 inputBorder ?? const OutlineInputBorder(),
//             errorBorder:
//                 inputBorder ?? const OutlineInputBorder(),
//             focusedErrorBorder:
//                 inputBorder ?? const OutlineInputBorder(),
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: 16,
//               vertical: 12,
//             ),
//             prefixIcon: isPrefixIconShow
//                 ? Icon(
//                     Icons.phone,
//                     color: textLightGrey(context),
//                   )
//                 : null,
//           ),
//         ),
//       ],
//     );
//   }
// }
