import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toptap/common/manager/logger.dart';

enum CallSignalStatus {
  pending,
  accepted,
  declined,
  ended,
  missed,
  failed;

  static CallSignalStatus? fromValue(Object? value) {
    final text = value?.toString();
    for (final status in CallSignalStatus.values) {
      if (status.name == text) return status;
    }
    return null;
  }
}

/// Lightweight Firestore signalling used alongside Agora. Agora transports
/// audio/video; this document tells both phones whether a call was answered,
/// declined or ended before the remote Agora user joined.
class CallSignalingService {
  CallSignalingService._();

  static final instance = CallSignalingService._();
  static const _collection = 'call_sessions';

  DocumentReference<Map<String, dynamic>> _ref(String callId) =>
      FirebaseFirestore.instance.collection(_collection).doc(callId);

  Future<void> createCall({
    required String callId,
    required int callerId,
    required int calleeId,
    required bool isVideo,
  }) async {
    await _ref(callId).set({
      'call_id': callId,
      'caller_id': callerId,
      'callee_id': calleeId,
      'is_video': isVideo,
      'status': CallSignalStatus.pending.name,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStatus(
    String callId,
    CallSignalStatus status, {
    String? reason,
  }) async {
    if (callId.trim().isEmpty) return;
    try {
      await _ref(callId).set({
        'call_id': callId,
        'status': status.name,
        if (reason != null) 'reason': reason,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      Loggers.error('Call signalling update failed: $e');
      rethrow;
    }
  }

  Stream<CallSignalStatus?> watch(String callId) =>
      _ref(callId).snapshots().map(
          (snapshot) => CallSignalStatus.fromValue(snapshot.data()?['status']));
}
