import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/common/widget/user_list.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/find_friends_screen/find_friends_screen_controller.dart';
import 'package:shortzz/screen/scan_qr_code_screen/scan_qr_code_screen.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';

class FindFriendsScreen extends StatelessWidget {
  const FindFriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FindFriendsScreenController());

    return Scaffold(
      backgroundColor: ColorRes.blackPure,
      body: SafeArea(
        child: Column(
          children: [
            _FindFriendsHeader(),
            const SizedBox(height: 16),
            _SearchBar(controller: controller),
            const SizedBox(height: 16),
            _InviteFriendsRow(controller: controller),
            const SizedBox(height: 8),
            Expanded(
              child: Obx(
                () => UserList<User>(
                  users: controller.users,
                  isLoading: controller.isUsersLoading,
                  loadMore: controller.searchUsers,
                  onTap: controller.onUserTap,
                  getProfilePhoto: (user) => user.profilePhoto ?? '',
                  getUserName: (user) => user.username ?? '',
                  getFullName: (user) => user.fullname ?? '',
                  getVerified: (user) => user.isVerify ?? 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FindFriendsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const CustomBackButton(
            color: ColorRes.whitePure,
            width: 18,
            height: 18,
            padding: EdgeInsets.all(15),
          ),
          Expanded(
            child: Center(
              child: Text(
                LKey.findFriends.tr,
                style: TextStyleCustom.outFitBold700(
                    color: ColorRes.whitePure, fontSize: 18),
              ),
            ),
          ),
          InkWell(
            onTap: () => Get.to(() => const ScanQrCodeScreen()),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Image.asset(
                AssetRes.icQrCode,
                height: 22,
                width: 22,
                color: ColorRes.likeRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final FindFriendsScreenController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: ShapeDecoration(
          color: ColorRes.whitePure,
          shape: SmoothRectangleBorder(
            borderRadius:
                SmoothBorderRadius(cornerRadius: 26, cornerSmoothing: 1),
          ),
        ),
        child: Row(
          children: [
            Image.asset(
              AssetRes.icSearch,
              height: 18,
              width: 18,
              color: ColorRes.textLightGrey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller.searchController,
                onChanged: controller.onSearchChanged,
                cursorHeight: 16,
                style: TextStyleCustom.outFitRegular400(
                    fontSize: 15, color: ColorRes.blackPure),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: LKey.searchHere.tr,
                  hintStyle: TextStyleCustom.outFitLight300(
                      fontSize: 15, color: ColorRes.textLightGrey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteFriendsRow extends StatelessWidget {
  final FindFriendsScreenController controller;

  const _InviteFriendsRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: controller.onInviteFriendsTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: const BoxDecoration(
                color: ColorRes.likeRed,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Image.asset(
                AssetRes.icaddfriend,
                height: 21,
                width: 21,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                LKey.inviteFriends.tr,
                style: TextStyleCustom.outFitMedium500(
                    color: ColorRes.whitePure, fontSize: 15),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: ColorRes.textLightGrey,
            ),
          ],
        ),
      ),
    );
  }
}
