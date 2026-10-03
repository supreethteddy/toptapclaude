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
  });

  factory LivestreamUserState.fromJson(Map<String, dynamic> json) {
    return LivestreamUserState(
      isMuted: json['is_muted'] ?? false,
      isVideoOn: json['is_video_on'] ?? true,
      type: LivestreamUserType.fromString(json['type'] ?? ''),
      invitedRole: LivestreamUserType.fromStringOrNull(json['invited_role']),
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

/// Two on-stage roles besides the host, and they are NOT interchangeable:
/// [coHost] is a Co-host Mode participant (max 4 in frame incl. host) — the
/// only role that can be a PK player; [guest] is a Guest Call participant
/// (the request-to-join flow, up to 9) and is never offered PK. The client
/// requires participants to be identified by this role, not by whether they
/// happen to be visible on screen.
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

  /// Publishing a camera/mic stream in the room (host, co-host or guest).
  bool get isOnStage => this == host || this == coHost || this == guest;

  /// The two roles a host can invite someone into.
  bool get isStageRole => this == coHost || this == guest;
}
