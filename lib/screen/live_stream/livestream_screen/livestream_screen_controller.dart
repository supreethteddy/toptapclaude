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
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/haptic_manager.dart';
import 'package:shortzz/common/manager/live_invite_watcher.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/utilities/beautify_controls_mixin.dart';
import 'package:shortzz/config/gifts/battle_gift_tiers.dart';
import 'package:shortzz/model/livestream/battle_result.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/notification_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/live_invite_service.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/live_invite.dart';
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
import 'package:shortzz/screen/live_stream/livestream_screen/widget/league_standings_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_ranking_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/members_sheet.dart';
import 'package:shortzz/screen/report_sheet/report_sheet.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/firebase_const.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class LivestreamScreenController extends BaseController
    with BeautifyControlsMixin {
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

  // Cross-room PK Battle: the opponent room's own state, watched read-only
  // while opponentRoomId is set. No multi-room Zego login needed — see
  // opponentStreamViews.
  String? _watchedOpponentRoomId;
  StreamSubscription<DocumentSnapshot>? opponentLiveDocListener;
  StreamSubscription<QuerySnapshot>? opponentUserStatesListener;
  Rx<Livestream?> opponentLiveData = Rx(null);
  RxList<LivestreamUserState> opponentUserStates =
      <LivestreamUserState>[].obs;
  RxList<StreamView> opponentStreamViews = <StreamView>[].obs;
  int? _lastHandledInviteFromId;
  int? _lastHandledRematchFromId;

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

  LivestreamScreenController(this.liveData, this.isHost, {this.hostPreview});

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

  List<LivestreamUserState> memberList = <LivestreamUserState>[];

  List<Gift> get gifts => setting?.gifts ?? [];

  // Seat caps come from the admin panel (Phase 0 settings); the literals are
  // only the fallback for a backend that predates those columns and match
  // the client's spec (Co-host Mode = 4 in frame incl. host; 9 guests).
  int get maxCoHosts => setting?.maxLiveCohosts ?? 3;
  int get maxGuests => setting?.maxLiveGuests ?? 9;
  bool get guestRequestsEnabled =>
      (setting?.liveGuestRequestsEnabled ?? 1) == 1;

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
  RxList<LivestreamComment> comments = <LivestreamComment>[].obs;
  RxList<LivestreamUserState> liveUsersStates = <LivestreamUserState>[].obs;

  Rx<AppUser?> selectedGiftUser = Rx(null);
  Rx<VideoPlayerController?> videoPlayerController = Rx(null);

  Rx<User?> get myUser => SessionManager.instance.getUser().obs;
  Rx<Livestream> liveData;

  AudioPlayer countdownPlayer = AudioPlayer();
  AudioPlayer battleStartPlayer = AudioPlayer();
  AudioPlayer winAudioPlayer = AudioPlayer();

  @override
  void onInit() {
    super.onInit();
    activeRoomIds.add(liveData.value.roomID ?? '');
    // Tell LiveInviteWatcher this room already has its screen open, so an
    // out-of-room invite for it is handled by the in-room INVITED path
    // instead of double-prompting with a second sheet.
    LiveInviteWatcher.activeRoomIds.add(liveData.value.roomID ?? '');
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
    activeRoomIds.remove(liveData.value.roomID ?? '');
    LiveInviteWatcher.activeRoomIds.remove(liveData.value.roomID ?? '');
    _outgoingInvitesSub?.cancel();
    WakelockPlus.disable();
    timer?.cancel();
    minViewerTimeoutTimer?.cancel();
    presenceTimer?.cancel();
    _giftComboTimer?.cancel();
    _battleInviteExpiryTimer?.cancel();
    videoPlayerController.value?.dispose();
    liveStreamUserStatesListener?.cancel();
    liveStreamCommentsListener?.cancel();
    liveStreamDocListener?.cancel();
    _stopWatchingOpponent();
    countdownPlayer.dispose();
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
    ReelsScreenController.resumeHomeFeed();
    super.onClose();
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
    countdownPlayer.setAsset(AssetRes.endCountdown);
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
      final pendingInvite =
          LiveInviteService.instance.takeAcceptedFor(roomID);
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

      return result;
    } catch (e) {
      Loggers.error('Error in loginRoom: $e');
      showSnackBar('Something went wrong while joining the room.');
      rethrow;
    }
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
            startPlayStream(stream.streamID);
          }
          break;
        case ZegoUpdateType.Delete:
          for (final stream in streamList) {
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
          streamViews.removeWhere((element) => element.streamId == streamID);
        case ZegoPublisherState.PublishRequesting:
        case ZegoPublisherState.Publishing:
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
      }).then((canvasViewWidget) {
        if (canvasViewWidget != null) {
          streamViews.add(
            StreamView(streamID, streamViewId, canvasViewWidget, false),
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
    try {
      _hasIncrementedWatchingCount = await db.runTransaction<bool>((tx) async {
        final streamSnapshot = await tx.get(liveStreamDocRef);
        if (!streamSnapshot.exists) return false;

        final stateRef = liveStreamUserStatesRef.doc(myUserId.toString());
        final stateSnapshot = await tx.get(stateRef);
        final stateData = stateSnapshot.data() as Map<String, dynamic>? ?? {};
        final alreadyCounted = stateData[FirebaseConst.countedAsViewer] == true;
        final now = DateTime.now().millisecondsSinceEpoch;

        tx.set(
            stateRef,
            {
              FirebaseConst.countedAsViewer: true,
              FirebaseConst.lastSeenAt: now,
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

    try {
      await liveStreamUserStatesRef.doc(myUserId.toString()).set({
        FirebaseConst.lastSeenAt: now,
        FirebaseConst.countedAsViewer: true,
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
      final type = LivestreamUserType.fromString(data[FirebaseConst.type] ?? '');
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
          countdownPlayer.pause();
        }

        if (stream.battleType == BattleType.waiting) {
          totalBattleSecond = Duration(
            minutes: stream.battleDuration,
          ).inSeconds;
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

        // Cross-room PK Battle: an incoming invite to accept/decline.
        if (isHost &&
            stream.pendingBattleInviteFromId != null &&
            stream.pendingBattleInviteFromId != _lastHandledInviteFromId) {
          _lastHandledInviteFromId = stream.pendingBattleInviteFromId;
          _showIncomingBattleInviteDialog(stream.pendingBattleInviteFromId!);
        }
        if (stream.pendingBattleInviteFromId == null) {
          _lastHandledInviteFromId = null;
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
    liveStreamCommentsListener = liveStreamCommentsRef
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
              _registerGiftForCombo(comment);
              if (comment.giftId == eagleGiftId) {
                eagleGiftAnimationTrigger.value++;
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

  void onLikeButtonTap([Offset? tapPosition]) async {
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
      liveStreamDocRef.update({
        FirebaseConst.likeCount: FieldValue.increment(1),
      });

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
      onCompletion: (giftManager) async {
        Gift gift = giftManager.gift;
        AppUser? user = giftManager.streamUser;

        int coinPrice = gift.coinPrice?.toInt() ?? 0;
        if (type == GiftType.battle) {
          coinPrice = await _claimFirstGiftBonusIfEligible(coinPrice);
        }
        // Battle score and real coin value are deliberately different
        // numbers: battleGiftTiers lets specific gifts (Rose/Heart/Coffee/
        // Galaxy) be worth a fixed, configured point value in a PK Battle
        // (e.g. Galaxy = 1000) independent of what they actually cost in
        // coins. Everything else (liveCoin, the ranking/league controllers
        // below) still uses the real coinPrice, including the first-gift
        // bonus applied above — only the battle scoreboard itself reads
        // battlePoints. A gift with no tier mapping falls back to coinPrice
        // 1:1, so this is a no-op for every gift not explicitly configured.
        final battlePoints =
            battlePointsForGift(gift.id, fallbackCoins: coinPrice);

        _sendCommentToFirestore(
          type: LivestreamCommentType.gift,
          giftId: gift.id,
          receiverId: user?.userId,
        );
        updateUserStateToFirestore(
          user?.userId,
          battleCoin: type == GiftType.battle ? battlePoints : null,
          currentBattleCoin: type == GiftType.battle ? battlePoints : null,
          liveCoin: type == GiftType.livestream ? coinPrice : null,
        );
        // Daily + hourly ranking: every coin received in a LIVE counts for
        // the receiver in both leaderboards.
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
      },
      giftType: type,
      battleViewType: battleViewType,
      streamUsers: availableUsers,
      roomID: liveData.value.roomID,
    );
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
        tx.update(liveStreamDocRef, {FirebaseConst.firstGiftBonusClaimed: true});
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
            (data[arrayKey] as List<dynamic>? ?? const []).whereType<num>().map((e) => e.toInt()));
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

      // Seat membership was already written by _claimStageSeat above.
      _sendCommentToFirestore(type: LivestreamCommentType.joinedCoHost);
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
            element.commentType == LivestreamCommentType.joinedCoHost,
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
      final wasOnStageNonHost =
          oldState?.type == LivestreamUserType.coHost ||
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
      if (wasOnStageNonHost &&
          newState.type == LivestreamUserType.audience) {
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

  /// Explicit host action moving a Guest Call participant into Co-host Mode
  /// (never automatic — the client forbids guests silently becoming PK
  /// players). The guest keeps publishing; only the seat array and role move,
  /// atomically, so the co-host cap can't be exceeded by two promotions.
  Future<void> promoteGuestToCoHost(LivestreamUserState state) async {
    if (state.type != LivestreamUserType.guest) return;
    if (liveData.value.type == LivestreamType.battle) {
      showSnackBar(LKey.cannotLeaveDuringBattle.tr);
      return;
    }
    final cap = maxCoHosts;
    bool moved = false;
    try {
      moved = await db.runTransaction<bool>((tx) async {
        final snap = await tx.get(liveStreamDocRef);
        if (!snap.exists) return false;
        final data = snap.data() as Map<String, dynamic>? ?? {};
        final coHosts = (data[FirebaseConst.coHostIds] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList();
        final pending = (data[FirebaseConst.pendingSeatIds] as List<dynamic>? ?? const [])
            .whereType<num>()
            .length;
        if (coHosts.contains(state.userId)) return true;
        if (coHosts.length + pending >= cap) return false;
        tx.update(liveStreamDocRef, {
          FirebaseConst.coHostIds: FieldValue.arrayUnion([state.userId]),
          FirebaseConst.guestIds: FieldValue.arrayRemove([state.userId]),
        });
        return true;
      });
    } catch (e) {
      Loggers.error('Failed to promote guest ${state.userId}: $e');
    }
    if (!moved) {
      showSnackBar(LKey.coHostSeatsFull.tr);
      return;
    }
    await updateUserStateToFirestore(
      state.userId,
      type: LivestreamUserType.coHost,
    );
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
              endCrossRoomBattleAndReset();
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
  /// running round-win tally (only [onStopButtonTap] / [endCrossRoomBattleAndReset]
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
      final hostState = liveUsersStates
          .firstWhereOrNull((state) => state.userId == liveData.value.hostId);
      final coHostIds = liveData.value.coHostIds ?? const <int>[];
      final coHostId = coHostIds.isEmpty ? null : coHostIds.first;
      final coHostState = liveUsersStates
          .firstWhereOrNull((state) => state.userId == coHostId);
      final hostCoins = hostState?.currentBattleCoin ?? 0;
      final coHostCoins = coHostState?.currentBattleCoin ?? 0;
      final isRoundDraw = hostCoins == coHostCoins;
      final hostWon = !isRoundDraw && hostCoins > coHostCoins;
      roundBaselineRed.value = hostCoins;
      roundBaselineBlue.value = coHostCoins;
      await updateLiveStreamData(
        battleType: BattleType.waiting,
        battleCreatedAt: now,
        battleRoundWinsHost: hostWon ? FieldValue.increment(1) : null,
        battleRoundWinsCoHost:
            (!isRoundDraw && !hostWon) ? FieldValue.increment(1) : null,
        battleCurrentRound: nextRound,
        firstGiftBonusClaimed: false,
      );
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

  /// Transaction-guarded so two hosts inviting each other at the same
  /// instant (or someone double-tapping Challenge) can't both land a write —
  /// previously this was a bare `.update()`, so a second invite always
  /// silently clobbered whatever the target's doc already had.
  Future<void> sendBattleInvite(int opponentHostId) async {
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
        if (target.type == LivestreamType.battle ||
            target.pendingBattleInviteFromId != null) {
          throw Exception('Target is already busy');
        }
        transaction.update(targetRef, {
          FirebaseConst.pendingBattleInviteFromId: myUserId,
          FirebaseConst.battleInviteSentAt: DateTime.now().millisecondsSinceEpoch,
        });
      });
      showSnackBar(LKey.battleInviteSent.tr);
    } catch (e) {
      Loggers.error('Failed to send PK invite: $e');
      showSnackBar(LKey.battleInviteFailed.tr);
    }
  }

  Timer? _battleInviteExpiryTimer;

  void _showIncomingBattleInviteDialog(int fromHostId) {
    if (liveData.value.type == LivestreamType.battle) {
      // Already battling (or mid-invite) — quietly decline further invites.
      declineBattleInvite();
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
        declineBattleInvite();
        return;
      }
    }
    final inviter = firestoreController.users
        .firstWhereOrNull((user) => user.userId == fromHostId);
    _battleInviteExpiryTimer?.cancel();
    _battleInviteExpiryTimer =
        Timer(const Duration(seconds: AppRes.battleInviteExpiryInSecond), () {
      if (Get.isDialogOpen ?? false) Get.back();
      declineBattleInvite();
    });
    Get.dialog(
      AlertDialog(
        title: Text(LKey.battleInviteTitle.tr),
        content: Text(LKey.battleInviteDescription
            .trParams({'name': inviter?.username ?? 'A creator'})),
        actions: [
          TextButton(
            onPressed: () {
              _battleInviteExpiryTimer?.cancel();
              Get.back();
              declineBattleInvite();
            },
            child: Text(LKey.refuse.tr),
          ),
          TextButton(
            onPressed: () {
              _battleInviteExpiryTimer?.cancel();
              Get.back();
              acceptBattleInvite(fromHostId);
            },
            child: Text(LKey.accept.tr),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> declineBattleInvite() async {
    await liveStreamDocRef.update({
      FirebaseConst.pendingBattleInviteFromId: null,
      FirebaseConst.battleInviteSentAt: null,
    });
  }

  Future<void> acceptBattleInvite(int fromHostId) async {
    if (!isHost) return;
    // Re-check freshness at accept time, not just at dialog-open time — a
    // dialog can sit on screen while the invite expires underneath it.
    final sentAt = liveData.value.battleInviteSentAt;
    if (sentAt != null) {
      final elapsedSeconds =
          (DateTime.now().millisecondsSinceEpoch - sentAt) / 1000;
      if (elapsedSeconds >= AppRes.battleInviteExpiryInSecond) {
        showSnackBar(LKey.battleInviteExpired.tr);
        await declineBattleInvite();
        return;
      }
    }
    final myRoomId = liveData.value.roomID;
    if (myRoomId == null) return;
    final opponentRoomId = '$fromHostId';
    roundBaselineRed.value = 0;
    roundBaselineBlue.value = 0;
    try {
      // A transaction (not a plain batch) so the invite can't be accepted
      // twice, or accepted after the inviter already cancelled/expired it,
      // or accepted while the opponent raced into a different battle in the
      // meantime — all reads happen first, then both writes commit atomically
      // only if every check still holds against the latest server state.
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
        if (opponentLatest.type == LivestreamType.battle) {
          throw Exception('Opponent already in a battle');
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        transaction.update(liveStreamDocRef, {
          FirebaseConst.type: LivestreamType.battle.value,
          FirebaseConst.battleType: BattleType.waiting.value,
          FirebaseConst.battleCreatedAt: now,
          FirebaseConst.opponentRoomId: opponentRoomId,
          FirebaseConst.pendingBattleInviteFromId: null,
          FirebaseConst.battleInviteSentAt: null,
          FirebaseConst.battleRoundWins: 0,
          FirebaseConst.battleTotalRounds: AppRes.battleTotalRounds,
          FirebaseConst.battleCurrentRound: 1,
          FirebaseConst.firstGiftBonusClaimed: false,
        });
        transaction.update(_roomDocRef(opponentRoomId), {
          FirebaseConst.type: LivestreamType.battle.value,
          FirebaseConst.battleType: BattleType.waiting.value,
          FirebaseConst.battleCreatedAt: now,
          FirebaseConst.opponentRoomId: myRoomId,
          FirebaseConst.battleRoundWins: 0,
          FirebaseConst.battleTotalRounds: AppRes.battleTotalRounds,
          FirebaseConst.battleCurrentRound: 1,
          FirebaseConst.firstGiftBonusClaimed: false,
        });
      });
    } catch (e) {
      Loggers.error('Failed to accept PK invite: $e');
      showSnackBar(LKey.battleInviteFailed.tr);
    }
  }

  /// Only meaningful right after a cross-room battle has ended — the two
  /// rooms are still linked via [opponentRoomId] at that point (nothing is
  /// cleared until [endCrossRoomBattleAndReset] runs), so this reuses that
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
      final batch = db.batch();
      batch.update(liveStreamDocRef, {
        FirebaseConst.type: LivestreamType.battle.value,
        FirebaseConst.battleType: BattleType.waiting.value,
        FirebaseConst.battleCreatedAt: DateTime.now().millisecondsSinceEpoch,
        FirebaseConst.opponentRoomId: opponentRoomId,
        FirebaseConst.pendingRematchFromId: null,
        FirebaseConst.battleRoundWins: 0,
        FirebaseConst.battleTotalRounds: AppRes.battleTotalRounds,
        FirebaseConst.battleCurrentRound: 1,
        FirebaseConst.firstGiftBonusClaimed: false,
      });
      batch.update(_roomDocRef(opponentRoomId), {
        FirebaseConst.type: LivestreamType.battle.value,
        FirebaseConst.battleType: BattleType.waiting.value,
        FirebaseConst.battleCreatedAt: DateTime.now().millisecondsSinceEpoch,
        FirebaseConst.opponentRoomId: myRoomId,
        FirebaseConst.battleRoundWins: 0,
        FirebaseConst.battleTotalRounds: AppRes.battleTotalRounds,
        FirebaseConst.battleCurrentRound: 1,
        FirebaseConst.firstGiftBonusClaimed: false,
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
  /// are still populated — i.e. before `endCrossRoomBattleAndReset` or the
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
        final coHostIds = stream.coHostIds ?? const <int>[];
        if (coHostIds.isEmpty) return;
        opponentHostId = coHostIds.first;
        roomIds = [myRoomId];
        final hostState = liveUsersStates
            .firstWhereOrNull((state) => state.userId == myHostId);
        final coHostState = liveUsersStates
            .firstWhereOrNull((state) => state.userId == opponentHostId);
        finalScores = {
          '$myHostId': hostState?.currentBattleCoin ?? 0,
          '$opponentHostId': coHostState?.currentBattleCoin ?? 0,
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
      final winnerHostId =
          isDraw ? null : (outcome == BattleOutcome.sideAWins ? myHostId : opponentHostId);

      final sortedIds = [myHostId, opponentHostId]..sort();
      final battleId = '${sortedIds[0]}_${sortedIds[1]}_${stream.battleCreatedAt ?? 0}';

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
      final batch = db.batch();
      batch.update(liveStreamDocRef, {
        FirebaseConst.battleType: BattleType.end.value,
      });
      batch.update(_roomDocRef(opponentRoomId), {
        FirebaseConst.battleType: BattleType.end.value,
      });
      await batch.commit();
    } catch (e) {
      Loggers.error('Failed to end cross-room battle: $e');
    }
  }

  /// Reverts both rooms to normal once the host dismisses the battle-end
  /// screen (mirrors the same-room battle's manual "Stop" behavior).
  Future<void> endCrossRoomBattleAndReset() async {
    final opponentRoomId = liveData.value.opponentRoomId;
    try {
      await updateLiveStreamData(
        battleType: BattleType.initiate,
        type: LivestreamType.livestream,
        battleRoundWins: 0,
      );
      await liveStreamDocRef.update({FirebaseConst.opponentRoomId: null});
      if (opponentRoomId != null) {
        await _roomDocRef(opponentRoomId).update({
          FirebaseConst.battleType: BattleType.initiate.value,
          FirebaseConst.type: LivestreamType.livestream.value,
          FirebaseConst.opponentRoomId: null,
          FirebaseConst.battleRoundWins: 0,
        });
      }
    } catch (e) {
      Loggers.error('Failed to reset after cross-room battle: $e');
    }
  }

  Future<void> _startWatchingOpponent(String opponentRoomId) async {
    _stopWatchingOpponent();
    _watchedOpponentRoomId = opponentRoomId;

    opponentLiveDocListener = _roomDocRef(opponentRoomId)
        .snapshots()
        .listen((snapshot) {
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
    }, onError: (e) => Loggers.error('Opponent user-states listener failed: $e'));
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
    _opponentReconnectGraceTimer =
        Timer(const Duration(seconds: 15), () {
      _opponentReconnectGraceTimer = null;
      isOpponentReconnecting.value = false;
      // Still not a battle after the grace window — treat it as abandoned:
      // record what happened (final scores as they stood) and reset, same
      // as a manual Stop, so this room doesn't hang in a dead battle state
      // forever.
      if (liveData.value.type == LivestreamType.battle) {
        unawaited(
            _recordBattleHistory(endReason: 'opponent_disconnected'));
        unawaited(endCrossRoomBattleAndReset());
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
    opponentLiveDocListener = null;
    opponentUserStatesListener = null;
    opponentLiveData.value = null;
    opponentUserStates.clear();
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

      if (remainingBattleSeconds.value <= 10) {
        if (!countdownPlayer.playing) {
          countdownPlayer.seek(
            Duration(seconds: 10 - remainingBattleSeconds.value),
          );
          countdownPlayer.play();
        }
      }

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
