import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/battle_result.dart';
import 'package:shortzz/utilities/firebase_const.dart';

/// Reads the `battle_history` collection written by
/// `LivestreamScreenController._recordBattleHistory` — see that method for
/// exactly when/how a record gets created. Wins/losses/draws/win-rate are
/// computed client-side from these same documents rather than a separate
/// aggregate, which is correct at this data scale (a creator's own battle
/// count) and avoids a second write path that could drift from the ledger.
class BattleHistoryScreenController extends BaseController {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final int myUserId = SessionManager.instance.getUserID();

  RxList<BattleResult> battles = <BattleResult>[].obs;

  int get totalBattles => battles.length;
  int get wins => battles.where((b) => !b.isDraw && b.winnerHostId == myUserId).length;
  int get losses =>
      battles.where((b) => !b.isDraw && b.winnerHostId != myUserId).length;
  int get draws => battles.where((b) => b.isDraw).length;
  String get winRateDisplay {
    if (totalBattles == 0) return '0%';
    return '${((wins / totalBattles) * 100).round()}%';
  }

  int get totalBattleGiftPoints => battles.fold(
      0, (total, b) => total + b.scoreFor(myUserId));

  AppUser? opponentOf(BattleResult battle) {
    final opponentId = battle.opponentIdFor(myUserId);
    if (opponentId == null) return null;
    return FirebaseFirestoreController.instance.users
        .firstWhereOrNull((u) => u.userId == opponentId);
  }

  @override
  void onInit() {
    super.onInit();
    _fetchBattles();
  }

  Future<void> _fetchBattles() async {
    isLoading.value = true;
    try {
      final snapshot = await db
          .collection(FirebaseConst.battleHistory)
          .where('participant_host_ids', arrayContains: myUserId)
          .orderBy('battle_ended_at', descending: true)
          .limit(100)
          .get();
      battles.value = snapshot.docs
          .map((doc) => BattleResult.fromJson(doc.data()))
          .toList();
    } catch (e) {
      Loggers.error('Failed to fetch battle history: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
