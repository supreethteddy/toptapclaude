import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/firebase_const.dart';

/// Persistent, per-host list of LIVE moderators (kept on the host's own
/// `app_users` document, independent of any single stream so it survives
/// across every LIVE the host runs) — mirrors TikTok's "Manage moderators".
class ManageModeratorsScreenController extends BaseController {
  final int hostId = SessionManager.instance.getUserID();
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final firestoreController = Get.find<FirebaseFirestoreController>();

  final RxList<int> moderatorIds = <int>[].obs;
  final RxString query = ''.obs;
  StreamSubscription<QuerySnapshot>? _listener;

  CollectionReference get _moderatorsRef => db
      .collection(FirebaseConst.appUsers)
      .doc('$hostId')
      .collection(FirebaseConst.moderators);

  @override
  void onInit() {
    super.onInit();
    _listener = _moderatorsRef.snapshots().listen((snapshot) {
      moderatorIds.value =
          snapshot.docs.map((doc) => int.parse(doc.id)).toList();
    });
  }

  @override
  void onClose() {
    _listener?.cancel();
    super.onClose();
  }

  void onSearchChange(String value) => query.value = value;

  bool isModerator(int? userId) => moderatorIds.contains(userId);

  List<AppUser> get filteredUsers {
    final q = query.value.trim().toLowerCase();
    final candidates =
        firestoreController.users.where((user) => user.userId != hostId);
    if (q.isEmpty) return candidates.toList();
    return candidates.where((user) {
      final username = (user.username ?? '').toLowerCase();
      final fullname = (user.fullname ?? '').toLowerCase();
      return username.contains(q) || fullname.contains(q);
    }).toList();
  }

  Future<void> addModerator(AppUser user) async {
    if (user.userId == null) return;
    if (moderatorIds.length >= AppRes.maxLivestreamModerators) {
      showSnackBar(LKey.moderatorLimitReached.tr);
      return;
    }
    await _moderatorsRef.doc('${user.userId}').set({
      FirebaseConst.id: user.userId,
      FirebaseConst.addedAt: DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> removeModerator(AppUser user) async {
    if (user.userId == null) return;
    await _moderatorsRef.doc('${user.userId}').delete();
  }
}
