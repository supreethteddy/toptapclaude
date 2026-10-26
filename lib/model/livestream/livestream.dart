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
  // Co-host Mode participants (PK-eligible, max Setting.maxLiveCohosts).
  List<int>? coHostIds;
  // Guest Call participants (never PK players, max Setting.maxLiveGuests).
  List<int>? guestIds;
  // Seats reserved by accepted-but-not-yet-publishing invitees so two
  // accepters can't both take the last seat; cleared once they publish or
  // leave.
  List<int>? pendingSeatIds;
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

  // How this LIVE is being broadcast. 'GAMING' (mobile screen capture) is
  // modeled but not selectable yet — no native screen-capture support.
  BroadcastMode? broadcastMode;

  // Fan Club: free, opt-in membership viewers can join when the host turns
  // this on for a LIVE. No payment involved — see ManageFanClubScreen.
  bool? hasFanClub;
  String? fanClubPerks;

  // Interact (Poll): a single live question/options poll the host can run at
  // a time. Cleared/replaced when a new one starts; not archived after.
  LivePoll? poll;

  // Cross-room PK Battle: unlike the same-room co-host battle (BattleType
  // above, which scores a guest already in this room), this pits this whole
  // room (host + any co-hosts — naturally 2v2 when both sides already have a
  // co-host) against a second, independently-run LIVE room. No multi-room
  // Zego login needed — the SDK supports playing a stream from another room
  // under the same AppID directly.
  String? opponentRoomId;

  // Co-Host Connection: [opponentRoomId] now means "connected to this other
  // independently-live room" on its own -- it no longer implies a battle is
  // running (see the client's binding Guest-vs-Co-host clarification: a
  // Co-Host connection and a PK Match are two separate, explicit steps).
  // When this was established, so the UI can show "connected Xm ago".
  // Cleared only by exitCoHostConnection(), never by a battle ending.
  int? coHostConnectedAt;

  // Set on THIS room's doc (the invitee) while a cross-room Co-Host CONNECT
  // invite from [pendingBattleInviteFromId] is awaiting accept/decline.
  // (Field name kept from the original same-concept cross-room invite --
  // accepting it now only connects, see acceptCoHostConnectInvite(); it no
  // longer also starts a battle.)
  int? pendingBattleInviteFromId;

  // When the invite above was sent (ms epoch) — lets both the inviter's and
  // invitee's device independently compute whether it's past
  // AppRes.battleInviteExpiryInSecond without needing a server timer.
  int? battleInviteSentAt;

  // Client spec 3.2: "If Declined or Expired... Notify the inviter." Set on
  // THIS room's doc (the inviter's own) once their sent invite/request is
  // declined or expires elsewhere -- see declineCoHostConnectInvite /
  // declinePkMatchRequest. Value is the declining host's id; cleared by the
  // inviter's own device right after showing the notice.
  int? coHostConnectInviteDeclinedFor;
  int? pkMatchRequestDeclinedFor;

  // "Play PK Match" request: set on the OTHER connected co-host's doc once
  // this room's host taps Play PK Match. The battle itself only starts once
  // that other host accepts (acceptPkMatch()) -- same accept/decline/expiry
  // shape as the connect invite above, just for the separate "start a
  // battle on an already-connected pair" step.
  int? pendingPkMatchRequestFromId;
  int? pkMatchRequestSentAt;

  // Written the moment a battle ends (battleType -> END), for same-room and
  // cross-room alike -- the shared reference point postBattlePhaseFor
  // (pk_scores.dart) computes the post-match display phase from. Nulled
  // again once the arena fully resets. The co-host CONNECTION is untouched
  // by this, only the battle-result chrome.
  int? battleEndedAt;

  // 2v2 team assembly: a second independently-live room that joined THIS
  // room's team (null in 1v1). Symmetric -- the teammate's own doc points
  // back here. Kept separate from [opponentRoomId], which always stays
  // "my primary opponent", so existing 1v1 code paths don't need to change
  // shape to support this.
  String? coHostTeammateRoomId;
  // The opposing team's room ids beyond the primary [opponentRoomId] --
  // empty/null in 1v1, one extra entry in 2v2.
  List<String>? coHostOpponentTeamRoomIds;
  // Explicit rather than inferred from list lengths, since those lengths
  // can be transiently asymmetric mid-teammate-invite.
  String? pkMode; // '1v1' | '2v2'

  // Four-person Team PK (client spec Module 6): a pending "join my team as
  // teammate" invite, set on the INVITEE's own doc -- same shape as
  // pendingBattleInviteFromId/battleInviteSentAt above, just for this
  // separate relationship.
  int? pendingTeammateInviteFromId;
  int? teammateInviteSentAt;
  // Client spec 3.2's "notify the inviter" rule, extended to this invite
  // type -- set on the ORIGINAL SENDER's own doc once declined/expired.
  int? teammateInviteDeclinedFor;

  // Same shape as [pendingBattleInviteFromId], written after a battle has
  // ended rather than before one starts — the other host requested a
  // rematch and it's awaiting accept/decline on THIS room's doc.
  int? pendingRematchFromId;

  // PK Battle rounds: how many rounds each side has won across the current
  // multi-round match. Cleared only when the whole match ends (Stop), not
  // between individual rounds (Next Round). Cross-room battles use
  // [battleRoundWins] — this room's own side, the opponent's is read from
  // their own doc via opponentLiveData; same-room co-host battles use the
  // host/co-host pair since both sides live on this one doc.
  int? battleRoundWins;
  int? battleRoundWinsHost;
  int? battleRoundWinsCoHost;

  // Fixed round count per match ("Round 1/2") and the room-wide "first
  // gift" bonus window — both reset at the start of every round.
  int? battleTotalRounds;
  int? battleCurrentRound;
  bool? firstGiftBonusClaimed;

  // Same-room co-host PK Match invitation (Co-host Mode only — never a
  // Guest Call participant). Unlike the cross-room invite above, both sides
  // of the negotiation live on this one room doc: the host proposes teams,
  // every non-host player named in them must accept before the host's own
  // device promotes this into an active battle ([pkTeamAIds]/[pkTeamBIds]
  // below). `null` means no invite is pending.
  int? pkInviteFromId;
  List<int>? pkInviteTeamAIds;
  List<int>? pkInviteTeamBIds;
  // null = every gift counts toward the match score.
  List<int>? pkInviteEligibleGiftIds;
  int? pkInviteDurationMin;
  int? pkInviteSentAt;
  // Starts empty; each non-host player on a team appends their own id once
  // they accept. The host is not included — sending the invite is their
  // consent.
  List<int>? pkInviteAcceptedIds;

  // The negotiated teams for the PK Match currently in progress (or just
  // ended), promoted from the pk_invite_* fields above once every required
  // player accepted. The source of truth for team membership/scoring/like
  // attribution — never inferred from on-screen tile order.
  List<int>? pkTeamAIds;
  List<int>? pkTeamBIds;
  List<int>? pkEligibleGiftIds;

  // Likes tapped on each half of the screen during the match above, reset
  // to 0 at the start of every match/round (see onLikeButtonTap).
  int? pkLikePointsA;
  int? pkLikePointsB;

  // Cross-room Co-Host PK only -- unlike pkLikePointsA/B (one doc holds
  // both sides' counts, since a same-room match's two teams share a single
  // Livestream doc), a cross-room battle is two separate docs, so this
  // field holds ONLY this room's own side's like count; the opponent
  // room's doc carries its own copy the same way. Reset to 0 at the start
  // of every cross-room match (see acceptPkMatch/acceptRematch).
  int? crossRoomLikePoints;

  // Speed Challenge: during minute 2-3 of a Co-Host PK battle, eligible
  // gifts contribute 3x their normal value to the PK score ONLY (never to
  // actual coin/earnings -- see speedChallengeMultiplierFor()). null/empty
  // = every gift is eligible, same null-means-all convention as
  // [pkEligibleGiftIds] above.
  List<int>? speedChallengeEligibleGiftIds;

  // Single pinned comment slot (client spec 14.2) — only ever one at a time;
  // pinning another comment replaces this field rather than appending to a
  // list, same "one slot, newest wins" semantics as the ordinary feed-post
  // pin feature (AppRes.maxPinComment == 1) this mirrors. null = nothing
  // pinned. Lives directly on the room doc rather than as a flag on the
  // comment itself, since a comment doc's own lifecycle (deleted once the
  // join-request flow clears it, for example) shouldn't be able to silently
  // unpin something still worth showing.
  PinnedComment? pinnedComment;

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
    this.guestIds,
    this.pendingSeatIds,
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
    this.broadcastMode,
    this.hasFanClub,
    this.fanClubPerks,
    this.poll,
    this.opponentRoomId,
    this.coHostConnectedAt,
    this.pendingBattleInviteFromId,
    this.battleInviteSentAt,
    this.coHostConnectInviteDeclinedFor,
    this.pkMatchRequestDeclinedFor,
    this.pendingPkMatchRequestFromId,
    this.pkMatchRequestSentAt,
    this.battleEndedAt,
    this.coHostTeammateRoomId,
    this.coHostOpponentTeamRoomIds,
    this.pkMode,
    this.pendingTeammateInviteFromId,
    this.teammateInviteSentAt,
    this.teammateInviteDeclinedFor,
    this.pendingRematchFromId,
    this.battleRoundWins,
    this.battleRoundWinsHost,
    this.battleRoundWinsCoHost,
    this.battleTotalRounds,
    this.battleCurrentRound,
    this.firstGiftBonusClaimed,
    this.pkInviteFromId,
    this.pkInviteTeamAIds,
    this.pkInviteTeamBIds,
    this.pkInviteEligibleGiftIds,
    this.pkInviteDurationMin,
    this.pkInviteSentAt,
    this.pkInviteAcceptedIds,
    this.pkTeamAIds,
    this.pkTeamBIds,
    this.pkEligibleGiftIds,
    this.pkLikePointsA,
    this.pkLikePointsB,
    this.crossRoomLikePoints,
    this.speedChallengeEligibleGiftIds,
    this.pinnedComment,
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
    guestIds = json['guest_ids'] != null ? json['guest_ids'].cast<int>() : [];
    pendingSeatIds = json['pending_seat_ids'] != null
        ? json['pending_seat_ids'].cast<int>()
        : [];
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
    broadcastMode = BroadcastMode.fromString(json['broadcast_mode']);
    hasFanClub = json['has_fan_club'];
    fanClubPerks = json['fan_club_perks'];
    poll = json['poll'] != null
        ? LivePoll.fromJson(Map<String, dynamic>.from(json['poll']))
        : null;
    opponentRoomId = json['opponent_room_id'];
    coHostConnectedAt = json['co_host_connected_at'];
    pendingBattleInviteFromId = json['pending_battle_invite_from_id'];
    battleInviteSentAt = json['battle_invite_sent_at'];
    coHostConnectInviteDeclinedFor =
        json['co_host_connect_invite_declined_for'];
    pkMatchRequestDeclinedFor = json['pk_match_request_declined_for'];
    pendingPkMatchRequestFromId = json['pending_pk_match_request_from_id'];
    pkMatchRequestSentAt = json['pk_match_request_sent_at'];
    battleEndedAt = json['battle_ended_at'];
    coHostTeammateRoomId = json['co_host_teammate_room_id'];
    coHostOpponentTeamRoomIds =
        (json['co_host_opponent_team_room_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();
    pkMode = json['pk_mode'];
    pendingTeammateInviteFromId = json['pending_teammate_invite_from_id'];
    teammateInviteSentAt = json['teammate_invite_sent_at'];
    teammateInviteDeclinedFor = json['teammate_invite_declined_for'];
    pendingRematchFromId = json['pending_rematch_from_id'];
    battleRoundWins = json['battle_round_wins'];
    battleRoundWinsHost = json['battle_round_wins_host'];
    battleRoundWinsCoHost = json['battle_round_wins_cohost'];
    battleTotalRounds = json['battle_total_rounds'];
    battleCurrentRound = json['battle_current_round'];
    firstGiftBonusClaimed = json['first_gift_bonus_claimed'];
    pkInviteFromId = json['pk_invite_from_id'];
    pkInviteTeamAIds = (json['pk_invite_team_a_ids'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList();
    pkInviteTeamBIds = (json['pk_invite_team_b_ids'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList();
    pkInviteEligibleGiftIds =
        (json['pk_invite_eligible_gift_ids'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList();
    pkInviteDurationMin = json['pk_invite_duration_min'];
    pkInviteSentAt = json['pk_invite_sent_at'];
    pkInviteAcceptedIds = (json['pk_invite_accepted_ids'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList();
    pkTeamAIds = (json['pk_team_a_ids'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList();
    pkTeamBIds = (json['pk_team_b_ids'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList();
    pkEligibleGiftIds = (json['pk_eligible_gift_ids'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList();
    pkLikePointsA = json['pk_like_points_a'];
    pkLikePointsB = json['pk_like_points_b'];
    crossRoomLikePoints = json['cross_room_like_points'];
    speedChallengeEligibleGiftIds =
        (json['speed_challenge_eligible_gift_ids'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList();
    pinnedComment = json['pinned_comment'] != null
        ? PinnedComment.fromJson(
            Map<String, dynamic>.from(json['pinned_comment']))
        : null;
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
    data['guest_ids'] = guestIds;
    data['pending_seat_ids'] = pendingSeatIds;
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
    data['broadcast_mode'] = broadcastMode?.value;
    data['has_fan_club'] = hasFanClub;
    data['fan_club_perks'] = fanClubPerks;
    data['poll'] = poll?.toJson();
    data['opponent_room_id'] = opponentRoomId;
    data['co_host_connected_at'] = coHostConnectedAt;
    data['pending_battle_invite_from_id'] = pendingBattleInviteFromId;
    data['battle_invite_sent_at'] = battleInviteSentAt;
    data['co_host_connect_invite_declined_for'] =
        coHostConnectInviteDeclinedFor;
    data['pk_match_request_declined_for'] = pkMatchRequestDeclinedFor;
    data['pending_pk_match_request_from_id'] = pendingPkMatchRequestFromId;
    data['pk_match_request_sent_at'] = pkMatchRequestSentAt;
    data['battle_ended_at'] = battleEndedAt;
    data['co_host_teammate_room_id'] = coHostTeammateRoomId;
    data['co_host_opponent_team_room_ids'] = coHostOpponentTeamRoomIds;
    data['pk_mode'] = pkMode;
    data['pending_teammate_invite_from_id'] = pendingTeammateInviteFromId;
    data['teammate_invite_sent_at'] = teammateInviteSentAt;
    data['teammate_invite_declined_for'] = teammateInviteDeclinedFor;
    data['pending_rematch_from_id'] = pendingRematchFromId;
    data['battle_round_wins'] = battleRoundWins;
    data['battle_round_wins_host'] = battleRoundWinsHost;
    data['battle_round_wins_cohost'] = battleRoundWinsCoHost;
    data['battle_total_rounds'] = battleTotalRounds;
    data['battle_current_round'] = battleCurrentRound;
    data['first_gift_bonus_claimed'] = firstGiftBonusClaimed;
    data['pk_invite_from_id'] = pkInviteFromId;
    data['pk_invite_team_a_ids'] = pkInviteTeamAIds;
    data['pk_invite_team_b_ids'] = pkInviteTeamBIds;
    data['pk_invite_eligible_gift_ids'] = pkInviteEligibleGiftIds;
    data['pk_invite_duration_min'] = pkInviteDurationMin;
    data['pk_invite_sent_at'] = pkInviteSentAt;
    data['pk_invite_accepted_ids'] = pkInviteAcceptedIds;
    data['pk_team_a_ids'] = pkTeamAIds;
    data['pk_team_b_ids'] = pkTeamBIds;
    data['pk_eligible_gift_ids'] = pkEligibleGiftIds;
    data['pk_like_points_a'] = pkLikePointsA;
    data['pk_like_points_b'] = pkLikePointsB;
    data['cross_room_like_points'] = crossRoomLikePoints;
    data['speed_challenge_eligible_gift_ids'] = speedChallengeEligibleGiftIds;
    data['pinned_comment'] = pinnedComment?.toJson();
    return data;
  }

  /// Everyone on stage, host first, then co-hosts, then guests.
  List<AppUser> getAllUsers(List<AppUser> users) {
    AppUser? hostUser = users.firstWhereOrNull(
      (element) => element.userId == hostId,
    );
    final allUsers = [
      if (hostUser != null) hostUser,
      ...getCoHostUsers(users),
      ...getGuestUsers(users),
    ];
    return allUsers;
  }

  /// Host + co-hosts only — the people PK eligibility is computed from.
  /// Guest Call participants are deliberately excluded.
  List<AppUser> getCoHostModeUsers(List<AppUser> users) {
    AppUser? hostUser = users.firstWhereOrNull(
      (element) => element.userId == hostId,
    );
    return [if (hostUser != null) hostUser, ...getCoHostUsers(users)];
  }

  List<AppUser> getGuestUsers(List<AppUser> users) {
    return guestIds
            ?.map((id) => users.firstWhereOrNull((user) => user.userId == id))
            .whereType<AppUser>()
            .toList() ??
        [];
  }

  /// Ids of everyone publishing a stream: host, co-hosts, guests.
  List<int> get stageIds => [
        if (hostId != null) hostId!,
        ...?coHostIds,
        ...?guestIds,
      ];

  bool isCoHost(int? userId) =>
      userId != null && (coHostIds ?? const []).contains(userId);

  bool isGuest(int? userId) =>
      userId != null && (guestIds ?? const []).contains(userId);

  bool isOnStage(int? userId) =>
      userId != null &&
      (userId == hostId || isCoHost(userId) || isGuest(userId));

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

enum BroadcastMode {
  camera('CAMERA'),
  voice('VOICE'),
  // Mobile screen-capture broadcasting. Modeled for forward-compat but not
  // selectable yet — needs native screen-capture support (MediaProjection).
  gaming('GAMING');

  final String value;

  const BroadcastMode(this.value);

  static BroadcastMode fromString(String? value) {
    return BroadcastMode.values.firstWhereOrNull((e) => e.value == value) ??
        BroadcastMode.camera;
  }
}

/// A single live question/options poll a host can run during a LIVE.
/// Replaces any previous poll on the stream when a new one starts.
class LivePoll {
  String id;
  String question;
  List<String> options;

  /// Parallel to [options]: how many votes each option has.
  List<int> voteCounts;

  /// Every user id that has voted on this poll, so no one can vote twice.
  List<int> voterIds;
  bool isClosed;

  LivePoll({
    required this.id,
    required this.question,
    required this.options,
    List<int>? voteCounts,
    this.voterIds = const [],
    this.isClosed = false,
  }) : voteCounts = voteCounts ?? List.filled(options.length, 0);

  factory LivePoll.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    return LivePoll(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      options: options,
      voteCounts: (json['vote_counts'] as List<dynamic>? ?? [])
          .whereType<num>()
          .map((e) => e.toInt())
          .toList(),
      voterIds: (json['voter_ids'] as List<dynamic>? ?? [])
          .whereType<num>()
          .map((e) => e.toInt())
          .toList(),
      isClosed: json['is_closed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'vote_counts': voteCounts,
      'voter_ids': voterIds,
      'is_closed': isClosed,
    };
  }

  int get totalVotes => voteCounts.fold(0, (sum, v) => sum + v);
}

/// The one comment currently pinned to a LIVE (client spec 14.2). A small
/// snapshot of the source [LivestreamComment] rather than a reference to it,
/// so it keeps displaying correctly even if the underlying comment doc is
/// later removed from the feed.
class PinnedComment {
  int commentId;
  int senderId;
  String? username;
  String? comment;
  int pinnedAt;

  PinnedComment({
    required this.commentId,
    required this.senderId,
    this.username,
    this.comment,
    required this.pinnedAt,
  });

  factory PinnedComment.fromJson(Map<String, dynamic> json) {
    return PinnedComment(
      commentId: (json['comment_id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt() ?? -1,
      username: json['username'],
      comment: json['comment'],
      pinnedAt: (json['pinned_at'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comment_id': commentId,
      'sender_id': senderId,
      'username': username,
      'comment': comment,
      'pinned_at': pinnedAt,
    };
  }
}
