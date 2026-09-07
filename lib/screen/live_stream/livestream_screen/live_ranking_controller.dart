import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/model/livestream/app_user.dart';

/// One host's position in today's LIVE ranking.
class LiveRankEntry {
  final int hostId;
  final int coins;
  final int gifts;
  final AppUser? user;

  const LiveRankEntry({
    required this.hostId,
    required this.coins,
    required this.gifts,
    this.user,
  });

  factory LiveRankEntry.fromJson(Map<String, dynamic> json) {
    return LiveRankEntry(
      hostId: (json['host_id'] as num?)?.toInt() ?? -1,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      gifts: (json['gifts'] as num?)?.toInt() ?? 0,
      user: json['user'] is Map<String, dynamic>
          ? AppUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Daily LIVE ranking backed by Firestore.
///
/// Every gift sent to a host during a LIVE is added to
/// `live_rankings/{yyyy-MM-dd}/hosts/{hostId}` (coins received today).
/// The ranking is the list of hosts ordered by coins, and a host's own rank is
/// their 1-based index in that list. The document resets naturally each day
/// because the day is part of the path.
class LiveRankingController extends GetxController {
  static const String collection = 'live_rankings';
  static const int maxEntries = 100;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final int hostId;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listener;
  Timer? _dayWatchTimer;
  String _listeningDay = '';

  final RxList<LiveRankEntry> entries = <LiveRankEntry>[].obs;

  /// 1-based rank of [hostId] today, 0 when the host has not received gifts.
  final RxInt hostRank = 0.obs;
  final RxInt hostCoins = 0.obs;
  final RxBool isLoaded = false.obs;

  LiveRankingController(this.hostId);

  static String dayKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static CollectionReference<Map<String, dynamic>> hostsRef(
      FirebaseFirestore db,
      [String? day]) {
    return db.collection(collection).doc(day ?? dayKey()).collection('hosts');
  }

  /// Adds [coins] to the host's total for today. Safe to call from any
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
      Loggers.error('Failed to record LIVE ranking gift: $e');
    }
  }

  @override
  void onInit() {
    super.onInit();
    _listen();
    // Re-subscribe when the calendar day changes mid-stream.
    _dayWatchTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (dayKey() != _listeningDay) _listen();
    });
  }

  @override
  void onClose() {
    _listener?.cancel();
    _dayWatchTimer?.cancel();
    super.onClose();
  }

  void _listen() {
    _listener?.cancel();
    _listeningDay = dayKey();
    _listener = hostsRef(_db, _listeningDay)
        .orderBy('coins', descending: true)
        .limit(maxEntries)
        .snapshots()
        .listen((snapshot) {
      final items = snapshot.docs
          .map((doc) => LiveRankEntry.fromJson(doc.data()))
          .where((entry) => entry.hostId != -1)
          .toList();
      entries.assignAll(items);
      final index = items.indexWhere((e) => e.hostId == hostId);
      hostRank.value = index == -1 ? 0 : index + 1;
      hostCoins.value = index == -1 ? 0 : items[index].coins;
      isLoaded.value = true;
    }, onError: (e) {
      Loggers.error('LIVE ranking listen error: $e');
      isLoaded.value = true;
    });
  }
}
