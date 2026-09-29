import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/extensions/list_extension.dart';
import 'package:shortzz/common/extensions/user_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/host/livestream_host_screen.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/live_rooms_page_view.dart';
import 'package:shortzz/utilities/firebase_const.dart';

class LiveStreamSearchScreenController extends BaseController {
  FirebaseFirestore db = FirebaseFirestore.instance;
  RxList<Livestream> livestreamList = <Livestream>[].obs;
  RxList<Livestream> livestreamFilterList = <Livestream>[].obs;
  StreamSubscription<QuerySnapshot<Livestream>>? livestreamListListener;
  Timer? staleRoomTimer;
  final Map<String, Livestream> _livestreamMap = {};

  final firebaseFirestoreController = Get.find<FirebaseFirestoreController>();

  Setting? get setting => SessionManager.instance.getSettings();

  RxList<DummyLive> get dummyLives => (setting?.dummyLives ?? []).obs;

  @override
  void onReady() {
    super.onReady();
    Future.wait({fetchLiveStreams(), addDummyUsers()});
    staleRoomTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _publishActiveStreams(),
    );
  }

  @override
  void onClose() {
    super.onClose();
    livestreamListListener?.cancel();
    staleRoomTimer?.cancel();
  }

  Future<void> fetchLiveStreams() async {
    isLoading.value = true;
    await Future.delayed(const Duration(milliseconds: 100));

    // Using a map for faster access and modification
    livestreamListListener = db
        .collection(FirebaseConst.liveStreams)
        .withConverter(
          fromFirestore: (snapshot, options) =>
              Livestream.fromJson(snapshot.data()!),
          toFirestore: (Livestream livestream, options) => livestream.toJson(),
        )
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final Livestream? livestream = change.doc.data();
        String roomId = livestream?.roomID ?? '';
        if (livestream == null || roomId.isEmpty) continue;

        // Add, modify, or remove based on document change type
        switch (change.type) {
          case DocumentChangeType.added:
            _livestreamMap[roomId] = livestream;
            break;

          case DocumentChangeType.modified:
            // Update only if the livestream has changed
            _livestreamMap[roomId] = livestream;
            break;

          case DocumentChangeType.removed:
            _livestreamMap.remove(roomId);
            break;
        }
      }

      // Convert map back to lists
      _publishActiveStreams();
      // // Perform any additional cleanup or transformations
      // removeDummyLive();

      _assignHostUsersToStreams();

      isLoading.value = false; // Hide loader after initial fetch
    });
  }

  void _publishActiveStreams() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final active = _livestreamMap.values.where((stream) {
      if (stream.isDummyLive == 1) return true;
      final heartbeat = stream.lastHeartbeatAt ?? stream.createdAt;
      return heartbeat == null || now - heartbeat <= 60000;
    }).toList()
      ..sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));

    livestreamList.value = active;
    livestreamFilterList.value = List<Livestream>.from(active);
    _assignHostUsersToStreams();
  }

  void _assignHostUsersToStreams() {
    final userMap = _userMapFromList(firebaseFirestoreController.users);
    for (var stream in livestreamList) {
      stream.hostUser = userMap[stream.hostId];
    }
  }

  Map<int, AppUser> _userMapFromList(List<AppUser> list) {
    return {
      for (var user in list)
        if (user.userId != null) user.userId!: user,
    };
  }

  void onLiveUserTap(Livestream stream) async {
    User? myUser = SessionManager.instance.getUser();
    if (stream.hostId == myUser?.id) {
      Get.to(() => LivestreamHostScreen(isHost: true, livestream: stream));
    } else {
      Get.to(() => LiveRoomsPageView(
          initialRoom: stream, rooms: livestreamFilterList));
    }
  }

  onSearchChange(String value) {
    livestreamFilterList.value = livestreamList.search(value, (p0) {
      return p0.hostUser?.username ?? '';
    }, (p1) => p1.description ?? '');
  }

  Future<void> addDummyUsers() async {
    //   try {
    //     // Fetch existing livestreams from Firestore
    //     final livestreamList = await db
    //         .collection(FirebaseConst.liveStreams)
    //         .withConverter<Livestream>(
    //           fromFirestore: (snapshot, _) =>
    //               Livestream.fromJson(snapshot.data()!),
    //           toFirestore: (livestream, _) => livestream.toJson(),
    //         )
    //         .get();

    //     // Collect existing stream IDs
    //     final existingIds = livestreamList.docs.map((doc) => doc.id).toSet();
    //     List<String?> dummyIds =
    //         dummyLives.map((element) => element.userId.toString()).toList();

    //     for (var dummy in dummyLives) {
    //       final dummyId = dummy.userId;

    //       // Skip invalid IDs
    //       if (dummyId == -1) continue;

    //       final alreadyExists = existingIds.contains('$dummyId');
    //       if (!alreadyExists && dummy.status == 1) {
    //         // Create new dummy livestream
    //         await createLiveStream(dummy);
    //         print('✅ Created dummy livestream: $dummyId');
    //       } else if (alreadyExists && dummy.status == 0) {
    //         // Delete if status is inactive
    //         await deleteStreamOnFirebase(dummyId);
    //         print('🗑️ Deleted inactive dummy livestream: $dummyId');
    //       } else {
    //         print(
    //             'ℹ️ No action for: $dummyId (exists: $alreadyExists, status: ${dummy.status})');
    //       }
    //     }
    //     // Delete any extra livestreams in Firestore not present in dummyLives
    //     final outdatedIds = existingIds
    //         .difference(dummyIds.toSet()); // Strings in Firestore not in dummy

    //     for (var id in outdatedIds) {
    //       if (id.isNotEmpty) {
    //         await deleteStreamOnFirebase(int.tryParse(id) ?? -1);
    //         print('🗑️ Removed orphaned livestream from Firestore: $id');
    //       }
    //     }
    //   } catch (e, stack) {
    //     print('❌ Error in addDummyUsers: $e');
    //     print(stack);
    //   }
    // }

    Future<void> createLiveStream(DummyLive? dummyLive) async {
      User? dummyUser = dummyLive?.user;
      if (dummyUser == null) {
        Loggers.error('Dummy User Not found');
        return;
      }
      int userId = dummyLive?.userId ?? -1;

      DocumentReference livestreamRef =
          db.collection(FirebaseConst.liveStreams).doc('$userId');

      int time = DateTime.now().millisecondsSinceEpoch;

      // Livestream model
      Livestream livestream = dummyUser.livestream(
          type: LivestreamType.dummy,
          time: time,
          dummyUserLink: dummyLive?.link,
          isDummyLive: 1,
          description: dummyLive?.title);

      // LivestreamUser model
      AppUser? livestreamUser = dummyUser.appUser;

      // LivestreamUserState model
      LivestreamUserState livestreamUserState =
          dummyUser.streamState(time: time, stateType: LivestreamUserType.host);

      try {
        DocumentReference usersRef =
            db.collection(FirebaseConst.appUsers).doc('$userId');
        DocumentReference userStateRef =
            livestreamRef.collection(FirebaseConst.userState).doc('$userId');

        WriteBatch batch = db.batch();

        bool isExist = (await livestreamRef.get()).exists;
        bool isUserExist = (await usersRef.get()).exists;

        if (isExist) {
          // Update existing documents
          batch.update(livestreamRef, livestream.toJson());
          batch.update(userStateRef, livestreamUserState.toJson());
        } else {
          // Create new documents
          batch.set(livestreamRef, livestream.toJson());
          batch.set(userStateRef, livestreamUserState.toJson());
        }
        if (isUserExist) {
          batch.update(usersRef, livestreamUser.toJson());
        } else {
          batch.set(usersRef, livestreamUser.toJson());
        }

        await batch.commit();
        Loggers.success(isExist ? 'Updated Dummy Live' : 'Created Dummy Live');
      } catch (e, stackTrace) {
        Loggers.error('Failed to create/update live stream: $e');
        Loggers.error('StackTrace: $stackTrace');
      }
    }

    Future<void> deleteStreamOnFirebase(int? dummyUserId) async {
      if (dummyUserId == null) return;

      final String roomId = dummyUserId.toString();

      final DocumentReference livestreamRef =
          db.collection(FirebaseConst.liveStreams).doc(roomId);

      final CollectionReference usersStateRef =
          livestreamRef.collection(FirebaseConst.userState);

      final CollectionReference commentsRef =
          livestreamRef.collection(FirebaseConst.comments);

      try {
        // Fetch both collections in parallel
        final results = await Future.wait([
          usersStateRef.get(),
          commentsRef.get(),
        ]);

        final QuerySnapshot usersSnapshot = results[0];
        final QuerySnapshot commentsSnapshot = results[1];

        final WriteBatch batch = db.batch();

        // Queue deletions for user states
        for (final doc in usersSnapshot.docs) {
          batch.delete(doc.reference);
        }
        Loggers.info('Queued ${usersSnapshot.size} user state deletions.');

        // Queue deletions for comments
        for (final doc in commentsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        Loggers.info('Queued ${commentsSnapshot.size} comment deletions.');

        // Delete the livestream document
        batch.delete(livestreamRef);

        // Commit all deletions in one batch
        await batch.commit();
        Loggers.success(
            'Deleted live stream, user states, and comments from Firestore.');
      } catch (e, stackTrace) {
        Loggers.error('Failed to delete live stream: $e');
        Loggers.error('StackTrace: $stackTrace');
      }
    }

    void removeDummyLive() {
      final dummyStream =
          livestreamFilterList.where((e) => e.isDummyLive == 1).toList();
      if (dummyStream.isEmpty) return;
      if (setting?.liveDummyShow == 0) {
        for (var element in dummyStream) {
          deleteStreamOnFirebase(element.hostId);
        }
      } else {
        for (var element in dummyStream) {
          final shouldDelete = dummyLives.isEmpty ||
              !dummyLives.any((e) => e.userId == element.hostId);

          if (shouldDelete) {
            deleteStreamOnFirebase(element.hostId);
          }
        }
      }
    }
  }
}
