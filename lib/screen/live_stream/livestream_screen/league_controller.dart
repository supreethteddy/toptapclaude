import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/model/livestream/app_user.dart';

/// One host's position within their own division of the current season's
/// League. Scoped to a single division (not the whole League) — see
/// [LeagueController._listenStandings].
class LeagueEntry {
  final int hostId;
  final int coins;
  final AppUser? user;

  const LeagueEntry({required this.hostId, required this.coins, this.user});

  factory LeagueEntry.fromJson(Map<String, dynamic> json) {
    return LeagueEntry(
      hostId: (json['host_id'] as num?)?.toInt() ?? -1,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      user: json['user'] is Map<String, dynamic>
          ? AppUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Weekly competitive League: hosts sit in one of 12 divisions (lowest to
/// highest: D3, D2, D1, C3, C2, C1, B3, B2, B1, A3, A2, A1 — matching the
/// "League A1" badge in the TikTok reference this feature is modelled on),
/// ranked within their division by coins received that week. At the end of
/// each week the top of each division is promoted a band and the bottom is
/// demoted, then everyone's coins reset to 0 for the new week.
///
/// Storage: `leagues/{seasonKey}/hosts/{hostId}` — the exact same shape as
/// [LiveRankingController]'s daily ranking, just with an extra `division`
/// field. The parent `leagues/{seasonKey}` document is otherwise unused by
/// gifting — it exists only so the rollover below has somewhere to record
/// "this week has already been rolled into the next one", guarding against
/// two clients both trying to roll the same week over at once.
///
/// [seasonKey] buckets time into rolling 7-day windows from a fixed Monday
/// epoch (day-count division, not literal ISO-8601 week numbers) — simpler
/// than calendar ISO weeks to compute correctly across year boundaries,
/// while still rolling over on a predictable 7-day cadence.
class LeagueController extends GetxController {
  static const String collection = 'leagues';
  static const int maxEntries = 100;

  /// How many top/bottom hosts move a band at each week's rollover. A
  /// division with too few hosts to split meaningfully (<= promoteCount)
  /// just promotes everyone in it instead of also trying to demote from the
  /// same handful of hosts — see [_maybeRolloverSeason].
  static const int promoteCount = 3;
  static const int demoteCount = 3;

  static const List<String> divisionLadder = [
    'D3', 'D2', 'D1',
    'C3', 'C2', 'C1',
    'B3', 'B2', 'B1',
    'A3', 'A2', 'A1',
  ];

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final int hostId;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _myDocListener;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _standingsListener;
  Timer? _seasonWatchTimer;
  String _listeningSeason = '';

  final RxString division = divisionLadder.first.obs;
  final RxInt hostCoins = 0.obs;
  final RxInt hostRank = 0.obs;
  final RxList<LeagueEntry> entries = <LeagueEntry>[].obs;
  final RxBool isLoaded = false.obs;

  LeagueController(this.hostId);

  static final DateTime _weekEpoch = DateTime.utc(2020, 1, 6); // a Monday

  static String seasonKey([DateTime? date]) {
    final d = (date ?? DateTime.now()).toUtc();
    final weekIndex = d.difference(_weekEpoch).inDays ~/ 7;
    return 'season_$weekIndex';
  }

  static DocumentReference<Map<String, dynamic>> _seasonDocRef(
      FirebaseFirestore db, String key) {
    return db.collection(collection).doc(key);
  }

  static CollectionReference<Map<String, dynamic>> hostsRef(
      FirebaseFirestore db,
      [String? season]) {
    return _seasonDocRef(db, season ?? seasonKey()).collection('hosts');
  }

  /// Adds [coins] to the host's total for this week. A brand new host (no
  /// doc yet, in any season) is seeded into the lowest division; an
  /// existing host's division is left untouched here — it only ever
  /// changes at [_maybeRolloverSeason].
  static Future<void> recordGift({
    required int? hostId,
    required int coins,
    AppUser? host,
  }) async {
    if (hostId == null || coins <= 0) return;
    final ref = hostsRef(FirebaseFirestore.instance).doc('$hostId');
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final base = {
          'host_id': hostId,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          if (host != null) 'user': host.toJson(),
        };
        if (!snap.exists) {
          tx.set(ref, {
            ...base,
            'coins': coins,
            'division': divisionLadder.first,
          });
        } else {
          tx.set(
            ref,
            {...base, 'coins': FieldValue.increment(coins)},
            SetOptions(merge: true),
          );
        }
      });
    } catch (e) {
      Loggers.error('Failed to record League gift: $e');
    }
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_maybeRolloverSeason());
    _watchMyDoc();
    _seasonWatchTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (seasonKey() != _listeningSeason) {
        unawaited(_maybeRolloverSeason());
        _watchMyDoc();
      }
    });
  }

  @override
  void onClose() {
    _myDocListener?.cancel();
    _standingsListener?.cancel();
    _seasonWatchTimer?.cancel();
    super.onClose();
  }

  void _watchMyDoc() {
    _myDocListener?.cancel();
    _listeningSeason = seasonKey();
    final myRef = hostsRef(_db, _listeningSeason).doc('$hostId');
    _myDocListener = myRef.snapshots().listen((snap) {
      final data = snap.data();
      final myDivision = data?['division'] as String? ?? divisionLadder.first;
      hostCoins.value = (data?['coins'] as num?)?.toInt() ?? 0;
      if (division.value != myDivision || _standingsListener == null) {
        division.value = myDivision;
        _listenStandings(myDivision);
      }
    }, onError: (e) => Loggers.error('League my-doc listen error: $e'));
  }

  void _listenStandings(String forDivision) {
    _standingsListener?.cancel();
    _standingsListener = hostsRef(_db, _listeningSeason)
        .where('division', isEqualTo: forDivision)
        .orderBy('coins', descending: true)
        .limit(maxEntries)
        .snapshots()
        .listen((snapshot) {
      final items = snapshot.docs
          .map((doc) => LeagueEntry.fromJson(doc.data()))
          .where((entry) => entry.hostId != -1)
          .toList();
      entries.assignAll(items);
      final index = items.indexWhere((e) => e.hostId == hostId);
      hostRank.value = index == -1 ? 0 : index + 1;
      isLoaded.value = true;
    }, onError: (e) {
      Loggers.error('League standings listen error: $e');
      isLoaded.value = true;
    });
  }

  /// Best-effort, client-triggered season rollover: whichever client happens
  /// to open a LIVE first after a week boundary performs it once, guarded by
  /// [prevSeasonRef]'s existence acting as a "already rolled over" flag that
  /// only this method ever writes. Two clients racing both compute the same
  /// promotion/relegation result from the same (pre-boundary) data, but only
  /// one's transaction commits — the other's re-read inside the transaction
  /// sees the flag already set and bails. There is no server-side cron in
  /// this app to do this instead; see the Phase 4 plan for that caveat.
  Future<void> _maybeRolloverSeason() async {
    final now = DateTime.now();
    final prevKey = seasonKey(now.subtract(const Duration(days: 7)));
    final curKey = seasonKey(now);
    if (prevKey == curKey) return;

    final prevSeasonRef = _seasonDocRef(_db, prevKey);
    try {
      final prevSnap = await prevSeasonRef.get();
      if (prevSnap.exists) return; // already rolled over

      final hostsSnap = await hostsRef(_db, prevKey).get();
      if (hostsSnap.docs.isEmpty) return; // nothing happened last week

      final byDivision = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
      for (final doc in hostsSnap.docs) {
        final div = doc.data()['division'] as String? ?? divisionLadder.first;
        byDivision.putIfAbsent(div, () => []).add(doc);
      }

      final newDivisionByHostId = <String, String>{};
      byDivision.forEach((div, docs) {
        docs.sort((a, b) => (((b.data()['coins']) as num?) ?? 0)
            .compareTo(((a.data()['coins']) as num?) ?? 0));
        final divIndex = divisionLadder.indexOf(div);
        final n = docs.length;
        for (var i = 0; i < n; i++) {
          int newIndex = divIndex;
          if (n <= promoteCount) {
            newIndex = divIndex + 1;
          } else if (i < promoteCount) {
            newIndex = divIndex + 1;
          } else if (i >= n - demoteCount) {
            newIndex = divIndex - 1;
          }
          newDivisionByHostId[docs[i].id] =
              divisionLadder[newIndex.clamp(0, divisionLadder.length - 1)];
        }
      });

      await _db.runTransaction((tx) async {
        final recheck = await tx.get(prevSeasonRef);
        if (recheck.exists) return;
        tx.set(prevSeasonRef, {
          'rolled_over': true,
          'rolled_over_at': DateTime.now().millisecondsSinceEpoch,
        });
        final newHostsRef = hostsRef(_db, curKey);
        newDivisionByHostId.forEach((hostId, newDivision) {
          // merge: true — seeds `division` for a host with no new-season
          // doc yet, or nudges an existing one's division without
          // clobbering coins they may have already earned this week before
          // this rollover ran.
          tx.set(newHostsRef.doc(hostId), {'division': newDivision},
              SetOptions(merge: true));
        });
      });
    } catch (e) {
      Loggers.error('League season rollover failed: $e');
    }
  }
}
