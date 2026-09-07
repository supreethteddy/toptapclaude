import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';

class LiveGoalProgressWidget extends StatefulWidget {
  final LivestreamScreenController controller;

  /// Compact = single-line chip that fits inside the LIVE top toolbar row.
  final bool compact;

  const LiveGoalProgressWidget(
      {super.key, required this.controller, this.compact = false});

  @override
  State<LiveGoalProgressWidget> createState() => _LiveGoalProgressWidgetState();
}

class _LiveGoalProgressWidgetState extends State<LiveGoalProgressWidget> {
  Timer? _durationRefreshTimer;

  @override
  void initState() {
    super.initState();
    _durationRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted &&
            widget.controller.liveData.value.liveGoalType == 'duration') {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _durationRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Livestream stream = widget.controller.liveData.value;

      if (stream.hasLiveGoal != true) return const SizedBox.shrink();

      String goalType = stream.liveGoalType ?? '';
      int targetAmount = stream.liveGoalTargetAmount ?? 0;
      int currentAmount = _getCurrentAmount(stream, goalType);
      double progress = targetAmount > 0
          ? (currentAmount / targetAmount).clamp(0.0, 1.0)
          : 0.0;
      bool isCompleted = currentAmount >= targetAmount && targetAmount > 0;

      if (widget.compact) {
        final accent = isCompleted ? Colors.green : Colors.orange;
        return Tooltip(
          message: stream.liveGoalTitle ?? 'Live Goal',
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isCompleted ? Icons.check_circle : Icons.flag,
                    color: accent, size: 13),
                const SizedBox(width: 4),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$currentAmount/$targetAmount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 2), // Reduced vertical margin from 5 to 2
        padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6), // Reduced vertical padding from 8 to 6
        decoration: BoxDecoration(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted
                ? Colors.green.withValues(alpha: 0.5)
                : Colors.orange.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.flag,
              color: isCompleted ? Colors.green : Colors.orange,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.liveGoalTitle ?? 'Live Goal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1), // Reduced from 2 to 1 pixel
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Container(
                          height: 4,
                          constraints:
                              const BoxConstraints(minWidth: 60, maxWidth: 100),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    isCompleted ? Colors.green : Colors.orange,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$currentAmount/$targetAmount',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  int _getCurrentAmount(Livestream stream, String goalType) {
    switch (goalType) {
      case 'followers':
        // This would need to be tracked separately based on new followers gained during stream
        return stream.liveGoalCurrentAmount ?? 0;
      case 'likes':
        return stream.likeCount ?? 0;
      case 'gifts':
        // This would need to be tracked separately based on gifts received during stream
        return stream.liveGoalCurrentAmount ?? 0;
      case 'duration':
        // Calculate minutes since stream started
        if (stream.createdAt != null) {
          int currentTime = DateTime.now().millisecondsSinceEpoch;
          int duration =
              ((currentTime - stream.createdAt!) / (1000 * 60)).floor();
          return duration;
        }
        return 0;
      default:
        return stream.liveGoalCurrentAmount ?? 0;
    }
  }
}
