import 'package:get/get.dart';
import 'package:toptap/model/post_story/post_model.dart';

/// Service for filtering content based on user preferences
/// 🔇 COMPLETELY DISABLED TO FIX AUDIO ISSUES - ALL FILTERING LOGIC COMMENTED OUT
class ContentFilterService extends GetxService {
  static ContentFilterService get instance =>
      Get.find<ContentFilterService>();

  // 🔇 COMMENTED OUT: final SettingsService _settings = SettingsService.instance;

  @override
  void onInit() {
    super.onInit();
    print(
        '✅ ContentFilterService: Initialized (DISABLED - all filtering bypassed)');
  }

  // =============================================================================
  // CONTENT FILTERING METHODS - 🔇 ALL DISABLED TO FIX AUDIO ISSUES
  // =============================================================================

  /// Filter a list of posts based on user content preferences - 🔇 DISABLED
  List<Post> filterPosts(List<Post> posts) {
    // 🔇 COMPLETELY BYPASSED: Return all posts without filtering
    return posts;
  }

  /// Check if a post should be shown to the user - 🔇 DISABLED
  bool shouldShowPost(Post post) {
    // 🔇 COMPLETELY BYPASSED: Always show all posts
    return true;
  }

  /// Check if comments should be filtered - 🔇 DISABLED
  bool shouldFilterComments() {
    // 🔇 COMPLETELY BYPASSED: Never filter comments
    return false;
  }

  /// Get age restriction level - 🔇 DISABLED
  String getAgeRestrictionLevel() {
    // 🔇 COMPLETELY BYPASSED: No restrictions
    return 'Off';
  }

  /// Check if content type filtering is enabled - 🔇 DISABLED
  bool isContentTypeFilteringEnabled() {
    // 🔇 COMPLETELY BYPASSED: No content type filtering
    return false;
  }

  /// Check if regional filtering is enabled - 🔇 DISABLED
  bool isRegionalFilteringEnabled() {
    // 🔇 COMPLETELY BYPASSED: No regional filtering
    return false;
  }

  /// Check if trending filter is enabled - 🔇 DISABLED
  bool isTrendingFilterEnabled() {
    // 🔇 COMPLETELY BYPASSED: Show all trending content
    return true;
  }

  /// Get current filter settings summary - 🔇 DISABLED
  Map<String, dynamic> getFilterSettingsSummary() {
    // 🔇 COMPLETELY BYPASSED: Return disabled state
    return {
      'status': 'DISABLED',
      'message':
          'All content filtering disabled to fix audio issues',
      'filtersActive': false,
    };
  }

  /*
  // 🔇 ALL ORIGINAL FILTERING LOGIC COMMENTED OUT TO FIX AUDIO ISSUES
  // This prevents any calls to disabled SettingsService methods
      
      if (removedCount > 0) {
        print('🎨 ContentFilter: Filtered $removedCount of $originalCount posts');
      }
      
      return filteredPosts;
    } catch (e) {
      print('❌ ContentFilter: Error filtering posts: $e');
      return posts; // Return original list if filtering fails
    }
  }
  
  /// Check if a specific post should be shown based on user preferences
  bool shouldShowPost(Post post) {
    try {
      // Check sensitive content filter
      if (_settings.hideSensitiveContent && _isPostSensitive(post)) {
        print('🚫 ContentFilter: Hiding sensitive post: ${post.id}');
        return false;
      }
      
      // Check restricted mode
      if (_isRestrictedContent(post)) {
        print('🚫 ContentFilter: Hiding restricted post: ${post.id}');
        return false;
      }
      
      // Check content type preferences
      if (!_isContentTypeAllowed(post)) {
        print('🚫 ContentFilter: Content type not allowed: ${post.id}');
        return false;
      }
      
      // Check regional content preferences
      if (!_isRegionalContentAllowed(post)) {
        print('🚫 ContentFilter: Regional content filtered: ${post.id}');
        return false;
      }
      
      return true;
    } catch (e) {
      print('❌ ContentFilter: Error checking post ${post.id}: $e');
      return true; // Show post if filtering check fails
    }
  }
  
  /// Filter comments based on inappropriate content settings
  List<String> filterComments(List<String> comments) {
    if (!_settings.filterInappropriateComments) {
      return comments; // No filtering needed
    }
    
    try {
      List<String> filteredComments = comments.where((comment) => 
        !_isCommentInappropriate(comment)
      ).toList();
      
      int removedCount = comments.length - filteredComments.length;
      if (removedCount > 0) {
        print('🎨 ContentFilter: Filtered $removedCount inappropriate comments');
      }
      
      return filteredComments;
    } catch (e) {
      print('❌ ContentFilter: Error filtering comments: $e');
      return comments;
    }
  }
  
  // =============================================================================
  // CONTENT ANALYSIS METHODS
  // =============================================================================
  
  /// Check if post contains sensitive content
  bool _isPostSensitive(Post post) {
    // Check description for sensitive keywords
    String description = (post.description ?? '').toLowerCase();
    List<String> sensitiveKeywords = [
      'nsfw', 'explicit', 'adult', 'mature', 'warning',
      'graphic', 'disturbing', 'violence', 'sensitive'
    ];
    
    for (String keyword in sensitiveKeywords) {
      if (description.contains(keyword)) {
        return true;
      }
    }
    
    // Check if post is marked as sensitive (this would come from your API)
    // For now, we'll check if there's a sensitive flag or hashtags
    if (description.contains('#nsfw') || 
        description.contains('#adult') || 
        description.contains('#mature')) {
      return true;
    }
    
    return false;
  }
  
  /// Check if content violates restricted mode settings
  bool _isRestrictedContent(Post post) {
    String restrictedMode = _settings.restrictedMode;
    
    if (restrictedMode == 'Off') {
      return false; // No restrictions
    }
    
    String description = (post.description ?? '').toLowerCase();
    
    // Basic restricted content keywords
    List<String> restrictedKeywords = [
      'explicit', 'adult', 'nsfw', 'mature', 'sex', 'violence',
      'drugs', 'alcohol', 'gambling', 'weapons'
    ];
    
    if (restrictedMode == 'Moderate') {
      // Filter only obviously explicit content
      List<String> explicitKeywords = ['explicit', 'nsfw', 'adult', 'sex'];
      return explicitKeywords.any((keyword) => description.contains(keyword));
    } else if (restrictedMode == 'Strict') {
      // Filter all potentially inappropriate content
      return restrictedKeywords.any((keyword) => description.contains(keyword));
    }
    
    return false;
  }
  
  /// Check if the content type is allowed based on user preferences
  bool _isContentTypeAllowed(Post post) {
    // Check music video preferences
    if (!_settings.showMusicVideos && _isMusicContent(post)) {
      return false;
    }
    
    // Check gaming content preferences
    if (!_settings.showGamingContent && _isGamingContent(post)) {
      return false;
    }
    
    // Check educational content preferences
    if (!_settings.showEducationalContent && _isEducationalContent(post)) {
      return false;
    }
    
    return true;
  }
  
  /// Check if regional content is allowed
  bool _isRegionalContentAllowed(Post post) {
    if (_settings.showRegionalContent) {
      return true; // All regional content allowed
    }
    
    // For now, we'll assume all content is allowed unless specifically marked
    // This would need to be enhanced with actual geographic/regional data
    return true;
  }
  
  /// Check if comment contains inappropriate content
  bool _isCommentInappropriate(String comment) {
    String lowercaseComment = comment.toLowerCase();
    
    // Basic inappropriate content keywords
    List<String> inappropriateKeywords = [
      'spam', 'scam', 'fake', 'bot', 'hate', 'toxic',
      'abuse', 'bully', 'threat', 'harassment'
    ];
    
    // Check for excessive caps (potential spam)
    if (_isExcessiveCaps(comment)) {
      return true;
    }
    
    // Check for repeated characters (potential spam)
    if (_hasRepeatedChars(comment)) {
      return true;
    }
    
    // Check for inappropriate keywords
    return inappropriateKeywords.any((keyword) => 
      lowercaseComment.contains(keyword)
    );
  }
  
  // =============================================================================
  // CONTENT TYPE DETECTION HELPERS
  // =============================================================================
  
  /// Check if post is music-related content
  bool _isMusicContent(Post post) {
    String description = (post.description ?? '').toLowerCase();
    List<String> musicKeywords = [
      'music', 'song', 'audio', 'beat', 'rhythm', 'melody',
      'artist', 'band', 'album', 'track', 'playlist',
      '#music', '#song', '#audio', '#beat'
    ];
    
    return musicKeywords.any((keyword) => description.contains(keyword));
  }
  
  /// Check if post is gaming-related content
  bool _isGamingContent(Post post) {
    String description = (post.description ?? '').toLowerCase();
    List<String> gamingKeywords = [
      'game', 'gaming', 'player', 'gameplay', 'streamer',
      'esports', 'xbox', 'playstation', 'nintendo', 'pc',
      '#gaming', '#game', '#gameplay', '#streamer', '#esports'
    ];
    
    return gamingKeywords.any((keyword) => description.contains(keyword));
  }
  
  /// Check if post is educational content
  bool _isEducationalContent(Post post) {
    String description = (post.description ?? '').toLowerCase();
    List<String> educationalKeywords = [
      'learn', 'education', 'tutorial', 'lesson', 'teach',
      'study', 'school', 'university', 'course', 'knowledge',
      '#education', '#learn', '#tutorial', '#lesson', '#study'
    ];
    
    return educationalKeywords.any((keyword) => description.contains(keyword));
  }
  
  /// Check if comment has excessive capital letters (spam indicator)
  bool _isExcessiveCaps(String comment) {
    if (comment.length < 10) return false;
    
    int capsCount = comment.split('').where((char) => 
      char == char.toUpperCase() && char != char.toLowerCase()
    ).length;
    
    double capsRatio = capsCount / comment.length;
    return capsRatio > 0.7; // More than 70% caps
  }
  
  /// Check if comment has repeated characters (spam indicator)
  bool _hasRepeatedChars(String comment) {
    if (comment.length < 5) return false;
    
    // Check for 4+ consecutive identical characters
    for (int i = 0; i < comment.length - 3; i++) {
      if (comment[i] == comment[i + 1] && 
          comment[i] == comment[i + 2] && 
          comment[i] == comment[i + 3]) {
        return true;
      }
    }
    
    return false;
  }
  
  // =============================================================================
  // RECOMMENDATION METHODS
  // =============================================================================
  
  /// Apply personalization to content recommendations
  List<Post> applyPersonalization(List<Post> posts) {
    if (!_settings.personalizedRecommendations) {
      return posts; // Return unmodified if personalization is disabled
    }
    
    try {
      // This is where you would integrate with recommendation algorithms
      // For now, we'll just apply basic content type filtering
      List<Post> personalizedPosts = posts.where((post) => shouldShowPost(post)).toList();
      
      print('🎯 ContentFilter: Applied personalization to ${posts.length} posts');
      return personalizedPosts;
    } catch (e) {
      print('❌ ContentFilter: Error applying personalization: $e');
      return posts;
    }
  }
  
  /// Check if trending content should be shown
  bool shouldShowTrendingContent() {
    return _settings.showTrendingContent;
  }
  
  // =============================================================================
  // UTILITY METHODS
  // =============================================================================
  
  /// Get content filtering summary for debugging
  Map<String, dynamic> getFilteringSummary() {
    return {
      'hideSensitiveContent': _settings.hideSensitiveContent,
      'filterInappropriateComments': _settings.filterInappropriateComments,
      'restrictedMode': _settings.restrictedMode,
      'showMusicVideos': _settings.showMusicVideos,
      'showGamingContent': _settings.showGamingContent,
      'showEducationalContent': _settings.showEducationalContent,
      'showRegionalContent': _settings.showRegionalContent,
      'showTrendingContent': _settings.showTrendingContent,
      'personalizedRecommendations': _settings.personalizedRecommendations,
    };
  }
  
  /// Print current filtering settings to console
  void debugPrintFiltering() {
    print('🎨 ContentFilterService Debug Info:');
    print('  Hide Sensitive: ${_settings.hideSensitiveContent}');
    print('  Filter Comments: ${_settings.filterInappropriateComments}');
    print('  Restricted Mode: ${_settings.restrictedMode}');
    print('  Show Music: ${_settings.showMusicVideos}');
    print('  Show Gaming: ${_settings.showGamingContent}');
    print('  Show Educational: ${_settings.showEducationalContent}');
    print('  Show Regional: ${_settings.showRegionalContent}');
    print('  Show Trending: ${_settings.showTrendingContent}');
    print('  Personalized: ${_settings.personalizedRecommendations}');
  }
  
  /// Test content filtering with sample data
  void runFilteringTest() {
    print('🧪 Running ContentFilterService test...');
    
    // Create sample posts for testing
    List<Post> testPosts = [
      Post(id: 1, description: 'Beautiful sunset #nature'),
      Post(id: 2, description: 'NSFW content warning #adult'),
      Post(id: 3, description: 'Gaming livestream #gaming #streamer'),
      Post(id: 4, description: 'Educational tutorial #learn #education'),
      Post(id: 5, description: 'Music video premiere #music #song'),
    ];
    
    print('  Original posts: ${testPosts.length}');
    
    List<Post> filtered = filterPosts(testPosts);
    print('  Filtered posts: ${filtered.length}');
    print('  Removed: ${testPosts.length - filtered.length}');
    
    // Test individual post filtering
    for (Post post in testPosts) {
      bool shouldShow = shouldShowPost(post);
      print('  Post ${post.id}: ${shouldShow ? "SHOW" : "HIDE"} - "${post.description}"');
    }
    
    print('✅ ContentFilterService test completed');
  }
**/
}
