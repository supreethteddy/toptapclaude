import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/extensions/user_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/utilities/firebase_const.dart';

class FirebaseFirestoreController extends BaseController {
  FirebaseFirestore db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<AppUser>>? usersListener;
  Timer? _retryTimer;
  int _retryDelaySeconds = 2;
  RxList<AppUser> users = <AppUser>[].obs;

  static final instance = FirebaseFirestoreController();

  @override
  void onReady() {
    fetchLivestreamUsers();
    super.onReady();
  }

  void fetchLivestreamUsers() {
    close();
    usersListener = db
        .collection(FirebaseConst.appUsers)
        .withConverter<AppUser>(
            fromFirestore: (snapshot, _) {
              if (snapshot.data() != null) {
                return AppUser.fromJson(snapshot.data()!);
              } else {
                return AppUser();
              }
            },
            toFirestore: (user, _) => user.toJson())
        .snapshots()
        .listen((snapshot) {
      // See the matching comment in LiveStatusController._listen -- a prior
      // permission-denied error (Firebase Auth still being established
      // right after cold start) has now cleared; stop backing off.
      _retryDelaySeconds = 2;
      for (var change in snapshot.docChanges) {
        final user = change.doc.data();
        if (user == null) {
          Loggers.error(
              'App User data is null for doc: ${change.doc.id}, skipping...');
          continue;
        }
        final userId = user.userId;
        Loggers.info('[TYPE : ${change.type}] - ${user.toJson()}');
        switch (change.type) {
          case DocumentChangeType.added:
            users.add(user);
            break;
          case DocumentChangeType.modified:
            users.removeWhere((e) => e.userId == userId);
            users.add(user);
            break;
          case DocumentChangeType.removed:
            users.removeWhere((e) => e.userId == userId);
            break;
        }
      }
    }, onError: (e) {
      // A PERMISSION_DENIED (e.g. this listener attaching before
      // SplashScreenController's Firebase custom-token sign-in completes)
      // terminates the subscription for good -- it never resubscribes on
      // its own even once auth resolves moments later. Without a retry,
      // `users` stays empty for the rest of the app's lifetime and every
      // LIVE screen reads "No users in livestream" even though the host
      // really is live. Backs off up to 30s so a persistent error doesn't
      // spin.
      Loggers.error(
          'FirebaseFirestoreController listen error: $e, retrying in ${_retryDelaySeconds}s');
      _retryTimer?.cancel();
      _retryTimer =
          Timer(Duration(seconds: _retryDelaySeconds), fetchLivestreamUsers);
      _retryDelaySeconds = (_retryDelaySeconds * 2).clamp(2, 30);
    });
  }

  void updateUser(User? user) async {
    if (user == null) return;
    DocumentSnapshot<AppUser> value = await db
        .collection(FirebaseConst.appUsers)
        .doc('${user.id}')
        .withConverter(
          fromFirestore: (snapshot, options) =>
              AppUser.fromJson(snapshot.data()!),
          toFirestore: (AppUser value, options) {
            return value.toJson();
          },
        )
        .get();
    AppUser? chatUser = user.appUser;

    if (value.exists) {
      db
          .collection(FirebaseConst.appUsers)
          .doc('${user.id}')
          .update(chatUser.toJson());
    }
  }

  void deleteUser(int? userId) async {
    if (userId == null) return;
    await db.collection(FirebaseConst.appUsers).doc('$userId').delete();

    final userListSnapshot = await db
        .collection(FirebaseConst.users)
        .doc('$userId')
        .collection(FirebaseConst.usersList)
        .get();

    final batch = db.batch();

    for (var doc in userListSnapshot.docs) {
      final otherUserId = doc.id;

      final otherUserRef = db
          .collection(FirebaseConst.users)
          .doc(otherUserId)
          .collection(FirebaseConst.usersList)
          .doc('$userId');

      final currentUserRef = db
          .collection(FirebaseConst.users)
          .doc('$userId')
          .collection(FirebaseConst.usersList)
          .doc(otherUserId);

      batch.delete(otherUserRef);
      batch.delete(currentUserRef);
    }

    await batch.commit();
  }

  void close() {
    usersListener?.cancel();
    _retryTimer?.cancel();
  }

  @override
  void onClose() {
    super.onClose();
    close();
  }
}
