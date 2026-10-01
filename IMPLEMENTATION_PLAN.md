# LIVE PK Battle — Implementation Plan

Builds on `PROJECT_ANALYSIS.md`, now updated with direct, read-only VPS inspection (Laravel 10 + MySQL confirmed, no Redis/queue/broadcasting installed, a real race condition found in `sendGift`). Phases A–F below are Flutter+Firestore only and need no backend changes. Phase G is the one backend-touching item, kept separate and optional because it edits a live production server and needs its own explicit go-ahead.

## Explicitly out of scope, and why

- **A real push backend (Reverb/Soketi), Redis, a queue worker**: confirmed not installed on the VPS. Standing these up is new infrastructure on a live production box, not a config change — disproportionate to this feature and out of scope unless separately requested.
- **New Laravel battle/scoring endpoints**: technically possible now (Laravel+MySQL confirmed reachable), but deliberately not part of this pass — see the recommendation in `PROJECT_ANALYSIS.md` §5. Firestore remains the real-time layer.
- **Admin panel integration**: no admin-facing code was found in the Laravel app's routes during inspection. If a separate admin frontend exists elsewhere, battle-terminate there is out of reach from here.
- **Literal `battle:*` socket event names**: the spec's event list maps directly onto Firestore field changes already being listened for (e.g. `battle:started` ≈ `battleType` snapshot transitioning to `running`). I will document this mapping rather than build parallel, redundant plumbing.

## Phase A — Configurable gift-tier battle scoring

**Problem**: today 1 coin = 1 battle point, unconditionally, because `Gift.coinPrice` is the only numeric field and there's no points/multiplier concept anywhere.

**Plan**: add a local (Flutter-side) battle gift-tier table, same pattern already used for `local_deepar_filters.dart` — a const list the admin can't edit remotely (no backend access), but that gives real, distinct scoring:

```dart
class BattleGiftTier {
  final String id;          // matches a real backend Gift.id once configured there
  final String label;       // "Rose", "Heart", "Coffee", "Galaxy"
  final String icon;        // bundled asset, the 4 generated icons
  final int points;         // 1 / 5 / 10 / 1000
}
```
Scoring changes from "coins spent" to "sum of `points` for each battle gift received," computed the same place it is today (`updateUserStateToFirestore`'s battle-coin increment), just looked up through this table instead of using `coinPrice` directly. Falls back to 1:1 coin-to-point for any gift not in the table, so nothing breaks for gifts not yet mapped.

**Files touched**: new `lib/config/gifts/battle_gift_tiers.dart`, `livestream_screen_controller.dart` (scoring lookup only), 4 new assets already generated (`assets/gifts/battle_tiers/`).

## Phase B — Persisted battle history

**Problem**: a battle's outcome is computed for one render and discarded the moment the host dismisses the result.

**Plan**: on battle end (both the natural end-of-timer path and manual Stop), write one immutable document to a new Firestore collection `battle_history/{battleId}` **before** the existing reset logic runs — containing both host ids, final scores, winner/draw, duration, round count, and start/end timestamps. `battleId` = `'${roomA}_${roomB}_${battleCreatedAt.millisecondsSinceEpoch}'`, giving a stable, collision-resistant id without needing a server to mint one. Add a read-only "Battle History" screen under the existing profile area, querying this collection filtered to `hostIds array-contains myUserId`, showing wins/losses/draws/win-rate (computed client-side from the same documents, not a separate aggregate — correct at this data scale, revisit only if history grows very large).

**Files touched**: `livestream_screen_controller.dart` (write call added to both end paths), new `lib/model/livestream/battle_result.dart`, new `lib/screen/profile_screen/battle_history_screen.dart` (+ controller).

## Phase C — Rematch

**Plan**: add `rematchRequestedBy`/`rematchAccepted` fields to the existing per-room battle fields (same pattern as the invite flow already uses). When a battle ends, show "Rematch" alongside the existing dismiss button; tapping writes `rematchRequestedBy: myUserId` to the opponent's room; the opponent's existing `listenLiveStreamData` listener (already running) shows an accept/decline dialog, reusing `_showIncomingBattleInviteDialog`'s pattern; accepting calls the same `acceptBattleInvite`-style batch write with a **new** `battleCreatedAt`, resetting round/score state for a clean new match while Phase B's history record of the *previous* match is already safely persisted.

**Files touched**: `livestream_screen_controller.dart` only (new methods alongside the existing invite-handling ones), `battle_view.dart`/`party_battle_view.dart` (one new button).

## Phase D — Disconnect/reconnect handling

**Problem**: `opponentLiveDocListener` currently does nothing if the opponent's room vanishes mid-battle.

**Plan**: when that listener sees the opponent doc deleted or its `type` leave `battle` unexpectedly (not via our own reset), start a 15-second local grace-period timer (matches the spec's suggestion) showing a "Opponent reconnecting…" banner instead of silently hanging; if the opponent doc reappears as `battle` within that window, resume normally; if not, auto-run the existing end-and-reset path with a `battleEndReason: 'opponent_disconnected'` field added to the Phase B history record, so this is distinguishable from a normal timer-expiry end later.

**Files touched**: `livestream_screen_controller.dart`, `battle_view.dart`/`party_battle_view.dart` (one new banner widget).

## Phase E — Close the obvious race conditions within Firestore's own guarantees

- Battle-coin increments already use `FieldValue.increment`, which is atomic at the Firestore level — no change needed there.
- Invite accept already uses a batch write — no change needed there.
- Add a Firestore **transaction** around `sendBattleInvite` that checks the target's `pendingBattleInviteFromId` is currently null before writing (closes the "two simultaneous invites" race the spec calls out), and around invite-accept to confirm the invite is still the same one the UI is responding to (closes a stale-dialog-accepted-late race).
- Add a real, enforced invite expiry: store `battleInviteSentAt`; the UI dialog already auto-dismisses locally, but the inviter's side should also clear `pendingBattleInviteFromId` itself after the configured window via the same transaction pattern, so a late accept can't resurrect an expired invite.

**Files touched**: `livestream_screen_controller.dart` only.

## Phase F — Tests

Flutter/Dart unit tests are genuinely runnable in this repo (`flutter test`) and will cover what doesn't need a device or a second account:
- Battle gift-tier point lookup (Phase A) — pure function, trivially testable.
- Winner/draw calculation given scores (pure function already in `battle_view.dart`, worth extracting to a testable top-level function if not already one).
- Round-baseline subtraction math.
- Battle-history document shape/serialization (Phase B model).

**What will not be covered by automated tests, and why**: invitation accept/decline against a live Firestore instance, countdown synchronization across two real devices, concurrent gift transactions against the real Laravel wallet, and server-restart recovery all require either a Firestore emulator setup (not currently in this repo — would be a separate, sizeable addition) or two live devices/accounts, consistent with every other LIVE feature's testing limitation this session. I will flag each such case honestly in the final summary rather than claim coverage that doesn't exist.

## Phase G — Fix the `sendGift` race condition (backend, explicit sign-off required)

**Not part of A–F's scope** — this edits live Laravel code on a production VPS that's actively serving real traffic, which is categorically different from editing this Flutter repo. Only to be done if explicitly confirmed, as its own reviewed change, separately from everything else.

**What's wrong** (`app/Http/Controllers/WalletController.php:568-604`, verified by reading it directly): the balance check and both users' wallet updates are three separate, unguarded statements — no `DB::transaction()`, no `lockForUpdate()`. Two concurrent `sendGift` calls from the same account can both read the pre-deduction balance, both pass the `<` check, and both deduct — a real double-spend, not hypothetical.

**Proposed fix** (small, surgical, same method signature and response shape — no API contract change):
```php
DB::transaction(function () use ($request, $user, $gift, $dataUser) {
    $lockedUser = User::where('id', $user->id)->lockForUpdate()->first();
    if ($lockedUser->coin_wallet < $gift->coin_price) {
        throw new InsufficientBalanceException();
    }
    $lockedUser->decrement('coin_wallet', $gift->coin_price);
    $lockedUser->increment('coin_gifted_lifetime', $gift->coin_price);
    User::where('id', $dataUser->id)->lockForUpdate()->increment('coin_wallet', $gift->coin_price);
    User::where('id', $dataUser->id)->increment('coin_collected_lifetime', $gift->coin_price);
});
```
(exact exception handling to match the existing `GlobalFunction::sendSimpleResponse` pattern). This closes the double-spend path without touching routes, request/response shape, or anything Flutter-side.

**What this does not do**: add an idempotency key column (a slightly larger change — new migration, new column, client needs to generate and send a key) or a transaction ledger table (bigger still). Both are reasonable follow-ups but are separate asks from "stop the double-spend," which the above fixes on its own.

**Rollback plan if approved**: single git commit on the Laravel repo (or direct file edit on the VPS with a `.bak` copy kept, if that repo isn't under version control there — needs checking at approval time), PHP-FPM reload only (no downtime, no schema change).

## Verification approach (per phase, matching this session's established pattern)

1. `flutter analyze` after each Flutter phase, confirm the 323-issue baseline is unchanged.
2. Build + install on the `toptap2` emulator, confirm no crash launching and reaching the relevant screen.
3. Where the feature requires an active two-sided battle (most of Phases B–D), state plainly that on-device confirmation needs two live accounts and was not possible here, same as this session's standing limitation — code-reviewed correctness only.
4. Commit each phase separately with an honest message about what was and wasn't verified.
5. Phase G (if approved) gets tested with a `sendGift` call against the live VPS from this session before/after the change, plus a concurrent-request test (fire two simultaneous requests, confirm only one succeeds when balance covers exactly one), not just a code read.

## Order of work

A → B → C → D → E → F, then G separately once explicitly confirmed. Each phase is small enough to stop after if priorities change; A (scoring) and B (history) deliver the most visible value first and have no dependency on the others.
