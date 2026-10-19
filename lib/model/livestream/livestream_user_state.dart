import 'package:get/get.dart';
import 'package:shortzz/model/livestream/app_user.dart';

class LivestreamUserState {
  bool isMuted;
  bool isVideoOn;
  LivestreamUserType type;
  int userId;
  int liveCoin;
  int currentBattleCoin;
  int totalBattleCoin;
  List<int> followersGained;
  int joinStreamTime;
  AppUser? user;

  /// Which on-stage role an INVITED user was invited into (CO-HOST or GUEST),
  /// so accepting lands them in the right one. Null for every other state.
  LivestreamUserType? invitedRole;

  /// 2v2 Co-Host PK only: 'A'/'B', which side this person's whole
  /// independently-live room is on. Lets a tile render "Team A · Partner:
  /// @name" without re-deriving it from the room docs' coHostTeammateRoomId
  /// chain at render time. Null outside an active 2v2 match.
  String? pkTeamSlot;

  LivestreamUserState({
    required this.isMuted,
    required this.isVideoOn,
    required this.type,
    required this.userId,
    required this.liveCoin,
    required this.currentBattleCoin,
    required this.totalBattleCoin,
    required this.followersGained,
    required this.joinStreamTime,
    this.user,
    this.invitedRole,
    this.pkTeamSlot,
  });

  factory LivestreamUserState.fromJson(Map<String, dynamic> json) {
    return LivestreamUserState(
      isMuted: json['is_muted'] ?? false,
      isVideoOn: json['is_video_on'] ?? true,
      type: LivestreamUserType.fromString(json['type'] ?? ''),
      invitedRole: LivestreamUserType.fromStringOrNull(json['invited_role']),
      pkTeamSlot: json['pk_team_slot'],
      userId: json['user_id'] ?? 0,
      liveCoin: json['live_coin'] ?? 0,
      currentBattleCoin: json['current_battle_coin'] ?? 0,
      totalBattleCoin: json['total_battle_coin'] ?? 0,
      followersGained: (json['followers_gained'] as List<dynamic>? ?? [])
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(),
      joinStreamTime: json['join_stream_time'] ?? 0,
      user: json['user'] != null ? AppUser.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_muted': isMuted,
      'is_video_on': isVideoOn,
      'type': type.value,
      'user_id': userId,
      'live_coin': liveCoin,
      'current_battle_coin': currentBattleCoin,
      'total_battle_coin': totalBattleCoin,
      'followers_gained': followersGained,
      'join_stream_time': joinStreamTime,
      if (invitedRole != null) 'invited_role': invitedRole!.value,
      if (pkTeamSlot != null) 'pk_team_slot': pkTeamSlot,
      if (user != null) 'user': user?.toJson(),
    };
  }

  AppUser? getUser(List<AppUser> users) {
    return users.firstWhereOrNull((element) => element.userId == userId);
  }

  int get totalCoin {
    return totalBattleCoin + liveCoin;
  }
}

/// [coHost] is RETIRED as an in-room role (kept only so fromString/historical
/// Firestore docs and battle-history records still parse) — the client's
/// binding clarification is that "Co-host" means connecting two separate,
/// independently-live rooms together (see opponentRoomId on the Livestream
/// model), never an in-room seat. A mistake in an earlier build let an
/// in-room participant become PK-eligible via this role; PK is now reachable
/// ONLY through that cross-room connection, never through any in-room role.
/// [guest] is the one remaining in-room role (the request-to-join/invite
/// flow, up to 8) — never PK-eligible, same as before. Participants are
/// identified by this role, not by whether they happen to be visible on
/// screen.
enum LivestreamUserType {
  host('HOST'),
  coHost('CO-HOST'),
  guest('GUEST'),
  audience('AUDIENCE'),
  requested('REQUESTED'),
  invited('INVITED'),
  left('LEFT');

  final String value;

  const LivestreamUserType(this.value);

  static LivestreamUserType fromString(String value) {
    return LivestreamUserType.values.firstWhereOrNull(
          (e) => e.value == value,
        ) ??
        LivestreamUserType.audience;
  }

  static LivestreamUserType? fromStringOrNull(String? value) {
    if (value == null || value.isEmpty) return null;
    return LivestreamUserType.values.firstWhereOrNull((e) => e.value == value);
  }

  /// Publishing a camera/mic stream in the room (host, guest, or a
  /// pre-migration legacy co-host doc still on stage from before the role
  /// was retired -- never assign coHost to a new participant, but don't
  /// treat an old one as suddenly off-stage either).
  bool get isOnStage => this == host || this == coHost || this == guest;

  /// The only role a host can invite someone into now. (coHost deliberately
  /// excluded -- see the enum doc comment.)
  bool get isStageRole => this == guest;
}
