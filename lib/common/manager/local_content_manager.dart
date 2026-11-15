import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/model/post_story/post_model.dart';

/// 🌟 LocalContentManager - Manages local storage for likes and private posts
///
/// This manager handles:
/// - Tracking liked posts locally (alternative to fetchLikedPosts API)
/// - Managing private posts locally (alternative to fetchPrivatePosts API)
/// - Providing fallback solutions when backend APIs are not available
class LocalContentManager extends GetxController {
  static LocalContentManager get instance =>
      Get.find<LocalContentManager>();

  // Storage keys
  static const String _likedPostsKey = 'liked_post_ids';
  static const String _likeTimestampsKey =
      'like_timestamps';
  static const String _privatePostsKey = 'private_post_ids';
  static const String _privacyTimestampsKey =
      'privacy_timestamps';

  // Reactive lists for UI updates
  final RxList<int> _likedPostIds = <int>[].obs;
  final RxList<int> _privatePostIds = <int>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadFromStorage();
    Loggers.success('🌟 LocalContentManager initialized');
  }

  /// Load saved data from storage
  void _loadFromStorage() {
    try {
      final storage = GetStorage('toptap');

      // Load liked posts
      final likedIds =
          storage.read<List>(_likedPostsKey) ?? [];
      _likedPostIds.value = likedIds.cast<int>();

      // Load private posts
      final privateIds =
          storage.read<List>(_privatePostsKey) ?? [];
      _privatePostIds.value = privateIds.cast<int>();

      Loggers.info(
          '📱 Loaded ${_likedPostIds.length} liked posts and ${_privatePostIds.length} private posts from storage');
    } catch (e) {
      Loggers.error('Error loading from storage: $e');
    }
  }

  // ❤️ LIKED POSTS MANAGEMENT

  /// Add a post to liked posts
  void addLikedPost(int postId) {
    try {
      if (!_likedPostIds.contains(postId)) {
        _likedPostIds.add(postId);
        _saveToStorage(_likedPostsKey, _likedPostIds);
        _saveTimestamp(_likeTimestampsKey, postId);
        Loggers.info('❤️ Added liked post: $postId');
      }
    } catch (e) {
      Loggers.error('Error adding liked post: $e');
    }
  }

  /// Remove a post from liked posts
  void removeLikedPost(int postId) {
    try {
      _likedPostIds.remove(postId);
      _saveToStorage(_likedPostsKey, _likedPostIds);
      _removeTimestamp(_likeTimestampsKey, postId);
      Loggers.info('💔 Removed liked post: $postId');
    } catch (e) {
      Loggers.error('Error removing liked post: $e');
    }
  }

  /// Check if a post is liked
  bool isPostLiked(int postId) {
    return _likedPostIds.contains(postId);
  }

  /// Get all liked post IDs
  List<int> getLikedPostIds() {
    return List.from(_likedPostIds);
  }

  /// Get liked posts filtered from a list
  List<Post> filterLikedPosts(List<Post> allPosts) {
    return allPosts
        .where((post) => _likedPostIds.contains(post.id))
        .toList()
      ..sort((a, b) =>
          _getTimestamp(_likeTimestampsKey, b.id ?? 0)
              .compareTo(_getTimestamp(
                  _likeTimestampsKey, a.id ?? 0)));
  }

  // 🔒 PRIVATE POSTS MANAGEMENT

  /// Add a post to private posts
  void addPrivatePost(int postId) {
    try {
      if (!_privatePostIds.contains(postId)) {
        _privatePostIds.add(postId);
        _saveToStorage(_privatePostsKey, _privatePostIds);
        _saveTimestamp(_privacyTimestampsKey, postId);
        Loggers.info('🔒 Added private post: $postId');
      }
    } catch (e) {
      Loggers.error('Error adding private post: $e');
    }
  }

  /// Remove a post from private posts
  void removePrivatePost(int postId) {
    try {
      _privatePostIds.remove(postId);
      _saveToStorage(_privatePostsKey, _privatePostIds);
      _removeTimestamp(_privacyTimestampsKey, postId);
      Loggers.info('🔓 Removed private post: $postId');
    } catch (e) {
      Loggers.error('Error removing private post: $e');
    }
  }

  /// Check if a post is private
  bool isPostPrivate(int postId) {
    return _privatePostIds.contains(postId);
  }

  /// Get all private post IDs
  List<int> getPrivatePostIds() {
    return List.from(_privatePostIds);
  }

  /// Get private posts filtered from a list
  List<Post> filterPrivatePosts(List<Post> allPosts) {
    return allPosts
        .where((post) => _privatePostIds.contains(post.id))
        .toList()
      ..sort((a, b) =>
          _getTimestamp(_privacyTimestampsKey, b.id ?? 0)
              .compareTo(_getTimestamp(
                  _privacyTimestampsKey, a.id ?? 0)));
  }

  // 🛠️ HELPER METHODS

  /// Save list to storage
  void _saveToStorage(String key, List<int> list) {
    try {
      final storage = GetStorage('toptap');
      storage.write(key, list);
    } catch (e) {
      Loggers.error('Error saving to storage: $e');
    }
  }

  /// Save timestamp for an action
  void _saveTimestamp(String key, int postId) {
    try {
      final storage = GetStorage('toptap');
      final timestamps = storage.read<Map>(key) ?? {};
      timestamps[postId.toString()] =
          DateTime.now().millisecondsSinceEpoch;
      storage.write(key, timestamps);
    } catch (e) {
      Loggers.error('Error saving timestamp: $e');
    }
  }

  /// Remove timestamp for an action
  void _removeTimestamp(String key, int postId) {
    try {
      final storage = GetStorage('toptap');
      final timestamps = storage.read<Map>(key) ?? {};
      timestamps.remove(postId.toString());
      storage.write(key, timestamps);
    } catch (e) {
      Loggers.error('Error removing timestamp: $e');
    }
  }

  /// Get timestamp for a post
  int _getTimestamp(String key, int postId) {
    try {
      final storage = GetStorage('toptap');
      final timestamps = storage.read<Map>(key) ?? {};
      return timestamps[postId.toString()] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all data (useful for testing or logout)
  void clearAll() {
    try {
      final storage = GetStorage('toptap');
      storage.remove(_likedPostsKey);
      storage.remove(_likeTimestampsKey);
      storage.remove(_privatePostsKey);
      storage.remove(_privacyTimestampsKey);

      _likedPostIds.clear();
      _privatePostIds.clear();

      Loggers.info('🧹 Cleared all local content data');
    } catch (e) {
      Loggers.error('Error clearing data: $e');
    }
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'totalLikedPosts': _likedPostIds.length,
      'totalPrivatePosts': _privatePostIds.length,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }
}
