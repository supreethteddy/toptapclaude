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
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/notification_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/livestream/app_user.dart';
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
import 'package:shortzz/screen/live_stream/livestream_screen/live_ranking_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/contributor_ranking_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_ranking_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/members_sheet.dart';
import 'package:shortzz/screen/report_sheet/report_sheet.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/firebase_const.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class LivestreamScreenController extends BaseController {
  FirebaseFirestore db = FirebaseFirestore.instance;
  ZegoExpressEngine zegoEngine = ZegoExpressEngine.instance;

  final firestoreController = Get.find<FirebaseFirestoreController>();

  Timer? timer;
  Timer? minViewerTimeoutTimer;
  Timer? presenceTimer;
  Function? onLikeTap;

  Setting? get setting => SessionManager.instance.getSettings();

  int get minViewersThreshold => setting?.liveMinViewers ?? 0;

  int get timeoutMinutes => setting?.liveTimeout ?? 0;

  int get myUserId => SessionManager.instance.getUserID();

  RxBool isPlayerMute = false.obs;
  RxBool isMinViewerTimeout = false.obs;
  RxBool isTextEmpty = true.obs;
  bool isJoinSheetOpen = false;
  bool isFrontCamera = true;
  bool isHost;
  bool _hasShownGoalCompletion = false;
  bool _hasIncrementedWatchingCount = false;
  bool _isLoggingOut = false;
  bool _hasHandledRemoteEnd = false;

  StreamSubscription<DocumentSnapshot<Livestream>>? liveStreamDocListener;
  StreamSubscription<QuerySnapshot<LivestreamUserState?>>?
      liveStreamUserStatesListener;
  StreamSubscription<QuerySnapshot<LivestreamComment?>>?
      liveStreamCommentsListener;

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

  Widget? hostPreview;

  /// Daily ranking (coins received today) for the host of this LIVE.
  LiveRankingController? rankingController;

  String get _rankingTag => 'rank_${liveData.value.roomID}';

  LivestreamScreenController(this.liveData, this.isHost, {this.hostPreview});

  int totalBattleSecond = 0;

  RxInt remainingBattleSeconds = 0.obs;
  RxBool isViewVisible = true.obs;
  RxBool isRightControlsVisible = false
      .obs; // Controls visibility of right controls (beauty, share, more, like)
  RxBool canPopStreamRoute = false.obs;

  List<LivestreamUserState> memberList = <LivestreamUserState>[];

  List<Gift> get gifts => setting?.gifts ?? [];
  RxList<LivestreamUserState> requestList = <LivestreamUserState>[].obs;
  RxList<LivestreamUserState> audienceList = <LivestreamUserState>[].obs;
  RxList<LivestreamUserState> invitedList = <LivestreamUserState>[].obs;
  RxList<LivestreamUserState> coHostList = <LivestreamUserState>[].obs;
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
    WakelockPlus.enable();
  }

  @override
  void onClose() {
    WakelockPlus.disable();
    timer?.cancel();
    minViewerTimeoutTimer?.cancel();
    presenceTimer?.cancel();
    videoPlayerController.value?.dispose();
    liveStreamUserStatesListener?.cancel();
    liveStreamCommentsListener?.cancel();
    liveStreamDocListener?.cancel();
    countdownPlayer.dispose();
    battleStartPlayer.dispose();
    winAudioPlayer.dispose();
    stopListenEvent();
    unawaited(logoutRoom());
    if (!isHost) {
      unawaited(_leaveAudience());
    }
    if (Get.isRegistered<LiveRankingController>(tag: _rankingTag)) {
      Get.delete<LiveRankingController>(tag: _rankingTag);
    }
    rankingController = null;
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
      const MembersSheet(isHost: false),
      isScrollControlled: true,
    );
  }

  /// Opens the guests sheet (Requests / Invited / Co-hosts) for the host.
  void openMembersSheet({int initialTab = MembersSheet.tabRequests}) {
    HapticManager.shared.light();
    Get.bottomSheet(
      MembersSheet(isHost: true, initialTab: initialTab),
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

    await onRequestRefuse(
      user,
      comment: comment,
      type: LivestreamCommentType.request,
      resetToAudience: false,
    );
    await updateUserStateToFirestore(
      user!.userId,
      type: LivestreamUserType.coHost,
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
    int likeCount = liveData.value.likeCount ?? 0;

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

        // Trigger like animation if changed
        final newLikeCount = stream.likeCount ?? 0;
        if (likeCount != newLikeCount) {
          onLikeTap?.call();
          likeCount = newLikeCount;
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

  void onLikeButtonTap() async {
    bool isExist = (await liveStreamDocRef.get()).exists;
    if (isExist) {
      HapticManager.shared.light();
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
      onCompletion: (giftManager) {
        Gift gift = giftManager.gift;
        AppUser? user = giftManager.streamUser;

        int coinPrice = gift.coinPrice?.toInt() ?? 0;

        _sendCommentToFirestore(
          type: LivestreamCommentType.gift,
          giftId: gift.id,
          receiverId: user?.userId,
        );
        updateUserStateToFirestore(
          user?.userId,
          battleCoin: type == GiftType.battle ? coinPrice : null,
          currentBattleCoin: type == GiftType.battle ? coinPrice : null,
          liveCoin: type == GiftType.livestream ? coinPrice : null,
        );
        // Daily ranking: every coin received in a LIVE counts for the receiver.
        unawaited(LiveRankingController.recordGift(
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
    );
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

  void onVideoRequestSend(Livestream liveData) {
    LivestreamUserState? state = liveUsersStates.firstWhereOrNull(
      (element) => element.userId == myUserId,
    );
    switch (state?.type) {
      case null:
        break;
      case LivestreamUserType.audience:
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

  void onInvite(AppUser? user, {bool isInvited = false}) {
    updateUserStateToFirestore(
      user?.userId,
      type:
          isInvited ? LivestreamUserType.audience : LivestreamUserType.invited,
    );
  }

  void _showJoinStreamSheet(LivestreamUserState state) {
    if (state.userId == myUserId && state.type == LivestreamUserType.invited) {
      AppUser? hostUser = liveData.value.getHostUser(firestoreController.users);
      isJoinSheetOpen = true;
      Get.bottomSheet(
        LiveStreamJoinSheet(
          hostUser: hostUser,
          myUser: myUser.value,
          onJoined: () async {
            LivestreamUserState? userState = liveUsersStates.firstWhereOrNull(
              (element) => element.userId == myUserId,
            );
            if (userState?.type == LivestreamUserType.invited) {
              updateUserStateToFirestore(
                myUserId,
                type: LivestreamUserType.coHost,
              );
            } else {
              showSnackBar(LKey.joinCancelledDescription.tr);
            }
          },
          onCancel: () {
            updateUserStateToFirestore(
              myUserId,
              type: LivestreamUserType.audience,
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

  void publishCoHostStream(int streamId) async {
    bool isPermissionGranted = await requestPermission();
    if (isPermissionGranted) {
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

      // ✅ Publish the stream
      await zegoEngine.startPublishingStream('$streamId');

      // ✅ Force audio output to speaker (after stream starts)
      Future.delayed(const Duration(milliseconds: 300), () {
        zegoEngine.setAudioRouteToSpeaker(true);
      });

      updateLiveStreamData(coHostId: FieldValue.arrayUnion([streamId]));
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
      updateLiveStreamData(coHostId: FieldValue.arrayRemove([streamId]));
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
      if (newState.type == LivestreamUserType.coHost &&
          oldState?.type != LivestreamUserType.coHost) {
        publishCoHostStream(myUserId);
      }

      if (newState.type == LivestreamUserType.audience &&
          oldState?.type == LivestreamUserType.invited &&
          isJoinSheetOpen) {
        Get.back();
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
      if (oldState?.type == LivestreamUserType.coHost &&
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
    if (state.type == LivestreamUserType.coHost) {
      updateLiveStreamData(coHostId: FieldValue.arrayRemove([state.userId]));
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
            updateLiveStreamData(
              battleType: BattleType.initiate,
              type: LivestreamType.livestream,
            );
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

  void toggleView() {
    isViewVisible.value = !isViewVisible.value;
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
    updateLiveStreamData(
      battleType: BattleType.waiting,
      battleDuration: AppRes.battleDurationInMinutes,
      battleCreatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool get canStartBattle {
    final coHostIds = liveData.value.coHostIds ?? const <int>[];
    if (coHostIds.isEmpty) return false;
    return streamViews.any((view) {
      final userId = int.tryParse(view.streamId);
      return userId != null && coHostIds.contains(userId);
    });
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
        updateLiveStreamData(battleType: BattleType.end);
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
}

class StreamView {
  String streamId;
  int streamViewId;
  Widget streamView;
  bool isMuted;

  StreamView(this.streamId, this.streamViewId, this.streamView, this.isMuted);
}
