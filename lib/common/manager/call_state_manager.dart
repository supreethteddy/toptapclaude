import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/model/user_model/user_model.dart';

/// Call State Manager
/// Handles call history, state tracking, and persistent storage of call information
class CallStateManager {
  CallStateManager._();
  static final CallStateManager instance =
      CallStateManager._();

  // Call history storage
  final RxList<CallHistoryItem> _callHistory =
      <CallHistoryItem>[].obs;
  final RxMap<String, CallState> _activeCallStates =
      <String, CallState>{}.obs;

  // SharedPreferences for persistence
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Storage keys
  static const String _callHistoryKey = 'call_history';
  static const String _maxHistoryItems =
      'max_history_items';
  static const int _defaultMaxHistory = 100;

  // Getters
  List<CallHistoryItem> get callHistory =>
      _callHistory.toList();
  Map<String, CallState> get activeCallStates =>
      Map.from(_activeCallStates);
  bool get isInitialized => _isInitialized;

  /// Initialize the call state manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Loggers.info('📋 Initializing Call State Manager...');

      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Load call history from storage
      await _loadCallHistory();

      _isInitialized = true;
      Loggers.success(
          '📋 ✅ Call State Manager initialized successfully');
    } catch (e) {
      Loggers.error(
          '📋 ❌ Failed to initialize Call State Manager: $e');
      rethrow;
    }
  }

  /// Load call history from persistent storage
  Future<void> _loadCallHistory() async {
    try {
      final historyJson =
          _prefs?.getStringList(_callHistoryKey) ?? [];

      _callHistory.clear();
      for (final itemJson in historyJson) {
        try {
          final item = CallHistoryItem.fromJson(
              jsonDecode(itemJson));
          _callHistory.add(item);
        } catch (e) {
          Loggers.warning(
              '📋 Failed to parse call history item: $e');
        }
      }

      // Sort by timestamp (newest first)
      _callHistory.sort(
          (a, b) => b.timestamp.compareTo(a.timestamp));

      Loggers.info(
          '📋 Loaded ${_callHistory.length} call history items');
    } catch (e) {
      Loggers.error('📋 ❌ Failed to load call history: $e');
    }
  }

  /// Save call history to persistent storage
  Future<void> _saveCallHistory() async {
    try {
      if (_prefs == null) return;

      // Limit history size
      final maxItems = _prefs!.getInt(_maxHistoryItems) ??
          _defaultMaxHistory;
      if (_callHistory.length > maxItems) {
        _callHistory.removeRange(
            maxItems, _callHistory.length);
      }

      // Convert to JSON strings
      final historyJson = _callHistory
          .map((item) => jsonEncode(item.toJson()))
          .toList();

      await _prefs!
          .setStringList(_callHistoryKey, historyJson);
      Loggers.info(
          '📋 💾 Saved ${_callHistory.length} call history items');
    } catch (e) {
      Loggers.error('📋 ❌ Failed to save call history: $e');
    }
  }

  /// Record incoming call
  Future<void> recordIncomingCall({
    required String callId,
    required User caller,
    required String channelId,
    required bool isVideoCall,
    String? token,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      final callState = CallState(
        callId: callId,
        caller: caller,
        channelId: channelId,
        isVideoCall: isVideoCall,
        token: token,
        state: CallStatus.incoming,
        timestamp: DateTime.now(),
      );

      _activeCallStates[callId] = callState;

      Loggers.info(
          '📋 📞 Recorded incoming call: $callId from ${caller.fullname}');
    } catch (e) {
      Loggers.error(
          '📋 ❌ Failed to record incoming call: $e');
    }
  }

  /// Update call state
  Future<void> updateCallState(
      String callId, CallStatus status,
      {String? reason}) async {
    try {
      final callState = _activeCallStates[callId];
      if (callState == null) {
        Loggers.warning(
            '📋 ⚠️ No active call state found for ID: $callId');
        return;
      }

      // Update state
      final updatedState = callState.copyWith(
        state: status,
        endTime: status.isEndState ? DateTime.now() : null,
        endReason: reason,
      );

      _activeCallStates[callId] = updatedState;

      // If call ended, move to history
      if (status.isEndState) {
        await _moveCallToHistory(callId, updatedState);
      }

      Loggers.info(
          '📋 📝 Updated call state: $callId -> $status${reason != null ? ' ($reason)' : ''}');
    } catch (e) {
      Loggers.error('📋 ❌ Failed to update call state: $e');
    }
  }

  /// Move call to history and cleanup active state
  Future<void> _moveCallToHistory(
      String callId, CallState callState) async {
    try {
      // Create history item
      final historyItem = CallHistoryItem(
        callId: callId,
        caller: callState.caller,
        isVideoCall: callState.isVideoCall,
        status: callState.state,
        timestamp: callState.timestamp,
        duration: callState.duration,
        endReason: callState.endReason,
      );

      // Add to history (at beginning for newest first)
      _callHistory.insert(0, historyItem);

      // Remove from active calls
      _activeCallStates.remove(callId);

      // Save to storage
      await _saveCallHistory();

      Loggers.info('📋 📚 Moved call to history: $callId');
    } catch (e) {
      Loggers.error(
          '📋 ❌ Failed to move call to history: $e');
    }
  }

  /// Accept call
  Future<void> acceptCall(String callId) async {
    await updateCallState(callId, CallStatus.accepted);
  }

  /// Decline call
  Future<void> declineCall(String callId,
      {String reason = 'user_declined'}) async {
    await updateCallState(callId, CallStatus.declined,
        reason: reason);
  }

  /// End call
  Future<void> endCall(String callId,
      {String reason = 'user_ended'}) async {
    await updateCallState(callId, CallStatus.ended,
        reason: reason);
  }

  /// Mark call as missed
  Future<void> missCall(String callId,
      {String reason = 'no_answer'}) async {
    await updateCallState(callId, CallStatus.missed,
        reason: reason);
  }

  /// Get call history filtered by type
  List<CallHistoryItem> getCallHistory({
    CallHistoryFilter? filter,
    int? limit,
  }) {
    var history = _callHistory.toList();

    // Apply filter
    if (filter != null) {
      switch (filter) {
        case CallHistoryFilter.missed:
          history = history
              .where((item) =>
                  item.status == CallStatus.missed)
              .toList();
          break;
        case CallHistoryFilter.incoming:
          history = history
              .where((item) =>
                  item.status == CallStatus.accepted ||
                  item.status == CallStatus.declined ||
                  item.status == CallStatus.missed)
              .toList();
          break;
        case CallHistoryFilter.video:
          history = history
              .where((item) => item.isVideoCall)
              .toList();
          break;
        case CallHistoryFilter.audio:
          history = history
              .where((item) => !item.isVideoCall)
              .toList();
          break;
      }
    }

    // Apply limit
    if (limit != null && limit > 0) {
      history = history.take(limit).toList();
    }

    return history;
  }

  /// Get missed calls count
  int getMissedCallsCount() {
    return _callHistory
        .where((item) => item.status == CallStatus.missed)
        .length;
  }

  /// Clear all call history
  Future<void> clearCallHistory() async {
    try {
      _callHistory.clear();
      await _saveCallHistory();
      Loggers.info('📋 🗑️ Cleared all call history');
    } catch (e) {
      Loggers.error(
          '📋 ❌ Failed to clear call history: $e');
    }
  }

  /// Delete specific call from history
  Future<void> deleteCallFromHistory(String callId) async {
    try {
      _callHistory
          .removeWhere((item) => item.callId == callId);
      await _saveCallHistory();
      Loggers.info(
          '📋 🗑️ Deleted call from history: $callId');
    } catch (e) {
      Loggers.error(
          '📋 ❌ Failed to delete call from history: $e');
    }
  }

  /// Set maximum history items
  Future<void> setMaxHistoryItems(int max) async {
    try {
      await _prefs?.setInt(_maxHistoryItems, max);

      // Trim current history if needed
      if (_callHistory.length > max) {
        _callHistory.removeRange(max, _callHistory.length);
        await _saveCallHistory();
      }

      Loggers.info('📋 ⚙️ Set max history items to: $max');
    } catch (e) {
      Loggers.error(
          '📋 ❌ Failed to set max history items: $e');
    }
  }

  /// Get active call by ID
  CallState? getActiveCall(String callId) {
    return _activeCallStates[callId];
  }

  /// Get all active calls
  List<CallState> getActiveCalls() {
    return _activeCallStates.values.toList();
  }

  /// Check if there are any active calls
  bool hasActiveCalls() {
    return _activeCallStates.isNotEmpty;
  }

  /// Export call history as JSON (for backup/sync)
  Map<String, dynamic> exportCallHistory() {
    return {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'callHistory': _callHistory
          .map((item) => item.toJson())
          .toList(),
    };
  }

  /// Import call history from JSON (for backup/sync)
  Future<void> importCallHistory(
      Map<String, dynamic> data) async {
    try {
      final historyData = data['callHistory'] as List?;
      if (historyData == null) return;

      _callHistory.clear();
      for (final itemData in historyData) {
        try {
          final item = CallHistoryItem.fromJson(itemData);
          _callHistory.add(item);
        } catch (e) {
          Loggers.warning(
              '📋 Failed to import call history item: $e');
        }
      }

      // Sort by timestamp
      _callHistory.sort(
          (a, b) => b.timestamp.compareTo(a.timestamp));

      await _saveCallHistory();
      Loggers.info(
          '📋 📥 Imported ${_callHistory.length} call history items');
    } catch (e) {
      Loggers.error(
          '📋 ❌ Failed to import call history: $e');
    }
  }

  /// Dispose and cleanup
  Future<void> dispose() async {
    try {
      // Save any pending changes
      await _saveCallHistory();

      // Clear active states
      _activeCallStates.clear();

      _isInitialized = false;
      Loggers.info('📋 🗑️ Call State Manager disposed');
    } catch (e) {
      Loggers.error(
          '📋 ❌ Error disposing Call State Manager: $e');
    }
  }
}

/// Call status enumeration
enum CallStatus {
  incoming,
  accepted,
  declined,
  ended,
  missed;

  bool get isEndState =>
      this == declined || this == ended || this == missed;
}

/// Call history filter options
enum CallHistoryFilter {
  missed,
  incoming,
  video,
  audio,
}

/// Call state model for active calls
class CallState {
  final String callId;
  final User caller;
  final String channelId;
  final bool isVideoCall;
  final String? token;
  final CallStatus state;
  final DateTime timestamp;
  final DateTime? endTime;
  final String? endReason;

  CallState({
    required this.callId,
    required this.caller,
    required this.channelId,
    required this.isVideoCall,
    this.token,
    required this.state,
    required this.timestamp,
    this.endTime,
    this.endReason,
  });

  Duration get duration {
    if (endTime == null) return Duration.zero;
    return endTime!.difference(timestamp);
  }

  CallState copyWith({
    CallStatus? state,
    DateTime? endTime,
    String? endReason,
  }) {
    return CallState(
      callId: callId,
      caller: caller,
      channelId: channelId,
      isVideoCall: isVideoCall,
      token: token,
      state: state ?? this.state,
      timestamp: timestamp,
      endTime: endTime ?? this.endTime,
      endReason: endReason ?? this.endReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'callId': callId,
        'caller': caller.toJson(),
        'channelId': channelId,
        'isVideoCall': isVideoCall,
        'token': token,
        'state': state.name,
        'timestamp': timestamp.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'endReason': endReason,
      };

  factory CallState.fromJson(Map<String, dynamic> json) =>
      CallState(
        callId: json['callId'] ?? '',
        caller: User.fromJson(json['caller'] ?? {}),
        channelId: json['channelId'] ?? '',
        isVideoCall: json['isVideoCall'] ?? false,
        token: json['token'],
        state: CallStatus.values.firstWhere(
          (s) => s.name == json['state'],
          orElse: () => CallStatus.incoming,
        ),
        timestamp:
            DateTime.tryParse(json['timestamp'] ?? '') ??
                DateTime.now(),
        endTime: json['endTime'] != null
            ? DateTime.tryParse(json['endTime'])
            : null,
        endReason: json['endReason'],
      );
}

/// Call history item model for completed calls
class CallHistoryItem {
  final String callId;
  final User caller;
  final bool isVideoCall;
  final CallStatus status;
  final DateTime timestamp;
  final Duration duration;
  final String? endReason;

  CallHistoryItem({
    required this.callId,
    required this.caller,
    required this.isVideoCall,
    required this.status,
    required this.timestamp,
    this.duration = Duration.zero,
    this.endReason,
  });

  String get displayDuration {
    if (duration.inSeconds == 0) return '';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get statusText {
    switch (status) {
      case CallStatus.accepted:
        return 'Accepted';
      case CallStatus.declined:
        return 'Declined';
      case CallStatus.ended:
        return 'Ended';
      case CallStatus.missed:
        return 'Missed';
      case CallStatus.incoming:
        return 'Incoming';
    }
  }

  Map<String, dynamic> toJson() => {
        'callId': callId,
        'caller': caller.toJson(),
        'isVideoCall': isVideoCall,
        'status': status.name,
        'timestamp': timestamp.toIso8601String(),
        'duration': duration.inSeconds,
        'endReason': endReason,
      };

  factory CallHistoryItem.fromJson(
          Map<String, dynamic> json) =>
      CallHistoryItem(
        callId: json['callId'] ?? '',
        caller: User.fromJson(json['caller'] ?? {}),
        isVideoCall: json['isVideoCall'] ?? false,
        status: CallStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => CallStatus.missed,
        ),
        timestamp:
            DateTime.tryParse(json['timestamp'] ?? '') ??
                DateTime.now(),
        duration: Duration(seconds: json['duration'] ?? 0),
        endReason: json['endReason'],
      );
}
