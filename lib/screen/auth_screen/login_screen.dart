// import 'dart:io';

// import 'package:figma_squircle_updated/figma_squircle.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shortzz/common/widget/custom_divider.dart';
// import 'package:shortzz/common/widget/privacy_policy_text.dart';
// import 'package:shortzz/common/widget/text_button_custom.dart';
// import 'package:shortzz/common/widget/theme_blur_bg.dart';
// import 'package:shortzz/languages/languages_keys.dart';
// import 'package:shortzz/screen/auth_screen/auth_screen_controller.dart';
// import 'package:shortzz/screen/auth_screen/forget_password_sheet.dart';
// import 'package:shortzz/screen/auth_screen/registration_screen.dart';
// import 'package:shortzz/utilities/asset_res.dart';
// import 'package:shortzz/utilities/text_style_custom.dart';
// import 'package:shortzz/utilities/theme_res.dart';

// class LoginScreen extends StatelessWidget {
//   const LoginScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final controller = Get.put(AuthScreenController());
//     return Scaffold(
//       resizeToAvoidBottomInset: false,
//       body: Container(
//         height: Get.height,
//         decoration: const ShapeDecoration(
//             shape: SmoothRectangleBorder(
//           borderRadius: SmoothBorderRadius.vertical(
//               top: SmoothRadius(
//                   cornerRadius: 0, cornerSmoothing: 1)),
//         )),
//         child: Stack(
//           children: [
//             const ThemeBlurBg(),
//             SingleChildScrollView(
//               child: SafeArea(
//                 bottom: false,
//                 child: Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.only(
//                           left: 20, right: 20, top: 30),
//                       child: Column(
//                         children: [
//                           Padding(
//                             padding: const EdgeInsets.only(
//                                 top: 30.0),
//                             child: RichText(
//                                 textAlign: TextAlign.center,
//                                 text: TextSpan(
//                                   text: LKey.signIn.tr
//                                       .toUpperCase(),
//                                   style: TextStyleCustom
//                                       .unboundedBlack900(
//                                     fontSize: 25,
//                                     color:
//                                         whitePure(context),
//                                   ).copyWith(
//                                       letterSpacing: -.2),
//                                   children: [
//                                     TextSpan(
//                                         text: '\n${LKey.toContinue.tr}'
//                                             .toUpperCase(),
//                                         style: TextStyleCustom.unboundedBlack900(
//                                             fontSize: 25,
//                                             color: whitePure(
//                                                     context)
//                                                 .withValues(
//                                                     alpha:
//                                                         .5),
//                                             opacity: .5))
//                                   ],
//                                 )),
//                           ),
//                           const SizedBox(height: 50 * 1.5),
//                           LoginSheetTextField(
//                             labelText: LKey.email.tr,
//                             hintText:
//                                 LKey.enterYourEmail.tr,
//                             controller:
//                                 controller.emailController,
//                             keyboardType:
//                                 TextInputType.emailAddress,
//                           ),
//                           const SizedBox(height: 14),
//                           LoginSheetTextField(
//                             isPasswordField: true,
//                             hintText: LKey.enterPassword.tr,
//                             controller: controller
//                                 .passwordController,
//                           ),
//                           Align(
//                             alignment: AlignmentDirectional
//                                 .centerEnd,
//                             child: InkWell(
//                               onTap: () {
//                                 Get.bottomSheet(
//                                         const ForgetPasswordSheet(),
//                                         isScrollControlled:
//                                             true)
//                                     .then((value) => controller
//                                         .forgetEmailController
//                                         .clear());
//                               },
//                               child: Padding(
//                                   padding: const EdgeInsets
//                                       .symmetric(
//                                       vertical: 14.0),
//                                   child: Text(
//                                       LKey.forgetPassword
//                                           .tr,
//                                       style: TextStyleCustom
//                                           .outFitRegular400(
//                                               fontSize: 16,
//                                               color: whitePure(
//                                                   context)))),
//                             ),
//                           ),
//                           TextButtonCustom(
//                               onTap: controller.onLogin,
//                               title: LKey.logIn.tr,
//                               btnHeight: 50,
//                               horizontalMargin: 0)
//                         ],
//                       ),
//                     ),
//                     InkWell(
//                       onTap: () {
//                         controller.fullNameController
//                             .clear();
//                         controller.emailController.clear();
//                         controller.passwordController
//                             .clear();
//                         controller.confirmPassController
//                             .clear();
//                         Get.to(() =>
//                             const RegistrationScreen());
//                       },
//                       child: Container(
//                         height: 48,
//                         margin: const EdgeInsets.symmetric(
//                             vertical: 25),
//                         alignment: Alignment.center,
//                         color: whitePure(context)
//                             .withValues(alpha: .2),
//                         child: Text(
//                           LKey.createAccountHere.tr,
//                           style: TextStyleCustom
//                               .outFitRegular400(
//                                   color: whitePure(context),
//                                   fontSize: 16),
//                         ),
//                       ),
//                     ),
//                     Row(
//                       mainAxisAlignment:
//                           MainAxisAlignment.center,
//                       children: [
//                         CustomDivider(
//                           color: whitePure(context),
//                           height: .5,
//                           width: 100,
//                         ),
//                         Padding(
//                           padding:
//                               const EdgeInsets.symmetric(
//                                   horizontal: 15.0),
//                           child: Text(
//                             LKey.continueWith.tr,
//                             style: TextStyleCustom
//                                 .outFitRegular400(
//                                     fontSize: 16,
//                                     color:
//                                         whitePure(context)),
//                           ),
//                         ),
//                         CustomDivider(
//                           color: whitePure(context),
//                           height: .5,
//                           width: 100,
//                         ),
//                       ],
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.symmetric(
//                           vertical: 25.0),
//                       child: Row(
//                         mainAxisAlignment:
//                             MainAxisAlignment.center,
//                         children: [
//                           if (Platform.isIOS)
//                             SocialBtn(
//                               onTap: controller.onAppleTap,
//                               icon: AssetRes.icApple,
//                             ),
//                           if (Platform.isIOS)
//                             const SizedBox(width: 10),
//                           SocialBtn(
//                               onTap: controller.onGoogleTap,
//                               icon: AssetRes.icGoogle),
//                         ],
//                       ),
//                     ),
//                     PrivacyPolicyText(
//                       boldTextColor: whitePure(context),
//                       regularTextColor: whitePure(context)
//                           .withValues(alpha: .8),
//                     )
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class LoginSheetTextField extends StatefulWidget {
//   final bool isPasswordField;
//   final String? labelText;
//   final String hintText;
//   final TextEditingController controller;
//   final TextInputType? keyboardType;

//   const LoginSheetTextField(
//       {super.key,
//       this.labelText,
//       this.isPasswordField = false,
//       required this.hintText,
//       required this.controller,
//       this.keyboardType});

//   @override
//   State<LoginSheetTextField> createState() =>
//       _LoginSheetTextFieldState();
// }

// class _LoginSheetTextFieldState
//     extends State<LoginSheetTextField> {
//   bool isHide = true;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: ShapeDecoration(
//           shape: SmoothRectangleBorder(
//             borderRadius: SmoothBorderRadius(
//                 cornerRadius: 10, cornerSmoothing: 1),
//             side: BorderSide(
//                 color: whitePure(context)
//                     .withValues(alpha: .4)),
//             borderAlign: BorderAlign.inside,
//           ),
//           color: whitePure(context).withValues(alpha: .1)),
//       child: TextField(
//         controller: widget.controller,
//         style: TextStyleCustom.outFitRegular400(
//             color: whitePure(context), fontSize: 16),
//         onTapOutside: (event) =>
//             FocusManager.instance.primaryFocus?.unfocus(),
//         obscureText: widget.isPasswordField && isHide,
//         keyboardType:
//             widget.keyboardType ?? TextInputType.text,
//         decoration: InputDecoration(
//           border: InputBorder.none,
//           hintText: widget.hintText,
//           hintStyle: TextStyleCustom.outFitRegular400(
//               color: whitePure(context), fontSize: 16),
//           contentPadding: EdgeInsets.only(
//               left: 10,
//               right: 10,
//               top: widget.isPasswordField ? 2 : 0),
//           suffixIconConstraints: const BoxConstraints(),
//           suffixIcon: widget.isPasswordField
//               ? InkWell(
//                   onTap: () {
//                     isHide = !isHide;
//                     setState(() {});
//                   },
//                   child: AnimatedSwitcher(
//                     duration:
//                         const Duration(milliseconds: 250),
//                     child: Image.asset(
//                         isHide
//                             ? AssetRes.icEye
//                             : AssetRes.icHideEye,
//                         height: 24,
//                         width: 35,
//                         color: whitePure(context),
//                         key: UniqueKey()),
//                   ),
//                 )
//               : null,
//         ),
//         cursorColor: whitePure(context),
//       ),
//     );
//   }
// }

// class SocialBtn extends StatelessWidget {
//   final String icon;
//   final VoidCallback onTap;

//   const SocialBtn(
//       {super.key, required this.icon, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       child: Container(
//         height: 57,
//         width: 57,
//         decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: whitePure(context)),
//         alignment: Alignment.center,
//         child: Image.asset(icon, height: 32, width: 32),
//       ),
//     );
//   }
// }

// TopTap UI

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/custom_divider.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/common/widget/theme_blur_bg.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/auth_screen/auth_screen_controller.dart';
import 'package:shortzz/screen/auth_screen/forget_password_sheet.dart';
import 'package:shortzz/screen/auth_screen/registration_screen.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AuthScreenController());
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        height: Get.height,
        decoration: const ShapeDecoration(
            shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(
                  cornerRadius: 0, cornerSmoothing: 1)),
        )),
        child: Stack(
          children: [
            // const ThemeBlurBg(),
            SingleChildScrollView(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 20, right: 20, top: 30),
                      child: Column(
                        children: [
                          // Logo placement
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                                    vertical: 20.0),
                            child: Image.asset(
                              'assets/images/Toptap_logo.png',
                              height: 80,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Email Field
                          LoginSheetTextField(
                            
                            labelText: LKey.email.tr,
                            hintText:
                                LKey.enterYourEmail.tr,
                            controller:
                                controller.emailController,
                            keyboardType:
                                TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),

                          // Password Field
                          LoginSheetTextField(
                            isPasswordField: true,
                            hintText: LKey.enterPassword.tr,
                            controller: controller
                                .passwordController,
                          ),

                          // Forgot Password
                          Align(
                            alignment: AlignmentDirectional
                                .centerEnd,
                            child: InkWell(
                              onTap: () {
                                Get.bottomSheet(
                                        const ForgetPasswordSheet(),
                                        isScrollControlled:
                                            true)
                                    .then((value) => controller
                                        .forgetEmailController
                                        .clear());
                              },
                              child: Padding(
                                padding: const EdgeInsets
                                    .symmetric(
                                    vertical: 14.0),
                                child: Text(
                                  LKey.forgetPassword.tr,
                                  style: TextStyleCustom
                                      .outFitRegular400(
                                    fontSize: 16,
                                    color: ColorRes
                                        .textgreenColor,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Login Button
                          TextButtonCustomforloginandsingup(
                            onTap: controller.onLogin,
                            title: LKey.logIn.tr,
                            btnHeight: 50,
                            horizontalMargin: 0,
                          ),
                        ],
                      ),
                    ),

                    // // Sign Up Button
                    // InkWell(
                    //   onTap: () {
                    //     controller.fullNameController
                    //         .clear();
                    //     controller.emailController.clear();
                    //     controller.passwordController
                    //         .clear();
                    //     controller.confirmPassController
                    //         .clear();
                    //     Get.to(() =>
                    //         const RegistrationScreen());
                    //   },
                    //   child: Container(
                    //     height: 48,
                    //     margin: const EdgeInsets.symmetric(
                    //         vertical: 25),
                    //     alignment: Alignment.center,
                    //     color: whitePure(context)
                    //         .withValues(alpha: .2),
                    //     child: Text(
                    //       LKey.createAccountHere.tr,
                    //       style: TextStyleCustom
                    //           .outFitRegular400(
                    //               color: whitePure(context),
                    //               fontSize: 16),
                    //     ),
                    //   ),
                    // ),

                    const SizedBox(height: 40),

                    // Divider
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        CustomDivider(
                          color: adaptiveTextColor(context),
                          height: .5,
                          width: 100,
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 15.0),
                          child: Text(
                            LKey.orWith.tr,
                            style: TextStyleCustom
                                .outFitRegular400(
                                    fontSize: 16,
                                    color:
                                        adaptiveTextColor(
                                            context)),
                          ),
                        ),
                        CustomDivider(
                          color: adaptiveTextColor(context),
                          height: .5,
                          width: 100,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Social Login Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 25.0),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          SocialBtn(
                            onTap: controller.onGoogleTap,
                            icon: AssetRes.icGoogle,
                          ),
                          const SizedBox(width: 20),
                          // if (Platform.isIOS)
                          SocialBtn(
                            onTap: controller.onAppleTap,
                            icon: AssetRes.icApple,
                          ),
                          const SizedBox(width: 20),
                          SocialBtn(
                            onTap: () {
                              print("Not Yet Implemented");
                            }, // TODO: implement Facebook login
                            icon: AssetRes
                                .icFacebook, // Add this in AssetRes
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sign Up Button
                    InkWell(
                      onTap: () {
                        controller.fullNameController
                            .clear();
                        controller.emailController.clear();
                        controller.passwordController
                            .clear();
                        // controller.confirmPassController
                        //     .clear();
                        Get.to(() =>
                            const RegistrationScreen());
                      },

                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 25),
                        child: RichText(
                          text: TextSpan(
                            text: LKey.dontHaveAccount
                                .tr, // "Don't have an account ?"
                            style: TextStyleCustom
                                .outFitRegular400(
                              color: adaptiveTextColor(
                                  context),
                              fontSize: 16,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    ' ${LKey.signUp.tr}', // "Sign Up"
                                style: TextStyleCustom
                                    .outFitSemiBold600(
                                  // color: whitePure(context),
                                  color: ColorRes
                                      .textgreenColor,
                                  //  color: Colors.green, // Or your theme's success color
                                  fontSize: 16,
                                  //fontWeight: FontWeight.w600,
                                ),
                                recognizer:
                                    TapGestureRecognizer()
                                      ..onTap = () {
                                        controller
                                            .fullNameController
                                            .clear();
                                        controller
                                            .emailController
                                            .clear();
                                        controller
                                            .passwordController
                                            .clear();
                                        // controller
                                        //     .confirmPassController
                                        //     .clear();
                                        Get.to(() =>
                                            const RegistrationScreen());
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // child: Container(
                      //   height: 48,
                      //   margin: const EdgeInsets.symmetric(
                      //       vertical: 25),
                      //   alignment: Alignment.center,
                      //   color: whitePure(context)
                      //       .withValues(alpha: .2),
                      //   child: Text(
                      //     LKey.orWith.tr,
                      //     style: TextStyleCustom
                      //         .outFitRegular400(
                      //             color: whitePure(context),
                      //             fontSize: 16),
                      //   ),
                      // ),
                    ),
                    // // Privacy Policy
                    // PrivacyPolicyText(
                    //   boldTextColor: whitePure(context),
                    //   regularTextColor: whitePure(context)
                    //       .withValues(alpha: .8),
                    // ),
                    //const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginSheetTextField extends StatefulWidget {
  final bool isPasswordField;
  final String? labelText;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const LoginSheetTextField({
    super.key,
    this.labelText,
    this.isPasswordField = false,
    required this.hintText,
    required this.controller,
    this.keyboardType,
  });

  @override
  State<LoginSheetTextField> createState() =>
      _LoginSheetTextFieldState();
}

class _LoginSheetTextFieldState
    extends State<LoginSheetTextField> {
  bool isHide = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
              cornerRadius: 10, cornerSmoothing: 1),
          side: BorderSide(
              color: adaptiveBorderColor(context)
                  .withValues(alpha: .4)),
          borderAlign: BorderAlign.inside,
        ),
        // color: whitePure(context).withValues(alpha: .1),
      ),
      child: TextField(
        controller: widget.controller,
        style: TextStyleCustom.outFitRegular400(
            color: adaptiveTextColor(context),
            fontSize: 16),
        onTapOutside: (event) =>
            FocusManager.instance.primaryFocus?.unfocus(),
        obscureText: widget.isPasswordField && isHide,
        keyboardType:
            widget.keyboardType ?? TextInputType.text,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.hintText,
          hintStyle: TextStyleCustom.outFitRegular400(
              color: ColorRes.textlightGreenColor,
              fontSize: 16),
          contentPadding: EdgeInsets.only(
              left: 10,
              right: 10,
              top: widget.isPasswordField ? 2 : 0),
          suffixIconConstraints: const BoxConstraints(
            minHeight: 48,
            minWidth: 48,
          ),
          suffixIcon: widget.isPasswordField
              ? InkWell(
                  onTap: () {
                    isHide = !isHide;
                    setState(() {});
                  },
                  child: AnimatedSwitcher(
                    duration:
                        const Duration(milliseconds: 250),
                    child: Image.asset(
                      isHide
                          ? AssetRes.icEye
                          : AssetRes.icHideEye,
                      height: 24,
                      width: 35,
                      color: ColorRes.textlightGreenColor,
                      key: UniqueKey(),
                    ),
                  ),
                )
              : null,
        ),
        cursorColor: ColorRes.likeRed,
      ),
    );
  }
}

class SocialBtn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;

  const SocialBtn(
      {super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 57,
        width: 57,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: adaptiveBorderColor(context),
                width: 1.5),
            color: whitePure(context)),
        alignment: Alignment.center,
        child: Image.asset(icon, height: 32, width: 32),
      ),
    );
  }
}
