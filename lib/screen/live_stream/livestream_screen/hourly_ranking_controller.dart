import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/model/livestream/app_user.dart';

/// One host's position in this hour's LIVE ranking. Structurally identical
/// to [LiveRankEntry] (see live_ranking_controller.dart) — kept as its own
/// small class rather than shared so the hourly and daily rankings stay
/// fully independent collections/models, matching how TikTok treats them as
/// two separate leaderboards rather than one re-keyed by different windows.
class HourlyRankEntry {
  final int hostId;
  final int coins;
  final int gifts;
  final AppUser? user;

  const HourlyRankEntry({
    required this.hostId,
    required this.coins,
    required this.gifts,
    this.user,
  });

  factory HourlyRankEntry.fromJson(Map<String, dynamic> json) {
    return HourlyRankEntry(
      hostId: (json['host_id'] as num?)?.toInt() ?? -1,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      gifts: (json['gifts'] as num?)?.toInt() ?? 0,
      user: json['user'] is Map<String, dynamic>
          ? AppUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Hourly LIVE ranking backed by Firestore — the exact same shape as
/// [LiveRankingController]'s daily ranking, just keyed by hour instead of
/// day. Every gift sent to a host during a LIVE is added to
/// `live_rankings_hourly/{yyyy-MM-dd-HH}/hosts/{hostId}` (coins received this
/// hour). The document resets naturally each hour because the hour is part
/// of the path — same trick the daily ranking already relies on, just
/// watched more often since hour boundaries roll over much faster than day
/// boundaries.
class HourlyRankingController extends GetxController {
  static const String collection = 'live_rankings_hourly';
  static const int maxEntries = 100;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final int hostId;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listener;
  Timer? _hourWatchTimer;
  String _listeningHour = '';

  final RxList<HourlyRankEntry> entries = <HourlyRankEntry>[].obs;

  /// 1-based rank of [hostId] this hour, 0 when the host has not received
  /// gifts yet this hour.
  final RxInt hostRank = 0.obs;
  final RxInt hostCoins = 0.obs;
  final RxBool isLoaded = false.obs;

  HourlyRankingController(this.hostId);

  static String hourKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}-${d.hour.toString().padLeft(2, '0')}';
  }

  static CollectionReference<Map<String, dynamic>> hostsRef(
      FirebaseFirestore db,
      [String? hour]) {
    return db.collection(collection).doc(hour ?? hourKey()).collection('hosts');
  }

  /// Adds [coins] to the host's total for this hour. Safe to call from any
  /// participant (sender side) so the ranking updates instantly.
  static Future<void> recordGift({
    required int? hostId,
    required int coins,
    AppUser? host,
  }) async {
    if (hostId == null || coins <= 0) return;
    try {
      await hostsRef(FirebaseFirestore.instance).doc('$hostId').set({
        'host_id': hostId,
        'coins': FieldValue.increment(coins),
        'gifts': FieldValue.increment(1),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        if (host != null) 'user': host.toJson(),
      }, SetOptions(merge: true));
    } catch (e) {
      Loggers.error('Failed to record hourly LIVE ranking gift: $e');
    }
  }

  @override
  void onInit() {
    super.onInit();
    _listen();
    // Re-subscribe when the calendar hour changes mid-stream. Checked every
    // 30s (vs. the daily ranking's 1 minute) since an hour boundary can be
    // missed for up to a full check interval otherwise, and hours roll over
    // 24x more often than days.
    _hourWatchTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (hourKey() != _listeningHour) _listen();
    });
  }

  @override
  void onClose() {
    _listener?.cancel();
    _hourWatchTimer?.cancel();
    super.onClose();
  }

  void _listen() {
    _listener?.cancel();
    _listeningHour = hourKey();
    _listener = hostsRef(_db, _listeningHour)
        .orderBy('coins', descending: true)
        .limit(maxEntries)
        .snapshots()
        .listen((snapshot) {
      final items = snapshot.docs
          .map((doc) => HourlyRankEntry.fromJson(doc.data()))
          .where((entry) => entry.hostId != -1)
          .toList();
      entries.assignAll(items);
      final index = items.indexWhere((e) => e.hostId == hostId);
      hostRank.value = index == -1 ? 0 : index + 1;
      hostCoins.value = index == -1 ? 0 : items[index].coins;
      isLoaded.value = true;
    }, onError: (e) {
      Loggers.error('Hourly LIVE ranking listen error: $e');
      isLoaded.value = true;
    });
  }
}
