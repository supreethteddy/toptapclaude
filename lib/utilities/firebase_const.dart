// ⚠️ DO NOT CHANGE ANY KEY

class FirebaseConst {
  static const String users = 'users';
  static const String usersList = 'users_list';
  static const String chats = 'chats';
  static const String messages = 'messages';
  static const String id = 'id';
  static const String msgCount = 'msg_count';
  static const String lastMsg = 'last_msg';
  static const String lastMsgType = 'last_msg_type';
  static const String noDeleteIds = 'no_delete_ids';
  static const String deletedId = 'deleted_id';
  static const String isDeleted = 'is_deleted';
  static const String requestType = 'request_type';
  static const String chatType = 'chat_type';
  static const String iAmBlocked = 'i_am_blocked';
  static const String iBlocked = 'i_blocked';
  static const String chatUser = 'chat_user';
  static const String storyReplyMessage = 'story_reply_message';

  // Common
  static const String appUsers = 'app_users';

  // LiveStream
  static const String liveStreams = 'livestreams';
  static const String battleHistory = 'battle_history';
  static const String comments = 'comments';
  static const String userState = 'user_state';
  static const String type = 'type';
  static const String liveCoin = 'live_coin';
  static const String followersGained = 'followers_gained';
  static const String totalBattleCoin = 'total_battle_coin';
  static const String currentBattleCoin = 'current_battle_coin';
  static const String isVideoOn = 'is_video_on';
  static const String isMuted = 'is_muted';
  static const String watchingCount = 'watching_count';
  static const String battleCreatedAt = 'battle_created_at';
  static const String battleDuration = 'battle_duration';
  static const String battleType = 'battle_type';
  static const String coHostIds = 'co-host_ids';
  // Guest Call participants (request-to-join flow). Kept separate from
  // coHostIds on purpose: only co-hosts can be PK players, and the two have
  // different seat caps (Setting.maxLiveCohosts / maxLiveGuests).
  static const String guestIds = 'guest_ids';
  // Seats reserved by users who accepted an invite but haven't published
  // yet, so two accepters can't both squeeze into the last seat.
  static const String pendingSeatIds = 'pending_seat_ids';
  // On a user_state doc while type == INVITED: which stage role the host
  // invited them into (CO-HOST or GUEST).
  static const String invitedRole = 'invited_role';
  static const String joinStreamTime = 'join_stream_time';
  static const String likeCount = 'like_count';
  static const String commentsEnabled = 'comments_enabled';
  static const String lastHeartbeatAt = 'last_heartbeat_at';
  static const String lastSeenAt = 'last_seen_at';
  static const String countedAsViewer = 'counted_as_viewer';
  static const String moderators = 'moderators';
  static const String addedAt = 'added_at';
  // Per-LIVE-session Moderator grant (client spec Module 14.1) — lives at
  // livestreams/{roomID}/moderators/{userId}, distinct from the legacy
  // permanent app_users/{hostId}/moderators list above (kept only for the
  // old screen's migration path, no longer written to by new code).
  static const String canManageGuests = 'can_manage_guests';
  static const String moderationLog = 'moderation_log';
  static const String actorId = 'actor_id';
  static const String actorUsername = 'actor_username';
  static const String action = 'action';
  static const String targetId = 'target_id';
  static const String targetUsername = 'target_username';
  static const String detail = 'detail';
  static const String at = 'at';
  // Single-slot pinned comment on the room doc itself (client spec 14.2 —
  // pinning another comment replaces this one, never a list).
  static const String pinnedComment = 'pinned_comment';
  static const String commentId = 'comment_id';
  static const String senderId = 'sender_id';
  static const String username = 'username';
  static const String pinnedAt = 'pinned_at';
  static const String fanClub = 'fan_club';
  static const String opponentRoomId = 'opponent_room_id';
  // Co-Host Connection: opponentRoomId now means "connected", not
  // "connected and battling" -- this is when that connection was made.
  static const String coHostConnectedAt = 'co_host_connected_at';
  static const String pendingBattleInviteFromId =
      'pending_battle_invite_from_id';
  static const String battleInviteSentAt = 'battle_invite_sent_at';
  // Written onto the INVITER's own room doc when their Co-Host connect
  // invite / Play PK Match request gets declined or expires on the other
  // side (client spec 3.2: "If Declined or Expired... Notify the
  // inviter."). Value is the declining host's user id, purely for the
  // snackbar's username lookup -- the inviter clears it themselves right
  // after showing that snackbar, same self-acknowledging pattern as the
  // other pending_*_from_id fields in this file.
  static const String coHostConnectInviteDeclinedFor =
      'co_host_connect_invite_declined_for';
  static const String pkMatchRequestDeclinedFor =
      'pk_match_request_declined_for';

  // "Play PK Match": same request/accept shape as pendingBattleInviteFromId
  // above, but for starting a battle on an ALREADY-connected pair, rather
  // than for the connection itself.
  static const String pendingPkMatchRequestFromId =
      'pending_pk_match_request_from_id';
  static const String pkMatchRequestSentAt = 'pk_match_request_sent_at';

  // Written the moment a battle ends: now + 60s. Every participant/viewer
  // gates the post-match results UI on this, then it auto-clears -- the
  // co-host connection itself is untouched.
  static const String battleResultsVisibleUntil =
      'battle_results_visible_until';

  // 2v2 team assembly across independently-live rooms (see Livestream
  // model doc comments for the full shape).
  static const String coHostTeammateRoomId = 'co_host_teammate_room_id';
  static const String coHostOpponentTeamRoomIds =
      'co_host_opponent_team_room_ids';
  static const String pkMode = 'pk_mode';
  static const String speedChallengeEligibleGiftIds =
      'speed_challenge_eligible_gift_ids';

  // PK Battle rounds: how many rounds each side has won across the current
  // multi-round match (cleared only when the whole match ends, not between
  // rounds). Cross-room battles use battleRoundWins (this room's own side,
  // read from the opponent's own doc for their count); same-room co-host
  // battles use the host/co-host pair since both sides live on one doc.
  static const String battleRoundWins = 'battle_round_wins';
  static const String battleRoundWinsHost = 'battle_round_wins_host';
  static const String battleRoundWinsCoHost = 'battle_round_wins_cohost';

  // PK Battle rounds: fixed round count per match, and the room-wide
  // "first gift" bonus window that resets every round.
  static const String battleTotalRounds = 'battle_total_rounds';
  static const String battleCurrentRound = 'battle_current_round';
  static const String firstGiftBonusClaimed = 'first_gift_bonus_claimed';

  // Rematch: same request/accept shape as pendingBattleInviteFromId, written
  // onto the OTHER host's room doc once a battle has ended, so their
  // existing listenLiveStreamData snapshot listener (already running) picks
  // it up the same way an initial battle invite is picked up.
  static const String pendingRematchFromId = 'pending_rematch_from_id';

  // Same-room co-host PK Match invitation — negotiated on this one room doc
  // (unlike the cross-room invite above, which spans two docs).
  static const String pkInviteFromId = 'pk_invite_from_id';
  static const String pkInviteTeamAIds = 'pk_invite_team_a_ids';
  static const String pkInviteTeamBIds = 'pk_invite_team_b_ids';
  static const String pkInviteEligibleGiftIds = 'pk_invite_eligible_gift_ids';
  static const String pkInviteDurationMin = 'pk_invite_duration_min';
  static const String pkInviteSentAt = 'pk_invite_sent_at';
  static const String pkInviteAcceptedIds = 'pk_invite_accepted_ids';

  // The negotiated teams for the PK Match in progress, promoted from the
  // pk_invite_* fields once every required player accepts.
  static const String pkTeamAIds = 'pk_team_a_ids';
  static const String pkTeamBIds = 'pk_team_b_ids';
  static const String pkEligibleGiftIds = 'pk_eligible_gift_ids';

  // Likes tapped on each half of the screen during an active PK Match,
  // reset to 0 at the start of every match/round.
  static const String pkLikePointsA = 'pk_like_points_a';
  static const String pkLikePointsB = 'pk_like_points_b';
  // Cross-room Co-Host PK only -- this room's own side's like count (see
  // the doc comment on Livestream.crossRoomLikePoints).
  static const String crossRoomLikePoints = 'cross_room_like_points';
}
