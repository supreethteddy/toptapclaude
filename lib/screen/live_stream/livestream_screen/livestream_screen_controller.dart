import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/extensions/user_extension.dart';
import 'package:shortzz/common/functions/debounce_action.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/haptic_manager.dart';
import 'package:shortzz/common/manager/live_invite_watcher.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/utilities/beautify_controls_mixin.dart';
import 'package:shortzz/config/gifts/battle_gift_tiers.dart';
import 'package:shortzz/config/gifts/premium_gift_animations.dart';
import 'package:shortzz/model/livestream/battle_result.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/notification_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/live_invite_service.dart';
import 'package:shortzz/common/service/zego_engine_service.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/live_invite.dart';
import 'package:shortzz/model/livestream/pk_eligibility.dart';
import 'package:shortzz/model/livestream/pk_invite.dart';
import 'package:shortzz/model/livestream/pk_scores.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/livestream/livestream_comment.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/gift_sheet/send_gift_sheet.dart';
import 'package:shortzz/screen/gift_sheet/send_gift_sheet_controller.dart';
import 'package:shortzz/screen/live_stream/live_stream_end_screen/live_stream_end_screen.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/screen/live_stream/live_stream_end_screen/widget/livestream_summary.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/audience/widget/live_stream_join_sheet.dart';
import 'package:shortzz/screen/live_stream/live_stream_search_screen/live_stream_search_screen.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/contributor_rank_entry.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/hourly_ranking_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/league_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/live_ranking_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/contributor_ranking_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/hourly_ranking_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/go_live_with_guests_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/league_standings_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_ranking_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/members_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/pk_match_invite_dialog.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/pk_match_setup_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/timed_invite_dialog.dart';
import 'package:shortzz/screen/report_sheet/report_sheet.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/firebase_const.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class LivestreamScreenController extends BaseController
    with BeautifyControlsMixin, WidgetsBindingObserver {
  FirebaseFirestore db = FirebaseFirestore.instance;
  @override
  ZegoExpressEngine zegoEngine = ZegoExpressEngine.instance;

  final firestoreController = Get.find<FirebaseFirestoreController>();

  Timer? timer;
  Timer? minViewerTimeoutTimer;
  Timer? presenceTimer;
  StreamSubscription<List<LiveInvite>>? _outgoingInvitesSub;

  /// Every out-of-room invite this host has sent for this room, any status —
  /// drives the Friends/Recommended row button states (Invite / Invited… /
  /// Declined / Seats full). Host-only; empty for everyone else.
  RxList<LiveInvite> outgoingInvites = <LiveInvite>[].obs;
  // Offset is where the burst should originate (the actual tap point); null
  // means "no specific tap to anchor to" (a like echoed in from Firestore).
  void Function(Offset?)? onLikeTap;

  Setting? get setting => SessionManager.instance.getSettings();

  int get minViewersThreshold => setting?.liveMinViewers ?? 0;

  int get timeoutMinutes => setting?.liveTimeout ?? 0;

  int get myUserId => SessionManager.instance.getUserID();

  /// This device's own currently-publishing stream ID (host publishes
  /// under the room ID -- see startHostPublish -- co-hosts/guests under
  /// their own user ID -- see publishCoHostStream's startPublishingStream
  /// call). Used below to keep this device's own stream out of the
  /// generic remote-stream Add/Delete handling in onRoomStreamUpdate: that
  /// pipeline (startPlayStream/stopPlayStream) decodes and renders *other*
  /// people's video over the network -- meaningless for a stream that's
  /// mine, since my own video is already rendered locally straight off
  /// the camera/DeepAR canvas with zero round trip. Before this guard, a
  /// brief Zego-level republish of this device's own stream (e.g.
  /// toggling enableCustomVideoCapture while switching a live filter --
  /// create_live_stream_screen_controller.dart) fell through to
  /// stopPlayStream's destroyCanvasView call on this device's own live
  /// preview canvas, which doesn't just hide the tile -- it destroys that
  /// canvas view id for good, so nothing could render there again for the
  /// rest of the LIVE. That, not a timing gap in publish-state handling,
  /// is the actual cause of the tile getting stuck on "Reconnecting"
  /// forever after switching filters.
  String get _myOwnStreamId => isHost ? (liveData.value.roomID ?? '') : '$myUserId';

  RxBool isPlayerMute = false.obs;
  RxBool isMinViewerTimeout = false.obs;
  RxBool isTextEmpty = true.obs;
  RxBool isFanClubMember = false.obs;
  bool isJoinSheetOpen = false;
  bool isFrontCamera = true;
  bool isHost;
  bool _hasShownGoalCompletion = false;
  bool _hasIncrementedWatchingCount = false;
  bool _isLoggingOut = false;
  bool _hasHandledRemoteEnd = false;

  /// Last like count we've already animated for (see listenLiveStreamData
  /// and onLikeButtonTap's optimistic call) — a class field rather than a
  /// listener-local variable so a tap's immediate local heart burst is
  /// correctly recognised as "already shown" once the Firestore echo of
  /// that same increment comes back, instead of firing a second burst.
  int _lastAnimatedLikeCount = 0;

  StreamSubscription<DocumentSnapshot<Livestream>>? liveStreamDocListener;
  StreamSubscription<QuerySnapshot<LivestreamUserState?>>?
      liveStreamUserStatesListener;
  StreamSubscription<QuerySnapshot<LivestreamComment?>>?
      liveStreamCommentsListener;
  // Set the instant fetchLiveStreamComments (re)subscribes -- the listener
  // itself replays this whole session's comment history as fresh "added"
  // events on every subscribe (see that function's own comment), so a
  // viewer leaving and re-entering an still-ongoing LIVE would otherwise
  // re-fire one-shot effects (the premium gift video overlay, the eagle
  // animation) for a gift someone sent long before they came back,
  // including getting the overlay stuck again if the network stalls the
  // replayed video. Side effects below only fire for a comment id (a
  // creation-time epoch millis) at or after this value.
  int? _commentListenerStartedAt;

  // Cross-room PK Battle: the opponent room's own state, watched read-only
  // while opponentRoomId is set. No multi-room Zego login needed — see
  // opponentStreamViews.
  String? _watchedOpponentRoomId;
  StreamSubscription<DocumentSnapshot>? opponentLiveDocListener;
  StreamSubscription<QuerySnapshot>? opponentUserStatesListener;
  Rx<Livestream?> opponentLiveData = Rx(null);
  RxList<LivestreamUserState> opponentUserStates = <LivestreamUserState>[].obs;
  RxList<StreamView> opponentStreamViews = <StreamView>[].obs;
  int? _lastHandledInviteFromId;
  int? _lastHandledRematchFromId;
  int? _lastHandledPkMatchRequestFromId;

  // Same-room PK Match invite: deduped by (fromId, sentAt) rather than just
  // fromId, since the same host re-sending after a decline must re-trigger
  // the dialog on the invitee's side.
  int? _lastHandledPkInviteFromId;
  int? _lastHandledPkInviteSentAt;
  Timer? _pkInviteExpiryTimer;
  // True from the moment I (the host) send a PK Match invite until it
  // either starts a battle or is cleared — lets the listener tell a decline
  // apart from any other reason pk_invite_from_id might be null.
  bool _awaitingPkInviteResponse = false;
  // Guards the host's own "everyone accepted, start the battle" transaction
  // against firing twice from two rapid snapshot events while it's in
  // flight.
  bool _pkMatchStartInFlight = false;

  TextEditingController textCommentController = TextEditingController();

  DocumentReference get liveStreamDocRef =>
      db.collection(FirebaseConst.liveStreams).doc(liveData.value.roomID);

  CollectionReference get liveStreamUsersRef =>
      db.collection(FirebaseConst.appUsers);

  CollectionReference get liveStreamUserStatesRef => db
      .collection(FirebaseConst.liveStreams)
      .doc(liveData.value.roomID)
      .collection(FirebaseConst.userState);

  CollectionReference get liveStreamCommentsRef => db
      .collection(FirebaseConst.liveStreams)
      .doc(liveData.value.roomID)
      .collection(FirebaseConst.comments);

  CollectionReference get fanClubRef => db
      .collection(FirebaseConst.appUsers)
      .doc('${liveData.value.hostId}')
      .collection(FirebaseConst.fanClub);

  Widget? hostPreview;

  /// True while this controller exists purely so a viewer can browse this
  /// room's real video in LiveDiscoveryFeedScreen without being a counted
  /// participant — loginRoom() still does the real Zego room login (that's
  /// what lets the video stream come through), but skips every Firestore
  /// read/write an audience join normally does: no watching_count
  /// increment, no "X joined" comment, no presence heartbeat. Flipped to
  /// false (and the skipped join completed) by
  /// upgradeFromPreviewToJoined() once the viewer actually taps in. Always
  /// false for a host controller and for every other existing entry point.
  bool isPreviewOnly;

  /// Daily ranking (coins received today) for the host of this LIVE.
  LiveRankingController? rankingController;

  /// Hourly ranking (coins received this hour) for the host of this LIVE —
  /// same idea as [rankingController], keyed by hour instead of day.
  HourlyRankingController? hourlyRankingController;

  /// This week's competitive League standing for the host of this LIVE.
  LeagueController? leagueController;

  String get _rankingTag => 'rank_${liveData.value.roomID}';

  String get _hourlyRankingTag => 'hourly_rank_${liveData.value.roomID}';

  String get _leagueTag => 'league_${liveData.value.roomID}';

  LivestreamScreenController(this.liveData, this.isHost,
      {this.hostPreview, this.isPreviewOnly = false});

  /// Room IDs of every [LivestreamScreenController] currently alive, tagged
  /// one-per-room so several rooms can be mounted at once (needed for
  /// swiping between live rooms). Call sites that used to ask the old
  /// untagged singleton "is a LIVE screen open right now" (via
  /// `Get.isRegistered<LivestreamScreenController>()`) can't do that lookup
  /// by type alone anymore, since GetX has no "any tag registered" query —
  /// they check this set instead.
  static final Set<String> activeRoomIds = {};

  int totalBattleSecond = 0;

  RxInt remainingBattleSeconds = 0.obs;

  /// Snapshot of each side's cumulative battle coins at the moment the
  /// current round started. The round's own live score (shown in the
  /// progress bar / WIN tallies) is `cumulative - baseline`, so starting a
  /// "Next Round" via [startNextRound] only needs to update these two local
  /// values — no Firestore reset of per-user battle coins required, which
  /// would otherwise mean writing into the opponent's own room's user_state
  /// subcollection in the cross-room case.
  RxInt roundBaselineRed = 0.obs;
  RxInt roundBaselineBlue = 0.obs;

  /// One-shot guard for _recordPkMatchWin — see where it's used in
  /// listenLiveStreamData.
  bool _pkMatchWinRecorded = false;

  /// Live gift-combo streak: how many times in a row the most recent gift
  /// comment repeats the same sender+gift+receiver, each arriving within
  /// [_giftComboWindow] of the previous one. Derived purely from the shared
  /// `comments` stream every viewer already listens to (see
  /// [fetchLiveStreamComments]) — no extra Firestore writes, and every
  /// device sees the same count since they all fold the same ordered gift
  /// events. Resets to 0 (and [currentGiftComboComment] to null) once
  /// [_giftComboWindow] passes with no further matching gift.
  static const Duration _giftComboWindow = Duration(seconds: 4);
  RxInt currentGiftComboCount = 0.obs;
  Rx<LivestreamComment?> currentGiftComboComment = Rx(null);
  Timer? _giftComboTimer;

  /// Full-screen "epic gift" animation, bundled locally since there's no
  /// backend field to attach an animation asset to a gift (Gift only carries
  /// a static `image` URL — see settings_model.dart) and no admin UI to add
  /// one from this session. Hardcoded to this backend's one existing gift
  /// (id 18); bumping the trigger int (rather than a bool) lets the same
  /// gift be sent again immediately and still replay from frame 0, and every
  /// viewer bumps it identically since it's driven by the same shared
  /// comments snapshot listener each of them already runs (see
  /// fetchLiveStreamComments), not a per-device local action.
  static const int eagleGiftId = 18;
  RxInt eagleGiftAnimationTrigger = 0.obs;
  static final List<String> eagleGiftFrames = List.generate(
    66,
    (i) => 'assets/gifts/eagle/eagle_${(i + 1).toString().padLeft(3, '0')}.png',
  );

  /// Same trigger contract as [eagleGiftAnimationTrigger], generalized for
  /// any gift in [premiumGiftAnimations] rather than one hardcoded id — see
  /// PremiumGiftRevealOverlay. Carries the triggering comment along so the
  /// overlay has the sender to show without a second lookup.
  RxInt premiumGiftAnimationTrigger = 0.obs;
  Rx<LivestreamComment?> premiumGiftAnimationComment =
      Rx<LivestreamComment?>(null);

  // Own instance (not the app-wide DebounceAction.shared) so a burst of
  // gifts received in quick succession doesn't fight with unrelated
  // debounced actions elsewhere for the one shared timer.
  final DebounceAction _balanceRefreshDebounce = DebounceAction();

  /// Gifts credit the receiver's earnings server-side in real time, but
  /// nothing pushes that to this device on its own — refresh from the
  /// server shortly after a gift comment addressed to me arrives, so the
  /// balance shown here (and everywhere else, via the shared
  /// SessionManager.currentUser) catches up without leaving the LIVE.
  void _refreshMyBalanceAfterGift() {
    _balanceRefreshDebounce.call(() async {
      // fetchUserDetails() already calls SessionManager.setUser() itself,
      // gated on the fetch actually succeeding (status == true) and my id
      // not having changed mid-flight. Calling setUser() again here on
      // whatever it returns — with no such gate — used to persist a blank
      // default User (id defaulting to 0) whenever this self-refresh call
      // errored, silently corrupting myUserId for the rest of the LIVE
      // session (every gift triggers this, so one flaky response during a
      // busy PK battle was enough). Just let fetchUserDetails() own it.
      await UserService.instance
          .fetchUserDetails(userId: SessionManager.instance.getUserID());
    }, milliseconds: 1500);
  }

  /// Debug-only: fires the premium gift overlay locally without a real
  /// backend gift send, since every entry in premiumGiftAnimations is a
  /// placeholder id with no real tbl_gifts row yet — there is no real send
  /// flow to test this through until that exists. Only reachable from a
  /// kDebugMode-gated menu item (see live_stream_bottom_view.dart).
  void debugTriggerPremiumGift(int giftId) {
    premiumGiftAnimationComment.value = LivestreamComment(
      senderId: myUserId,
      receiverId: myUserId,
      commentType: LivestreamCommentType.gift,
      giftId: giftId,
    );
    premiumGiftAnimationTrigger.value++;
  }

  void _registerGiftForCombo(LivestreamComment comment) {
    final last = currentGiftComboComment.value;
    final isSameStreak = last != null &&
        _giftComboTimer != null &&
        last.senderId == comment.senderId &&
        last.giftId == comment.giftId &&
        last.receiverId == comment.receiverId;
    currentGiftComboCount.value =
        isSameStreak ? currentGiftComboCount.value + 1 : 1;
    currentGiftComboComment.value = comment;
    _giftComboTimer?.cancel();
    _giftComboTimer = Timer(_giftComboWindow, () {
      currentGiftComboCount.value = 0;
      currentGiftComboComment.value = null;
    });
  }

  RxBool isViewVisible = true.obs;
  // Always visible now that the up-arrow toggle button is gone - this panel
  // (beauty filter shortcut, host-only more-options menu) has no other way
  // to be shown.
  RxBool isRightControlsVisible = true.obs;
  RxBool canPopStreamRoute = false.obs;

  // Actual rendered height of LiveStreamHostTopView (safe-area inset + its
  // 3 rows, which varies by device and by how many rank/goal/poll chips are
  // showing). The PK battle score bar used to sit behind a hardcoded
  // top-margin guess that was routinely too short, landing the score bar's
  // crown icon on top of the LIVE title text. LiveStreamHostTopView measures
  // itself post-frame and writes the real value here; the battle view reads
  // it for its top margin instead of guessing.
  RxDouble topHeaderHeight = 150.0.obs;

  List<LivestreamUserState> memberList = <LivestreamUserState>[];

  List<Gift> get gifts => setting?.gifts ?? [];

  // Seat caps come from the admin panel (Phase 0 settings); the literals are
  // only the fallback for a backend that predates those columns and match
  // the client's spec (Co-host Mode = 4 in frame incl. host; 9 guests).
  // In-room co-host is retired (see LivestreamUserType's doc comment) --
  // maxCoHosts is dormant, kept only so legacy/pre-migration docs don't
  // error if something still reads it.
  int get maxCoHosts => setting?.maxLiveCohosts ?? 3;
  int get maxGuests => setting?.maxLiveGuests ?? 8;
  bool get guestRequestsEnabled =>
      (setting?.liveGuestRequestsEnabled ?? 1) == 1;

  /// Who is actually on screen right now — PK eligibility only counts
  /// co-hosts that are publishing, same check [canStartBattle] used to make.
  Set<int> get _publishingUserIds => streamViews
      .map((view) => int.tryParse(view.streamId))
      .whereType<int>()
      .toSet();

  /// Whether a PK Match is currently offerable, and to whom — derived fresh
  /// from the room doc + who's actually streaming, never cached.
  PkEligibility get pkMatchEligibility => pkEligibilityFor(
        hostId: liveData.value.hostId,
        coHostIds: liveData.value.coHostIds ?? const [],
        guestIds: liveData.value.guestIds ?? const [],
        publishingIds: _publishingUserIds,
        battleEnabled: (setting?.liveBattle ?? 1) == 1,
      );

  /// Single round per the client's confirmed decision; only the length of
  /// that round is admin-configurable.
  int get pkMatchDurationMinutes => setting?.pkBattleDurationMinutes ?? 5;
  int get pkMatchTotalRounds => setting?.pkBattleRounds ?? 1;
  int get pkMatchInviteExpirySeconds => setting?.pkInviteExpirySeconds ?? 60;

  // ── Same-room PK Match scoring ──────────────────────────────────────────
  // Team membership for the battle currently in progress (or just ended):
  // the real pk_team_*_ids recorded by _startPkMatch, or — for any
  // same-room battle data that predates this feature — the host/first-co-
  // host pair the arena always used before team arrays existed. 1v1 only
  // for now, so each list always has at most one member; a 2v2 arena will
  // need the per-member baseline/raw-sum helpers below reworked, since they
  // currently treat "the team's one member" and "the team" as equivalent.
  List<int> get pkTeamAUserIds {
    final real = liveData.value.pkTeamAIds;
    if (real != null) return real;
    final hostId = liveData.value.hostId;
    return hostId == null ? const <int>[] : [hostId];
  }

  List<int> get pkTeamBUserIds {
    final real = liveData.value.pkTeamBIds;
    if (real != null) return real;
    final coHostIds = liveData.value.coHostIds ?? const <int>[];
    return coHostIds.isEmpty ? const <int>[] : [coHostIds.first];
  }

  Map<int, int> get _currentBattleCoinByUser => {
        for (final state in liveUsersStates)
          state.userId: state.currentBattleCoin,
      };

  int _teamRawBattleCoins(List<int> memberIds) {
    final coinByUser = _currentBattleCoinByUser;
    return memberIds.fold(0, (total, id) => total + (coinByUser[id] ?? 0));
  }

  PkTeamScore pkTeamAScore() {
    final members = pkTeamAUserIds;
    return pkTeamScore(
      memberIds: members,
      battleCoinByUser: _currentBattleCoinByUser,
      baselineByUser: {for (final id in members) id: roundBaselineRed.value},
      likeEvents: liveData.value.pkLikePointsA ?? 0,
      pointsPerLike: setting?.pkLikePoints ?? 1,
    );
  }

  PkTeamScore pkTeamBScore() {
    final members = pkTeamBUserIds;
    return pkTeamScore(
      memberIds: members,
      battleCoinByUser: _currentBattleCoinByUser,
      baselineByUser: {for (final id in members) id: roundBaselineBlue.value},
      likeEvents: liveData.value.pkLikePointsB ?? 0,
      pointsPerLike: setting?.pkLikePoints ?? 1,
    );
  }

  /// Seats still open for a given stage role, counting reservations held by
  /// invitees who accepted but haven't published yet (see pendingSeatIds).
  int seatsLeftFor(LivestreamUserType role) {
    final stream = liveData.value;
    final reserved = (stream.pendingSeatIds ?? const []).length;
    switch (role) {
      case LivestreamUserType.coHost:
        return maxCoHosts - (stream.coHostIds ?? const []).length - reserved;
      case LivestreamUserType.guest:
        return maxGuests - (stream.guestIds ?? const []).length - reserved;
      default:
        return 0;
    }
  }

  bool hasSeatFor(LivestreamUserType role) => seatsLeftFor(role) > 0;

  String seatsFullMessageFor(LivestreamUserType role) =>
      role == LivestreamUserType.coHost
          ? LKey.coHostSeatsFull.tr
          : LKey.guestSeatsFull.tr;

  RxList<LivestreamUserState> requestList = <LivestreamUserState>[].obs;
  RxList<LivestreamUserState> audienceList = <LivestreamUserState>[].obs;
  RxList<LivestreamUserState> invitedList = <LivestreamUserState>[].obs;
  RxList<LivestreamUserState> coHostList = <LivestreamUserState>[].obs;
  RxList<LivestreamUserState> guestList = <LivestreamUserState>[].obs;
  RxList<LivestreamUserState> audienceMemberList = <LivestreamUserState>[].obs;
  RxList<StreamView> streamViews = <StreamView>[].obs;
  // Cache of this device's own StreamView entry (host or co-host), kept so
  // onPublisherStateUpdate's Publishing case below can restore it without
  // re-creating a canvas view. See that callback for why it's needed.
  StreamView? _lastOwnStreamView;
  RxList<LivestreamComment> comments = <LivestreamComment>[].obs;
  RxList<LivestreamUserState> liveUsersStates = <LivestreamUserState>[].obs;

  // Cross-room Co-Host PK only -- a gift sent to the opponent host posts to
  // THEIR room's own comments subcollection, not mine, so TopGiftersRow
  // (ranking who gifted each side) needs this separate watch to know who
  // gifted the opponent side; see allBattleComments/_startWatchingOpponent.
  RxList<LivestreamComment> opponentComments = <LivestreamComment>[].obs;
  StreamSubscription<QuerySnapshot>? opponentCommentsListener;

  List<LivestreamComment> get allBattleComments =>
      liveData.value.opponentRoomId == null
          ? comments
          : [...comments, ...opponentComments];

  Rx<AppUser?> selectedGiftUser = Rx(null);
  Rx<VideoPlayerController?> videoPlayerController = Rx(null);

  // Forwards the shared Rx so Obx widgets reading controller.myUser.value
  // actually track future updates (e.g. _refreshMyBalanceAfterGift below) —
  // SessionManager.instance.getUser().obs previously wrapped a one-off
  // snapshot in a throwaway .obs that nothing ever updated again.
  Rx<User?> get myUser => SessionManager.instance.currentUser;
  Rx<Livestream> liveData;

  AudioPlayer battleStartPlayer = AudioPlayer();
  AudioPlayer winAudioPlayer = AudioPlayer();

  @override
  void onInit() {
    super.onInit();
    if (isHost) WidgetsBinding.instance.addObserver(this);
    // Pause the background home-feed reel so its audio doesn't keep playing
    // under this screen. Some entry points (LiveDiscoveryFeedScreen,
    // CreateLiveStreamScreenController) already did this themselves before
    // navigating here, but several others (a "went live" push notification,
    // accepting an in-app LIVE invite, Live Stream Search) opened this
    // screen directly and never did — doing it here instead covers every
    // entry point uniformly, current and future, matching the unconditional
    // resumeHomeFeed() this class already calls in onClose(). A harmless
    // no-op if the reels feed was already paused or was never playing.
    ReelsScreenController.pauseHomeFeed('livestreamCtrl-isPreview=$isPreviewOnly-room=${liveData.value.roomID}-hash=${identityHashCode(this)}');
    // A preview-only controller isn't "a LIVE screen the viewer has open"
    // for the purposes of these two guards — LiveStatusController.openLive
    // checks activeRoomIds.isNotEmpty (any room, not just this one) before
    // letting a LIVE-ring avatar elsewhere in the app open a stream, which
    // would wrongly refuse while merely browsing the discovery feed. Added
    // instead inside upgradeFromPreviewToJoined() once the viewer actually
    // taps in. onClose()'s removal stays unconditional — Set.remove() on an
    // id that was never added is a harmless no-op.
    if (!isPreviewOnly) {
      activeRoomIds.add(liveData.value.roomID ?? '');
      // Tell LiveInviteWatcher this room already has its screen open, so an
      // out-of-room invite for it is handled by the in-room INVITED path
      // instead of double-prompting with a second sheet.
      LiveInviteWatcher.activeRoomIds.add(liveData.value.roomID ?? '');
    }
    if (isHost) {
      _outgoingInvitesSub = LiveInviteService.instance
          .watchOutgoing(myUserId, liveData.value.roomID ?? '')
          .listen(
            (invites) => outgoingInvites.value = invites,
            onError: (Object e) => Loggers.error('watchOutgoing failed: $e'),
          );
    }
    if (liveData.value.isDummyLive == 1) {
      initVideoPlayer();
    } else {
      totalBattleSecond = Duration(
        minutes: liveData.value.battleDuration,
      ).inSeconds;
      remainingBattleSeconds.value = totalBattleSecond;
      zegoEngine.setAudioDeviceMode(ZegoAudioDeviceMode.General);
      loginRoom();
      startListenEvent();
    }

    // Common listeners for all users
    listenLiveStreamData();
    listenUserState();
    fetchLiveStreamComments();
    initAudioPlayer();
    rankingController = Get.put(
      LiveRankingController(liveData.value.hostId ?? -1),
      tag: _rankingTag,
    );
    hourlyRankingController = Get.put(
      HourlyRankingController(liveData.value.hostId ?? -1),
      tag: _hourlyRankingTag,
    );
    leagueController = Get.put(
      LeagueController(liveData.value.hostId ?? -1),
      tag: _leagueTag,
    );
    WakelockPlus.enable();
    if (!isHost) unawaited(_checkFanClubMembership());
  }

  Future<void> _checkFanClubMembership() async {
    try {
      final doc = await fanClubRef.doc('$myUserId').get();
      isFanClubMember.value = doc.exists;
    } catch (e) {
      Loggers.error('Failed to check Fan Club membership: $e');
    }
  }

  Future<void> joinFanClub() async {
    if (isFanClubMember.value) return;
    isFanClubMember.value = true;
    try {
      await fanClubRef.doc('$myUserId').set({
        FirebaseConst.id: myUserId,
        FirebaseConst.addedAt: DateTime.now().millisecondsSinceEpoch,
      });
      showSnackBar(LKey.joinedFanClub.tr);
    } catch (e) {
      isFanClubMember.value = false;
      Loggers.error('Failed to join Fan Club: $e');
    }
  }

  @override
  void onClose() {
    if (isHost) WidgetsBinding.instance.removeObserver(this);
    activeRoomIds.remove(liveData.value.roomID ?? '');
    LiveInviteWatcher.activeRoomIds.remove(liveData.value.roomID ?? '');
    _outgoingInvitesSub?.cancel();
    WakelockPlus.disable();
    timer?.cancel();
    minViewerTimeoutTimer?.cancel();
    presenceTimer?.cancel();
    _giftComboTimer?.cancel();
    _battleInviteExpiryTimer?.cancel();
    _pkInviteExpiryTimer?.cancel();
    videoPlayerController.value?.dispose();
    liveStreamUserStatesListener?.cancel();
    liveStreamCommentsListener?.cancel();
    liveStreamDocListener?.cancel();
    _stopWatchingOpponent();
    battleStartPlayer.dispose();
    winAudioPlayer.dispose();
    stopListenEvent();
    // Best-effort: if this host went live using a DeepAR filter (see
    // CreateLiveStreamScreenController), make sure Zego's custom-capture
    // flag from that session doesn't outlive it. Harmless no-op otherwise —
    // the native bridge is a guarded no-op when never started.
    if (isHost) {
      unawaited(const MethodChannel('toptap/deepar_zego_bridge')
          .invokeMethod('stop')
          .catchError((_) {}));
    }
    unawaited(logoutRoom());
    if (!isHost) {
      unawaited(_leaveAudience());
    }
    if (Get.isRegistered<LiveRankingController>(tag: _rankingTag)) {
      Get.delete<LiveRankingController>(tag: _rankingTag);
    }
    rankingController = null;
    if (Get.isRegistered<HourlyRankingController>(tag: _hourlyRankingTag)) {
      Get.delete<HourlyRankingController>(tag: _hourlyRankingTag);
    }
    hourlyRankingController = null;
    if (Get.isRegistered<LeagueController>(tag: _leagueTag)) {
      Get.delete<LeagueController>(tag: _leagueTag);
    }
    leagueController = null;
    // Resume the background home-feed reels that were paused when the LIVE flow
    // opened, now that we are leaving the LIVE screen.
    ReelsScreenController.resumeHomeFeed('livestreamCtrl-room=${liveData.value.roomID}-hash=${identityHashCode(this)}');
    super.onClose();
  }

  bool _detachedCleanupDone = false;

  /// Only acts on [AppLifecycleState.detached] (the Flutter engine actually
  /// being torn down), never on [AppLifecycleState.paused]/[inactive] --
  /// those fire on completely normal, temporary backgrounding (switching
  /// apps for a moment, answering a call, checking a notification), and a
  /// host still fully intends to keep streaming through those. Reacting to
  /// detached is still only a best-effort speed-up, not a guarantee: a
  /// process killed outright by the OS (e.g. swiping the task away under
  /// memory pressure) can die before this callback -- or the awaited
  /// Firestore delete inside it -- ever completes. The real guarantee
  /// against a room being stuck LIVE forever is LiveStatusController's own
  /// heartbeat-staleness watchdog, which cleans up this same doc from any
  /// other client's device without depending on this one surviving at all.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isHost &&
        state == AppLifecycleState.detached &&
        !_detachedCleanupDone) {
      _detachedCleanupDone = true;
      unawaited(deleteStreamOnFirebase());
    }
  }

  void openRankingSheet() {
    final ranking = rankingController;
    if (ranking == null) return;
    HapticManager.shared.light();
    Get.bottomSheet(
      LiveRankingSheet(controller: ranking),
      isScrollControlled: true,
    );
  }

  void openHourlyRankingSheet() {
    final ranking = hourlyRankingController;
    if (ranking == null) return;
    HapticManager.shared.light();
    Get.bottomSheet(
      HourlyRankingSheet(controller: ranking),
      isScrollControlled: true,
    );
  }

  void openLeagueSheet() {
    final league = leagueController;
    if (league == null) return;
    HapticManager.shared.light();
    Get.bottomSheet(
      LeagueStandingsSheet(controller: league),
      isScrollControlled: true,
    );
  }

  /// Per-room "Contributor Ranking": contributors ordered by total coins
  /// gifted during THIS LIVE session only.
  ///
  /// This is intentionally *not* backed by a separate Firestore query.
  /// [comments] already streams every `livestreams/{roomID}/comments`
  /// document for this room (see [fetchLiveStreamComments]), so gift
  /// comments (`commentType == LivestreamCommentType.gift`) are grouped by
  /// `senderId` and summed here using the same gift-catalog lookup
  /// (`gifts.firstWhereOrNull`) that [onGiftTap] uses to price a gift, via
  /// the `comment.gift` already resolved in [fetchLiveStreamComments].
  /// Reusing that stream avoids a second Firestore listener on the same
  /// collection and stays perfectly in sync with the chat feed.
  List<ContributorRankEntry> get contributorRanking {
    final Map<int, int> coinsBySender = {};
    final Map<int, int> giftsBySender = {};
    for (final comment in comments) {
      if (comment.commentType != LivestreamCommentType.gift) continue;
      final senderId = comment.senderId;
      if (senderId == null) continue;
      final coinPrice = (comment.gift ??
                  gifts.firstWhereOrNull((g) => g.id == comment.giftId))
              ?.coinPrice
              ?.toInt() ??
          0;
      if (coinPrice <= 0) continue;
      coinsBySender[senderId] = (coinsBySender[senderId] ?? 0) + coinPrice;
      giftsBySender[senderId] = (giftsBySender[senderId] ?? 0) + 1;
    }
    final entries = coinsBySender.entries.map((entry) {
      final user = firestoreController.users
          .firstWhereOrNull((u) => u.userId == entry.key);
      return ContributorRankEntry(
        userId: entry.key,
        coins: entry.value,
        gifts: giftsBySender[entry.key] ?? 0,
        user: user,
      );
    }).toList();
    entries.sort((a, b) => b.coins.compareTo(a.coins));
    return entries;
  }

  /// Top 3 of [contributorRanking], for the small avatar badges shown in the
  /// LIVE top bar next to the viewer count.
  List<ContributorRankEntry> get topContributors =>
      contributorRanking.take(3).toList();

  void openContributorRankingSheet() {
    HapticManager.shared.light();
    Get.bottomSheet(
      ContributorRankingSheet(controller: this),
      isScrollControlled: true,
    );
  }

  /// Audience list (eye icon) for everyone.
  void openAudienceSheet() {
    Get.bottomSheet(
      MembersSheet(isHost: false, roomID: liveData.value.roomID ?? ''),
      isScrollControlled: true,
    );
  }

  /// Opens the guests sheet (Requests / Invited / Co-hosts) for the host.
  void openMembersSheet({int initialTab = MembersSheet.tabRequests}) {
    HapticManager.shared.light();
    Get.bottomSheet(
      MembersSheet(
          isHost: true,
          initialTab: initialTab,
          roomID: liveData.value.roomID ?? ''),
      isScrollControlled: true,
    );
  }

  /// Stage-3 entry point (client's 5-stage breakdown) — the primary guest
  /// icon now opens this instead of the Requests tab of MembersSheet
  /// directly; MembersSheet itself stays reachable from the "..." menu.
  void openGoLiveWithGuestsSheet() {
    HapticManager.shared.light();
    Get.bottomSheet(
      GoLiveWithGuestsSheet(roomID: liveData.value.roomID ?? ''),
      isScrollControlled: true,
    );
  }

  void openPkMatchSetupSheet() {
    HapticManager.shared.light();
    Get.bottomSheet(
      PkMatchSetupSheet(roomID: liveData.value.roomID ?? ''),
      isScrollControlled: true,
      enableDrag: false,
    );
  }

  Future<void> initVideoPlayer() async {
    final url = liveData.value.dummyUserLink ?? '';
    if (url.isEmpty) return;

    // Dispose old controller if exists to avoid memory leak
    await videoPlayerController.value?.dispose();

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    isPlayerMute.value = false;

    try {
      await controller.initialize();
      controller
        ..setLooping(true)
        ..play();

      videoPlayerController.value = controller;
      videoPlayerController.value?.setLooping(true);
      await _joinAudience();
    } on PlatformException catch (e) {
      showSnackBar(e.message);
      Loggers.error(e);
    }
  }

  void initAudioPlayer() {
    battleStartPlayer.setAsset(AssetRes.battleStart);
    winAudioPlayer.setAsset(AssetRes.winSound);
  }

  Future<void> logoutRoom() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    // Each teardown step is guarded independently so that a failure in one
    // (e.g. deleting the Firestore doc) never skips the Zego room logout. If the
    // room is left logged-in the host cannot start a new live afterwards.
    if (isHost) {
      try {
        await deleteStreamOnFirebase();
      } catch (e, s) {
        Loggers.error('deleteStreamOnFirebase failed during logout: $e\n$s');
      }
    }
    try {
      await stopPreview();
    } catch (e) {
      Loggers.error('stopPreview failed during logout: $e');
    }
    try {
      await stopPublish();
    } catch (e) {
      Loggers.error('stopPublish failed during logout: $e');
    }
    try {
      await zegoEngine.logoutRoom(liveData.value.roomID ?? '');
    } catch (e) {
      Loggers.error('zego logoutRoom failed: $e');
    }
  }

  Future<ZegoRoomLoginResult> loginRoom() async {
    // The dashboard kicks off engine creation fire-and-forget in onReady()
    // (ZegoEngineService.ensureEngine isn't awaited there), so a viewer who
    // taps into a LIVE within the first second or two of a cold app launch
    // can race ahead of it: zegoEngine.loginRoom() then runs against a
    // not-yet-created native engine and silently no-ops (no Zego-side log,
    // no thrown error, no stream ever subscribed) — the join still "looks"
    // successful (Firestore writes go through) but the viewer is stuck on
    // "Reconnecting..." forever. ensureEngine() is idempotent/cheap once the
    // engine already exists, so this costs nothing on the normal path.
    final engineReady = await ZegoEngineService.instance.ensureEngine();
    if (!engineReady) {
      showSnackBar('Unable to connect to the live server. Please try again.');
      return ZegoRoomLoginResult(-1, {});
    }

    final roomID = liveData.value.roomID ?? '';
    final user = ZegoUser('$myUserId', myUser.value?.username ?? '');

    final roomConfig = ZegoRoomConfig.defaultConfig()
      ..isUserStatusNotify = true;

    try {
      final result = await zegoEngine.loginRoom(
        roomID,
        user,
        config: roomConfig,
      );

      if (result.errorCode != 0) {
        showSnackBar('loginRoom failed: ${result.errorCode}');
        return result;
      }

      if (isHost) {
        startHostPublish();
        _startPresenceMaintenance();
        return result;
      }

      if (isPreviewOnly) {
        // Browsing-only: the Zego room login above is already enough for
        // the real video to arrive via onRoomStreamUpdate/streamViews — no
        // Firestore read or write happens below, so this can never count
        // as a participant, bump watching_count, or fire the "joined"
        // comment. upgradeFromPreviewToJoined() runs the skipped join (via
        // _completeAudienceJoin below) if the viewer taps in to watch for
        // real.
        return result;
      }

      await _completeAudienceJoin(roomID);
      return result;
    } catch (e) {
      Loggers.error('Error in loginRoom: $e');
      showSnackBar('Something went wrong while joining the room.');
      rethrow;
    }
  }

  /// The actual audience-join Firestore work: create the user doc, create
  /// or sync the user_state doc (firing the "joined" comment exactly once,
  /// the first time that doc is created), bump watching_count, start the
  /// presence heartbeat, and resolve any pending out-of-room invite. Split
  /// out of loginRoom() so it can also run later, standalone, when a
  /// preview-only controller is upgraded to a real join (see
  /// [upgradeFromPreviewToJoined]) without repeating the Zego room login
  /// that already happened.
  Future<void> _completeAudienceJoin(String roomID) async {
    // SessionManager.currentUser can still be transiently null this early
    // in the screen's lifecycle (session restore from disk racing against
    // this screen's first frame) — myUserId falls back to 0 in that
    // window. Every write below is keyed by doc(myUserId.toString()), so
    // a 0 read here doesn't just fail — it creates/touches a *real*,
    // separate Firestore doc at userState/0 with no way back to the
    // actual viewer. That doc then sits in this room (room id = host's
    // own id, so it's the same room every time this host goes live) and
    // the invite button on it fails forever with "userId is null" even
    // though the real viewer is working perfectly otherwise. Wait briefly
    // for a valid session instead of racing ahead with a bad id.
    var waited = 0;
    while (myUserId == 0 && waited < 2000) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      waited += 50;
    }
    if (myUserId == 0) {
      Loggers.error(
          '_completeAudienceJoin: myUserId still 0 after ${waited}ms wait — session not restored, aborting audience join to avoid writing a corrupt state doc.');
      return;
    }
    final userRef = liveStreamUsersRef.doc(myUserId.toString());
    final stateRef = liveStreamUserStatesRef.doc(myUserId.toString());

    // Set user document if not exists
    if (!(await userRef.get()).exists) {
      final userModel = myUser.value?.appUser;
      if (userModel != null) {
        await userRef.set(userModel.toJson());
      }
    }

    // Fetch user state
    final stateSnap = await stateRef
        .withConverter(
          fromFirestore: (snapshot, _) =>
              LivestreamUserState.fromJson(snapshot.data()!),
          toFirestore: (value, _) => value.toJson(),
        )
        .get();

    if (!stateSnap.exists) {
      User? myUser = this.myUser.value;
      if (myUser != null) {
        final initialState = myUser.streamState(time: 0);
        await stateRef.set(initialState.toJson());
        _sendCommentToFirestore(type: LivestreamCommentType.joined);
      } else {
        Loggers.error('User not found');
      }
    } else {
      final state = stateSnap.data();
      if (state != null) {
        updateUserStateToFirestore(
          myUserId,
          type: state.type,
          isMuted: state.isMuted,
          isVideoOn: state.isVideoOn,
        );
      }
    }

    await _joinAudience();
    _startPresenceMaintenance();

    // Arriving here via an accepted out-of-room invite (Friends /
    // Recommended tab): land in INVITED so the existing
    // updateStateAction -> _showJoinStreamSheet -> publishCoHostStream
    // path takes over, exactly like the in-room invite path. Re-check the
    // current state first so a room-state change that raced ahead of us
    // (already promoted, or re-invited to a different room) is not
    // clobbered.
    final pendingInvite = LiveInviteService.instance.takeAcceptedFor(roomID);
    if (pendingInvite != null) {
      final latestState =
          (await stateRef.get()).data() as Map<String, dynamic>?;
      final currentType = LivestreamUserType.fromStringOrNull(
        latestState?[FirebaseConst.type],
      );
      if (currentType == null || currentType == LivestreamUserType.audience) {
        await updateUserStateToFirestore(
          myUserId,
          type: LivestreamUserType.invited,
          invitedRole: pendingInvite.role,
        );
      }
    }
  }

  /// Called when a viewer taps into a room they were only previewing in
  /// LiveDiscoveryFeedScreen — runs the audience join that loginRoom()
  /// deliberately skipped while isPreviewOnly was true (no re-login needed,
  /// Zego is already connected). A no-op if this controller was never in
  /// preview mode, or already upgraded.
  Future<void> upgradeFromPreviewToJoined() async {
    if (!isPreviewOnly) return;
    isPreviewOnly = false;
    final roomID = liveData.value.roomID ?? '';
    activeRoomIds.add(roomID);
    LiveInviteWatcher.activeRoomIds.add(roomID);
    // Every stream already playing silently for the preview (see
    // startPlayStream's isPreviewOnly mute) needs its audio turned back on
    // now that this is a real join, not just a browse.
    for (final view in streamViews) {
      if (view.isMuted) {
        zegoEngine.mutePlayStreamAudio(view.streamId, false);
        view.isMuted = false;
      }
    }
    streamViews.refresh();
    await _completeAudienceJoin(roomID);
  }

  void startListenEvent() async {
    // Callback for updates on the status of other users in the room.
    // Users can only receive callbacks when the isUserStatusNotify property of ZegoRoomConfig is set to `true` when logging in to the room (loginRoom).
    ZegoExpressEngine.onRoomUserUpdate =
        (roomID, updateType, List<ZegoUser> userList) {
      // Check if multiple users are in the room
      if (userList.length > 1) {
        // Force audio to speaker
        ZegoExpressEngine.instance.setAudioRouteToSpeaker(true);
      }
      Loggers.info(
        'onRoomUserUpdate: roomID: $roomID, updateType: ${updateType.name}, userList: ${userList.map((e) => e.userID)}',
      );
    };
    // Callback for updates on the status of the streams in the room.
    ZegoExpressEngine.onRoomStreamUpdate =
        (roomID, updateType, List<ZegoStream> streamList, extendedData) async {
      String priorityId = liveData.value.hostId.toString();

      streamList.sort((a, b) {
        if (a.streamID == priorityId) {
          return -1; // a goes first
        }
        if (b.streamID == priorityId) {
          return 1; // b goes first
        }
        return a.streamID.compareTo(b.streamID); // regular sorting
      });
      Loggers.info(
        'onRoomStreamUpdate: roomID: $roomID, updateType: $updateType, streamList: ${streamList.map((e) => e.streamID)}, extendedData: $extendedData',
      );
      switch (updateType) {
        case ZegoUpdateType.Add:
          for (final stream in streamList) {
            if (stream.streamID == _myOwnStreamId) continue;
            startPlayStream(stream.streamID);
          }
          break;
        case ZegoUpdateType.Delete:
          for (final stream in streamList) {
            if (stream.streamID == _myOwnStreamId) continue;
            if (liveData.value.roomID == stream.streamID) {
              unawaited(_handleRemoteStreamEnded());
            }
            streamViews.removeWhere(
              (element) => element.streamId == stream.streamID,
            );
            stopPlayStream(stream.streamID);
          }
          break;
      }
    };
    // Callback for updates on the current user's room connection status.
    ZegoExpressEngine.onRoomStateUpdate =
        (roomID, state, errorCode, extendedData) {
      Loggers.info(
        'onRoomStateUpdate: roomID: $roomID, state: ${state.name}, errorCode: $errorCode, extendedData: $extendedData',
      );
    };

    // Callback for updates on the current user's stream publishing changes.
    ZegoExpressEngine.onPublisherStateUpdate =
        (streamID, state, errorCode, extendedData) {
      switch (state) {
        case ZegoPublisherState.NoPublish:
          final mine = streamViews.firstWhereOrNull(
            (element) => element.streamId == streamID,
          );
          if (mine != null) _lastOwnStreamView = mine;
          streamViews.removeWhere((element) => element.streamId == streamID);
          break;
        case ZegoPublisherState.PublishRequesting:
          break;
        case ZegoPublisherState.Publishing:
          // Toggling the local capture source (e.g. switching DeepAR
          // filters live — create_live_stream_screen_controller.dart's
          // enableCamera(false)/enableCustomVideoCapture/enableCamera(true)
          // handoff) briefly flips this device's own publish state through
          // NoPublish and back, even though the canvas view itself is never
          // torn down. Without restoring the entry here, the NoPublish
          // branch above leaves this seat's StreamView gone for good and
          // the host/co-host's own tile is stuck on the "Reconnecting..."
          // placeholder forever, despite video actually flowing again.
          final stillMissing = !streamViews.any(
            (element) => element.streamId == streamID,
          );
          if (stillMissing && _lastOwnStreamView?.streamId == streamID) {
            streamViews.add(_lastOwnStreamView!);
          }
          break;
      }
      debugPrint(
        'onPublisherStateUpdate: streamID: $streamID, state: ${state.name}, errorCode: $errorCode, extendedData: $extendedData',
      );
    };
  }

  void stopListenEvent() {
    ZegoExpressEngine.onRoomUserUpdate = null;
    ZegoExpressEngine.onRoomStreamUpdate = null;
    ZegoExpressEngine.onRoomStateUpdate = null;
    ZegoExpressEngine.onPublisherStateUpdate = null;
  }

  Future<void> startHostPublish() async {
    if ((liveData.value.roomID ?? '').isEmpty) {
      return Loggers.error('No ID FOUND');
    }
    String streamID = liveData.value.roomID ?? '';
    streamViews.add(
      StreamView(
        streamID,
        liveData.value.hostViewID ?? -1,
        hostPreview!,
        false,
      ),
    );
    await zegoEngine.mutePublishStreamAudio(false); // Ensure audio is not muted
    startMinViewerTimeoutCheck(); //  Check time to Min. Viewers Required to continue live
    pushNotificationToFollowers(liveData.value);
    return zegoEngine.startPublishingStream(streamID);
  }

  Future<void> stopPublish() async {
    return zegoEngine.stopPublishingStream();
  }

  Future<void> startPlayStream(String streamID) async {
    Loggers.info('Starting to play stream: $streamID');
    int streamViewId = -1;
    try {
      await zegoEngine.createCanvasView((viewID) {
        Loggers.info('Created remote view with ID: $viewID');
        streamViewId = viewID;
        ZegoCanvas canvas = ZegoCanvas(
          viewID,
          viewMode: ZegoViewMode.AspectFill,
        );
        ZegoPlayerConfig config = ZegoPlayerConfig.defaultConfig();
        config.resourceMode =
            ZegoStreamResourceMode.Default; // live streaming (CDN)

        Loggers.info(
          'StartPlayStream playback: StreamID: $streamID, ViewMode: ${canvas.viewMode}, ResourceMode: ${config.resourceMode}',
        );

        zegoEngine.startPlayingStream(
          streamID,
          canvas: canvas,
          config: config,
        );
        // A preview-only controller (LiveDiscoveryFeedScreen browsing, see
        // isPreviewOnly) is meant to be silent -- real video, no audio --
        // until the viewer actually taps in. startPlayingStream() has no
        // muted option of its own, so mute right after starting or every
        // stream in a previewed room plays its audio out loud the instant
        // it's detected, with no join on this viewer's part.
        if (isPreviewOnly) {
          zegoEngine.mutePlayStreamAudio(streamID, true);
        }
      }).then((canvasViewWidget) {
        if (canvasViewWidget != null) {
          streamViews.add(
            StreamView(streamID, streamViewId, canvasViewWidget, isPreviewOnly),
          );
        }
        Loggers.success(
          'Stream playback started successfully for: $streamID',
        );
      });
    } catch (e, stackTrace) {
      Loggers.error('Failed to start playing stream: $e');
      Loggers.error('StackTrace: $stackTrace');
    }
  }

  Future<void> stopPlayStream(String streamID) async {
    Loggers.info('Stopping playback for stream: $streamID');

    try {
      zegoEngine.stopPlayingStream(streamID);
      Loggers.success('Stopped playing stream: $streamID');

      StreamView? stream = streamViews.firstWhereOrNull(
        (element) => element.streamId == streamID,
      );

      if (stream?.streamViewId != null) {
        Loggers.info('Destroying remote view with ID: ${stream?.streamViewId}');
        await zegoEngine.destroyCanvasView(stream!.streamViewId);
        Loggers.success('Remote view destroyed successfully.');
      }
    } catch (e, stackTrace) {
      Loggers.error('Failed to stop playing stream: $e');
      Loggers.error('StackTrace: $stackTrace');
    }
  }

  Future<void> stopPreview({int? viewId}) async {
    int id = viewId ?? -1;
    zegoEngine.stopPreview();
    if (id != -1) {
      await zegoEngine.destroyCanvasView(id);
    }
  }

  Future<void> updateLiveStreamData({
    BattleType? battleType,
    LivestreamType? type,
    String? description,
    bool? commentsEnabled,
    int? battleCreatedAt,
    int? battleDuration,
    FieldValue? coHostId,
    FieldValue? guestId,
    FieldValue? pendingSeatId,
    dynamic battleRoundWins,
    dynamic battleRoundWinsHost,
    dynamic battleRoundWinsCoHost,
    dynamic battleTotalRounds,
    dynamic battleCurrentRound,
    dynamic firstGiftBonusClaimed,
  }) async {
    bool isExist = (await liveStreamDocRef.get()).exists;
    if (!isExist) return;

    await liveStreamDocRef.update({
      if (battleType != null) FirebaseConst.battleType: battleType.value,
      if (type != null) FirebaseConst.type: type.value,
      if (description != null) 'description': description,
      if (commentsEnabled != null)
        FirebaseConst.commentsEnabled: commentsEnabled,
      if (battleCreatedAt != null)
        FirebaseConst.battleCreatedAt: battleCreatedAt,
      if (battleDuration != null) FirebaseConst.battleDuration: battleDuration,
      if (coHostId != null) FirebaseConst.coHostIds: coHostId,
      if (guestId != null) FirebaseConst.guestIds: guestId,
      if (pendingSeatId != null) FirebaseConst.pendingSeatIds: pendingSeatId,
      if (battleRoundWins != null)
        FirebaseConst.battleRoundWins: battleRoundWins,
      if (battleRoundWinsHost != null)
        FirebaseConst.battleRoundWinsHost: battleRoundWinsHost,
      if (battleRoundWinsCoHost != null)
        FirebaseConst.battleRoundWinsCoHost: battleRoundWinsCoHost,
      if (battleTotalRounds != null)
        FirebaseConst.battleTotalRounds: battleTotalRounds,
      if (battleCurrentRound != null)
        FirebaseConst.battleCurrentRound: battleCurrentRound,
      if (firstGiftBonusClaimed != null)
        FirebaseConst.firstGiftBonusClaimed: firstGiftBonusClaimed,
    });
  }

  Future<void> _joinAudience() async {
    if (_hasIncrementedWatchingCount) return;
    // Defense in depth alongside loginRoom()'s own wait: never let a 0 id
    // reach doc(myUserId.toString()) and create a phantom userState/0.
    if (myUserId == 0) {
      Loggers.error(
          '_joinAudience: myUserId is 0, skipping to avoid a corrupt state doc.');
      return;
    }
    try {
      _hasIncrementedWatchingCount = await db.runTransaction<bool>((tx) async {
        final streamSnapshot = await tx.get(liveStreamDocRef);
        if (!streamSnapshot.exists) return false;

        final stateRef = liveStreamUserStatesRef.doc(myUserId.toString());
        final stateSnapshot = await tx.get(stateRef);
        final stateData = stateSnapshot.data() as Map<String, dynamic>? ?? {};
        final alreadyCounted = stateData[FirebaseConst.countedAsViewer] == true;
        final now = DateTime.now().millisecondsSinceEpoch;

        // loginRoom()'s full-state creation silently does nothing if
        // myUser.value is transiently null at that exact moment (just logs
        // "User not found") — but this merge still runs right after
        // regardless. Without 'user_id' here, that leaves behind a doc at
        // the correct path (userState/<myUserId>) whose identity field is
        // simply absent, which LivestreamUserState.fromJson defaults to 0
        // (`json['user_id'] ?? 0`). That doc then poisons every future
        // "Go Live" in this room (room id = host's own id, so it's the same
        // room every time) — the invite button starts failing with
        // "userId is null" for a viewer who is, in reality, fine. Always
        // writing user_id here means this merge can never produce a
        // document with a missing identity, whether or not it ends up
        // being the first write to create it.
        tx.set(
            stateRef,
            {
              FirebaseConst.countedAsViewer: true,
              FirebaseConst.lastSeenAt: now,
              'user_id': myUserId,
            },
            SetOptions(merge: true));

        if (!alreadyCounted) {
          final streamData =
              streamSnapshot.data() as Map<String, dynamic>? ?? {};
          final current =
              (streamData[FirebaseConst.watchingCount] as num?)?.toInt() ?? 0;
          tx.update(liveStreamDocRef, {
            FirebaseConst.watchingCount: current + 1,
          });
        }
        return true;
      });
    } catch (e) {
      Loggers.error('Failed to join LIVE audience: $e');
    }
  }

  Future<void> _leaveAudience() async {
    if (!_hasIncrementedWatchingCount) return;
    _hasIncrementedWatchingCount = false;
    try {
      await db.runTransaction<void>((tx) async {
        final streamSnapshot = await tx.get(liveStreamDocRef);
        final stateRef = liveStreamUserStatesRef.doc(myUserId.toString());
        final stateSnapshot = await tx.get(stateRef);
        final stateData = stateSnapshot.data() as Map<String, dynamic>? ?? {};
        final wasCounted = stateData[FirebaseConst.countedAsViewer] == true;

        tx.set(
            stateRef,
            {
              FirebaseConst.countedAsViewer: false,
              FirebaseConst.lastSeenAt: DateTime.now().millisecondsSinceEpoch,
            },
            SetOptions(merge: true));

        if (streamSnapshot.exists && wasCounted) {
          final streamData =
              streamSnapshot.data() as Map<String, dynamic>? ?? {};
          final current =
              (streamData[FirebaseConst.watchingCount] as num?)?.toInt() ?? 0;
          tx.update(liveStreamDocRef, {
            FirebaseConst.watchingCount: current > 0 ? current - 1 : 0,
          });
        }
      });
    } catch (e) {
      Loggers.error('Failed to leave LIVE audience: $e');
    }
    await updateLiveStreamData(
      coHostId: FieldValue.arrayRemove([myUserId]),
      guestId: FieldValue.arrayRemove([myUserId]),
      pendingSeatId: FieldValue.arrayRemove([myUserId]),
    );
  }

  void _startPresenceMaintenance() {
    presenceTimer?.cancel();
    unawaited(_maintainPresence());
    presenceTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_maintainPresence()),
    );
  }

  Future<void> _maintainPresence() async {
    if (liveData.value.isDummyLive == 1 || _isLoggingOut) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (isHost) {
      try {
        await liveStreamDocRef.update({FirebaseConst.lastHeartbeatAt: now});
        await _removeStaleAudience(now);
      } catch (e) {
        Loggers.error('LIVE heartbeat failed: $e');
      }
      return;
    }

    if (myUserId == 0) return;
    try {
      await liveStreamUserStatesRef.doc(myUserId.toString()).set({
        FirebaseConst.lastSeenAt: now,
        FirebaseConst.countedAsViewer: true,
        'user_id': myUserId,
      }, SetOptions(merge: true));
    } catch (e) {
      Loggers.error('LIVE viewer heartbeat failed: $e');
    }

    final heartbeat =
        liveData.value.lastHeartbeatAt ?? liveData.value.createdAt;
    if (heartbeat != null && now - heartbeat > 60000) {
      try {
        final latest = await liveStreamDocRef.get();
        final data = latest.data() as Map<String, dynamic>?;
        final latestHeartbeat =
            (data?[FirebaseConst.lastHeartbeatAt] as num?)?.toInt() ??
                heartbeat;
        if (DateTime.now().millisecondsSinceEpoch - latestHeartbeat > 60000) {
          await liveStreamDocRef.delete();
          await _handleRemoteStreamEnded();
        }
      } catch (e) {
        Loggers.error('Failed to recover stale LIVE room: $e');
      }
    }
  }

  Future<void> _removeStaleAudience(int now) async {
    final snapshot = await liveStreamUserStatesRef.get();
    final staleRefs = <DocumentReference>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      if (data[FirebaseConst.countedAsViewer] != true) continue;
      final userId = (data['user_id'] as num?)?.toInt();
      if (userId == liveData.value.hostId) continue;
      // Co-hosts and guests are publishing participants, not viewers: a
      // backgrounded one must not be silently dropped from the count.
      final type =
          LivestreamUserType.fromString(data[FirebaseConst.type] ?? '');
      if (type.isOnStage) continue;
      final lastSeen = (data[FirebaseConst.lastSeenAt] as num?)?.toInt();
      if (lastSeen != null && now - lastSeen > 45000)
        staleRefs.add(doc.reference);
    }
    if (staleRefs.isEmpty) return;

    await db.runTransaction<void>((tx) async {
      final streamSnapshot = await tx.get(liveStreamDocRef);
      if (!streamSnapshot.exists) return;
      final streamData = streamSnapshot.data() as Map<String, dynamic>? ?? {};
      final count =
          (streamData[FirebaseConst.watchingCount] as num?)?.toInt() ?? 0;
      for (final ref in staleRefs) {
        tx.update(ref, {FirebaseConst.countedAsViewer: false});
      }
      tx.update(liveStreamDocRef, {
        FirebaseConst.watchingCount: (count - staleRefs.length).clamp(0, count),
      });
    });
  }

  Future<void> _handleRemoteStreamEnded() async {
    if (isHost || _hasHandledRemoteEnd) return;
    _hasHandledRemoteEnd = true;

    showSnackBar(LKey.livestreamHasEnded.tr);
    await _leaveAudience();
    await logoutRoom();

    if (Get.isBottomSheetOpen == true || Get.isDialogOpen == true) {
      Get.back();
      await Future<void>.delayed(Duration.zero);
    }
    await _popAudienceRoute();
  }

  Future<void> _popAudienceRoute() async {
    canPopStreamRoute.value = true;
    await WidgetsBinding.instance.endOfFrame;
    Get.off(() => const LiveStreamSearchScreen());
  }

  Future<void> onRequestRefuse(
    AppUser? user, {
    LivestreamComment? comment,
    LivestreamCommentType? type,
    bool resetToAudience = true,
  }) async {
    if (user?.userId == null) return;

    if (resetToAudience) {
      await updateUserStateToFirestore(
        user?.userId,
        type: LivestreamUserType.audience,
      );
    }
    LivestreamComment? liveComment;
    if (comment == null) {
      liveComment = comments.firstWhereOrNull(
        (element) =>
            element.senderId == user?.userId &&
            LivestreamCommentType.request == type,
      );
    } else {
      liveComment = comment;
    }
    if (liveComment?.id != null) {
      await liveStreamCommentsRef.doc(liveComment!.id.toString()).delete();
    }
  }

  Future<void> acceptJoinRequest(
    AppUser? user, {
    LivestreamComment? comment,
  }) async {
    if (user?.userId == null) return;

    // Request-to-join always lands in the Guest Call role — Co-host Mode is
    // invite-only — so the cap checked here is the guest one.
    if (!hasSeatFor(LivestreamUserType.guest)) {
      showSnackBar(LKey.guestSeatsFull.tr);
      return;
    }
    await onRequestRefuse(
      user,
      comment: comment,
      type: LivestreamCommentType.request,
      resetToAudience: false,
    );
    await updateUserStateToFirestore(
      user!.userId,
      type: LivestreamUserType.guest,
    );
  }

  Future<void> deleteStreamOnFirebase() async {
    final String? roomId = liveData.value.roomID;

    if (roomId == null) {
      Loggers.error('Room ID is null. Cannot stop live stream.');
      return;
    }

    Loggers.info('Stopping live stream Room : $roomId');

    try {
      final usersSnapshot = await liveStreamUserStatesRef.get();
      final commentsSnapshot = await liveStreamCommentsRef.get();

      Loggers.info(
        'Found ${usersSnapshot.docs.length} livestream users_state documents.',
      );
      Loggers.info(
        'Found ${commentsSnapshot.docs.length} livestream comments.',
      );

      final childReferences = <DocumentReference>[
        ...usersSnapshot.docs.map((doc) => doc.reference),
        ...commentsSnapshot.docs.map((doc) => doc.reference),
      ];
      await _deleteReferencesInBatches(childReferences);
      await liveStreamDocRef.delete();
      Loggers.success(
        'livestream , users_states , comments  deleted from Firestore.',
      );
    } catch (e, stackTrace) {
      Loggers.error('Failed to stop live stream: $e');
      Loggers.error('StackTrace: $stackTrace');
    }
  }

  Future<void> _deleteReferencesInBatches(
    List<DocumentReference> references,
  ) async {
    const batchSize = 450;
    for (var start = 0; start < references.length; start += batchSize) {
      final end = (start + batchSize < references.length)
          ? start + batchSize
          : references.length;
      final batch = db.batch();
      for (final reference in references.sublist(start, end)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }

  void listenLiveStreamData() {
    _lastAnimatedLikeCount = liveData.value.likeCount ?? 0;

    liveStreamDocListener = liveStreamDocRef
        .withConverter<Livestream>(
          fromFirestore: (snapshot, _) {
            if (!snapshot.exists) {
              Loggers.error(
                'Livestream document not found for Room ID: ${liveData.value.roomID}',
              );
              return Livestream(); // default instance
            }
            return Livestream.fromJson(snapshot.data()!);
          },
          toFirestore: (value, _) => value.toJson(),
        )
        .snapshots()
        .listen(
      (event) async {
        if (!event.exists) {
          await _handleRemoteStreamEnded();
          return;
        }

        final stream = event.data();
        if (stream == null) {
          Loggers.warning('Livestream data is null');
          // AppUser? appUser = firestoreController.users.firstWhereOrNull(
          //     (element) => element.userId == liveData.value.hostId);
          // LivestreamUserState userState = LivestreamUserState(
          //     isMuted: false,
          //     isVideoOn: true,
          //     type: LivestreamUserType.host,
          //     userId: appUser?.userId ?? -1,
          //     liveCoin: 0,
          //     currentBattleCoin: 0,
          //     totalBattleCoin: 0,
          //     followersGained: [],
          //     joinStreamTime: 0,
          //     user: appUser);
          //
          // DebounceAction.shared.call(() {
          //   Get.bottomSheet(
          //     LivestreamEndSheet(
          //         onTap: deleteStreamOnFirebase, userState: userState),
          //     isScrollControlled: true,
          //     enableDrag: false,
          //   );
          // });
          return;
        }

        if (stream.battleType == BattleType.initiate) {
          timer?.cancel();
          remainingBattleSeconds.value = Duration(
            minutes: stream.battleDuration,
          ).inSeconds;
        }

        // RUNNING included, not just WAITING -- a cross-room PK match now
        // jumps straight from INITIATE to RUNNING (no countdown stage, see
        // acceptPkMatch/acceptRematch), so WAITING alone stopped firing for
        // that flow and totalBattleSecond was left stuck at whatever stale
        // value LIVE-start init or an earlier battle had set, not the fresh
        // battleDuration just written. Recomputing on RUNNING too is a
        // no-op once already correct (same battleDuration every time).
        if (stream.battleType == BattleType.waiting ||
            stream.battleType == BattleType.running) {
          totalBattleSecond = Duration(
            minutes: stream.battleDuration,
          ).inSeconds;
        }

        // Bump the winning side's running "WIN xN" tally once per same-room
        // match end (same battle_round_wins_host/cohost fields cross-room
        // battles already use, see WinPill) — host-only so every connected
        // device doesn't race to increment it. _pkMatchWinRecorded guards
        // against the listener re-firing on every snapshot update while
        // battleType stays "end" (likes ticking in, viewer count, etc.)
        // double-counting it; previously piggybacked on the now-removed
        // cosmetic "Victory lap" countdown timer's own null-check for the
        // same one-shot purpose.
        if (stream.battleType == BattleType.end &&
            stream.opponentRoomId == null &&
            !_pkMatchWinRecorded) {
          _pkMatchWinRecorded = true;
          if (isHost) unawaited(_recordPkMatchWin(stream));
        }
        if (stream.battleType != BattleType.end) {
          _pkMatchWinRecorded = false;
        }

        // Update LiveData
        liveData.value = stream;

        // Trigger like animation on forward progress only (never on a
        // smaller count than we've already shown). Guards two things: the
        // echo of a like this device already animated optimistically (see
        // onLikeButtonTap) shouldn't fire a second burst, and an
        // intermediate snapshot arriving out of order during rapid
        // multi-tapping shouldn't regress the counter and re-trigger.
        final newLikeCount = stream.likeCount ?? 0;
        if (newLikeCount > _lastAnimatedLikeCount) {
          onLikeTap?.call(null);
          _lastAnimatedLikeCount = newLikeCount;
        }

        // Co-Host Connection: an incoming connect invite to accept/decline.
        if (isHost &&
            stream.pendingBattleInviteFromId != null &&
            stream.pendingBattleInviteFromId != _lastHandledInviteFromId) {
          _lastHandledInviteFromId = stream.pendingBattleInviteFromId;
          _showIncomingCoHostConnectDialog(stream.pendingBattleInviteFromId!);
        }
        if (stream.pendingBattleInviteFromId == null) {
          _lastHandledInviteFromId = null;
        }

        // "Play PK Match": the other connected co-host wants to start a
        // battle on this already-connected pair -- same accept/decline
        // shape as the connect invite above, separate step (see client's
        // binding clarification that connecting must never auto-start PK).
        if (isHost &&
            stream.pendingPkMatchRequestFromId != null &&
            stream.pendingPkMatchRequestFromId !=
                _lastHandledPkMatchRequestFromId) {
          _lastHandledPkMatchRequestFromId =
              stream.pendingPkMatchRequestFromId;
          _showIncomingPkMatchRequestDialog(
              stream.pendingPkMatchRequestFromId!);
        }
        if (stream.pendingPkMatchRequestFromId == null) {
          _lastHandledPkMatchRequestFromId = null;
        }

        // Rematch: same shape as the invite above, just checked after a
        // battle has already ended rather than before one starts.
        if (isHost &&
            stream.pendingRematchFromId != null &&
            stream.pendingRematchFromId != _lastHandledRematchFromId) {
          _lastHandledRematchFromId = stream.pendingRematchFromId;
          _showIncomingRematchDialog(stream.pendingRematchFromId!);
        }
        if (stream.pendingRematchFromId == null) {
          _lastHandledRematchFromId = null;
        }

        // Same-room PK Match: shown to whichever non-host player(s) the
        // host named in the invite, never to the host themselves (they
        // already consented by sending it).
        if (!isHost &&
            stream.pkInviteFromId != null &&
            (stream.pkInviteFromId != _lastHandledPkInviteFromId ||
                stream.pkInviteSentAt != _lastHandledPkInviteSentAt) &&
            _isOnPkInviteTeam(stream, myUserId)) {
          _lastHandledPkInviteFromId = stream.pkInviteFromId;
          _lastHandledPkInviteSentAt = stream.pkInviteSentAt;
          _showIncomingPkMatchDialog(stream);
        }
        if (stream.pkInviteFromId == null) {
          _lastHandledPkInviteFromId = null;
          _lastHandledPkInviteSentAt = null;
        }

        // Host: the invite I sent disappeared without the match starting —
        // the invitee declined, or it expired on their side.
        if (isHost &&
            _awaitingPkInviteResponse &&
            stream.pkInviteFromId == null) {
          _awaitingPkInviteResponse = false;
          if (stream.type != LivestreamType.battle) {
            showSnackBar(LKey.pkMatchDeclined.tr);
          }
        }

        // Host: every required player has accepted — start the match.
        if (isHost &&
            stream.pkInviteFromId == myUserId &&
            !_pkMatchStartInFlight &&
            _allPkInviteesAccepted(stream)) {
          _pkMatchStartInFlight = true;
          unawaited(_startPkMatch(stream));
        }

        // Cross-room PK Battle: start/stop watching the opponent room as
        // opponentRoomId comes and goes.
        if (stream.opponentRoomId != _watchedOpponentRoomId) {
          if (stream.opponentRoomId != null) {
            _startWatchingOpponent(stream.opponentRoomId!);
          } else {
            _stopWatchingOpponent();
          }
        }
      },
      onError: (error) =>
          Loggers.error('Error listening to livestream: $error'),
    );
  }

  void listenUserState() {
    // Cancel any existing listener
    liveStreamUserStatesListener?.cancel();
    // Loggers.info('👂 Listening to live stream users state...');

    liveStreamUserStatesListener = liveStreamUserStatesRef
        .withConverter(
          fromFirestore: (snapshot, options) {
            if (!snapshot.exists) return null;
            return LivestreamUserState.fromJson(snapshot.data()!);
          },
          toFirestore: (value, options) {
            if (value == null) return {};
            return value.toJson();
          },
        )
        .snapshots()
        .listen((event) {
          // Loggers.info(
          //     '📦 Firestore snapshot received with ${event.docChanges.length} changes');

          for (var change in event.docChanges) {
            final state = change.doc.data();
            if (state == null) {
              // Loggers.warning('⚠️ Null state found in change, skipping...');
              continue;
            }
            switch (change.type) {
              case DocumentChangeType.added:
                _showJoinStreamSheet(state);
                liveUsersStates.removeWhere(
                  (user) => user.userId == state.userId,
                );
                liveUsersStates.add(state);
                // Loggers.info('➕ User added: ${state.userId}');
                break;

              case DocumentChangeType.modified:
                LivestreamUserState? oldState =
                    liveUsersStates.firstWhereOrNull(
                  (element) => element.userId == state.userId,
                );

                updateStateAction(oldState, state);
                liveUsersStates.removeWhere((u) => u.userId == state.userId);
                liveUsersStates.add(state);
                // Loggers.info('🔁 User modified: ${state.userId}');
                break;

              case DocumentChangeType.removed:
                liveUsersStates.removeWhere((u) => u.userId == state.userId);
                // Loggers.info('➖ User removed: ${state.userId}');
                break;
            }
          }
          requestList.value = liveUsersStates
              .where((element) => element.type == LivestreamUserType.requested)
              .toList();
          audienceList.value = liveUsersStates
              .where((element) => element.type == LivestreamUserType.audience)
              .toList();
          invitedList.value = liveUsersStates
              .where((element) => element.type == LivestreamUserType.invited)
              .toList();
          coHostList.value = liveUsersStates
              .where((element) => element.type == LivestreamUserType.coHost)
              .toList();
          guestList.value = liveUsersStates
              .where((element) => element.type == LivestreamUserType.guest)
              .toList();
          audienceMemberList.value = liveUsersStates
              .where(
                (element) =>
                    element.type != LivestreamUserType.left &&
                    element.userId != myUserId,
              )
              .toList();
        });
  }

  void fetchLiveStreamComments() {
    Loggers.info('Fetching live stream comments...');
    liveStreamCommentsListener?.cancel();
    _commentListenerStartedAt = DateTime.now().millisecondsSinceEpoch;
    // A room's comments subcollection lives at liveStreams/{roomID} —
    // roomID is the host's own user id, so it's the exact same Firestore
    // path every time this host ever goes live. An unfiltered listener on
    // that path fires every historical comment (including old "joined the
    // stream" messages from accounts that visited a *previous* session) as
    // a fresh "added" change the instant it subscribes — Firestore replays
    // the full current matching set on first snapshot, with no concept of
    // "only what's new since I opened this screen". Comments are id'd by
    // their own creation-time epoch millis (see _sendCommentToFirestore),
    // so scoping to this session's own createdAt excludes everything
    // written before this particular stream started.
    liveStreamCommentsListener = liveStreamCommentsRef
        .where(FirebaseConst.id,
            isGreaterThanOrEqualTo: liveData.value.createdAt ?? 0)
        .withConverter(
          fromFirestore: (snapshot, options) {
            if (!snapshot.exists) {
              Loggers.error('No comments found in Firestore.');
              return null;
            }
            return LivestreamComment.fromJson(snapshot.data()!);
          },
          toFirestore: (value, options) => value?.toJson() ?? {},
        )
        .snapshots()
        .listen((querySnapshot) {
      // Loggers.info(
      //     'Received comment changes: ${querySnapshot.docChanges.length}');

      for (var change in querySnapshot.docChanges) {
        LivestreamComment? comment = change.doc.data();
        if (comment == null) {
          Loggers.error('Null comment received.');
          continue;
        }

        switch (change.type) {
          case DocumentChangeType.added:
            if (comment.commentType == LivestreamCommentType.request &&
                !isHost) {
              continue;
            }
            comments.add(comment);
            if (comment.commentType == LivestreamCommentType.gift) {
              // One-shot visual effects only for a comment actually posted
              // since THIS subscribe -- otherwise re-entering an still-
              // ongoing LIVE replays every gift from earlier in the session
              // (see fetchLiveStreamComments' own comment) and re-fires
              // these, including getting the premium overlay stuck again
              // if its video stalls. The comment itself still belongs in
              // the feed either way, so comments.add above is unguarded.
              final isFreshComment = (comment.id ?? 0) >=
                  (_commentListenerStartedAt ?? 0);
              if (isFreshComment) {
                _registerGiftForCombo(comment);
                if (comment.giftId == eagleGiftId) {
                  eagleGiftAnimationTrigger.value++;
                }
                if (premiumAnimationForGift(comment.giftId) != null) {
                  premiumGiftAnimationComment.value = comment;
                  premiumGiftAnimationTrigger.value++;
                }
              }
              if (comment.receiverId == SessionManager.instance.getUserID()) {
                _refreshMyBalanceAfterGift();
              }
            }
            // Loggers.info('New comment added: ${comment.toJson()}');
            break;

          case DocumentChangeType.modified:
            if (comment.commentType == LivestreamCommentType.request &&
                !isHost) {
              return;
            }
            int index = comments.indexWhere((c) => c.id == comment.id);
            if (index != -1) {
              comments[index] = comment;
              // Loggers.info('Comment modified: ${comment.toJson()}');
            }
            break;

          case DocumentChangeType.removed:
            comments.removeWhere((c) => c.id == comment.id);
            // Loggers.info('Comment removed: ${comment.id}');
            break;
        }
      }

      // Assign sender and receiver users to comments
      for (var comment in comments) {
        comment.gift = gifts.firstWhereOrNull(
          (gift) => gift.id == comment.giftId,
        );
      }

      comments.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    });
  }

  Future<void> toggleCamera() async {
    await toggleFlipCamera();
  }

  Future<void> toggleFlipCamera() async {
    final nextValue = !isFrontCamera;
    try {
      await zegoEngine.useFrontCamera(
        nextValue,
        channel: ZegoPublishChannel.Main,
      );
      isFrontCamera = nextValue;
    } catch (e) {
      Loggers.error('Failed to flip LIVE camera: $e');
      showSnackBar('Unable to flip the camera.');
    }
  }

  Future<void> toggleMic(bool isMuted) async {
    final nextValue = !isMuted;
    try {
      await zegoEngine.muteMicrophone(nextValue);
      await liveStreamUserStatesRef.doc('$myUserId').update({
        FirebaseConst.isMuted: nextValue,
      });
    } catch (e) {
      Loggers.error('Failed to toggle LIVE microphone: $e');
      showSnackBar('Unable to change the microphone.');
    }
  }

  Future<void> toggleVideo(bool isVideoOn) async {
    final nextValue = !isVideoOn;
    try {
      await zegoEngine.enableCamera(nextValue);
      await liveStreamUserStatesRef.doc('$myUserId').update({
        FirebaseConst.isVideoOn: nextValue,
      });
    } catch (e) {
      Loggers.error('Failed to toggle LIVE camera: $e');
      showSnackBar('Unable to change the camera.');
    }
  }

  void toggleStreamAudio(int? streamId) {
    if (streamId == null) return;
    final streamKey = '$streamId';
    StreamView? view = streamViews.firstWhereOrNull(
      (element) => element.streamId == streamKey,
    );

    if (view == null) {
      showSnackBar('This LIVE audio stream is no longer available.');
      return;
    }

    zegoEngine.mutePlayStreamAudio(
      streamKey,
      !view.isMuted,
    );
    view.isMuted = !view.isMuted;
    streamViews[streamViews.indexWhere(
      (element) => element.streamId == streamKey,
    )] = view;
    streamViews.refresh();
  }

  /// [isLeftHalf] is which half of the screen was tapped, in screen-width
  /// terms — meaningful during either kind of active PK Match: same-room
  /// (left = team A/host, right = team B, both tallied on this one doc via
  /// pkLikePointsA/B) or cross-room (left = this room's own side, on this
  /// doc's crossRoomLikePoints; right = the opponent room's side, written
  /// to THEIR doc's crossRoomLikePoints — same cross-document write pattern
  /// already used elsewhere for a connected opponent, e.g.
  /// acceptCoHostConnectInvite).
  void onLikeButtonTap([Offset? tapPosition, bool? isLeftHalf]) async {
    HapticManager.shared.light();
    // Optimistic local heart burst — don't make the tapper wait for the
    // Firestore round-trip. _lastAnimatedLikeCount is bumped in lockstep so
    // listenLiveStreamData recognises the eventual Firestore echo of this
    // same increment as already-shown, rather than firing a second burst.
    // tapPosition anchors the burst at wherever the viewer actually tapped.
    onLikeTap?.call(tapPosition);
    _lastAnimatedLikeCount++;
    bool isExist = (await liveStreamDocRef.get()).exists;
    if (isExist) {
      final stream = liveData.value;
      final updates = <String, dynamic>{
        FirebaseConst.likeCount: FieldValue.increment(1),
      };
      final isCrossRoomBattling = stream.opponentRoomId != null &&
          stream.type == LivestreamType.battle;
      if (isLeftHalf != null &&
          stream.battleType == BattleType.waiting &&
          stream.pkTeamAIds != null) {
        updates[isLeftHalf
            ? FirebaseConst.pkLikePointsA
            : FirebaseConst.pkLikePointsB] = FieldValue.increment(1);
      } else if (isLeftHalf != null && isCrossRoomBattling) {
        if (isLeftHalf) {
          updates[FirebaseConst.crossRoomLikePoints] = FieldValue.increment(1);
        } else {
          unawaited(_roomDocRef(stream.opponentRoomId!).update({
            FirebaseConst.crossRoomLikePoints: FieldValue.increment(1),
          }));
        }
      }
      liveStreamDocRef.update(updates);

      // Like goals read directly from the atomically incremented like count.
    }
  }

  void onTextCommentSend() {
    String comment = textCommentController.text.trim();
    textCommentController.clear();
    isTextEmpty.value = true;
    if (comment.isEmpty) return;
    if (!liveData.value.commentsEnabled) {
      showSnackBar('Comments are turned off for this LIVE.');
      return;
    }
    _sendCommentToFirestore(type: LivestreamCommentType.text, comment: comment);
  }

  void onGiftTap(
    GiftType type, {
    BattleView battleViewType = BattleView.red,
    List<AppUser> users = const [],
  }) {
    final availableUsers = List<AppUser>.from(users)
      ..removeWhere((element) => element.userId == myUserId);
    if (liveData.value.type == LivestreamType.battle &&
        liveData.value.battleType == BattleType.end) {
      return showSnackBar(LKey.battleEndedGiftNotSent.tr);
    }
    GiftManager.openGiftSheet(
      onCompletion: (giftManager) => _handleGiftSent(type, giftManager),
      giftType: type,
      battleViewType: battleViewType,
      streamUsers: availableUsers,
      roomID: liveData.value.roomID,
    );
  }

  /// Everything that happens once a gift has actually been paid for and
  /// sent — Firestore comment (this is what drives TileGiftBubble/
  /// GiftComboBadge/the shared comment feed), battle score, daily/hourly/
  /// league ranking, live-goal progress. Pulled out of [onGiftTap]'s
  /// `onCompletion` so [sendQuickGift] (the one-tap Rose shortcut, no gift
  /// sheet involved) can trigger the exact same bookkeeping instead of a
  /// second, drift-prone copy of it.
  Future<void> _handleGiftSent(GiftType type, GiftManager giftManager) async {
    Gift gift = giftManager.gift;
    AppUser? user = giftManager.streamUser;

    int coinPrice = gift.coinPrice?.toInt() ?? 0;
    if (type == GiftType.battle) {
      coinPrice = await _claimFirstGiftBonusIfEligible(coinPrice);
    }
    // Battle score and real coin value are deliberately different numbers:
    // battleGiftTiers lets specific gifts (Rose/Heart/Coffee/Galaxy) be
    // worth a fixed, configured point value in a PK Battle (e.g. Galaxy =
    // 1000) independent of what they actually cost in coins. Everything
    // else (liveCoin, the ranking/league controllers below) still uses the
    // real coinPrice, including the first-gift bonus applied above — only
    // the battle scoreboard itself reads battlePoints. A gift with no tier
    // mapping falls back to coinPrice 1:1, so this is a no-op for every
    // gift not explicitly configured.
    final battlePoints = battlePointsForGift(gift.id, fallbackCoins: coinPrice);
    // A PK Match can restrict scoring to specific gifts (pkEligibleGiftIds,
    // set from the match setup sheet); null/empty means every gift counts,
    // same as every battle before this existed. The gift itself still sends
    // and the coin value above still transfers either way — only the
    // battle score is skipped.
    final countsForPk =
        giftCountsForPk(gift.id, liveData.value.pkEligibleGiftIds);

    _sendCommentToFirestore(
      type: LivestreamCommentType.gift,
      giftId: gift.id,
      receiverId: user?.userId,
    );
    updateUserStateToFirestore(
      user?.userId,
      battleCoin: type == GiftType.battle && countsForPk ? battlePoints : null,
      currentBattleCoin:
          type == GiftType.battle && countsForPk ? battlePoints : null,
      liveCoin: type == GiftType.livestream ? coinPrice : null,
    );
    // Daily + hourly ranking: every coin received in a LIVE counts for the
    // receiver in both leaderboards.
    unawaited(LiveRankingController.recordGift(
      hostId: user?.userId,
      coins: coinPrice,
      host: user,
    ));
    unawaited(HourlyRankingController.recordGift(
      hostId: user?.userId,
      coins: coinPrice,
      host: user,
    ));
    unawaited(LeagueController.recordGift(
      hostId: user?.userId,
      coins: coinPrice,
      host: user,
    ));
    if (type == GiftType.livestream &&
        user?.userId == liveData.value.hostId &&
        liveData.value.hasLiveGoal == true &&
        liveData.value.liveGoalType == 'gifts') {
      incrementLiveGoalProgress(1);
    }
    if (type == GiftType.livestream &&
        user?.userId == liveData.value.hostId &&
        gift.id != null) {
      unawaited(_recordGiftTowardGoals(gift.id!, myUserId));
    }
  }

  /// One-tap "Rose" quick-gift (footer shortcut, matches the reference's
  /// rose icon) — same send path [onGiftTap] uses (balance check, real
  /// backend API call via SendGiftSheetController, same post-send
  /// bookkeeping via [_handleGiftSent]), just without opening the full gift
  /// picker sheet. Target: the opponent host while cross-room battling
  /// (sending a rose "at" the other side, same spirit as the reference's
  /// battle-screen rose button), otherwise this room's own host (a plain
  /// viewer tipping the host they're watching).
  bool _isSendingQuickGift = false;

  Future<void> sendQuickGift({int giftId = 18}) async {
    if (_isSendingQuickGift) return;
    if (liveData.value.type == LivestreamType.battle &&
        liveData.value.battleType == BattleType.end) {
      return showSnackBar(LKey.battleEndedGiftNotSent.tr);
    }
    final gift = gifts.firstWhereOrNull((g) => g.id == giftId);
    if (gift == null) return;
    final coinPrice = gift.coinPrice ?? 0;
    if (coinPrice <= 0) return;
    if (coinPrice > (SessionManager.instance.currentUser.value?.coinWallet ?? 0)) {
      showSnackBar('Not enough coins to send a Rose.');
      return;
    }
    final isBattling = liveData.value.opponentRoomId != null &&
        liveData.value.type == LivestreamType.battle;
    final targetUserId =
        isBattling ? opponentLiveData.value?.hostId : liveData.value.hostId;
    final targetUser = firestoreController.users
        .firstWhereOrNull((u) => u.userId == targetUserId);
    if (targetUserId == null) return;

    _isSendingQuickGift = true;
    try {
      final sendController = SendGiftSheetController(
        isBattling ? GiftType.battle : GiftType.livestream,
        targetUserId,
        const [],
        liveData.value.roomID,
      );
      sendController.livestreamController = this;
      // selectedGiftUser lives on LivestreamScreenController (= `this`,
      // just wired above), not on SendGiftSheetController itself --
      // sendGiftAndGetResult reads it off livestreamController for the
      // returned GiftManager.streamUser.
      selectedGiftUser = (targetUser ?? AppUser(userId: targetUserId)).obs;
      final result = await sendController.sendGiftAndGetResult(gift);
      if (result != null) {
        await _handleGiftSent(
            isBattling ? GiftType.battle : GiftType.livestream, result);
      }
    } finally {
      _isSendingQuickGift = false;
    }
  }

  /// If a battle round is active, still within its first-gift bonus window
  /// (AppRes.firstGiftBonusWindowInSecond after battleCreatedAt), and no one
  /// has claimed it yet, atomically claims it and returns [coinPrice]
  /// multiplied by AppRes.firstGiftBonusMultiplier; otherwise returns
  /// [coinPrice] unchanged. The transaction is what makes "only the very
  /// first gift wins it" race-safe when two people gift near-simultaneously.
  Future<int> _claimFirstGiftBonusIfEligible(int coinPrice) async {
    final stream = liveData.value;
    if (stream.battleType != BattleType.waiting) return coinPrice;
    if (stream.firstGiftBonusClaimed == true) return coinPrice;
    final createdAt = stream.battleCreatedAt;
    if (createdAt == null) return coinPrice;
    final elapsedSeconds =
        (DateTime.now().millisecondsSinceEpoch - createdAt) / 1000;
    if (elapsedSeconds > AppRes.firstGiftBonusWindowInSecond) return coinPrice;

    try {
      final claimed = await db.runTransaction<bool>((tx) async {
        final snap = await tx.get(liveStreamDocRef);
        final data = snap.data() as Map<String, dynamic>? ?? {};
        if (data[FirebaseConst.firstGiftBonusClaimed] == true) return false;
        tx.update(
            liveStreamDocRef, {FirebaseConst.firstGiftBonusClaimed: true});
        return true;
      });
      if (claimed) {
        return coinPrice * AppRes.firstGiftBonusMultiplier;
      }
    } catch (e) {
      Loggers.error('Failed to claim first-gift bonus: $e');
    }
    return coinPrice;
  }

  _sendCommentToFirestore({
    required LivestreamCommentType type,
    String? comment,
    int? giftId,
    int? receiverId,
  }) async {
    int time = DateTime.now().millisecondsSinceEpoch;
    try {
      await _addUsersFirebaseFireStore();
      liveStreamCommentsRef.doc('$time').set(
            LivestreamComment(
              comment: comment,
              commentType: type,
              id: time,
              senderId: myUserId,
              receiverId: receiverId,
              giftId: giftId,
            ).toJson(),
          );
    } catch (e) {
      Loggers.error('Message Error : $e');
    }
  }

  Future<void> _addUsersFirebaseFireStore() async {
    DocumentReference myUserRef = liveStreamUsersRef.doc(myUserId.toString());

    DocumentSnapshot isMyUserExist = await myUserRef.get();
    if (myUser.value != null) {
      if (isMyUserExist.exists) {
        myUserRef.update(myUser.value!.appUser.toJson());
      } else {
        myUserRef.set(myUser.value?.appUser.toJson());
      }
    }
  }

  /// Viewer asks to join as a Guest Call participant. Requests always land
  /// in the GUEST role (never Co-host — that's invite-only), so the seat
  /// check here is against the guest cap.
  void onVideoRequestSend(Livestream liveData) {
    LivestreamUserState? state = liveUsersStates.firstWhereOrNull(
      (element) => element.userId == myUserId,
    );
    switch (state?.type) {
      case null:
        break;
      case LivestreamUserType.audience:
        if (!guestRequestsEnabled) {
          showSnackBar(LKey.guestRequestsDisabled.tr);
          return;
        }
        if (!hasSeatFor(LivestreamUserType.guest)) {
          showSnackBar(LKey.guestSeatsFull.tr);
          return;
        }
        updateUserStateToFirestore(
          myUserId,
          type: LivestreamUserType.requested,
        );
        _sendCommentToFirestore(
          type: LivestreamCommentType.request,
          receiverId: liveData.hostId,
        );
        showSnackBar(LKey.requestJoinToHost.tr);
        break;
      case LivestreamUserType.requested:
        showSnackBar(LKey.joinRequestSentDescription.tr);
        break;
      case LivestreamUserType.host:
      case LivestreamUserType.coHost:
      case LivestreamUserType.guest:
      case LivestreamUserType.invited:
      case LivestreamUserType.left:
        break;
    }
  }

  Future<void> updateUserStateToFirestore(
    int? userId, {
    LivestreamUserType? type,
    bool? isMuted,
    bool? isVideoOn,
    int? battleCoin,
    int? liveCoin,
    bool? isFollow,
    int? joinTime,
    int? currentBattleCoin,
    LivestreamUserType? invitedRole,
    bool clearInvitedRole = false,
  }) async {
    if (userId == null) {
      Loggers.error('updateUserStateToFirestore: userId is null');
      return;
    }

    DocumentReference reference = liveStreamUserStatesRef.doc(
      userId.toString(),
    );
    bool isExist = (await reference.get()).exists;
    if (!isExist) {
      Loggers.error('updateUserStateToFirestore Not Found $userId');
      return;
    }

    try {
      final updateData = <String, dynamic>{
        if (type != null) FirebaseConst.type: type.value,
        if (isMuted != null) FirebaseConst.isMuted: isMuted,
        if (isVideoOn != null) FirebaseConst.isVideoOn: isVideoOn,
        if (battleCoin != null)
          FirebaseConst.totalBattleCoin:
              battleCoin == 0 ? 0 : FieldValue.increment(battleCoin),
        if (currentBattleCoin != null)
          FirebaseConst.currentBattleCoin: currentBattleCoin == 0
              ? 0
              : FieldValue.increment(currentBattleCoin),
        if (liveCoin != null)
          FirebaseConst.liveCoin:
              liveCoin == 0 ? 0 : FieldValue.increment(liveCoin),
        if (isFollow != null)
          FirebaseConst.followersGained: isFollow
              ? FieldValue.arrayUnion([myUserId])
              : FieldValue.arrayRemove([myUserId]),
        if (joinTime != null) FirebaseConst.joinStreamTime: joinTime,
        if (invitedRole != null) FirebaseConst.invitedRole: invitedRole.value,
        if (clearInvitedRole) FirebaseConst.invitedRole: FieldValue.delete(),
      };
      if (battleCoin != null || liveCoin != null) {
        myUser.value?.coinEstimatedValue(
          battleCoin?.toDouble() ?? liveCoin?.toDouble(),
        );
        SessionManager.instance.setUser(myUser.value);
      }
      await liveStreamUserStatesRef.doc(userId.toString()).update(updateData);
      Loggers.success('User state updated for userId: $userId');
    } catch (e, stack) {
      Loggers.error('Failed to update user state: $e\n$stack');
    }
  }

  /// Host invites a viewer who is already in the room into a stage role.
  /// [isInvited] = true means "cancel the pending invite". The role is
  /// recorded on the invitee's state doc so accepting lands them in exactly
  /// what they were invited to (Co-host Mode vs Guest Call).
  void onInvite(
    AppUser? user, {
    bool isInvited = false,
    LivestreamUserType role = LivestreamUserType.guest,
  }) {
    if (isInvited) {
      updateUserStateToFirestore(
        user?.userId,
        type: LivestreamUserType.audience,
        clearInvitedRole: true,
      );
      return;
    }
    if (!role.isStageRole) return;
    if (!hasSeatFor(role)) {
      showSnackBar(seatsFullMessageFor(role));
      return;
    }
    updateUserStateToFirestore(
      user?.userId,
      type: LivestreamUserType.invited,
      invitedRole: role,
    );
  }

  /// The most recent out-of-room invite sent to [userId] for this room, if
  /// any — null means they have never been invited (or any prior invite was
  /// cancelled/expired and should be treated as a clean slate).
  LiveInvite? outgoingInviteFor(int userId) {
    LiveInvite? latest;
    for (final invite in outgoingInvites) {
      if (invite.inviteeId != userId) continue;
      final latestCreated = latest?.createdAt;
      final created = invite.createdAt;
      if (latest == null ||
          (created != null &&
              (latestCreated == null || created.isAfter(latestCreated)))) {
        latest = invite;
      }
    }
    return latest;
  }

  /// Invites someone who is NOT currently in the room (Friends / Recommended
  /// tab of the Invited page). There is no user_state doc to write to yet, so
  /// this goes through LiveInviteService + an FCM nudge instead of
  /// [onInvite]'s direct Firestore write.
  Future<void> inviteOutOfRoom(User candidate, LivestreamUserType role) async {
    final inviteeId = candidate.id;
    if (inviteeId == null || !role.isStageRole) return;
    if (!hasSeatFor(role)) {
      showSnackBar(seatsFullMessageFor(role));
      return;
    }
    final existing = outgoingInviteFor(inviteeId);
    if (existing != null && existing.isPending) return;
    final host = myUser.value?.appUser;
    if (host == null) return;

    LiveInvite invite;
    try {
      invite = await LiveInviteService.instance.createInvite(
        host: host,
        roomId: liveData.value.roomID ?? '',
        inviteeId: inviteeId,
        role: role,
        expiry: Duration(seconds: setting?.pkInviteExpirySeconds ?? 60),
      );
    } catch (e) {
      Loggers.error('Out-of-room invite failed: $e');
      showSnackBar(LKey.somethingWentWrong.tr);
      return;
    }
    unawaited(_pushLiveInvite(invite));
  }

  Future<void> cancelOutOfRoomInvite(LiveInvite invite) =>
      LiveInviteService.instance.updateStatus(
        invite.id,
        LiveInviteStatus.cancelled,
      );

  /// Best-effort nudge for a backgrounded/killed app; the in-app watcher
  /// already reacts to the Firestore document for a foregrounded one.
  Future<void> _pushLiveInvite(LiveInvite invite) async {
    try {
      final recipient =
          await UserService.instance.fetchUserDetails(userId: invite.inviteeId);
      final token = recipient?.deviceToken;
      if (token == null || token.isEmpty) return;
      await NotificationService.instance.pushNotification(
        type: NotificationType.liveInvite,
        title: myUser.value?.fullname ?? myUser.value?.username ?? '',
        body: invite.role == LivestreamUserType.coHost
            ? LKey.invitedYouAsCoHost.tr
            : LKey.invitedYouAsGuest.tr,
        data: {
          'invite_id': invite.id,
          'room_id': invite.roomId,
          'host_id': invite.hostId,
          'role': invite.role.value,
        },
        token: token,
        deviceType: recipient?.device,
      );
    } catch (e) {
      Loggers.error('Live invite push failed: $e');
    }
  }

  void _showJoinStreamSheet(LivestreamUserState state) {
    if (state.userId == myUserId && state.type == LivestreamUserType.invited) {
      AppUser? hostUser = liveData.value.getHostUser(firestoreController.users);
      isJoinSheetOpen = true;
      final invitedRole = state.invitedRole ?? LivestreamUserType.guest;
      Get.bottomSheet(
        LiveStreamJoinSheet(
          hostUser: hostUser,
          myUser: myUser.value,
          role: invitedRole,
          onJoined: () async {
            LivestreamUserState? userState = liveUsersStates.firstWhereOrNull(
              (element) => element.userId == myUserId,
            );
            if (userState?.type == LivestreamUserType.invited) {
              // Land in exactly the role the host invited us into; the seat
              // itself is claimed (and re-checked) in publishCoHostStream.
              updateUserStateToFirestore(
                myUserId,
                type: userState?.invitedRole ?? invitedRole,
                clearInvitedRole: true,
              );
            } else {
              showSnackBar(LKey.joinCancelledDescription.tr);
            }
          },
          onCancel: () {
            updateUserStateToFirestore(
              myUserId,
              type: LivestreamUserType.audience,
              clearInvitedRole: true,
            );
          },
        ),
        isScrollControlled: true,
        enableDrag: false,
        isDismissible: false,
      ).then((value) {
        isJoinSheetOpen = false;
      });
    }
  }

  /// Atomically takes a seat in the right array (co-host vs guest) for
  /// [role], re-checking the cap inside the transaction so two people can't
  /// both squeeze into the last seat, and releasing any reservation this
  /// user held in pendingSeatIds. Returns false when the room is full/gone.
  Future<bool> _claimStageSeat(int userId, LivestreamUserType role) async {
    if (!role.isStageRole) return false;
    final arrayKey = role == LivestreamUserType.coHost
        ? FirebaseConst.coHostIds
        : FirebaseConst.guestIds;
    final cap = role == LivestreamUserType.coHost ? maxCoHosts : maxGuests;
    try {
      return await db.runTransaction<bool>((tx) async {
        final snap = await tx.get(liveStreamDocRef);
        if (!snap.exists) return false;
        final data = snap.data() as Map<String, dynamic>? ?? {};
        final members = List<int>.from(
            (data[arrayKey] as List<dynamic>? ?? const [])
                .whereType<num>()
                .map((e) => e.toInt()));
        final pending = List<int>.from(
            (data[FirebaseConst.pendingSeatIds] as List<dynamic>? ?? const [])
                .whereType<num>()
                .map((e) => e.toInt()));
        if (members.contains(userId)) {
          tx.update(liveStreamDocRef, {
            FirebaseConst.pendingSeatIds: FieldValue.arrayRemove([userId]),
          });
          return true;
        }
        // My own reservation (if any) is the seat I'm converting, so it
        // doesn't count against me.
        final reservedByOthers = pending.where((id) => id != userId).length;
        if (members.length + reservedByOthers >= cap) return false;
        tx.update(liveStreamDocRef, {
          arrayKey: FieldValue.arrayUnion([userId]),
          FirebaseConst.pendingSeatIds: FieldValue.arrayRemove([userId]),
        });
        return true;
      });
    } catch (e) {
      Loggers.error('Failed to claim $role seat: $e');
      return false;
    }
  }

  void publishCoHostStream(int streamId) async {
    bool isPermissionGranted = await requestPermission();
    if (isPermissionGranted) {
      final myState = liveUsersStates.firstWhereOrNull(
        (element) => element.userId == myUserId,
      );
      final role = myState?.type == LivestreamUserType.guest
          ? LivestreamUserType.guest
          : LivestreamUserType.coHost;
      final seated = await _claimStageSeat(streamId, role);
      if (!seated) {
        showSnackBar(seatsFullMessageFor(role));
        await updateUserStateToFirestore(
          myUserId,
          type: LivestreamUserType.audience,
          clearInvitedRole: true,
        );
        return;
      }
      int canvasViewID = -1;

      // ✅ Enable camera and microphone
      await zegoEngine.enableCamera(true);
      await zegoEngine.mutePublishStreamAudio(false);
      zegoEngine.muteMicrophone(false);

      // ✅ Create preview canvas and start preview
      await zegoEngine.createCanvasView((viewID) async {
        canvasViewID = viewID;
        ZegoCanvas previewCanvas = ZegoCanvas(
          canvasViewID,
          viewMode: ZegoViewMode.AspectFill,
        );
        zegoEngine.startPreview(canvas: previewCanvas);
      }).then((canvasViewWidget) {
        if (canvasViewWidget != null) {
          streamViews.add(
            StreamView('$streamId', canvasViewID, canvasViewWidget, false),
          );
        }
      });

      // With 5-10 people each decoding everyone else, 720p per tile is more
      // bandwidth/CPU than mid-range phones cope with; 360p tiles are plenty
      // for a grid cell.
      if (liveData.value.stageIds.length > 4) {
        await zegoEngine.setVideoConfig(
          ZegoVideoConfig.preset(ZegoVideoConfigPreset.Preset360P),
        );
      }

      // ✅ Publish the stream
      await zegoEngine.startPublishingStream('$streamId');

      // ✅ Force audio output to speaker (after stream starts)
      Future.delayed(const Duration(milliseconds: 300), () {
        zegoEngine.setAudioRouteToSpeaker(true);
      });

      // Seat membership was already written by _claimStageSeat above. Must
      // match the role actually claimed above -- this used to always send
      // joinedCoHost regardless of role, so a plain Guest Call join request
      // (acceptJoinRequest sets type: guest directly, no co-host anywhere
      // in that path) announced "joined as a co-host" in chat, which the
      // host understandably read as co-host rights being granted without
      // their say-so.
      _sendCommentToFirestore(
          type: role == LivestreamUserType.guest
              ? LivestreamCommentType.joinedGuest
              : LivestreamCommentType.joinedCoHost);
      updateUserStateToFirestore(
        myUserId,
        joinTime: DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      Get.bottomSheet(
        ConfirmationSheet(
          title: LKey.cameraMicrophonePermissionTitle.tr,
          description: LKey.cameraMicrophonePermissionDescription.tr,
          onTap: openAppSettings,
        ),
      );
    }
  }

  Future<bool> requestPermission() async {
    Loggers.info("requestPermission...");
    try {
      PermissionStatus microphoneStatus = await Permission.microphone.request();
      if (microphoneStatus != PermissionStatus.granted) {
        Loggers.error('Error: Microphone permission not granted!!!');
        return false;
      }
    } on Exception catch (error) {
      Loggers.error("[ERROR], request microphone permission exception, $error");
    }

    try {
      PermissionStatus cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        Loggers.error('Error: Camera permission not granted!!!');
        return false;
      }
    } on Exception catch (error) {
      Loggers.error("[ERROR], request camera permission exception, $error");
    }

    return true;
  }

  void closeCoHostStream(int? streamId) {
    StreamView? view = streamViews.firstWhereOrNull(
      (element) => element.streamId == '$streamId',
    );
    if (view != null) {
      stopPreview(viewId: view.streamViewId);
      stopPublish();
      updateLiveStreamData(
        coHostId: FieldValue.arrayRemove([streamId]),
        guestId: FieldValue.arrayRemove([streamId]),
        pendingSeatId: FieldValue.arrayRemove([streamId]),
      );
      LivestreamComment? comment = comments.firstWhereOrNull(
        (element) =>
            element.senderId == myUserId &&
            (element.commentType == LivestreamCommentType.joinedCoHost ||
                element.commentType == LivestreamCommentType.joinedGuest),
      );
      if (comment != null) {
        liveStreamCommentsRef.doc(comment.id.toString()).delete();
      }
      updateUserStateToFirestore(
        streamId,
        type: LivestreamUserType.audience,
        isMuted: false,
        isVideoOn: false,
        battleCoin: 0,
        currentBattleCoin: 0,
      );
      streamViews.removeWhere((element) => element.streamId == '$streamId');
      stopPlayStream(streamId.toString());
      streamEnded();
    }
  }

  void coHostVideoToggle(LivestreamUserState state) {
    updateUserStateToFirestore(
      state.userId,
      isVideoOn: state.isVideoOn ? false : true,
    );
  }

  void coHostAudioToggle(LivestreamUserState state) {
    updateUserStateToFirestore(
      state.userId,
      isMuted: state.isMuted ? false : true,
    );
  }

  void updateStateAction(
    LivestreamUserState? oldState,
    LivestreamUserState newState,
  ) {
    Loggers.info('''
    ${oldState?.toJson()}
    ////////
    ${newState.toJson()}
    ''');
    if (newState.userId == myUserId) {
      Loggers.info('Updating state for userId: ${newState.userId}');
      // Becoming a co-host OR a guest both mean "start publishing"; the role
      // only decides which seat array publishCoHostStream claims.
      final wasOnStageNonHost = oldState?.type == LivestreamUserType.coHost ||
          oldState?.type == LivestreamUserType.guest;
      final isOnStageNonHost = newState.type == LivestreamUserType.coHost ||
          newState.type == LivestreamUserType.guest;
      if (isOnStageNonHost && !wasOnStageNonHost) {
        publishCoHostStream(myUserId);
      }

      if (newState.type == LivestreamUserType.audience &&
          oldState?.type == LivestreamUserType.invited &&
          isJoinSheetOpen) {
        Get.back();
      }

      // The only way a REQUESTED viewer goes back to AUDIENCE is the host
      // rejecting them — tell them, instead of the request silently vanishing.
      if (newState.type == LivestreamUserType.audience &&
          oldState?.type == LivestreamUserType.requested) {
        showSnackBar(LKey.requestDeclinedByHost.tr);
      }

      if (newState.type == LivestreamUserType.invited &&
          oldState?.type == LivestreamUserType.audience) {
        _showJoinStreamSheet(newState);
      }
      if (oldState?.isVideoOn != newState.isVideoOn) {
        zegoEngine.enableCamera(newState.isVideoOn);
      }
      if (oldState?.isMuted != newState.isMuted) {
        zegoEngine.muteMicrophone(newState.isMuted);
      }
      if (wasOnStageNonHost && newState.type == LivestreamUserType.audience) {
        closeCoHostStream(newState.userId);
      }
    }
  }

  void coHostDelete(LivestreamUserState state) {
    if (liveData.value.type == LivestreamType.battle) {
      showSnackBar('End the battle before removing a co-host.');
      return;
    }
    if (state.type == LivestreamUserType.coHost ||
        state.type == LivestreamUserType.guest) {
      updateLiveStreamData(
        coHostId: FieldValue.arrayRemove([state.userId]),
        guestId: FieldValue.arrayRemove([state.userId]),
        pendingSeatId: FieldValue.arrayRemove([state.userId]),
      );
      updateUserStateToFirestore(
        state.userId,
        type: LivestreamUserType.audience,
      );
    }
  }

  void reportUser(int? userId) {
    Get.bottomSheet(
      ReportSheet(reportType: ReportType.user, id: userId),
      isScrollControlled: true,
    );
  }

  void _timerStart(VoidCallback callBack) {
    timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      callBack.call();
      // if (t.tick >= totalBattleSecond) {
      //   timer?.cancel();
      // }
    });
  }

  void onStopButtonTap() {
    bool isBattleOn = liveData.value.type == LivestreamType.battle;
    String title =
        !isBattleOn ? LKey.endStreamTitle.tr : LKey.stopBattleTitle.tr;
    String description =
        !isBattleOn ? LKey.endStreamMessage.tr : LKey.stopBattleDescription.tr;

    Get.bottomSheet(
      StopLiveStreamSheet(
        onTap: () {
          if (isBattleOn) {
            roundBaselineRed.value = 0;
            roundBaselineBlue.value = 0;
            // Manual stop has no intermediate BattleType.end "frozen" state
            // the way a natural timer-expiry does — it jumps straight to
            // reset, so history has to be captured right here or the data
            // is gone.
            unawaited(_recordBattleHistory(endReason: 'manual_stop'));
            if (liveData.value.opponentRoomId != null) {
              endBattleOnly();
            } else {
              updateLiveStreamData(
                battleType: BattleType.initiate,
                type: LivestreamType.livestream,
                battleRoundWinsHost: 0,
                battleRoundWinsCoHost: 0,
              );
            }
            startMinViewerTimeoutCheck();
          } else {
            hostEndStream();
          }
        },
        title: title,
        description: description,
        positiveText: LKey.stop.tr,
      ),
      isScrollControlled: true,
    );
  }

  void hostEndStream() {
    streamEnded();
    logoutRoom();
  }

  void streamEnded() {
    LivestreamUserState? userState = liveUsersStates.firstWhereOrNull(
      (element) => element.userId == myUserId,
    );
    AppUser? user = firestoreController.users.firstWhereOrNull(
      (element) => element.userId == myUserId,
    );
    userState?.user = user;
    int viewers = liveUsersStates.length;
    if (isHost) {
      // Close the end-stream confirmation sheet/dialog if one is open, but do
      // NOT pop the host screen itself — Get.off below replaces it with the end
      // screen. Popping unconditionally here could remove the dashboard instead
      // and leave the host trapped with no route to return to.
      if (Get.isBottomSheetOpen ?? false) Get.back();
      if (Get.isDialogOpen ?? false) Get.back();
      Get.off(
        () => LiveStreamEndScreen(
          userState: userState,
          isHost: isHost,
          viewers: viewers,
          mostWatchedUsers: _mostWatchedViewers(excludeUserId: myUserId),
        ),
      );
    } else {
      if (userState?.type == LivestreamUserType.coHost) {
        Get.bottomSheet(
          LiveStreamSummary(
            userState: userState,
            isHost: isHost,
            viewers: viewers,
          ),
          isScrollControlled: true,
        ).then((value) {
          updateUserStateToFirestore(
            myUserId,
            battleCoin: 0,
            liveCoin: 0,
            currentBattleCoin: 0,
          );
          if ((liveData.value.roomID ?? '').isEmpty) {
            Get.back();
          }
        });
      }
    }
  }

  /// Top 3 non-host viewers by how long they stuck around this LIVE, for the
  /// host's end-of-stream "Most watch time" summary. Watch time is
  /// approximated as elapsed time since they joined, since that's the only
  /// timestamp already tracked per viewer.
  List<LivestreamUserState> _mostWatchedViewers({required int excludeUserId}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final viewers = liveUsersStates
        .where((state) =>
            state.userId != excludeUserId && state.joinStreamTime > 0)
        .toList()
      ..sort((a, b) =>
          (now - a.joinStreamTime).compareTo(now - b.joinStreamTime) * -1);
    for (final state in viewers) {
      state.user = firestoreController.users
          .firstWhereOrNull((user) => user.userId == state.userId);
    }
    return viewers.take(3).toList();
  }

  togglePlayerAudioToggle() {
    videoPlayerController.value?.setVolume(isPlayerMute.value ? 1 : 0);
    isPlayerMute.value = !isPlayerMute.value;
  }

  void startBattle() {
    if (liveData.value.type == LivestreamType.battle ||
        liveData.value.battleType != BattleType.initiate) {
      return;
    }
    if (!canStartBattle) {
      showSnackBar(LKey.pkNeedsGuest.tr);
      return;
    }
    roundBaselineRed.value = 0;
    roundBaselineBlue.value = 0;
    updateLiveStreamData(
      battleType: BattleType.waiting,
      battleDuration: AppRes.battleDurationInMinutes,
      battleCreatedAt: DateTime.now().millisecondsSinceEpoch,
      battleRoundWinsHost: 0,
      battleRoundWinsCoHost: 0,
      battleTotalRounds: AppRes.battleTotalRounds,
      battleCurrentRound: 1,
      firstGiftBonusClaimed: false,
    );
  }

  /// Starts a fresh timed round without ending the whole match: keeps the
  /// running round-win tally (only [onStopButtonTap] / [endBattleOnly]
  /// clear it, since those end the whole match), snapshots each side's
  /// current cumulative battle coins as the new round's baseline, and
  /// restarts the timer. Only meaningful once a round has actually ended.
  /// Whether a further round can start — false once the match has already
  /// played its fixed [Livestream.battleTotalRounds] rounds, at which point
  /// only Stop (ending the whole match) is offered.
  bool get canStartNextRound {
    final current = liveData.value.battleCurrentRound ?? 1;
    final total = liveData.value.battleTotalRounds ?? AppRes.battleTotalRounds;
    return current < total;
  }

  Future<void> startNextRound() async {
    if (liveData.value.battleType != BattleType.end) return;
    if (!canStartNextRound) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextRound = (liveData.value.battleCurrentRound ?? 1) + 1;
    final opponentRoomId = liveData.value.opponentRoomId;
    if (opponentRoomId != null) {
      final myCoins = mySideBattleCoins;
      final opponentCoins = opponentSideBattleCoins;
      // A tied round previously always credited MY side with the round win
      // (`myWon = myCoins >= opponentCoins`) — neither side should score a
      // round win on a genuine tie.
      final isRoundDraw = myCoins == opponentCoins;
      final myWon = !isRoundDraw && myCoins > opponentCoins;
      roundBaselineRed.value = myCoins;
      roundBaselineBlue.value = opponentCoins;
      try {
        final batch = db.batch();
        batch.update(liveStreamDocRef, {
          FirebaseConst.battleType: BattleType.waiting.value,
          FirebaseConst.battleCreatedAt: now,
          FirebaseConst.battleRoundWins: FieldValue.increment(myWon ? 1 : 0),
          FirebaseConst.battleCurrentRound: nextRound,
          FirebaseConst.firstGiftBonusClaimed: false,
        });
        batch.update(_roomDocRef(opponentRoomId), {
          FirebaseConst.battleType: BattleType.waiting.value,
          FirebaseConst.battleCreatedAt: now,
          FirebaseConst.battleRoundWins:
              FieldValue.increment((!isRoundDraw && !myWon) ? 1 : 0),
          FirebaseConst.battleCurrentRound: nextRound,
          FirebaseConst.firstGiftBonusClaimed: false,
        });
        await batch.commit();
      } catch (e) {
        Loggers.error('Failed to start next cross-room round: $e');
      }
    } else {
      // Team-based (pkTeamAIds/pkTeamBIds, falling back to host/first-co-host
      // for any battle predating them) rather than the host-vs-first-co-host
      // math this used to inline — same source pkTeamAScore/pkTeamBScore use
      // for the live arena display, so a round's win/loss always matches
      // what the scoreboard showed for it.
      final teamAScore = pkTeamAScore();
      final teamBScore = pkTeamBScore();
      final outcome = pkOutcome(teamAScore, teamBScore);
      final isRoundDraw = outcome == BattleOutcome.draw;
      final teamAWon = outcome == BattleOutcome.sideAWins;
      roundBaselineRed.value = _teamRawBattleCoins(pkTeamAUserIds);
      roundBaselineBlue.value = _teamRawBattleCoins(pkTeamBUserIds);
      try {
        await liveStreamDocRef.update({
          FirebaseConst.battleType: BattleType.waiting.value,
          FirebaseConst.battleCreatedAt: now,
          if (teamAWon)
            FirebaseConst.battleRoundWinsHost: FieldValue.increment(1),
          if (!isRoundDraw && !teamAWon)
            FirebaseConst.battleRoundWinsCoHost: FieldValue.increment(1),
          FirebaseConst.battleCurrentRound: nextRound,
          FirebaseConst.firstGiftBonusClaimed: false,
          FirebaseConst.pkLikePointsA: 0,
          FirebaseConst.pkLikePointsB: 0,
        });
      } catch (e) {
        Loggers.error('Failed to start next same-room round: $e');
      }
    }
  }

  bool get canStartBattle {
    final coHostIds = liveData.value.coHostIds ?? const <int>[];
    if (coHostIds.isEmpty) return false;
    return streamViews.any((view) {
      final userId = int.tryParse(view.streamId);
      return userId != null && coHostIds.contains(userId);
    });
  }

  // Cross-room PK Battle. This room's "side" is always whoever is already
  // publishing into it (host + any co-hosts, via streamViews) — so a room
  // that already has a co-host from the multi-guest grid naturally battles
  // as a 2v2 side with zero extra code. The opponent side works the same way
  // but read from their own, independent room.

  int get mySideBattleCoins => liveUsersStates.fold(
      0, (total, state) => total + state.currentBattleCoin);

  int get opponentSideBattleCoins => opponentUserStates.fold(
      0, (total, state) => total + state.currentBattleCoin);

  DocumentReference _roomDocRef(String roomId) =>
      db.collection(FirebaseConst.liveStreams).doc(roomId);

  // ───────────────────────── Co-Host Connection ─────────────────────────
  // Connecting two independently-live hosts together, per the client's
  // binding clarification: this is the ONLY path to a PK battle, and
  // connecting must NEVER auto-start one -- see requestPkMatch/acceptPkMatch
  // below for the separate, explicit "start a battle" step on an already-
  // connected pair.

  /// Transaction-guarded so two hosts inviting each other at the same
  /// instant (or someone double-tapping Invite) can't both land a write —
  /// previously this was a bare `.update()`, so a second invite always
  /// silently clobbered whatever the target's doc already had.
  Future<void> sendCoHostConnectInvite(int opponentHostId) async {
    if (!isHost) return;
    try {
      final targetRef = _roomDocRef('$opponentHostId');
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(targetRef);
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data == null) {
          throw Exception('Target room no longer exists');
        }
        final target = Livestream.fromJson(data);
        // One connection (plus optionally one 2v2 teammate link) at a
        // time per host -- already connected or already mid-invite, either
        // way they're not available.
        if (target.pendingBattleInviteFromId != null ||
            target.opponentRoomId != null) {
          throw Exception('Target is already connected');
        }
        transaction.update(targetRef, {
          FirebaseConst.pendingBattleInviteFromId: myUserId,
          FirebaseConst.battleInviteSentAt:
              DateTime.now().millisecondsSinceEpoch,
        });
      });
      showSnackBar(LKey.coHostConnectInviteSent.tr);
      // Best-effort nudge, same pattern LiveInviteWatcher's guest/co-host
      // invites already use -- found via diagnosis that this room-doc
      // listener can take 50+ seconds to deliver on some connections
      // (no WiFi drop, no Firestore stream error, just a slow realtime
      // propagation), well past the 30s invite expiry, silently dropping
      // the invite before it's ever shown. This push lets the recipient's
      // forceCheckPendingCoHostInvite() fetch the doc directly instead of
      // waiting on the listener.
      unawaited(_pushCoHostConnectInvite(opponentHostId));
    } catch (e) {
      Loggers.error('Failed to send Co-Host connect invite: $e');
      showSnackBar(LKey.coHostConnectInviteFailed.tr);
    }
  }

  // Shared by sendCoHostConnectInvite and requestPkMatch -- both are a
  // "come check your co-host screen" nudge, and the foreground handler
  // never shows this text (it force-refetches and returns silently); it
  // only surfaces as the system tray text for a backgrounded/killed app,
  // where a generic line is preferable to guessing which of the two this
  // particular nudge was for.
  Future<void> _pushCoHostConnectInvite(int opponentHostId) async {
    try {
      final recipient =
          await UserService.instance.fetchUserDetails(userId: opponentHostId);
      final token = recipient?.deviceToken;
      if (token == null || token.isEmpty) return;
      await NotificationService.instance.pushNotification(
        type: NotificationType.coHostConnectInvite,
        title: myUser.value?.fullname ?? myUser.value?.username ?? '',
        body: LKey.coHostConnectInviteDescription
            .trParams({'name': myUser.value?.username ?? ''}),
        data: {
          'room_id': '$opponentHostId',
          'from_host_id': '$myUserId',
        },
        token: token,
        deviceType: recipient?.device,
      );
    } catch (e) {
      Loggers.error('Co-Host connect invite push failed: $e');
    }
  }

  /// Called from the FCM nudge (see firebase_notification_manager.dart)
  /// when the realtime listener may be slow -- fetches the room doc
  /// directly and runs the exact same pending-invite / pending-match-
  /// request / pending-rematch checks listenLiveStreamData's own listener
  /// does, so the dialog shows immediately regardless of listener latency.
  /// Covers all three signals (never more than one pending at once in
  /// practice -- a match request only exists once already connected,
  /// after the connect invite field is long cleared, and a rematch only
  /// exists after a battle has already ended) so one push type/handler
  /// serves all three.
  Future<void> forceCheckPendingCoHostInvite() async {
    try {
      final snapshot = await liveStreamDocRef.get();
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return;
      final stream = Livestream.fromJson(data);
      if (isHost &&
          stream.pendingBattleInviteFromId != null &&
          stream.pendingBattleInviteFromId != _lastHandledInviteFromId) {
        _lastHandledInviteFromId = stream.pendingBattleInviteFromId;
        _showIncomingCoHostConnectDialog(stream.pendingBattleInviteFromId!);
      }
      if (isHost &&
          stream.pendingPkMatchRequestFromId != null &&
          stream.pendingPkMatchRequestFromId !=
              _lastHandledPkMatchRequestFromId) {
        _lastHandledPkMatchRequestFromId = stream.pendingPkMatchRequestFromId;
        _showIncomingPkMatchRequestDialog(
            stream.pendingPkMatchRequestFromId!);
      }
      if (isHost &&
          stream.pendingRematchFromId != null &&
          stream.pendingRematchFromId != _lastHandledRematchFromId) {
        _lastHandledRematchFromId = stream.pendingRematchFromId;
        _showIncomingRematchDialog(stream.pendingRematchFromId!);
      }
    } catch (e) {
      Loggers.error('forceCheckPendingCoHostInvite failed: $e');
    }
  }

  Timer? _battleInviteExpiryTimer;

  void _showIncomingCoHostConnectDialog(int fromHostId) {
    if (liveData.value.opponentRoomId != null) {
      // Already connected to someone (or mid-invite) — quietly decline.
      declineCoHostConnectInvite();
      return;
    }
    // Enforce the expiry on the invitee's side too, not just by the
    // inviter clearing it later — a dialog sitting open past the window
    // shouldn't still be acceptable.
    final sentAt = liveData.value.battleInviteSentAt;
    if (sentAt != null) {
      final elapsedSeconds =
          (DateTime.now().millisecondsSinceEpoch - sentAt) / 1000;
      if (elapsedSeconds >= AppRes.battleInviteExpiryInSecond) {
        declineCoHostConnectInvite();
        return;
      }
    }
    final inviter = firestoreController.users
        .firstWhereOrNull((user) => user.userId == fromHostId);
    final remaining = sentAt == null
        ? AppRes.battleInviteExpiryInSecond
        : (AppRes.battleInviteExpiryInSecond -
                (DateTime.now().millisecondsSinceEpoch - sentAt) / 1000)
            .round()
            .clamp(1, AppRes.battleInviteExpiryInSecond);
    Get.dialog(
      TimedInviteDialog(
        title: LKey.coHostConnectInviteTitle.tr,
        description: LKey.coHostConnectInviteDescription
            .trParams({'name': inviter?.username ?? 'A creator'}),
        requester: inviter,
        expirySeconds: remaining,
        onDecline: declineCoHostConnectInvite,
        onAccept: () => acceptCoHostConnectInvite(fromHostId),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> declineCoHostConnectInvite() async {
    await liveStreamDocRef.update({
      FirebaseConst.pendingBattleInviteFromId: null,
      FirebaseConst.battleInviteSentAt: null,
    });
  }

  /// Establishes the connection ONLY -- never touches `type`/`battleType`.
  /// Both hosts keep their own independent LIVE sessions running; starting
  /// an actual battle is a separate, explicit step (see requestPkMatch).
  Future<void> acceptCoHostConnectInvite(int fromHostId) async {
    if (!isHost) return;
    // Re-check freshness at accept time, not just at dialog-open time — a
    // dialog can sit on screen while the invite expires underneath it.
    final sentAt = liveData.value.battleInviteSentAt;
    if (sentAt != null) {
      final elapsedSeconds =
          (DateTime.now().millisecondsSinceEpoch - sentAt) / 1000;
      if (elapsedSeconds >= AppRes.battleInviteExpiryInSecond) {
        showSnackBar(LKey.coHostConnectInviteExpired.tr);
        await declineCoHostConnectInvite();
        return;
      }
    }
    final myRoomId = liveData.value.roomID;
    if (myRoomId == null) return;
    final opponentRoomId = '$fromHostId';
    try {
      // A transaction (not a plain batch) so the invite can't be accepted
      // twice, or accepted after the inviter already cancelled/expired it,
      // or accepted while the opponent raced into a different connection in
      // the meantime — all reads happen first, then both writes commit
      // atomically only if every check still holds against the latest
      // server state.
      await db.runTransaction((transaction) async {
        final mySnapshot = await transaction.get(liveStreamDocRef);
        final opponentSnapshot =
            await transaction.get(_roomDocRef(opponentRoomId));
        final myData = mySnapshot.data() as Map<String, dynamic>?;
        final opponentData = opponentSnapshot.data() as Map<String, dynamic>?;
        if (myData == null || opponentData == null) {
          throw Exception('Room no longer exists');
        }
        final myLatest = Livestream.fromJson(myData);
        final opponentLatest = Livestream.fromJson(opponentData);
        if (myLatest.pendingBattleInviteFromId != fromHostId) {
          throw Exception('Invite no longer pending');
        }
        if (opponentLatest.opponentRoomId != null) {
          throw Exception('Opponent already connected to someone else');
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        // Wipe any battle fields a stale leftover doc might still be
        // carrying from much earlier testing (pre-dating the connect/battle
        // split) -- a fresh connection must always start from a clean idle
        // state, never silently inherit a stray WAITING/RUNNING battleType
        // or old round-win counts and surface the old battle UI instantly.
        final cleanBattleState = {
          FirebaseConst.type: LivestreamType.livestream.value,
          FirebaseConst.battleType: BattleType.initiate.value,
          FirebaseConst.battleCreatedAt: null,
          FirebaseConst.battleResultsVisibleUntil: null,
          FirebaseConst.battleRoundWins: 0,
          FirebaseConst.battleCurrentRound: 1,
          FirebaseConst.battleTotalRounds: 1,
          FirebaseConst.firstGiftBonusClaimed: null,
        };
        transaction.update(liveStreamDocRef, {
          FirebaseConst.opponentRoomId: opponentRoomId,
          FirebaseConst.coHostConnectedAt: now,
          FirebaseConst.pendingBattleInviteFromId: null,
          FirebaseConst.battleInviteSentAt: null,
          ...cleanBattleState,
        });
        transaction.update(_roomDocRef(opponentRoomId), {
          FirebaseConst.opponentRoomId: myRoomId,
          FirebaseConst.coHostConnectedAt: now,
          ...cleanBattleState,
        });
      });
      // "X joined as a Co-Host" in each room's own comment feed, same
      // wording the old in-room promotion used to post -- there's no
      // single room being "joined" any more (each host stays in their own),
      // so this announces the OTHER party on each side: fromHostId shows up
      // in my feed, myUserId shows up in theirs.
      unawaited(_announceCoHostConnected(fromHostId));
    } catch (e) {
      Loggers.error('Failed to accept Co-Host connect invite: $e');
      showSnackBar(LKey.coHostConnectInviteFailed.tr);
    }
  }

  Future<void> _announceCoHostConnected(int otherHostId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _addUsersFirebaseFireStore();
      await liveStreamCommentsRef.doc('$now').set(
            LivestreamComment(
              commentType: LivestreamCommentType.joinedCoHost,
              id: now,
              senderId: otherHostId,
            ).toJson(),
          );
      await _roomDocRef('$otherHostId')
          .collection(FirebaseConst.comments)
          .doc('${now + 1}')
          .set(
            LivestreamComment(
              commentType: LivestreamCommentType.joinedCoHost,
              id: now + 1,
              senderId: myUserId,
            ).toJson(),
          );
    } catch (e) {
      Loggers.error('Failed to announce Co-Host connection: $e');
    }
  }

  /// Disconnects THIS host from whoever they're connected to -- the one
  /// explicit, deliberate action that ever clears `opponentRoomId`. Ending
  /// a battle (see endBattleOnly) or letting the post-match results window
  /// expire must never call this on their own; only an explicit Exit tap
  /// does (requirement: completing/expiring a match must never auto-exit).
  Future<void> exitCoHostConnection() async {
    if (!isHost) return;
    final opponentRoomId = liveData.value.opponentRoomId;
    if (opponentRoomId == null) return;
    // If a battle happens to still be running, end it first rather than
    // leaving an orphaned battle state on either doc.
    if (liveData.value.battleType == BattleType.waiting ||
        liveData.value.battleType == BattleType.running) {
      await endBattleOnly();
    }
    final teammateRoomId = liveData.value.coHostTeammateRoomId;
    try {
      final batch = db.batch();
      batch.update(liveStreamDocRef, {
        FirebaseConst.opponentRoomId: null,
        FirebaseConst.coHostConnectedAt: null,
        FirebaseConst.coHostTeammateRoomId: null,
        FirebaseConst.coHostOpponentTeamRoomIds: null,
        FirebaseConst.pkMode: null,
      });
      batch.update(_roomDocRef(opponentRoomId), {
        FirebaseConst.opponentRoomId: null,
        FirebaseConst.coHostConnectedAt: null,
        FirebaseConst.coHostTeammateRoomId: null,
        FirebaseConst.coHostOpponentTeamRoomIds: null,
        FirebaseConst.pkMode: null,
      });
      if (teammateRoomId != null) {
        batch.update(_roomDocRef(teammateRoomId), {
          FirebaseConst.coHostTeammateRoomId: null,
          FirebaseConst.coHostOpponentTeamRoomIds: null,
          FirebaseConst.pkMode: null,
        });
      }
      await batch.commit();
    } catch (e) {
      Loggers.error('Failed to exit Co-Host connection: $e');
    }
  }

  // ───────────────────────── Play PK Match ─────────────────────────
  // Starting a battle on an ALREADY-connected pair -- a separate, explicit
  // step from the connection itself (decision B: the other connected
  // co-host must accept/confirm before the battle actually starts).

  /// Tapped from the "Play PK Match" button -- sends a request to the
  /// other connected host rather than starting the battle immediately.
  Future<void> requestPkMatch() async {
    if (!isHost) return;
    final opponentRoomId = liveData.value.opponentRoomId;
    if (opponentRoomId == null) return;
    try {
      await _roomDocRef(opponentRoomId).update({
        FirebaseConst.pendingPkMatchRequestFromId: myUserId,
        FirebaseConst.pkMatchRequestSentAt:
            DateTime.now().millisecondsSinceEpoch,
      });
      showSnackBar(LKey.pkMatchRequestSent.tr);
      // Same realtime-listener-can-be-slow nudge sendCoHostConnectInvite
      // uses -- see that function's comment for why.
      unawaited(_pushCoHostConnectInvite(int.tryParse(opponentRoomId) ?? -1));
    } catch (e) {
      Loggers.error('Failed to send Play PK Match request: $e');
      showSnackBar(LKey.pkMatchRequestFailed.tr);
    }
  }

  void _showIncomingPkMatchRequestDialog(int fromHostId) {
    if (liveData.value.opponentRoomId != '$fromHostId') {
      // Not connected to this host (any more) — nothing to confirm.
      declinePkMatchRequest();
      return;
    }
    final sentAt = liveData.value.pkMatchRequestSentAt;
    if (sentAt != null) {
      final elapsedSeconds =
          (DateTime.now().millisecondsSinceEpoch - sentAt) / 1000;
      if (elapsedSeconds >= AppRes.battleInviteExpiryInSecond) {
        declinePkMatchRequest();
        return;
      }
    }
    final requester = firestoreController.users
        .firstWhereOrNull((user) => user.userId == fromHostId);
    final remaining = sentAt == null
        ? AppRes.battleInviteExpiryInSecond
        : (AppRes.battleInviteExpiryInSecond -
                (DateTime.now().millisecondsSinceEpoch - sentAt) / 1000)
            .round()
            .clamp(1, AppRes.battleInviteExpiryInSecond);
    Get.dialog(
      TimedInviteDialog(
        title: LKey.pkMatchRequestTitle.tr,
        description: LKey.pkMatchRequestDescription
            .trParams({'name': requester?.username ?? 'Your co-host'}),
        requester: requester,
        expirySeconds: remaining,
        onDecline: declinePkMatchRequest,
        onAccept: () => acceptPkMatch(fromHostId),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> declinePkMatchRequest() async {
    await liveStreamDocRef.update({
      FirebaseConst.pendingPkMatchRequestFromId: null,
      FirebaseConst.pkMatchRequestSentAt: null,
    });
  }

  /// Actually starts the battle -- always a single flat 5-minute round, no
  /// rounds concept (battleTotalRounds/battleCurrentRound are written as
  /// 1/1, which is what keeps the pre-existing "Next Round" button from
  /// ever being reachable through canStartNextRound, with no change needed
  /// to startNextRound itself).
  Future<void> acceptPkMatch(int fromHostId) async {
    if (!isHost) return;
    final sentAt = liveData.value.pkMatchRequestSentAt;
    if (sentAt != null) {
      final elapsedSeconds =
          (DateTime.now().millisecondsSinceEpoch - sentAt) / 1000;
      if (elapsedSeconds >= AppRes.battleInviteExpiryInSecond) {
        showSnackBar(LKey.pkMatchRequestExpired.tr);
        await declinePkMatchRequest();
        return;
      }
    }
    final myRoomId = liveData.value.roomID;
    if (myRoomId == null) return;
    final opponentRoomId = '$fromHostId';
    roundBaselineRed.value = 0;
    roundBaselineBlue.value = 0;
    try {
      await db.runTransaction((transaction) async {
        final mySnapshot = await transaction.get(liveStreamDocRef);
        final opponentSnapshot =
            await transaction.get(_roomDocRef(opponentRoomId));
        final myData = mySnapshot.data() as Map<String, dynamic>?;
        final opponentData = opponentSnapshot.data() as Map<String, dynamic>?;
        if (myData == null || opponentData == null) {
          throw Exception('Room no longer exists');
        }
        final myLatest = Livestream.fromJson(myData);
        if (myLatest.opponentRoomId != opponentRoomId ||
            myLatest.pendingPkMatchRequestFromId != fromHostId) {
          throw Exception('Match request no longer valid');
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        // RUNNING, not WAITING -- a co-host PK match starts the instant
        // both sides confirm, no pre-battle countdown stage (the old
        // full-screen "Battle starting in..." overlay was already removed
        // for the same-room flow per client spec; it must never apply here
        // either, see the removed BattleStartCountdownOverlay usage in
        // livestream_host_screen.dart / live_stream_audience_screen.dart).
        final battleFields = {
          FirebaseConst.type: LivestreamType.battle.value,
          FirebaseConst.battleType: BattleType.running.value,
          FirebaseConst.battleCreatedAt: now,
          FirebaseConst.battleDuration: AppRes.coHostBattleDurationInMinutes,
          FirebaseConst.battleRoundWins: 0,
          FirebaseConst.battleTotalRounds: 1,
          FirebaseConst.battleCurrentRound: 1,
          FirebaseConst.crossRoomLikePoints: 0,
        };
        transaction.update(liveStreamDocRef, {
          ...battleFields,
          FirebaseConst.pendingPkMatchRequestFromId: null,
          FirebaseConst.pkMatchRequestSentAt: null,
        });
        transaction.update(_roomDocRef(opponentRoomId), battleFields);
      });
    } catch (e) {
      Loggers.error('Failed to accept Play PK Match request: $e');
      showSnackBar(LKey.pkMatchRequestFailed.tr);
    }
  }

  // ───────────────────────── Same-room PK Match ─────────────────────────
  // Co-host-vs-co-host within this one room, as opposed to the cross-room
  // host-vs-host battle above. 1v1 only for now — 2v2 team assignment and
  // arena rendering ship in a later increment; pkMatchEligibility already
  // reports PkMode.twoVsTwo when it applies, the UI just doesn't act on it
  // yet.

  String pkIneligibleMessage(PkIneligibleReason? reason) {
    switch (reason) {
      case PkIneligibleReason.hostAlone:
        return LKey.pkMatchHostAlone.tr;
      case PkIneligibleReason.needEvenTeams:
        return LKey.pkMatchNeedEvenTeams.tr;
      case PkIneligibleReason.tooMany:
        return LKey.pkMatchTooManyCoHosts.tr;
      case PkIneligibleReason.battleDisabled:
        return LKey.pkMatchBattleDisabled.tr;
      case PkIneligibleReason.hostNotPublishing:
      case null:
        return LKey.pkMatchStartFailed.tr;
    }
  }

  /// A battle frozen on its end/"Victory lap" screen does NOT count as
  /// active — that state is exactly when a rematch invite should be
  /// allowed to replace it. Only an actively running round blocks a new
  /// same-room PK Match invite.
  static bool _isPkMatchActive(Livestream stream) =>
      stream.type == LivestreamType.battle &&
      stream.battleType == BattleType.waiting;

  bool _isOnPkInviteTeam(Livestream stream, int userId) =>
      (stream.pkInviteTeamAIds?.contains(userId) ?? false) ||
      (stream.pkInviteTeamBIds?.contains(userId) ?? false);

  bool _allPkInviteesAccepted(Livestream stream) => allPkInviteesAccepted(
        required: requiredPkInviteeIds(
          teamA: stream.pkInviteTeamAIds ?? const [],
          teamB: stream.pkInviteTeamBIds ?? const [],
          hostId: stream.pkInviteFromId,
        ),
        acceptedIds: stream.pkInviteAcceptedIds ?? const <int>[],
      );

  bool _isPkInviteExpired(Livestream stream) => isPkInviteExpired(
        sentAt: stream.pkInviteSentAt,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        expirySeconds: pkMatchInviteExpirySeconds,
      );

  Map<String, dynamic> _clearPkInviteFields() => {
        FirebaseConst.pkInviteFromId: null,
        FirebaseConst.pkInviteTeamAIds: null,
        FirebaseConst.pkInviteTeamBIds: null,
        FirebaseConst.pkInviteEligibleGiftIds: null,
        FirebaseConst.pkInviteDurationMin: null,
        FirebaseConst.pkInviteSentAt: null,
        FirebaseConst.pkInviteAcceptedIds: null,
      };

  /// Host-only. Auto-picks the sole eligible co-host — only correct when
  /// exactly 2 are eligible (the Match button's case). A room with more
  /// on-stage co-hosts than that needs [sendPkMatchInviteTo] instead, so the
  /// host can say which one.
  Future<void> sendPkMatchInvite({List<int>? eligibleGiftIds}) async {
    if (!isHost) return;
    final eligibility = pkMatchEligibility;
    if (eligibility.mode != PkMode.oneVsOne) {
      showSnackBar(pkIneligibleMessage(eligibility.reason));
      return;
    }
    final hostId = liveData.value.hostId;
    final opponentId = hostId == null
        ? null
        : eligibility.eligibleIds.firstWhereOrNull((id) => id != hostId);
    if (hostId == null || opponentId == null) return;
    await sendPkMatchInviteTo(opponentId, eligibleGiftIds: eligibleGiftIds);
  }

  /// Host-only. Sends a 1v1 PK Match invite to one specific on-stage
  /// co-host, regardless of how many others are also on stage — e.g. a
  /// room with 3 co-hosts (not an exact 1v1/2v2 count) still lets the host
  /// pick any one of them to battle; the rest stay as plain co-hosts.
  /// [eligibleGiftIds] null means every gift counts toward the match score.
  Future<void> sendPkMatchInviteTo(int opponentId,
      {List<int>? eligibleGiftIds}) async {
    if (!isHost) return;
    if ((setting?.liveBattle ?? 1) != 1) {
      showSnackBar(pkIneligibleMessage(PkIneligibleReason.battleDisabled));
      return;
    }
    final hostId = liveData.value.hostId;
    if (hostId == null || !_publishingUserIds.contains(hostId)) {
      showSnackBar(pkIneligibleMessage(PkIneligibleReason.hostNotPublishing));
      return;
    }
    if (opponentId == hostId ||
        !liveData.value.isCoHost(opponentId) ||
        !_publishingUserIds.contains(opponentId)) {
      Loggers.error(
          'PK match invite rejected locally: opponent $opponentId is not an eligible, publishing co-host');
      showSnackBar(LKey.pkMatchStartFailed.tr);
      return;
    }
    await _sendPkMatchInviteTeams(hostId, [hostId], [opponentId],
        eligibleGiftIds: eligibleGiftIds);
  }

  Future<void> _sendPkMatchInviteTeams(
      int hostId, List<int> teamA, List<int> teamB,
      {List<int>? eligibleGiftIds}) async {
    try {
      await db.runTransaction((transaction) async {
        final snap = await transaction.get(liveStreamDocRef);
        final data = snap.data() as Map<String, dynamic>?;
        if (data == null) throw Exception('Room no longer exists');
        final latest = Livestream.fromJson(data);
        // A match frozen on its end/"Victory lap" screen (battleType.end) is
        // fair game for a rematch invite — only an actively running one
        // blocks sending a new invite.
        final matchActive = _isPkMatchActive(latest);
        if (matchActive) {
          throw Exception('Already in a battle');
        }
        if (latest.pkInviteFromId != null && !_isPkInviteExpired(latest)) {
          throw Exception('A PK match invite is already pending');
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        transaction.update(liveStreamDocRef, {
          FirebaseConst.pkInviteFromId: hostId,
          FirebaseConst.pkInviteTeamAIds: teamA,
          FirebaseConst.pkInviteTeamBIds: teamB,
          FirebaseConst.pkInviteEligibleGiftIds: eligibleGiftIds,
          FirebaseConst.pkInviteDurationMin: pkMatchDurationMinutes,
          FirebaseConst.pkInviteSentAt: now,
          FirebaseConst.pkInviteAcceptedIds: <int>[],
        });
      });
      _awaitingPkInviteResponse = true;
      showSnackBar(LKey.pkMatchInviteSent.tr);
    } catch (e) {
      Loggers.error('Failed to send PK match invite: $e');
      showSnackBar(LKey.pkMatchInviteFailed.tr);
    }
  }

  void _showIncomingPkMatchDialog(Livestream stream) {
    if (stream.type == LivestreamType.battle) {
      unawaited(declinePkMatchInvite());
      return;
    }
    if (_isPkInviteExpired(stream)) {
      unawaited(declinePkMatchInvite());
      return;
    }
    final fromHostId = stream.pkInviteFromId;
    final sentAt = stream.pkInviteSentAt;
    if (fromHostId == null || sentAt == null) return;
    final inviter = firestoreController.users
        .firstWhereOrNull((user) => user.userId == fromHostId);
    final durationMin = stream.pkInviteDurationMin ?? pkMatchDurationMinutes;
    final remainingMs = (sentAt + pkMatchInviteExpirySeconds * 1000) -
        DateTime.now().millisecondsSinceEpoch;
    _pkInviteExpiryTimer?.cancel();
    _pkInviteExpiryTimer = Timer(
      Duration(milliseconds: remainingMs.clamp(0, 1 << 31)),
      () {
        if (Get.isDialogOpen ?? false) Get.back();
        unawaited(declinePkMatchInvite());
      },
    );
    Get.dialog(
      PkMatchInviteDialog(
        host: inviter,
        me: myUser.value?.appUser,
        durationMinutes: durationMin,
        onDecline: () {
          _pkInviteExpiryTimer?.cancel();
          Get.back();
          unawaited(declinePkMatchInvite());
        },
        onAccept: () {
          _pkInviteExpiryTimer?.cancel();
          Get.back();
          unawaited(acceptPkMatchInvite());
        },
      ),
      barrierDismissible: false,
    );
  }

  Future<void> declinePkMatchInvite() async {
    try {
      await liveStreamDocRef.update(_clearPkInviteFields());
    } catch (e) {
      Loggers.error('Failed to decline PK match invite: $e');
    }
  }

  Future<void> acceptPkMatchInvite() async {
    final stream = liveData.value;
    final fromHostId = stream.pkInviteFromId;
    if (fromHostId == null) return;
    if (_isPkInviteExpired(stream)) {
      showSnackBar(LKey.pkMatchInviteExpired.tr);
      unawaited(declinePkMatchInvite());
      return;
    }
    try {
      await db.runTransaction((transaction) async {
        final snap = await transaction.get(liveStreamDocRef);
        final data = snap.data() as Map<String, dynamic>?;
        if (data == null) throw Exception('Room no longer exists');
        final latest = Livestream.fromJson(data);
        if (latest.pkInviteFromId != fromHostId || _isPkInviteExpired(latest)) {
          throw Exception('Invite no longer pending');
        }
        transaction.update(liveStreamDocRef, {
          FirebaseConst.pkInviteAcceptedIds: FieldValue.arrayUnion([myUserId]),
        });
      });
    } catch (e) {
      Loggers.error('Failed to accept PK match invite: $e');
      showSnackBar(LKey.pkMatchStartFailed.tr);
    }
  }

  /// Host-only, triggered once every required player has accepted. Re-reads
  /// and re-validates everything fresh inside the transaction rather than
  /// trusting the snapshot that triggered it — a co-host could have left or
  /// been removed in the gap between the last accept and this running.
  Future<void> _startPkMatch(Livestream invite) async {
    String? failureReason;
    try {
      await db.runTransaction((transaction) async {
        final snap = await transaction.get(liveStreamDocRef);
        final data = snap.data() as Map<String, dynamic>?;
        if (data == null) return;
        final latest = Livestream.fromJson(data);
        // Already cleared, or already started/still running from another
        // trigger - nothing left for this one to do. A frozen end/"Victory
        // lap" screen from the PREVIOUS match doesn't count as "running" —
        // this invite is a rematch and is exactly what should replace it.
        if (latest.pkInviteFromId != myUserId || _isPkMatchActive(latest)) {
          return;
        }
        final teamA = latest.pkInviteTeamAIds ?? const <int>[];
        final teamB = latest.pkInviteTeamBIds ?? const <int>[];
        final hostId = latest.hostId;
        final eligibility = pkEligibilityFor(
          hostId: hostId,
          coHostIds: latest.coHostIds ?? const [],
          guestIds: latest.guestIds ?? const [],
          publishingIds: _publishingUserIds,
          battleEnabled: (setting?.liveBattle ?? 1) == 1,
        );
        final validationError = hostId == null
            ? 'missing_host'
            : validatePkTeams(
                eligibility: eligibility,
                hostId: hostId,
                teamA: teamA,
                teamB: teamB,
              );
        if (validationError != null) {
          failureReason = validationError;
          transaction.update(liveStreamDocRef, _clearPkInviteFields());
          return;
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        // "WIN xN" (battle_round_wins_host/cohost) tracks wins across
        // rematches against the SAME opponent within this LIVE session —
        // client reference shows it still showing a previous win while a
        // new match against that same opponent is already under way. A
        // fresh match against a different pairing starts the tally over.
        final previousTeamA = (latest.pkTeamAIds ?? const <int>[]).toSet();
        final previousTeamB = (latest.pkTeamBIds ?? const <int>[]).toSet();
        final samePairing = previousTeamA.length == teamA.length &&
            previousTeamB.length == teamB.length &&
            previousTeamA.containsAll(teamA) &&
            previousTeamB.containsAll(teamB);
        transaction.update(liveStreamDocRef, {
          FirebaseConst.type: LivestreamType.battle.value,
          FirebaseConst.battleType: BattleType.waiting.value,
          FirebaseConst.battleDuration:
              latest.pkInviteDurationMin ?? pkMatchDurationMinutes,
          FirebaseConst.battleCreatedAt: now,
          if (!samePairing) ...{
            FirebaseConst.battleRoundWinsHost: 0,
            FirebaseConst.battleRoundWinsCoHost: 0,
          },
          FirebaseConst.battleTotalRounds: pkMatchTotalRounds,
          FirebaseConst.battleCurrentRound: 1,
          FirebaseConst.firstGiftBonusClaimed: false,
          FirebaseConst.pkTeamAIds: teamA,
          FirebaseConst.pkTeamBIds: teamB,
          FirebaseConst.pkEligibleGiftIds: latest.pkInviteEligibleGiftIds,
          FirebaseConst.pkLikePointsA: 0,
          FirebaseConst.pkLikePointsB: 0,
          ..._clearPkInviteFields(),
        });
      });
      if (failureReason != null) {
        Loggers.error('PK match could not start: $failureReason');
        showSnackBar(LKey.pkMatchStartFailed.tr);
      } else {
        roundBaselineRed.value = 0;
        roundBaselineBlue.value = 0;
      }
    } catch (e) {
      Loggers.error('Failed to start PK match: $e');
      showSnackBar(LKey.pkMatchStartFailed.tr);
    } finally {
      _pkMatchStartInFlight = false;
    }
  }

  /// Bumps the winning side's running match-win tally once, called from the
  /// host's device only (see the BattleType.end branch in
  /// listenLiveStreamData). A draw increments neither side.
  Future<void> _recordPkMatchWin(Livestream stream) async {
    final redTotal = pkTeamAScore().total;
    final blueTotal = pkTeamBScore().total;
    if (redTotal == blueTotal) return;
    final field = redTotal > blueTotal
        ? FirebaseConst.battleRoundWinsHost
        : FirebaseConst.battleRoundWinsCoHost;
    try {
      await liveStreamDocRef.update({field: FieldValue.increment(1)});
    } catch (e) {
      Loggers.error('Failed to record PK match win: $e');
    }
  }

  /// Only meaningful right after a cross-room battle has ended — the two
  /// rooms are still linked via [opponentRoomId] at that point (nothing is
  /// cleared until [endBattleOnly] runs), so this reuses that
  /// same link rather than needing the opponent to be re-discovered via
  /// [FindOpponentScreen].
  Future<void> requestRematch() async {
    final opponentRoomId = liveData.value.opponentRoomId;
    if (opponentRoomId == null) {
      showSnackBar(LKey.battleInviteFailed.tr);
      return;
    }
    try {
      await _roomDocRef(opponentRoomId).update({
        FirebaseConst.pendingRematchFromId: myUserId,
      });
      showSnackBar(LKey.rematchRequestSent.tr);
      // Same best-effort nudge sendCoHostConnectInvite/requestPkMatch
      // already use -- this room-doc listener can take 50+ seconds to
      // deliver on some connections, so without it the other host's
      // dialog may never show up within any reasonable testing window.
      // forceCheckPendingCoHostInvite() (triggered by this same push type)
      // now also checks pendingRematchFromId, so this reuses that path.
      unawaited(_pushCoHostConnectInvite(int.tryParse(opponentRoomId) ?? -1));
    } catch (e) {
      Loggers.error('Failed to request rematch: $e');
      showSnackBar(LKey.battleInviteFailed.tr);
    }
  }

  void _showIncomingRematchDialog(int fromHostId) {
    final requester = firestoreController.users
        .firstWhereOrNull((user) => user.userId == fromHostId);
    Get.dialog(
      AlertDialog(
        title: Text(LKey.rematchRequestTitle.tr),
        content: Text(LKey.rematchRequestDescription
            .trParams({'name': requester?.username ?? 'A creator'})),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              declineRematch();
            },
            child: Text(LKey.refuse.tr),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              acceptRematch(fromHostId);
            },
            child: Text(LKey.accept.tr),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> declineRematch() async {
    await liveStreamDocRef.update({
      FirebaseConst.pendingRematchFromId: null,
    });
  }

  /// Same batch shape as [acceptBattleInvite] (fresh battleCreatedAt, zeroed
  /// round wins, round 1) — a rematch is a brand-new battle/battleId, the
  /// previous match's result is already safe in `battle_history` via
  /// [_recordBattleHistory], called before this room's old battle fields
  /// get overwritten here.
  Future<void> acceptRematch(int fromHostId) async {
    if (!isHost) return;
    final myRoomId = liveData.value.roomID;
    if (myRoomId == null) return;
    final opponentRoomId = '$fromHostId';
    roundBaselineRed.value = 0;
    roundBaselineBlue.value = 0;
    try {
      // Fresh 5-minute battle, scores at zero -- the co-host connection
      // itself was never cleared by the previous battle ending (see
      // endBattleOnly), so opponentRoomId is just reaffirmed here, not
      // re-established from scratch.
      final now = DateTime.now().millisecondsSinceEpoch;
      // RUNNING, not WAITING -- same reasoning as acceptPkMatch: a rematch
      // starts immediately too, no countdown stage.
      final battleFields = {
        FirebaseConst.type: LivestreamType.battle.value,
        FirebaseConst.battleType: BattleType.running.value,
        FirebaseConst.battleCreatedAt: now,
        FirebaseConst.battleDuration: AppRes.coHostBattleDurationInMinutes,
        FirebaseConst.battleRoundWins: 0,
        FirebaseConst.battleTotalRounds: 1,
        FirebaseConst.battleCurrentRound: 1,
        FirebaseConst.battleResultsVisibleUntil: null,
        FirebaseConst.crossRoomLikePoints: 0,
      };
      final batch = db.batch();
      batch.update(liveStreamDocRef, {
        ...battleFields,
        FirebaseConst.opponentRoomId: opponentRoomId,
        FirebaseConst.pendingRematchFromId: null,
      });
      batch.update(_roomDocRef(opponentRoomId), {
        ...battleFields,
        FirebaseConst.opponentRoomId: myRoomId,
      });
      await batch.commit();
    } catch (e) {
      Loggers.error('Failed to accept rematch: $e');
      showSnackBar(LKey.battleInviteFailed.tr);
    }
  }

  /// Freezes the current score and writes one immutable history document
  /// before anything gets reset. Must be called while all the battle fields
  /// (opponentRoomId, battleCreatedAt, round wins, per-side coin totals)
  /// are still populated — i.e. before `endBattleOnly` or the
  /// same-room equivalent wipes them. Safe to call from either host's
  /// device independently: both sides compute the same battleId
  /// (deterministic from the two room ids + battleCreatedAt, sorted so
  /// order doesn't matter) and Firestore's `set` is idempotent on a fixed
  /// document id, so a double-write from both hosts racing to end the
  /// battle just overwrites with the same data rather than creating a
  /// duplicate record.
  Future<void> _recordBattleHistory({required String endReason}) async {
    try {
      final stream = liveData.value;
      final myHostId = stream.hostId ?? myUserId;
      final myRoomId = stream.roomID;
      if (myRoomId == null) return;
      final isCrossRoom = stream.opponentRoomId != null;

      late final int opponentHostId;
      late final List<String> roomIds;
      late final Map<String, int> finalScores;
      late final Map<String, int> roundsWon;

      if (isCrossRoom) {
        opponentHostId = int.tryParse(stream.opponentRoomId!) ?? -1;
        if (opponentHostId == -1) return;
        roomIds = [myRoomId, stream.opponentRoomId!]..sort();
        finalScores = {
          '$myHostId': mySideBattleCoins,
          '$opponentHostId': opponentSideBattleCoins,
        };
        roundsWon = {
          '$myHostId': stream.battleRoundWins ?? 0,
          '$opponentHostId': opponentLiveData.value?.battleRoundWins ?? 0,
        };
      } else {
        // Team-based (pkTeamAIds/pkTeamBIds, with the usual host/first-co-
        // host fallback) rather than a raw currentBattleCoin lookup, so a
        // history entry's final score always matches what the live arena
        // showed for it — including like points and any gift-eligibility
        // restriction the match was set up with.
        final teamB = pkTeamBUserIds;
        if (teamB.isEmpty) return;
        opponentHostId = teamB.first;
        roomIds = [myRoomId];
        finalScores = {
          '$myHostId': pkTeamAScore().total,
          '$opponentHostId': pkTeamBScore().total,
        };
        roundsWon = {
          '$myHostId': stream.battleRoundWinsHost ?? 0,
          '$opponentHostId': stream.battleRoundWinsCoHost ?? 0,
        };
      }

      final myScore = finalScores['$myHostId'] ?? 0;
      final opponentScore = finalScores['$opponentHostId'] ?? 0;
      final outcome = determineBattleOutcome(myScore, opponentScore);
      final isDraw = outcome == BattleOutcome.draw;
      final winnerHostId = isDraw
          ? null
          : (outcome == BattleOutcome.sideAWins ? myHostId : opponentHostId);

      final sortedIds = [myHostId, opponentHostId]..sort();
      final battleId =
          '${sortedIds[0]}_${sortedIds[1]}_${stream.battleCreatedAt ?? 0}';

      final result = BattleResult(
        battleId: battleId,
        isCrossRoom: isCrossRoom,
        participantHostIds: [myHostId, opponentHostId],
        roomIds: roomIds,
        finalScores: finalScores,
        roundsWon: roundsWon,
        winnerHostId: winnerHostId,
        isDraw: isDraw,
        totalRounds: stream.battleTotalRounds ?? AppRes.battleTotalRounds,
        battleCreatedAt: stream.battleCreatedAt,
        battleEndedAt: DateTime.now().millisecondsSinceEpoch,
        endReason: endReason,
      );

      await db
          .collection(FirebaseConst.battleHistory)
          .doc(battleId)
          .set(result.toJson());
    } catch (e) {
      Loggers.error('Failed to record battle history: $e');
    }
  }

  /// Ends a cross-room battle on both sides at once, so whichever host's
  /// timer fires first (both start from the same battleCreatedAt) doesn't
  /// leave the other room stuck showing a running battle.
  Future<void> _endCrossRoomBattleType() async {
    final myRoomId = liveData.value.roomID;
    final opponentRoomId = liveData.value.opponentRoomId;
    if (myRoomId == null || opponentRoomId == null) return;
    try {
      final resultsVisibleUntil =
          DateTime.now().millisecondsSinceEpoch + 60000;
      final batch = db.batch();
      batch.update(liveStreamDocRef, {
        FirebaseConst.battleType: BattleType.end.value,
        FirebaseConst.battleResultsVisibleUntil: resultsVisibleUntil,
      });
      batch.update(_roomDocRef(opponentRoomId), {
        FirebaseConst.battleType: BattleType.end.value,
        FirebaseConst.battleResultsVisibleUntil: resultsVisibleUntil,
      });
      await batch.commit();
    } catch (e) {
      Loggers.error('Failed to end cross-room battle: $e');
    }
  }

  /// Resets BATTLE fields only -- the co-host CONNECTION (opponentRoomId/
  /// coHostConnectedAt) is deliberately untouched, so the two hosts can
  /// keep talking/interacting (and start a Rematch) without exiting and
  /// reconnecting. Called once the 1-minute post-match results window
  /// elapses, on a manual Stop while a battle is running, or when the
  /// opponent's stream looks gone past the reconnect grace period -- never
  /// automatically exits the connection itself (see exitCoHostConnection
  /// for the one function that does).
  Future<void> endBattleOnly() async {
    final opponentRoomId = liveData.value.opponentRoomId;
    try {
      await updateLiveStreamData(
        battleType: BattleType.initiate,
        type: LivestreamType.livestream,
        battleRoundWins: 0,
      );
      await liveStreamDocRef.update({
        FirebaseConst.battleCreatedAt: null,
        FirebaseConst.battleResultsVisibleUntil: null,
      });
      if (opponentRoomId != null) {
        await _roomDocRef(opponentRoomId).update({
          FirebaseConst.battleType: BattleType.initiate.value,
          FirebaseConst.type: LivestreamType.livestream.value,
          FirebaseConst.battleRoundWins: 0,
          FirebaseConst.battleCreatedAt: null,
          FirebaseConst.battleResultsVisibleUntil: null,
        });
      }
    } catch (e) {
      Loggers.error('Failed to reset after cross-room battle: $e');
    }
  }

  Future<void> _startWatchingOpponent(String opponentRoomId) async {
    _stopWatchingOpponent();
    _watchedOpponentRoomId = opponentRoomId;

    opponentLiveDocListener =
        _roomDocRef(opponentRoomId).snapshots().listen((snapshot) {
      if (!snapshot.exists) {
        _onOpponentLooksGone();
        return;
      }
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        _onOpponentLooksGone();
        return;
      }
      final stream = Livestream.fromJson(data);
      opponentLiveData.value = stream;
      // Their client plays MY stream the same way — I just need to know
      // their host id to subscribe to their published stream.
      if (opponentStreamViews.isEmpty && stream.hostId != null) {
        _playOpponentStream(stream.hostId!);
      }

      // Reconnect handling: their doc leaving `battle` (crash, manual end,
      // or their own room deleted outright above) while we're still mid-
      // battle is the only disconnect signal available in a Firestore-only
      // architecture — there's no presence/heartbeat channel to tell "clean
      // stop" apart from "crashed", so both get the same grace-period
      // treatment rather than silently hanging forever (the pre-existing
      // behavior: `if (!snapshot.exists) return;` never auto-ended
      // anything).
      if (liveData.value.type == LivestreamType.battle &&
          stream.type != LivestreamType.battle) {
        _onOpponentLooksGone();
      } else {
        _cancelOpponentReconnectGrace();
      }
    }, onError: (e) => Loggers.error('Opponent room listener failed: $e'));

    opponentUserStatesListener = _roomDocRef(opponentRoomId)
        .collection(FirebaseConst.userState)
        .snapshots()
        .listen((snapshot) {
      opponentUserStates.value = snapshot.docs
          .map((doc) => LivestreamUserState.fromJson(doc.data()))
          .toList();
    },
            onError: (e) =>
                Loggers.error('Opponent user-states listener failed: $e'));

    opponentCommentsListener = _roomDocRef(opponentRoomId)
        .collection(FirebaseConst.comments)
        .snapshots()
        .listen((snapshot) {
      opponentComments.value = snapshot.docs
          .map((doc) => LivestreamComment.fromJson(doc.data()))
          .toList();
    }, onError: (e) => Loggers.error('Opponent comments listener failed: $e'));
  }

  Future<void> _playOpponentStream(int opponentHostId) async {
    try {
      final streamId = '$opponentHostId';
      await zegoEngine.createCanvasView((viewID) {
        zegoEngine.startPlayingStream(
          streamId,
          canvas: ZegoCanvas(viewID, viewMode: ZegoViewMode.AspectFill),
        );
      }).then((canvasViewWidget) {
        if (canvasViewWidget != null) {
          opponentStreamViews.add(
            StreamView(streamId, -1, canvasViewWidget, false),
          );
        }
      });
    } catch (e) {
      Loggers.error('Failed to play opponent stream: $e');
    }
  }

  /// Shown as a banner over the battle arena while [_opponentReconnectGraceTimer]
  /// is running — "Opponent reconnecting…" rather than the stream silently
  /// freezing or hanging with no feedback.
  RxBool isOpponentReconnecting = false.obs;
  Timer? _opponentReconnectGraceTimer;

  void _onOpponentLooksGone() {
    if (_opponentReconnectGraceTimer != null) return; // grace already running
    isOpponentReconnecting.value = true;
    _opponentReconnectGraceTimer = Timer(const Duration(seconds: 15), () {
      _opponentReconnectGraceTimer = null;
      isOpponentReconnecting.value = false;
      // Still not a battle after the grace window — treat it as abandoned:
      // record what happened (final scores as they stood) and reset, same
      // as a manual Stop, so this room doesn't hang in a dead battle state
      // forever.
      if (liveData.value.type == LivestreamType.battle) {
        unawaited(_recordBattleHistory(endReason: 'opponent_disconnected'));
        unawaited(endBattleOnly());
      }
    });
  }

  void _cancelOpponentReconnectGrace() {
    if (_opponentReconnectGraceTimer == null) return;
    _opponentReconnectGraceTimer?.cancel();
    _opponentReconnectGraceTimer = null;
    isOpponentReconnecting.value = false;
  }

  void _stopWatchingOpponent() {
    _watchedOpponentRoomId = null;
    _cancelOpponentReconnectGrace();
    opponentLiveDocListener?.cancel();
    opponentUserStatesListener?.cancel();
    opponentCommentsListener?.cancel();
    opponentLiveDocListener = null;
    opponentUserStatesListener = null;
    opponentCommentsListener = null;
    opponentLiveData.value = null;
    opponentUserStates.clear();
    opponentComments.clear();
    if (opponentStreamViews.isNotEmpty) {
      for (final view in opponentStreamViews) {
        zegoEngine.stopPlayingStream(view.streamId);
      }
      opponentStreamViews.clear();
    }
  }

  Future<void> showEditLiveTitleDialog() async {
    if (!isHost) return;
    final titleController = TextEditingController(
      text: liveData.value.description ?? '',
    );

    await Get.dialog<void>(
      AlertDialog(
        title: const Text('Edit LIVE title'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          maxLength: 100,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'What is your LIVE about?',
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) {
                showSnackBar('LIVE title cannot be empty.');
                return;
              }
              await updateLiveStreamData(description: title);
              if (Get.isDialogOpen ?? false) Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    titleController.dispose();
  }

  Future<void> showAboutMeDialog() async {
    if (!isHost) return;

    final bioController = TextEditingController(
      text: SessionManager.instance.getUser()?.bio ?? '',
    );

    final updatedBio = await Get.dialog<String>(
      AlertDialog(
        title: const Text('About Me'),
        content: TextField(
          controller: bioController,
          autofocus: true,
          maxLength: 150,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Tell viewers about yourself',
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(
            onPressed: () => Get.back(result: bioController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    bioController.dispose();

    if (updatedBio == null) return;

    final updatedUser = await UserService.instance.updateUserDetails(
      bio: updatedBio,
    );

    if (updatedUser == null) {
      showSnackBar('Unable to update About Me.');
      return;
    }

    showSnackBar('About Me updated.');
  }

  Future<void> toggleCommentsEnabled() async {
    if (!isHost) return;
    final nextValue = !liveData.value.commentsEnabled;
    await updateLiveStreamData(commentsEnabled: nextValue);
    showSnackBar(
      nextValue ? 'Comments are enabled.' : 'Comments are disabled.',
    );
  }

  String get liveShareText {
    final username =
        liveData.value.getHostUser(firestoreController.users)?.username ??
            myUser.value?.username ??
            'a creator';
    final title = liveData.value.description?.trim() ?? '';
    final roomId = liveData.value.roomID ?? '';
    return 'Watch @$username LIVE on TopTap${title.isEmpty ? '' : ': $title'}\nLIVE room: $roomId';
  }

  Future<void> shareLiveStream() async {
    await SharePlus.instance.share(
      ShareParams(
        text: liveShareText,
        subject: 'TopTap LIVE',
      ),
    );
  }

  Future<void> copyLiveStreamInvite() async {
    await Clipboard.setData(ClipboardData(text: liveShareText));
    showSnackBar('LIVE invitation copied.');
  }

  void battleRunning() {
    Livestream stream = liveData.value;
    // Battle Start Timer Logic

    final startTime = DateTime.fromMillisecondsSinceEpoch(
      stream.battleCreatedAt ?? 0,
    );
    final endTime = startTime.add(
      Duration(seconds: totalBattleSecond + AppRes.battleStartInSecond),
    );

    Loggers.success('Battle Timer Started');

    _timerStart(() {
      final remaining = endTime.difference(DateTime.now()).inSeconds;
      remainingBattleSeconds.value = remaining.clamp(0, totalBattleSecond);

      Loggers.info(
        '[BATTLE RUNNING] Battle end in ${remainingBattleSeconds.value} sec.',
      );

      if (remainingBattleSeconds.value <= 0) {
        winAudioPlayer.seek(const Duration(seconds: 0));
        winAudioPlayer.play();
        timer?.cancel();
        // Record the result while every battle field is still live, before
        // either end path below (or the later host-dismiss reset) touches
        // anything — this is the actual "freeze scoring" moment, not
        // whenever the host happens to dismiss the result screen.
        unawaited(_recordBattleHistory(endReason: 'timer_expired'));
        if (liveData.value.opponentRoomId != null) {
          _endCrossRoomBattleType();
        } else {
          updateLiveStreamData(battleType: BattleType.end);
        }
      }
    });
  }

  void startMinViewerTimeoutCheck() {
    if (timeoutMinutes <= 0 || minViewersThreshold <= 0) {
      return;
    }
    if (minViewerTimeoutTimer?.isActive ?? false) return;
    Loggers.info(
      'Check Min. Viewers Required to continue live $timeoutMinutes Minutes',
    );
    minViewerTimeoutTimer = Timer.periodic(Duration(minutes: timeoutMinutes), (
      _,
    ) {
      minViewerTimeoutTimer?.cancel();
      if ((liveData.value.watchingCount ?? 0) <= minViewersThreshold) {
        isMinViewerTimeout.value = true;
        Loggers.info('Close Stream Because of Min. Viewers');
      }
    });
  }

  void onCloseAudienceBtn() {
    HapticManager.shared.light();
    Get.bottomSheet(
      ConfirmationSheet(
        title: LKey.exitLiveStreamTitle.tr,
        description: LKey.exitLiveStreamDescription.tr,
        onTap: () async {
          if (liveData.value.coHostIds?.contains(myUserId) ?? false) {
            closeCoHostStream(myUserId);
          }
          await logoutRoom();
          await _popAudienceRoute();
        },
      ),
    );
  }

  void pushNotificationToFollowers(Livestream liveData) {
    AppUser? hostUser = liveData.getHostUser([]);
    NotificationService.instance.pushNotification(
      type: NotificationType.liveStream,
      title: LKey.liveStreamNotificationTitle.trParams({
        'name': hostUser?.username ?? '',
      }),
      body: LKey.liveStreamNotificationBody.tr,
      deviceType: 1,
      topic: '${liveData.hostId}_ios',
      data: liveData.toJson(),
    );
    NotificationService.instance.pushNotification(
      type: NotificationType.liveStream,
      title: LKey.liveStreamNotificationTitle.trParams({
        'name': hostUser?.username ?? '',
      }),
      body: LKey.liveStreamNotificationBody.tr,
      deviceType: 0,
      topic: '${liveData.hostId}_android',
      data: liveData.toJson(),
    );
  }

  // Live Goal Progress Tracking Methods
  Future<void> updateLiveGoalProgress({
    int? followers,
    int? likes,
    int? gifts,
  }) async {
    Livestream stream = liveData.value;

    if (stream.hasLiveGoal != true) return;

    int currentAmount = 0;
    String goalType = stream.liveGoalType ?? '';

    switch (goalType) {
      case 'followers':
        if (followers != null) {
          currentAmount = (stream.liveGoalCurrentAmount ?? 0) + followers;
        }
        break;
      case 'likes':
        currentAmount = likes ?? stream.likeCount ?? 0;
        break;
      case 'gifts':
        if (gifts != null) {
          currentAmount = (stream.liveGoalCurrentAmount ?? 0) + gifts;
        }
        break;
      case 'duration':
        // Duration is calculated automatically in the widget
        return;
    }

    // Update the live goal progress in Firestore
    try {
      await liveStreamDocRef.update({
        'live_goal_current_amount': currentAmount,
      });

      // Check if goal is completed
      int targetAmount = stream.liveGoalTargetAmount ?? 0;
      if (currentAmount >= targetAmount && targetAmount > 0) {
        _showGoalCompletedAnimation();
      }
    } catch (e) {
      Loggers.error('Failed to update live goal progress: $e');
    }
  }

  Future<void> incrementLiveGoalProgress(int amount) async {
    final stream = liveData.value;
    if (stream.hasLiveGoal != true || amount == 0) {
      return;
    }

    try {
      final result = await db.runTransaction<(int, int)>((transaction) async {
        final snapshot = await transaction.get(liveStreamDocRef);
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        final current =
            (data['live_goal_current_amount'] as num?)?.toInt() ?? 0;
        final target = (data['live_goal_target_amount'] as num?)?.toInt() ?? 0;
        var next = current + amount;
        if (next < 0) next = 0;
        transaction.update(liveStreamDocRef, {
          'live_goal_current_amount': next,
        });
        return (next, target);
      });

      if (result.$2 > 0 && result.$1 >= result.$2 && !_hasShownGoalCompletion) {
        _hasShownGoalCompletion = true;
        _showGoalCompletedAnimation();
      }
    } catch (e) {
      Loggers.error('Failed to increment live goal progress: $e');
    }
  }

  void _showGoalCompletedAnimation() {
    // Show celebration animation when goal is completed
    Get.snackbar(
      '🎉 Goal Completed!',
      'Congratulations! You\'ve achieved your live goal!',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.TOP,
    );
  }

  // Gift Goals: several simultaneous per-gift targets, one pinned at a time.
  bool get canAddGiftGoal =>
      (liveData.value.giftGoals?.length ?? 0) < AppRes.maxGiftGoals;

  Future<void> addGiftGoal(Gift gift, int targetCount) async {
    if (!canAddGiftGoal || gift.id == null || targetCount <= 0) return;
    final goal = GiftGoal(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      giftId: gift.id!,
      giftCoinPrice: gift.coinPrice?.toInt() ?? 0,
      targetCount: targetCount,
      isPinned: (liveData.value.giftGoals ?? []).isEmpty,
    );
    final goals = [...(liveData.value.giftGoals ?? []), goal];
    await liveStreamDocRef.update({
      'gift_goals': goals.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> removeGiftGoal(String goalId) async {
    final goals = (liveData.value.giftGoals ?? [])
        .where((goal) => goal.id != goalId)
        .toList();
    await liveStreamDocRef.update({
      'gift_goals': goals.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> pinGiftGoal(String goalId) async {
    final goals = (liveData.value.giftGoals ?? [])
        .map((goal) => GiftGoal(
              id: goal.id,
              giftId: goal.giftId,
              giftCoinPrice: goal.giftCoinPrice,
              targetCount: goal.targetCount,
              currentCount: goal.currentCount,
              contributorIds: goal.contributorIds,
              isPinned: goal.id == goalId,
            ))
        .toList();
    await liveStreamDocRef.update({
      'gift_goals': goals.map((e) => e.toJson()).toList(),
    });
  }

  /// Called whenever a gift is sent to the host; bumps every active (not yet
  /// completed) Gift Goal that targets this exact gift.
  Future<void> _recordGiftTowardGoals(int giftId, int senderId) async {
    if ((liveData.value.giftGoals ?? []).isEmpty) return;
    try {
      await db.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(liveStreamDocRef);
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        final goals = (data['gift_goals'] as List<dynamic>? ?? [])
            .map((e) => GiftGoal.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        bool changed = false;
        for (final goal in goals) {
          if (goal.giftId == giftId && !goal.isCompleted) {
            goal.currentCount += 1;
            if (!goal.contributorIds.contains(senderId)) {
              goal.contributorIds = [...goal.contributorIds, senderId];
            }
            changed = true;
          }
        }
        if (changed) {
          transaction.update(liveStreamDocRef, {
            'gift_goals': goals.map((e) => e.toJson()).toList(),
          });
        }
      });
    } catch (e) {
      Loggers.error('Failed to record gift toward Gift Goals: $e');
    }
  }

  // Interact: a single live poll at a time.
  Future<void> createPoll(String question, List<String> options) async {
    final poll = LivePoll(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      question: question,
      options: options,
    );
    await liveStreamDocRef.update({'poll': poll.toJson()});
  }

  Future<void> votePoll(int optionIndex) async {
    try {
      await db.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(liveStreamDocRef);
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        if (data['poll'] == null) return;
        final poll = LivePoll.fromJson(Map<String, dynamic>.from(data['poll']));
        if (poll.isClosed ||
            poll.voterIds.contains(myUserId) ||
            optionIndex < 0 ||
            optionIndex >= poll.voteCounts.length) {
          return;
        }
        poll.voteCounts[optionIndex] += 1;
        poll.voterIds = [...poll.voterIds, myUserId];
        transaction.update(liveStreamDocRef, {'poll': poll.toJson()});
      });
    } catch (e) {
      Loggers.error('Failed to vote on poll: $e');
    }
  }

  Future<void> endPoll() async {
    await liveStreamDocRef.update({'poll': null});
  }
}

class StreamView {
  String streamId;
  int streamViewId;
  Widget streamView;
  bool isMuted;

  StreamView(this.streamId, this.streamViewId, this.streamView, this.isMuted);
}
