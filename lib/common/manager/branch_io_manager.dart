import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/share_sheet_widget/share_sheet_widget.dart';
import 'package:shortzz/utilities/app_res.dart';

enum ShareBranchType { post, user, qr }

class BranchIoManager {
  BranchIoManager._();

  static final BranchIoManager instance = BranchIoManager._();

  Future<CustomBranchResponse?> init(
      {required ShareBranchType type,
      User? user,
      Post? post,
      VoidCallback? onShareSuccess}) async {
    final BranchShareData shareData =
        _generateShareData(type, user: user, post: post);

    final branchObject = BranchUniversalObject(
      canonicalIdentifier: 'shortzz/${type.name}',
      title: shareData.title,
      imageUrl: shareData.imageUrl,
      keywords: ['TopTap', 'Flutter', 'Share'],
      contentMetadata: BranchContentMetaData()
        ..addCustomMetadata(shareData.metadataKey, shareData.metadataValue),
    );

    final linkProperties = BranchLinkProperties()
      ..addControlParam('url', shareData.deepLinkUrl);

    final response = await FlutterBranchSdk.getShortUrl(
        buo: branchObject, linkProperties: linkProperties);

    if (response.success) {
      return CustomBranchResponse(
          response.result, branchObject, linkProperties, shareData);
    } else {
      return null;
    }
  }

  Future<CustomBranchResponse?> generateLink(
      {required ShareBranchType type, User? user, Post? post}) async {
    return await init(type: type, user: user, post: post);
  }

  Future<void> shareContent(
      {required ShareBranchType type,
      User? user,
      Post? post,
      VoidCallback? onShareSuccess}) async {
    CustomBranchResponse? branchResponse = await init(
        type: type, user: user, post: post, onShareSuccess: onShareSuccess);
    if (branchResponse == null) {
      Loggers.error('Failed to generate link.');
      return;
    }

    if (type == ShareBranchType.qr) {
      _showBranchShareSheet(branchResponse.branchObject,
          branchResponse.linkProperties, branchResponse.shareData.title, type);
    } else {
      _showCustomShareSheet(
        link: branchResponse.link,
        type: type,
        user: user,
        post: post,
        buo: branchResponse.branchObject,
        linkProperties: branchResponse.linkProperties,
        title: branchResponse.shareData.title,
        onShareSuccess: onShareSuccess,
      );
    }
  }

  BranchShareData _generateShareData(ShareBranchType type,
      {User? user, Post? post}) {
    switch (type) {
      case ShareBranchType.post:
        return BranchShareData(
          title:
              '${post?.user?.username ?? ''} on ${AppRes.appName}${(post?.description ?? '').isNotEmpty ? ': ${post?.description}' : ''}',
          imageUrl: post?.getThumbnail.addBaseURL() ?? '',
          metadataKey: Params.postId,
          metadataValue: '${post?.id ?? -1}',
          deepLinkUrl:
              'https://yourdomain.com/post/${post?.id ?? ''}', // Update based on real URLs
        );
      case ShareBranchType.user:
      case ShareBranchType.qr:
        return BranchShareData(
          title: getUserTitle(
              fullname: user?.fullname ?? '', username: user?.username ?? ''),

          imageUrl: user?.profilePhoto?.addBaseURL() ?? '',
          metadataKey: Params.userId,
          metadataValue: '${user?.id ?? -1}',
          deepLinkUrl:
              'https://yourdomain.com/user/${user?.username ?? ''}', // Update based on real URLs
        );
    }
  }

  String getUserTitle({required String fullname, required String username}) {
    return '$fullname (@$username) • ${AppRes.appName} profile';
  }

  void _showBranchShareSheet(
    BranchUniversalObject buo,
    BranchLinkProperties linkProperties,
    String title,
    ShareBranchType type,
  ) async {
    final response = await FlutterBranchSdk.showShareSheet(
      buo: buo,
      linkProperties: linkProperties,
      messageText: type == ShareBranchType.post ? '' : title,
    );

    if (response.success) {
      Loggers.success('Branch share sheet displayed.');
    } else {
      Loggers.error(
          'Branch Share Sheet Error: ${response.errorCode} - ${response.errorMessage}');
    }
  }

  void _showCustomShareSheet({
    required String link,
    required ShareBranchType type,
    required User? user,
    required Post? post,
    required BranchUniversalObject buo,
    required BranchLinkProperties linkProperties,
    required String title,
    VoidCallback? onShareSuccess,
  }) {
    Get.bottomSheet(
      ShareSheetWidget(
        onMoreTap: () {
          Get.back();
          _showBranchShareSheet(
            buo,
            linkProperties,
            title,
            type,
          );
          if (type == ShareBranchType.post && post != null) {
            _increaseShareCount(post.id, onShareSuccess);
          }
        },
        post: post,
        link: link,
        title: type == ShareBranchType.post ? '' : title,
        isDownloadShow:
            type == ShareBranchType.post && post?.postType == PostType.reel,
        type: type,
        onCallBack: onShareSuccess,
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _increaseShareCount(int? postId, VoidCallback? onSuccess) async {
    if (postId == null) return;
    final response =
        await PostService.instance.increaseShareCount(postId: postId);
    if (response.status == true) {
      onSuccess?.call();
    }
  }
}

class BranchShareData {
  final String title;
  final String imageUrl;
  final String metadataKey;
  final String metadataValue;
  final String deepLinkUrl;

  BranchShareData({
    required this.title,
    required this.imageUrl,
    required this.metadataKey,
    required this.metadataValue,
    required this.deepLinkUrl,
  });
}

class CustomBranchResponse {
  final String link;
  final BranchUniversalObject branchObject;
  final BranchLinkProperties linkProperties;
  final BranchShareData shareData;

  CustomBranchResponse(
      this.link, this.branchObject, this.linkProperties, this.shareData);
}
