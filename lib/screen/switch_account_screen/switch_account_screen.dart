import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/screen/switch_account_screen/switch_account_controller.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class SwitchAccountScreen extends StatelessWidget {
  const SwitchAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SwitchAccountController());
    final user = SessionManager.instance.getUser();
    final username = user?.username?.trim();

    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(title: 'Switch Account'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Current Account Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgLightGrey(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: themeAccentSolid(context),
                          child: Icon(
                            Icons.person,
                            color: whitePure(context),
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Account',
                                style: TextStyleCustom.outFitRegular400(
                                  fontSize: 16,
                                  color: textDarkGrey(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                username == null || username.isEmpty
                                    ? (user?.fullname ?? 'Signed-in account')
                                    : '@$username',
                                style: TextStyleCustom.outFitRegular400(
                                  fontSize: 14,
                                  color: textLightGrey(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.check_circle,
                          color: themeAccentSolid(context),
                          size: 24,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Add Account Button
                  InkWell(
                    onTap: controller.addAccount,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgLightGrey(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: themeAccentSolid(context).withOpacity(0.3),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: themeAccentSolid(context),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.add,
                              color: themeAccentSolid(context),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Add Account',
                            style: TextStyleCustom.outFitRegular400(
                              fontSize: 16,
                              color: textDarkGrey(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Information Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgMediumGrey(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add another account',
                          style: TextStyleCustom.outFitMedium500(
                            fontSize: 16,
                            color: textDarkGrey(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in with another account, or create a new one. '
                          'Each account keeps its own content and settings.',
                          style: TextStyleCustom.outFitRegular400(
                            fontSize: 14,
                            color: textLightGrey(context),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Create New Account Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: controller.createNewAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeAccentSolid(context),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Create New Account',
                        style: TextStyleCustom.outFitMedium500(
                          fontSize: 16,
                          color: whitePure(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
