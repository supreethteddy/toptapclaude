import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/model/user_model/block_user_model.dart';
import 'package:shortzz/model/user_model/follower_model.dart';
import 'package:shortzz/model/user_model/following_model.dart';
import 'package:shortzz/model/user_model/links_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/model/user_model/users_model.dart';
import 'package:shortzz/screen/edit_profile_screen/widget/add_edit_link_sheet.dart';
import 'package:shortzz/utilities/app_res.dart';

enum LoginMethod {
  email,
  google,
  apple;

  String title() {
    switch (this) {
      case LoginMethod.email:
        return 'email';
      case LoginMethod.google:
        return 'google';
      case LoginMethod.apple:
        return 'apple';
    }
  }
}

class LoginApiException implements Exception {
  const LoginApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  Future<User> logInUser({
    String? fullName,
    required String identity,
    String? deviceToken,
    required LoginMethod loginMethod,
  }) async {
    UserModel model = await ApiService.instance.call(
        url: WebService.user.loginInUser,
        param: {
          Params.fullname: fullName,
          Params.identity: identity,
          Params.deviceToken: deviceToken,
          Params.device: Platform.isAndroid ? 0 : 1,
          Params.loginMethod: loginMethod.title()
        },
        cancelAuthToken: true,
        fromJson: UserModel.fromJson);

    final userData = model.data;
    if (model.status != true || userData == null) {
      throw LoginApiException(model.message?.trim().isNotEmpty == true
          ? model.message!.trim()
          : 'Unable to complete login. Please try again.');
    }

    SessionManager.instance.setUser(userData);
    SessionManager.instance.setAuthToken(userData.token);
    return userData;
  }

  Future<StatusModel> deleteMyAccount() async {
    StatusModel response = await ApiService.instance.call(
        url: WebService.user.deleteMyAccount, fromJson: StatusModel.fromJson);
    return response;
  }

  Future<StatusModel> logoutUser() async {
    StatusModel response = await ApiService.instance
        .call(url: WebService.user.logOutUser, fromJson: StatusModel.fromJson);
    return response;
  }

  Future<User?> fetchUserDetails({int? userId}) async {
    // Resolve to the same id actually sent to the API before comparing —
    // comparing the raw (often-null, defaulting to "my own profile")
    // parameter against getUserID()'s int meant this never matched on the
    // common no-arg call, so the session cache never got refreshed here.
    final targetUserId = userId ?? SessionManager.instance.getUserID();
    UserModel userModel = await ApiService.instance.call(
        url: WebService.user.fetchUserDetails,
        param: {Params.userId: targetUserId},
        fromJson: UserModel.fromJson);
    // Belt-and-braces alongside the status check: a response that parses
    // with status true but a blank/defaulted user (id null or 0 — seen from
    // this endpoint under load, e.g. mid-PK-battle gift bursts) must never
    // overwrite the session. This call persists my own profile on every
    // call site that self-refreshes (balance-after-gift, settings, feed,
    // etc.), so one bad response here used to zero out myUserId for the
    // rest of the session with no further signal.
    final fetchedId = userModel.data?.id;
    if (userModel.status == true &&
        fetchedId != null &&
        fetchedId > 0 &&
        targetUserId == SessionManager.instance.getUserID()) {
      SessionManager.instance.setUser(userModel.data);
    }
    return userModel.data;
  }

  // Mints a fresh Firebase custom token for the already-logged-in session
  // and returns it (or null on any failure). Call this on cold start before
  // fetchUserDetails -- session restore never otherwise touches Firebase
  // Auth at all, unlike the one-time interactive login flow, which left an
  // already-logged-in user permanently unauthenticated to Firestore once
  // security rules started requiring request.auth != null.
  Future<String?> refreshFirebaseSession() async {
    final response = await ApiService.instance
        .call<Map<String, dynamic>>(url: WebService.user.refreshFirebaseSession);
    if (response['status'] == true) {
      final token = response['data'];
      return token is String && token.isNotEmpty ? token : null;
    }
    return null;
  }

  Future<User?> updateUserDetails(
      {XFile? profilePhoto,
      String? fullname,
      String? userName,
      String? bio,
      String? email,
      String? phoneNumber,
      int? mobileCountryCode,
      String? countryCode,
      String? country,
      String? appLanguage,
      bool? showMyFollowing,
      bool? receiveMessage,
      bool? notifyPostLike,
      bool? notifyPostComment,
      bool? notifyFollow,
      bool? notifyMention,
      bool? notifyGiftReceived,
      bool? notifyChat,
      List<int>? savedMusicIds,
      double? lat,
      double? lon,
      String? whoCanSeePost,
      String? appLastUsed,
      String? region,
      String? regionName,
      String? timezone,
      int? isVerify}) async {
    UserModel userModel = await ApiService.instance.multiPartCallApi(
        url: WebService.user.updateUserDetails,
        filesMap: {
          Params.profilePhoto: [profilePhoto]
        },
        param: {
          Params.fullname: fullname,
          Params.username: userName,
          Params.bio: bio,
          Params.userEmail: email,
          Params.userMobileNo: phoneNumber,
          Params.country: country,
          Params.countryCode: countryCode,
          Params.whoCanViewPost: whoCanSeePost,
          Params.mobileCountryCode: mobileCountryCode,
          if (isVerify != null) Params.isVerify: isVerify,
          if (receiveMessage != null)
            Params.receiveMessage: receiveMessage ? 1 : 0,
          if (showMyFollowing != null)
            Params.showMyFollowing: showMyFollowing ? 1 : 0,
          if (notifyPostLike != null)
            Params.notifyPostLike: notifyPostLike ? 1 : 0,
          if (notifyPostComment != null)
            Params.notifyPostComment: notifyPostComment ? 1 : 0,
          if (notifyFollow != null) Params.notifyFollow: notifyFollow ? 1 : 0,
          if (notifyMention != null)
            Params.notifyMention: notifyMention ? 1 : 0,
          if (notifyGiftReceived != null)
            Params.notifyGiftReceived: notifyGiftReceived ? 1 : 0,
          if (notifyChat != null) Params.notifyChat: notifyChat ? 1 : 0,
          if (savedMusicIds != null)
            Params.savedMusicIds: savedMusicIds.join(','),
          if (appLanguage != null) Params.appLanguage: appLanguage,
          if (lat != null) Params.lat: lat,
          if (lon != null) Params.lon: lon,
          if (appLastUsed != null) Params.appLastUsedAt: appLastUsed,
          if (region != null) Params.region: region,
          if (regionName != null) Params.regionName: regionName,
          if (timezone != null) Params.timezone: timezone
        },
        fromJson: UserModel.fromJson);
    if (userModel.status == true) {
      SessionManager.instance.setUser(userModel.data);
      FirebaseFirestoreController.instance.updateUser(userModel.data);
    }
    return userModel.data;
  }

  Future<StatusModel> checkUsernameAvailability(
      {required String userName}) async {
    return await ApiService.instance.call(
        url: WebService.user.checkUsernameAvailability,
        param: {Params.username: userName},
        fromJson: StatusModel.fromJson);
  }

  Future<LinksModel> addEditDeleteUserLink(
      {String? title,
      String? urlLink,
      int? linkId,
      required LinkType linkType}) async {
    String url;

    switch (linkType) {
      case LinkType.add:
        url = WebService.user.addUserLink;
      case LinkType.edit:
        url = WebService.user.editeUserLink;
      case LinkType.delete:
        url = WebService.user.deleteUserLink;
    }

    LinksModel model = await ApiService.instance.call(
        url: url,
        fromJson: LinksModel.fromJson,
        param: {
          Params.linkId: linkId,
          Params.title: title,
          Params.url: urlLink
        });
    return model;
  }

  Future<List<User>> searchUsers(
      {int? lastItemId, String keyWord = '', required int limit}) async {
    UsersModel model = await ApiService.instance.call(
        url: WebService.user.searchUsers,
        param: {
          if (lastItemId != null) Params.lastItemId: lastItemId,
          Params.limit: limit,
          if (keyWord.isNotEmpty) Params.keyword: keyWord,
        },
        fromJson: UsersModel.fromJson);
    return model.data ?? [];
  }

  Future<List<Follower>> fetchMyFollowers(
      {required int lastItemId, required int? userId}) async {
    bool isMe = userId == SessionManager.instance.getUserID();
    String url = isMe
        ? WebService.user.fetchMyFollowers
        : WebService.user.fetchUserFollowers;

    FollowerModel model = await ApiService.instance.call(
        url: url,
        param: {
          Params.limit: AppRes.paginationLimit,
          if (lastItemId != -1) Params.lastItemId: lastItemId,
          if (!isMe) Params.userId: userId,
        },
        fromJson: FollowerModel.fromJson);
    return model.data ?? [];
  }

  Future<List<Following>> fetchMyFollowing(
      {required int lastItemId, required int? userId}) async {
    bool isMe = userId == SessionManager.instance.getUserID();
    String url = isMe
        ? WebService.user.fetchMyFollowings
        : WebService.user.fetchUserFollowings;

    FollowingModel model = await ApiService.instance.call(
        url: url,
        param: {
          Params.limit: AppRes.paginationLimit,
          if (lastItemId != -1) Params.lastItemId: lastItemId,
          if (!isMe) Params.userId: userId,
        },
        fromJson: FollowingModel.fromJson);
    return model.data ?? [];
  }

  Future<StatusModel> followUser({required int userId}) async {
    StatusModel model = await ApiService.instance.call(
      url: WebService.user.followUser,
      param: {Params.userId: userId},
      fromJson: StatusModel.fromJson,
    );
    return model;
  }

  Future<StatusModel> unFollowUser({required int userId}) async {
    StatusModel model = await ApiService.instance.call(
      url: WebService.user.unFollowUser,
      param: {Params.userId: userId},
      fromJson: StatusModel.fromJson,
    );
    return model;
  }

  Future<StatusModel> unBlockUser({required int userId}) async {
    StatusModel model = await ApiService.instance.call(
        url: WebService.user.unBlockUser,
        param: {Params.userId: userId},
        fromJson: StatusModel.fromJson);

    return model;
  }

  Future<StatusModel> blockUser({required int userId}) async {
    StatusModel model = await ApiService.instance.call(
        url: WebService.user.blockUser,
        param: {Params.userId: userId},
        fromJson: StatusModel.fromJson);
    return model;
  }

  Future<StatusModel> reportPost(
      {required int userId,
      required String reason,
      required String description}) async {
    StatusModel model = await ApiService.instance.call(
        url: WebService.user.reportUser,
        param: {
          Params.userId: userId,
          Params.reason: reason,
          Params.description: description,
        },
        fromJson: StatusModel.fromJson);
    return model;
  }

  Future<List<BlockUsers>> fetchMyBlockedUsers() async {
    BlockUserModel response = await ApiService.instance.call(
      url: WebService.user.fetchMyBlockedUsers,
      fromJson: BlockUserModel.fromJson,
    );
    return response.data ?? [];
  }

  Future<Map<String, dynamic>> updateNotificationPreferences(
      Map<String, dynamic> preferences) async {
    try {
      StatusModel model = await ApiService.instance.call(
        url: WebService.user.updateNotificationPreferences,
        param: preferences,
        fromJson: StatusModel.fromJson,
      );

      if (model.status == true) {
        return {'success': true, 'message': model.message};
      } else {
        return {
          'success': false,
          'message': model.message ?? 'Failed to update preferences'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred'};
    }
  }
}
