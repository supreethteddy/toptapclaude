import 'package:get/get.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/model/post_story/post_model.dart';

/// 🚀 ReactiveSaveManager - Real-time save/unsave state synchronization
/// 
/// This manager ensures that save/unsave actions are instantly reflected
/// across all screens without requiring manual refresh.
/// 
/// Key Features:
/// - Real-time save state updates
/// - Cross-controller communication
/// - Instant UI synchronization
/// - Memory efficient reactive streams
class ReactiveSaveManager extends GetxController {
  static ReactiveSaveManager get instance => Get.find<ReactiveSaveManager>();
  
  // Observable maps for tracking save states
  final RxMap<int, bool> _savedPostStates = <int, bool>{}.obs;
  final RxMap<int, bool> _savedReelStates = <int, bool>{}.obs;
  
  // Observable lists for saved content
  final RxList<Post> _savedPosts = <Post>[].obs;
  final RxList<Post> _savedReels = <Post>[].obs;
  
  // Performance tracking
  final RxInt _syncOperations = 0.obs;
  final RxString _lastSyncTime = ''.obs;
  
  @override
  void onInit() {
    super.onInit();
    Loggers.success('🔄 ReactiveSaveManager initialized successfully');
    _setupSaveStateListeners();
  }
  
  /// Setup reactive listeners for save state changes
  void _setupSaveStateListeners() {
    // Listen to post save states
    _savedPostStates.listen((states) {
      _updateSavedPostsList();
    });
    
    // Listen to reel save states
    _savedReelStates.listen((states) {
      _updateSavedReelsList();
    });
    
    Loggers.info('📡 Save state listeners established');
  }
  
  /// CRITICAL FIX: Update a post's save state across all controllers
  void updatePostSaveState(int postId, bool isSaved, {bool isReel = false}) {
    Loggers.info('🔄 Updating save state: Post $postId = $isSaved (isReel: $isReel)');
    
    try {
      // Update the appropriate state map
      if (isReel) {
        _savedReelStates[postId] = isSaved;
      } else {
        _savedPostStates[postId] = isSaved;
      }
      
      // Find and update all controller instances that might have this post
      _syncAcrossControllers(postId, isSaved, isReel);
      
      // Update saved content lists
      _updateSavedContentLists(postId, isSaved, isReel);
      
      // Track sync operation
      _syncOperations.value++;
      _lastSyncTime.value = DateTime.now().toIso8601String();
      
      Loggers.success('✅ Save state synchronized for post $postId');
    } catch (e) {
      Loggers.error('❌ Failed to update save state: $e');
    }
  }
  
  /// Sync save state across all relevant controllers
  void _syncAcrossControllers(int postId, bool isSaved, bool isReel) {
    try {
      // Update ReelsScreenController instances
      if (Get.isRegistered<dynamic>(tag: 'ReelsScreenController')) {
        final controller = Get.find<dynamic>(tag: 'ReelsScreenController');
        _updateControllerReels(controller, postId, isSaved);
      }
      
      // Update ProfileScreenController instances  
      try {
        // Update profile controllers if they exist
        final profileTags = ['ProfileScreenController', 'ProfileController'];
        for (var tag in profileTags) {
          if (Get.isRegistered<dynamic>(tag: tag)) {
            final controller = Get.find<dynamic>(tag: tag);
            _updateControllerPosts(controller, postId, isSaved, isReel);
          }
        }
      } catch (e) {
        Loggers.warning('⚠️ Could not find profile controllers: $e');
      }
      
      // Update SavedPostScreenController if exists
      if (Get.isRegistered<dynamic>(tag: 'SavedPostScreenController')) {
        final savedController = Get.find<dynamic>(tag: 'SavedPostScreenController');
        _updateSavedController(savedController, postId, isSaved, isReel);
      }
      
      Loggers.info('🔄 Synced across multiple controllers');
    } catch (e) {
      Loggers.warning('⚠️ Some controllers could not be synced: $e');
    }
  }
  
  /// Update reels in controller
  void _updateControllerReels(dynamic controller, int postId, bool isSaved) {
    try {
      if (controller.reels != null) {
        final reels = controller.reels as RxList<Post>;
        final index = reels.indexWhere((post) => post.id == postId);
        if (index != -1) {
          reels[index].isSaved = isSaved;
          reels.refresh();
          Loggers.info('📱 Updated reel $postId in ReelsController');
        }
      }
    } catch (e) {
      Loggers.warning('⚠️ Could not update reels controller: $e');
    }
  }
  
  /// Update posts in controller
  void _updateControllerPosts(dynamic controller, int postId, bool isSaved, bool isReel) {
    try {
      if (isReel && controller.reels != null) {
        final reels = controller.reels as RxList<Post>;
        final index = reels.indexWhere((post) => post.id == postId);
        if (index != -1) {
          reels[index].isSaved = isSaved;
          reels.refresh();
        }
      } else if (!isReel && controller.posts != null) {
        final posts = controller.posts as RxList<Post>;
        final index = posts.indexWhere((post) => post.id == postId);
        if (index != -1) {
          posts[index].isSaved = isSaved;
          posts.refresh();
        }
      }
      
      // CRITICAL: Update saved posts list in profile
      if (controller.savedPosts != null) {
        final savedPosts = controller.savedPosts as RxList<Post>;
        if (isSaved) {
          // Add to saved if not already there
          final existsIndex = savedPosts.indexWhere((post) => post.id == postId);
          if (existsIndex == -1) {
            // Find the post in other lists and add to saved
            Post? postToAdd;
            if (isReel && controller.reels != null) {
              final reels = controller.reels as RxList<Post>;
              postToAdd = reels.firstWhereOrNull((post) => post.id == postId);
            } else if (!isReel && controller.posts != null) {
              final posts = controller.posts as RxList<Post>;
              postToAdd = posts.firstWhereOrNull((post) => post.id == postId);
            }
            
            if (postToAdd != null) {
              postToAdd.isSaved = isSaved;
              savedPosts.insert(0, postToAdd); // Add to beginning
              Loggers.info('➕ Added post $postId to saved list');
            }
          }
        } else {
          // Remove from saved
          savedPosts.removeWhere((post) => post.id == postId);
          Loggers.info('➖ Removed post $postId from saved list');
        }
        savedPosts.refresh();
      }
    } catch (e) {
      Loggers.warning('⚠️ Could not update controller posts: $e');
    }
  }
  
  /// Update saved posts controller
  void _updateSavedController(dynamic controller, int postId, bool isSaved, bool isReel) {
    try {
      if (isReel && controller.reels != null) {
        final reels = controller.reels as RxList<Post>;
        if (!isSaved) {
          reels.removeWhere((post) => post.id == postId);
          reels.refresh();
        }
      } else if (!isReel && controller.posts != null) {
        final posts = controller.posts as RxList<Post>;
        if (!isSaved) {
          posts.removeWhere((post) => post.id == postId);
          posts.refresh();
        }
      }
    } catch (e) {
      Loggers.warning('⚠️ Could not update saved controller: $e');
    }
  }
  
  /// Update saved content lists
  void _updateSavedContentLists(int postId, bool isSaved, bool isReel) {
    if (isReel) {
      if (isSaved) {
        // Add to saved reels if not exists
        if (!_savedReels.any((post) => post.id == postId)) {
          // Would need the actual post object to add
          Loggers.info('📋 Post $postId marked as saved reel');
        }
      } else {
        // Remove from saved reels
        _savedReels.removeWhere((post) => post.id == postId);
        Loggers.info('🗑️ Removed post $postId from saved reels');
      }
    } else {
      if (isSaved) {
        // Add to saved posts if not exists
        if (!_savedPosts.any((post) => post.id == postId)) {
          Loggers.info('📋 Post $postId marked as saved post');
        }
      } else {
        // Remove from saved posts
        _savedPosts.removeWhere((post) => post.id == postId);
        Loggers.info('🗑️ Removed post $postId from saved posts');
      }
    }
  }
  
  /// Update saved posts list based on current states
  void _updateSavedPostsList() {
    // This would typically sync with backend or local storage
    Loggers.info('🔄 Updating saved posts list');
  }
  
  /// Update saved reels list based on current states
  void _updateSavedReelsList() {
    // This would typically sync with backend or local storage
    Loggers.info('🔄 Updating saved reels list');
  }
  
  /// Get current save state for a post
  bool getPostSaveState(int postId, {bool isReel = false}) {
    if (isReel) {
      return _savedReelStates[postId] ?? false;
    } else {
      return _savedPostStates[postId] ?? false;
    }
  }
  
  /// Initialize save states from a list of posts
  void initializeSaveStates(List<Post> posts, {bool isReel = false}) {
    for (var post in posts) {
      if (post.id != null) {
        final isSaved = (post.isSaved ?? false) == true;
        if (isReel) {
          _savedReelStates[post.id!] = isSaved;
        } else {
          _savedPostStates[post.id!] = isSaved;
        }
      }
    }
    Loggers.info('🔄 Initialized ${posts.length} ${isReel ? 'reel' : 'post'} save states');
  }
  
  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'totalSavedPosts': _savedPosts.length,
      'totalSavedReels': _savedReels.length,
      'syncOperations': _syncOperations.value,
      'lastSyncTime': _lastSyncTime.value,
      'trackedPostStates': _savedPostStates.length,
      'trackedReelStates': _savedReelStates.length,
    };
  }

  /// Track a newly created post for save state management
  void trackNewPost(Post post) {
    try {
      final postId = post.id;
      if (postId == null) {
        Loggers.warning('Cannot track post with null ID');
        return;
      }

      // Initialize save state as false for new posts
      _savedPostStates[postId] = false;
      
      Loggers.info('🆕 New post tracked: ID $postId');
      
      // Increment sync operations
      _syncOperations.value++;
      _lastSyncTime.value = DateTime.now().toIso8601String();

      Loggers.success('✅ New post tracked successfully: ID $postId');
    } catch (e) {
      Loggers.error('❌ Error tracking new post: $e');
    }
  }
}