import 'package:get/get.dart';
import 'package:shortzz/common/enum/chat_enum.dart';
import 'package:shortzz/common/extensions/list_extension.dart';
import 'package:shortzz/common/extensions/user_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/chat_screen/chat_screen.dart';
import 'package:shortzz/utilities/app_res.dart';

/// "Live Chat Support" = an in-app chat with the official support account.
///
/// The support account is a normal TopTap user whose username is configured
/// in the admin panel (`support_username`, default [AppRes.supportUsername]).
/// Admins answer from the app like any other conversation, so no third party
/// chat tool is needed.
class SupportChatService {
  SupportChatService._();

  static final SupportChatService instance = SupportChatService._();

  String get supportUsername {
    final configured =
        (SessionManager.instance.getSettings()?.supportUsername ?? '').trim();
    return configured.isNotEmpty ? configured : AppRes.supportUsername;
  }

  Future<User?> findSupportUser() async {
    final username = supportUsername.replaceFirst('@', '');
    try {
      final users = await UserService.instance
          .searchUsers(keyWord: username, limit: 20);
      return users.firstWhereOrNull((u) =>
              (u.username ?? '').toLowerCase() == username.toLowerCase()) ??
          users.firstWhereOrNull((u) =>
              (u.username ?? '').toLowerCase().contains(username.toLowerCase()));
    } catch (e) {
      Loggers.error('Support user lookup failed: $e');
      return null;
    }
  }

  /// Opens the chat with the support account. Returns false when the support
  /// account does not exist yet (the admin has to create it).
  Future<bool> openSupportChat() async {
    final support = await findSupportUser();
    if (support == null || support.id == null) return false;
    if (support.id == SessionManager.instance.getUserID()) return false;

    final conversation = ChatThread(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lastMsg: '',
      msgCount: 0,
      isDeleted: false,
      deletedId: 0,
      iAmBlocked: false,
      iBlocked: false,
      requestType: UserRequestAction.accept.title,
      chatType: ChatType.approved,
      conversationId:
          [SessionManager.instance.getUserID(), support.id].conversationId,
      userId: support.id,
    );
    conversation.chatUser = support.appUser;
    await Get.to(() => ChatScreen(conversationUser: conversation, user: support));
    return true;
  }
}
