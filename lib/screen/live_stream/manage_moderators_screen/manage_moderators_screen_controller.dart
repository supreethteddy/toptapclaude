import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/moderation_log_entry.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/app_res.dart';

/// Per-LIVE-session Moderator list (client spec Module 14.1: "Permissions
/// apply only to the LIVE session for which the Moderator is authorized") --
/// replaces the retired permanent app_users/{hostId}/moderators list, which
/// survived across every LIVE the host ever ran and let any app user be
/// picked as a candidate. Candidates here are scoped to this one room's own
/// participants (host excluded) via the already-live
/// [LivestreamScreenController], matching "per-session" in both directions:
/// who can be made a Moderator, and how long the grant lasts.
class ManageModeratorsScreenController extends BaseController {
  final String roomID;
  late final LivestreamScreenController liveController =
      Get.find<LivestreamScreenController>(tag: roomID);
  final firestoreController = Get.find<FirebaseFirestoreController>();

  final RxString query = ''.obs;
  final RxList<ModerationLogEntry> logEntries = <ModerationLogEntry>[].obs;
  StreamSubscription<QuerySnapshot>? _logListener;

  ManageModeratorsScreenController(this.roomID);

  @override
  void onInit() {
    super.onInit();
    _logListener = liveController.moderationLogRef
        .orderBy('at', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      logEntries.value = snapshot.docs
          .map((doc) =>
              ModerationLogEntry.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  void onClose() {
    _logListener?.cancel();
    super.onClose();
  }

  void onSearchChange(String value) => query.value = value;

  bool isModerator(int? userId) =>
      liveController.liveModerators.any((mod) => mod.userId == userId);

  bool canManageGuestsFor(int? userId) {
    return liveController.liveModerators
            .firstWhereOrNull((mod) => mod.userId == userId)
            ?.canManageGuests ??
        false;
  }

  /// Candidates: everyone currently in this room (any role — on stage or
  /// just watching), minus the host themselves. Unlike the retired global
  /// list, a host can no longer grant Moderator to someone who isn't even
  /// here.
  List<AppUser> get filteredUsers {
    final hostId = liveController.liveData.value.hostId;
    final q = query.value.trim().toLowerCase();
    final roomUserIds = liveController.liveUsersStates
        .map((state) => state.userId)
        .whereType<int>()
        .where((id) => id != hostId)
        .toSet();
    final candidates = firestoreController.users
        .where((user) => roomUserIds.contains(user.userId));
    if (q.isEmpty) return candidates.toList();
    return candidates.where((user) {
      final username = (user.username ?? '').toLowerCase();
      final fullname = (user.fullname ?? '').toLowerCase();
      return username.contains(q) || fullname.contains(q);
    }).toList();
  }

  /// Host-only (client spec 14.5: Moderators must not assign other
  /// Moderators) -- this whole screen is already reached only through a
  /// host-gated entry point, but the check lives here too rather than
  /// relying on that alone.
  Future<void> addModerator(AppUser user) async {
    if (!liveController.isHost || user.userId == null) return;
    if (liveController.liveModerators.length >=
        AppRes.maxLivestreamModerators) {
      showSnackBar(LKey.moderatorLimitReached.tr);
      return;
    }
    await liveController.liveModeratorsRef.doc('${user.userId}').set({
      'id': user.userId,
      'can_manage_guests': false,
      'added_at': DateTime.now().millisecondsSinceEpoch,
    });
    liveController.logModeratorGrant('add_moderator', user);
  }

  Future<void> removeModerator(AppUser user) async {
    if (!liveController.isHost || user.userId == null) return;
    await liveController.liveModeratorsRef.doc('${user.userId}').delete();
    liveController.logModeratorGrant('remove_moderator', user);
  }

  Future<void> toggleCanManageGuests(AppUser user, bool value) async {
    if (!liveController.isHost || user.userId == null) return;
    await liveController.liveModeratorsRef.doc('${user.userId}').update({
      'can_manage_guests': value,
    });
    liveController.logModeratorGrant(
        value ? 'grant_manage_guests' : 'revoke_manage_guests', user);
  }
}
