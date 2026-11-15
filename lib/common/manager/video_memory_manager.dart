import 'dart:async';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:get/get.dart';
import 'package:toptap/common/manager/logger.dart';

/// 🎬 VideoMemoryManager - Advanced video controller lifecycle management
///
/// This manager prevents memory leaks by:
/// - Limiting active video controllers (max 7 for smooth scrolling)
/// - Auto-disposing unused controllers after 15 min
/// - Proper buffer cleanup
/// - Thread-safe disposed state checking
class VideoMemoryManager extends GetxController {
  static VideoMemoryManager get instance =>
      Get.find<VideoMemoryManager>();

  // Configuration - Optimized for smooth scrolling
  static const int maxActiveControllers =
      7; // Increased to handle preloading without churn
  static const Duration idleDisposalTime =
      Duration(minutes: 15); // Longer timeout for better UX

  // Active controllers tracking
  final Map<String, CachedVideoPlayerPlusController>
      _activeControllers = {};
  final Map<String, DateTime> _lastUsedTime = {};
  final Map<String, Timer> _disposalTimers = {};

  // 🔒 Track disposed controllers to prevent race conditions
  final Set<String> _disposedIdentifiers = {};

  // Performance metrics
  final RxInt _totalControllersCreated = 0.obs;
  final RxInt _totalControllersDisposed = 0.obs;
  final RxInt _currentActiveCount = 0.obs;
  final RxDouble _memoryUsageMB = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    Loggers.success('🎬 VideoMemoryManager initialized');
    _startMemoryMonitoring();
  }

  /// Create or reuse a video controller
  CachedVideoPlayerPlusController createController(
    String identifier,
    dynamic source, {
    bool isNetworkUrl = true,
  }) {
    Loggers.info(
        '🎬 Creating/retrieving controller for: $identifier');

    // 🔒 Remove from disposed set if recreating
    _disposedIdentifiers.remove(identifier);

    // Check if controller already exists and is valid
    if (_activeControllers.containsKey(identifier)) {
      final existing = _activeControllers[identifier]!;

      // 🔒 Verify controller is still valid
      if (!isControllerDisposed(identifier)) {
        _updateLastUsedTime(identifier);
        Loggers.info(
            '♻️ Reusing existing controller for: $identifier');
        return existing;
      } else {
        // Controller was disposed, remove it and create new
        Loggers.warning(
            '⚠️ Existing controller $identifier is disposed, recreating...');
        _activeControllers.remove(identifier);
        _lastUsedTime.remove(identifier);
        _disposalTimers[identifier]?.cancel();
        _disposalTimers.remove(identifier);
      }
    }

    // Enforce controller limit to prevent memory exhaustion
    _enforceControllerLimit();

    // Create new controller
    final controller = isNetworkUrl
        ? CachedVideoPlayerPlusController.networkUrl(
            Uri.parse(source.toString()),
            invalidateCacheIfOlderThan:
                const Duration(seconds: 7))
        : CachedVideoPlayerPlusController.file(source);

    // Register controller
    _activeControllers[identifier] = controller;
    _updateLastUsedTime(identifier);
    _totalControllersCreated.value++;
    _currentActiveCount.value = _activeControllers.length;

    // Setup auto-disposal timer
    _setupAutoDisposal(identifier);

    Loggers.success(
        '✅ Created new controller for: $identifier');
    return controller;
  }

  /// Enforce controller limit by disposing least recently used controllers
  /// 🔒 Skips controllers that are currently playing to avoid black screens
  void _enforceControllerLimit() {
    if (_activeControllers.length >= maxActiveControllers) {
      // Find least recently used controller that is NOT playing
      String? oldestKey;
      DateTime? oldestTime;

      for (var entry in _lastUsedTime.entries) {
        // 🔒 Check if controller is playing before considering for disposal
        final controller = _activeControllers[entry.key];
        if (controller != null) {
          try {
            final value = controller.value;
            // Skip controllers that are playing or initializing
            if (value.isPlaying || !value.isInitialized) {
              continue;
            }
          } catch (e) {
            // Controller already disposed, can be cleaned up
          }
        }

        if (oldestTime == null ||
            entry.value.isBefore(oldestTime)) {
          oldestTime = entry.value;
          oldestKey = entry.key;
        }
      }

      if (oldestKey != null) {
        Loggers.warning(
            '⚠️ Controller limit reached ($maxActiveControllers). Disposing oldest non-playing: $oldestKey');
        _disposeController(oldestKey,
            reason: 'Controller limit exceeded');
      } else {
        Loggers.warning(
            '⚠️ Controller limit reached but all controllers are playing, skipping disposal');
      }
    }
  }

  /// Update last used time for a controller
  void _updateLastUsedTime(String identifier) {
    _lastUsedTime[identifier] = DateTime.now();

    // Cancel existing disposal timer before setting new one
    _disposalTimers[identifier]?.cancel();
    _disposalTimers.remove(identifier);
  }

  /// Setup auto-disposal timer for unused controllers (reduced timeout)
  void _setupAutoDisposal(String identifier) {
    _disposalTimers[identifier] =
        Timer(idleDisposalTime, () {
      _disposeController(identifier,
          reason: 'Auto-disposal (idle timeout)');
    });
  }

  /// 🔒 Check if a controller is disposed without throwing
  bool isControllerDisposed(String identifier) {
    // Check if we explicitly marked it as disposed
    if (_disposedIdentifiers.contains(identifier)) {
      return true;
    }

    final controller = _activeControllers[identifier];
    if (controller == null) {
      return true;
    }

    try {
      // This will throw if disposed
      final _ = controller.value;
      return false;
    } catch (e) {
      if (e.toString().contains('disposed')) {
        _disposedIdentifiers.add(identifier);
        return true;
      }
      // Some other error, assume not disposed
      return false;
    }
  }

  /// Dispose a specific controller
  void _disposeController(String identifier,
      {String reason = 'Manual disposal'}) {
    final controller = _activeControllers[identifier];
    if (controller == null) return;

    Loggers.info(
        '🗑️ Disposing controller $identifier: $reason');

    // 🔒 Mark as disposed immediately
    _disposedIdentifiers.add(identifier);

    try {
      // 🔒 CRITICAL: Check if already disposed before disposal
      try {
        final value = controller.value;

        // Pause if playing
        if (value.isInitialized && value.isPlaying) {
          controller.pause();
        }
      } catch (e) {
        // Controller already disposed
        if (e.toString().contains('disposed')) {
          Loggers.warning(
              '⚠️ Controller $identifier already disposed: $e');

          // Clean up tracking even if already disposed
          _activeControllers.remove(identifier);
          _lastUsedTime.remove(identifier);
          _disposalTimers[identifier]?.cancel();
          _disposalTimers.remove(identifier);
          _currentActiveCount.value =
              _activeControllers.length;
          return;
        }
        throw e;
      }

      // Now safe to dispose
      controller.dispose().catchError((e) {
        Loggers.error(
            '❌ Error disposing controller $identifier: $e');
      });
    } catch (e) {
      Loggers.error(
          '❌ Error during controller disposal: $e');
    }

    // Clean up tracking immediately
    _activeControllers.remove(identifier);
    _lastUsedTime.remove(identifier);
    _disposalTimers[identifier]?.cancel();
    _disposalTimers.remove(identifier);

    // Update metrics
    _totalControllersDisposed.value++;
    _currentActiveCount.value = _activeControllers.length;
  }

  /// Mark controller as actively used (refreshes disposal timer)
  void markControllerUsed(String identifier) {
    if (_activeControllers.containsKey(identifier)) {
      // Update timestamp AND refresh disposal timer to prevent premature disposal
      _lastUsedTime[identifier] = DateTime.now();

      // Cancel existing timer and setup new one
      _disposalTimers[identifier]?.cancel();
      _disposalTimers.remove(identifier);
      _setupAutoDisposal(identifier);

      Loggers.info(
          '🔄 Updated last used time for controller: $identifier');
    }
  }

  /// Pause all controllers
  void pauseAllControllers() {
    Loggers.info('⏸️ Pausing all active controllers');

    final controllersToRemove = <String>[];

    for (var entry in _activeControllers.entries) {
      try {
        final controller = entry.value;
        // Check if controller is still valid
        controller.value; // This will throw if disposed

        if (controller.value.isInitialized &&
            controller.value.isPlaying) {
          controller.pause();
        }
      } catch (e) {
        Loggers.warning(
            '⚠️ Controller ${entry.key} is invalid, marking for removal: $e');
        controllersToRemove.add(entry.key);
      }
    }

    // Remove invalid controllers
    for (String key in controllersToRemove) {
      _activeControllers.remove(key);
      _lastUsedTime.remove(key);
      _disposalTimers[key]?.cancel();
      _disposalTimers.remove(key);
    }

    _currentActiveCount.value = _activeControllers.length;
  }

  /// Dispose all controllers (for app background/cleanup)
  Future<void> disposeAllControllers(
      {String reason = 'Dispose all requested'}) async {
    Loggers.info('🗑️ Disposing all controllers: $reason');

    final controllersToDispose =
        Map<String, CachedVideoPlayerPlusController>.from(
            _activeControllers);

    // 🔒 Mark all as disposed immediately
    _disposedIdentifiers.addAll(controllersToDispose.keys);

    // Clear tracking immediately
    _activeControllers.clear();
    _lastUsedTime.clear();
    _disposalTimers.values
        .forEach((timer) => timer.cancel());
    _disposalTimers.clear();

    // Dispose controllers
    for (var entry in controllersToDispose.entries) {
      try {
        final controller = entry.value;

        // Check if already disposed
        try {
          // Pause first if still valid
          if (controller.value.isInitialized &&
              controller.value.isPlaying) {
            await controller.pause();
          }

          // Then dispose
          await controller.dispose();
        } catch (e) {
          if (!e.toString().contains('disposed')) {
            Loggers.error(
                '❌ Error disposing controller ${entry.key}: $e');
          }
        }
        _totalControllersDisposed.value++;
      } catch (e) {
        Loggers.error(
            '❌ Error disposing controller ${entry.key}: $e');
      }
    }

    _currentActiveCount.value = 0;
    Loggers.success('✅ All controllers disposed');
  }

  /// Get controller if exists and is still valid
  CachedVideoPlayerPlusController? getController(
      String identifier) {
    final controller = _activeControllers[identifier];
    if (controller != null) {
      try {
        // Check if controller is still valid (not disposed)
        controller.value; // This will throw if disposed
        _updateLastUsedTime(identifier);
        return controller;
      } catch (e) {
        // Controller was disposed, remove it from our tracking
        Loggers.warning(
            '⚠️ Controller $identifier was disposed externally, removing from cache');
        _activeControllers.remove(identifier);
        _lastUsedTime.remove(identifier);
        _disposalTimers[identifier]?.cancel();
        _disposalTimers.remove(identifier);
        _currentActiveCount.value =
            _activeControllers.length;
        return null;
      }
    }
    return null;
  }

  /// Check if controller exists
  bool hasController(String identifier) {
    return _activeControllers.containsKey(identifier);
  }

  /// Start memory monitoring
  void _startMemoryMonitoring() {
    // COMMENTED OUT: Periodic timer causing reel freezing and app crashes
    // Timer.periodic(const Duration(seconds: 30), (timer) {
    //   _updateMemoryUsage();
    //   _performMaintenanceCleanup();
    // });
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'totalCreated': _totalControllersCreated.value,
      'totalDisposed': _totalControllersDisposed.value,
      'currentActive': _currentActiveCount.value,
      'estimatedMemoryMB': _memoryUsageMB.value,
      'maxAllowed': maxActiveControllers,
      'memoryEfficiency': _totalControllersDisposed.value /
          (_totalControllersCreated.value
              .clamp(1, double.infinity)),
    };
  }

  /// Emergency cleanup method (can be called externally)
  void emergencyCleanup() {
    // COMMENTED OUT: External emergency cleanup causing crashes
    // Loggers.warning('🚨 External emergency cleanup requested');
    // _performEmergencyCleanup();
  }

  @override
  void onClose() {
    // Cancel all timers
    _disposalTimers.values
        .forEach((timer) => timer.cancel());

    // Dispose all controllers
    disposeAllControllers(
        reason: 'VideoMemoryManager closing');

    super.onClose();
  }
}
