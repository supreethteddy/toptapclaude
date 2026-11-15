import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/controller/base_controller.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/widget/confirmation_dialog.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/chat/chat_thread.dart';
import 'package:toptap/model/user_model/user_model.dart';
import 'package:toptap/utilities/firebase_const.dart';

class MessageScreenController extends BaseController {
  List<String> chatCategories = [
    LKey.chats.tr,
    LKey.requests.tr
  ];
  RxInt selectedChatCategory = 0.obs;
  FirebaseFirestore db = FirebaseFirestore.instance;
  PageController pageController = PageController();
  User? myUser = SessionManager.instance.getUser();
  RxList<ChatThread> chatsUsers = <ChatThread>[].obs;
  RxList<ChatThread> requestsUsers = <ChatThread>[].obs;
  StreamSubscription<QuerySnapshot<ChatThread>>?
      _chatStreamSubscription;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(
        initialPage: selectedChatCategory.value);
    _fetchUsers();
  }

  @override
  void onReady() {
    super.onReady();
    // Ensure fresh data when screen becomes active
    _refreshData();
  }

  void _refreshData() {
    // Cancel existing subscription and create a new one
    _chatStreamSubscription?.cancel();
    _fetchUsers();
  }

  void onPageChanged(int index) {
    selectedChatCategory.value = index;
    // Force refresh when switching tabs to ensure latest data
    if (index == 1) {
      // Requests tab
      Loggers.success(
          '🔄 Switching to requests tab - refreshing data');
    } else {
      // Chats tab
      Loggers.success(
          '🔄 Switching to chats tab - refreshing data');
    }
    // The stream will automatically update both tabs
  }

  void _fetchUsers() {
    _chatStreamSubscription = db
        .collection(FirebaseConst.users)
        .doc(myUser?.id.toString())
        .collection(FirebaseConst.usersList)
        .withConverter(
          fromFirestore: (snapshot, options) =>
              ChatThread.fromJson(snapshot.data()!),
          toFirestore: (ChatThread value, options) =>
              value.toJson(),
        )
        .where(FirebaseConst.isDeleted, isEqualTo: false)
        .orderBy(FirebaseConst.id, descending: true)
        .snapshots()
        .listen((event) {
      Loggers.success(
          'Firebase snapshot received: ${event.docs.length} documents');

      // Clear lists to rebuild them fresh
      List<ChatThread> newChatsUsers = [];
      List<ChatThread> newRequestsUsers = [];

      // Process all documents (not just changes) for more reliable updates
      for (var doc in event.docs) {
        final ChatThread? user = doc.data();
        if (user == null) continue;

        Loggers.success(
            'Processing user: ${user.chatUser?.username}, Type: ${user.chatType}');

        if (user.chatType == ChatType.approved) {
          newChatsUsers.add(user);
        } else {
          newRequestsUsers.add(user);
        }
      }

      // Sort lists by ID in descending order (newer conversations first)
      newChatsUsers.sort((a, b) {
        final aId = int.tryParse(a.id ?? '0') ?? 0;
        final bId = int.tryParse(b.id ?? '0') ?? 0;
        return bId.compareTo(aId);
      });
      newRequestsUsers.sort((a, b) {
        final aId = int.tryParse(a.id ?? '0') ?? 0;
        final bId = int.tryParse(b.id ?? '0') ?? 0;
        return bId.compareTo(aId);
      });

      // Update reactive lists with fresh data
      chatsUsers.assignAll(newChatsUsers);
      requestsUsers.assignAll(newRequestsUsers);

      Loggers.success(
          '✅ Updated - CHAT USERS: ${chatsUsers.length}');
      Loggers.success(
          '✅ Updated - REQUEST USERS: ${requestsUsers.length}');
    }, onError: (error) {
      Loggers.error('❌ Firebase stream error: $error');
    });
  }

  // Public method to manually refresh data if needed
  void refreshMessages() {
    Loggers.success('Manual refresh triggered');
    _refreshData();
  }

  void onLongPress(ChatThread chatConversation) {
    Get.bottomSheet(ConfirmationSheet(
      title: LKey.deleteChatUserTitle.trParams({
        'user_name':
            chatConversation.chatUser?.username ?? ''
      }),
      description: LKey.deleteChatUserDescription.tr,
      onTap: () async {
        int time = DateTime.now().millisecondsSinceEpoch;
        showLoader();
        await db
            .collection(FirebaseConst.users)
            .doc(myUser?.id.toString())
            .collection(FirebaseConst.usersList)
            .doc(chatConversation.chatUser?.userId
                .toString())
            .update({
          FirebaseConst.deletedId: time,
          FirebaseConst.isDeleted: true,
        }).catchError((error) {
          Loggers.error('USER NOT DELETE : $error');
        });
        stopLoader();
      },
    ));
  }

  @override
  void onClose() {
    _chatStreamSubscription?.cancel();
    pageController.dispose();
    super.onClose();
  }
}
