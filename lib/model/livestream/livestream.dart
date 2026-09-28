import 'package:get/get.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/utilities/app_res.dart';

class Livestream {
  int? watchingCount;
  String? description;
  LivestreamType? type;
  BattleType? battleType;
  int battleDuration = AppRes.battleDurationInMinutes;
  int? isRestrictToJoin;
  int? hostViewID;
  String? roomID;
  int? likeCount;
  int? hostId;
  List<int>? coHostIds;
  AppUser? hostUser;
  List<AppUser>? coHostUsers;
  int? createdAt;
  int? lastHeartbeatAt;
  int? battleCreatedAt;
  int? isDummyLive;
  String? dummyUserLink;
  bool commentsEnabled = true;

  // Live Goal fields
  bool? hasLiveGoal;
  String? liveGoalTitle;
  String? liveGoalType;
  int? liveGoalTargetAmount;
  int? liveGoalCurrentAmount;

  // Gift Goals: up to a few simultaneous per-gift targets the host can set,
  // one of which can be "pinned" to feature on screen. Separate from the
  // single Live Goal above, which tracks one overall follower/like/duration
  // target for the whole stream.
  List<GiftGoal>? giftGoals;

  Livestream({
    this.watchingCount,
    this.description,
    this.type,
    this.battleType,
    this.isRestrictToJoin,
    this.hostViewID,
    this.roomID,
    this.likeCount,
    this.hostId,
    this.coHostIds,
    this.createdAt,
    this.lastHeartbeatAt,
    this.battleCreatedAt,
    this.isDummyLive,
    this.dummyUserLink,
    this.commentsEnabled = true,
    this.battleDuration = AppRes.battleDurationInMinutes,
    this.hasLiveGoal,
    this.liveGoalTitle,
    this.liveGoalType,
    this.liveGoalTargetAmount,
    this.liveGoalCurrentAmount,
    this.giftGoals,
  });

  Livestream.fromJson(Map<String, dynamic> json) {
    type = LivestreamType.fromString(json['type']);
    battleType = BattleType.fromString(json['battle_type']);
    watchingCount = json['watching_count'];
    description = json['description'];
    isRestrictToJoin = json['is_restrict_to_join'];
    hostViewID = json['host_view_id'];
    roomID = json['room_id'];
    likeCount = json['like_count'];
    hostId = json['host_id'];
    coHostIds =
        json['co-host_ids'] != null ? json['co-host_ids'].cast<int>() : [];
    createdAt = json['created_at'];
    lastHeartbeatAt = json['last_heartbeat_at'];
    battleCreatedAt = json['battle_created_at'];
    isDummyLive = json['is_dummy_live'];
    dummyUserLink = json['dummy_user_link'];
    commentsEnabled = json['comments_enabled'] ?? true;
    battleDuration = json['battle_duration'] ?? AppRes.battleDurationInMinutes;
    hasLiveGoal = json['has_live_goal'];
    liveGoalTitle = json['live_goal_title'];
    liveGoalType = json['live_goal_type'];
    liveGoalTargetAmount = json['live_goal_target_amount'];
    liveGoalCurrentAmount = json['live_goal_current_amount'];
    giftGoals = (json['gift_goals'] as List<dynamic>?)
        ?.map((e) => GiftGoal.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['watching_count'] = watchingCount;
    data['description'] = description;
    data['type'] = type?.value;
    data['battle_type'] = battleType?.value;
    data['is_restrict_to_join'] = isRestrictToJoin;
    data['host_view_id'] = hostViewID;
    data['room_id'] = roomID;
    data['like_count'] = likeCount;
    data['host_id'] = hostId;
    data['co-host_ids'] = coHostIds;
    data['created_at'] = createdAt;
    data['last_heartbeat_at'] = lastHeartbeatAt;
    data['battle_created_at'] = battleCreatedAt;
    data['is_dummy_live'] = isDummyLive;
    data['dummy_user_link'] = dummyUserLink;
    data['comments_enabled'] = commentsEnabled;
    data['battle_duration'] = battleDuration;
    data['has_live_goal'] = hasLiveGoal;
    data['live_goal_title'] = liveGoalTitle;
    data['live_goal_type'] = liveGoalType;
    data['live_goal_target_amount'] = liveGoalTargetAmount;
    data['live_goal_current_amount'] = liveGoalCurrentAmount;
    data['gift_goals'] = giftGoals?.map((e) => e.toJson()).toList();
    return data;
  }

  List<AppUser> getAllUsers(List<AppUser> users) {
    AppUser? hostUser = users.firstWhereOrNull(
      (element) => element.userId == hostId,
    );
    final coHostUsers = coHostIds
            ?.map((id) => users.firstWhereOrNull((user) => user.userId == id))
            .whereType<AppUser>()
            .toList() ??
        [];

    final allUsers = [if (hostUser != null) hostUser, ...coHostUsers];
    return allUsers;
  }

  AppUser? getHostUser(List<AppUser> users) {
    final controller = Get.find<FirebaseFirestoreController>();
    AppUser? hostUser = controller.users.firstWhereOrNull(
      (element) => element.userId == hostId,
    );
    return hostUser;
  }

  List<AppUser> getCoHostUsers(List<AppUser> users) {
    final coHostUsers = coHostIds
            ?.map((id) => users.firstWhereOrNull((user) => user.userId == id))
            .whereType<AppUser>()
            .toList() ??
        [];
    return coHostUsers;
  }
}

enum LivestreamType {
  livestream('LIVESTREAM'),
  battle('BATTLE'),
  dummy('DUMMY');

  final String value;

  const LivestreamType(this.value);

  static LivestreamType fromString(String value) {
    return LivestreamType.values.firstWhereOrNull((e) => e.value == value) ??
        LivestreamType.livestream;
  }
}

enum BattleType {
  initiate('INITIATE'),
  waiting('WAITING'),
  running('RUNNING'),
  end('END');

  final String value;

  const BattleType(this.value);

  static BattleType fromString(String? value) {
    return BattleType.values.firstWhereOrNull((e) => e.value == value) ??
        BattleType.initiate;
  }
}

/// A single "send this specific gift N times" target the host can set up
/// before or during a LIVE. Several can run at once; [isPinned] marks the
/// one currently featured on screen.
class GiftGoal {
  String id;
  int giftId;
  int giftCoinPrice;
  int targetCount;
  int currentCount;
  bool isPinned;
  List<int> contributorIds;

  GiftGoal({
    required this.id,
    required this.giftId,
    required this.giftCoinPrice,
    required this.targetCount,
    this.currentCount = 0,
    this.isPinned = false,
    this.contributorIds = const [],
  });

  factory GiftGoal.fromJson(Map<String, dynamic> json) {
    return GiftGoal(
      id: json['id'] ?? '',
      giftId: json['gift_id'] ?? 0,
      giftCoinPrice: json['gift_coin_price'] ?? 0,
      targetCount: json['target_count'] ?? 0,
      currentCount: json['current_count'] ?? 0,
      isPinned: json['is_pinned'] ?? false,
      contributorIds: (json['contributor_ids'] as List<dynamic>? ?? [])
          .whereType<num>()
          .map((e) => e.toInt())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gift_id': giftId,
      'gift_coin_price': giftCoinPrice,
      'target_count': targetCount,
      'current_count': currentCount,
      'is_pinned': isPinned,
      'contributor_ids': contributorIds,
    };
  }

  bool get isCompleted => currentCount >= targetCount && targetCount > 0;
}
