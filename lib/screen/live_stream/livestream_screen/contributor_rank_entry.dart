import 'package:shortzz/model/livestream/app_user.dart';

/// One contributor's position in THIS LIVE session's "Contributor Ranking".
///
/// Unlike [LiveRankEntry] (the global DAILY ranking of hosts, aggregated in
/// Firestore at `live_rankings/{yyyy-MM-dd}/hosts/{hostId}`), this entry is
/// derived purely on-device from the gift comments already streamed for this
/// room (`livestreams/{roomID}/comments` where `comment_type == GIFT`) — see
/// `LivestreamScreenController.contributorRanking`. It resets naturally every
/// time a new LIVE session (new roomID) starts.
class ContributorRankEntry {
  final int userId;
  final int coins;
  final int gifts;
  final AppUser? user;

  const ContributorRankEntry({
    required this.userId,
    required this.coins,
    required this.gifts,
    this.user,
  });
}
