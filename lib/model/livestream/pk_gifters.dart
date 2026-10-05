import 'package:shortzz/config/gifts/battle_gift_tiers.dart';
import 'package:shortzz/model/livestream/livestream_comment.dart';
import 'package:shortzz/model/livestream/pk_eligibility.dart';

/// One viewer's standing on a team's top-gifters leaderboard for the
/// current PK match.
class GifterRank {
  final int senderId;
  final int points;

  const GifterRank({required this.senderId, required this.points});
}

/// Ranks viewers who gifted a team's members during the current match —
/// the row of avatars TikTok shows under the arena, ranked closest-to-
/// center outward, with empty seats for whatever is left of [limit].
///
/// Gift comments are keyed by `id`, which is a millisecond timestamp (see
/// LivestreamScreenController._sendCommentToFirestore), so comparing it to
/// [battleCreatedAt] scopes this to gifts sent during the current match
/// without needing a separate field or local snapshot — it works the same
/// way independently on the host's, a co-host's, or any viewer's device.
List<GifterRank> topGiftersForTeam({
  required List<LivestreamComment> comments,
  required List<int> teamMemberIds,
  required int? battleCreatedAt,
  List<int>? eligibleGiftIds,
  int limit = 3,
}) {
  if (battleCreatedAt == null || teamMemberIds.isEmpty) return const [];
  final totals = <int, int>{};
  for (final comment in comments) {
    if (comment.commentType != LivestreamCommentType.gift) continue;
    if ((comment.id ?? 0) < battleCreatedAt) continue;
    final receiverId = comment.receiverId;
    if (receiverId == null || !teamMemberIds.contains(receiverId)) continue;
    final senderId = comment.senderId;
    if (senderId == null) continue;
    if (!giftCountsForPk(comment.giftId, eligibleGiftIds)) continue;
    final points = battlePointsForGift(comment.giftId,
        fallbackCoins: comment.gift?.coinPrice ?? 0);
    totals[senderId] = (totals[senderId] ?? 0) + points;
  }
  final ranked = totals.entries
      .map((entry) => GifterRank(senderId: entry.key, points: entry.value))
      .toList()
    ..sort((a, b) => b.points.compareTo(a.points));
  return ranked.take(limit).toList();
}
