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
  static const String fanClub = 'fan_club';
  static const String opponentRoomId = 'opponent_room_id';
  static const String pendingBattleInviteFromId =
      'pending_battle_invite_from_id';
  static const String battleInviteSentAt = 'battle_invite_sent_at';

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
}
