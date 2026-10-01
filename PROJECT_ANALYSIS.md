# TopTap LIVE PK Battle — Project Analysis

Date: 2026-10-01
Scope: assessing the existing codebase against a full "production-grade LIVE PK Battle system" spec (server-authoritative scoring, WebSocket contracts, Redis, DB migrations, idempotent wallet transactions, admin panel, full test pyramid).

## 1. Tech stack (verified, not assumed)

- **Client**: Flutter (Dart), GetX for state/DI/routing.
- **Real-time data**: Firebase Firestore, read/written directly from the Flutter client via `snapshots()` listeners. There is no custom real-time server.
- **Video/audio**: ZegoExpressEngine (native Android/iOS SDK). Not LiveKit.
- **Core CRUD backend**: a separate Laravel 10 REST API (PHP 8.3.6), reached over plain HTTP from Flutter (`ApiService`/`WebService`). Not in this Flutter repo — **inspected directly via SSH on 2026-10-01** (Hostinger VPS, read-only, no changes made), findings below.
- **Confirmed absent from this Flutter repository** (full-repo search): any Node.js/Express server, `socket.io` (client or server), a Redis client, `.sql`/migration files, or `.env` files describing backend infrastructure.

### Backend VPS inspection (read-only, 2026-10-01)

Connected via a pre-provisioned SSH key (`claude-code-toptap-vps-setup`) to the VPS at the same IP this app's API already calls (`194.164.151.34`). No files were modified, no services restarted. Findings:

- **Stack**: nginx (port 80 only, no TLS) → PHP 8.3-FPM → Laravel 10 at `/var/www/toptap` (`laravel/framework: ^10.0`). MySQL 8 running locally (port 3306, localhost-only). This is the real backend for `WebService.apiURL` — confirmed by nginx's `root /var/www/toptap/public` + Laravel's standard front-controller rewrite.
- **No Redis, no queue, no broadcasting, in practice**: `.env` has `CACHE_DRIVER=file`, `SESSION_DRIVER=file`, `QUEUE_CONNECTION=sync`, `BROADCAST_DRIVER=log`. `redis-server`/`redis-cli` are not even installed on the box (checked `which`, checked `systemctl list-units --all`). `REDIS_HOST`/`REDIS_PORT`/`REDIS_PASSWORD` exist in `.env` but are **unused Laravel-boilerplate leftovers** — nothing reads them. No `queue:work` process running, no Supervisor, no crontab. Every Laravel request is handled synchronously, start to finish, with no background job system at all.
- **Database**: `tbl_gifts` confirmed to have exactly **one row** (id 18, coin_price 1) and exactly the columns `id, coin_price, image, created_at, updated_at` — matching the Flutter `Gift` model exactly. No points/multiplier column exists in the real schema either. Full table list (40 tables) has **no** live-stream, battle, or wallet-transaction-ledger table of any kind — `tbl_users.coin_wallet` is a single mutable integer column, and gift sends only bump two lifetime-aggregate counters (`coin_gifted_lifetime`/`coin_collected_lifetime`) alongside it. There is no transaction/audit log table. Only 1 Laravel migration file exists in the repo (schema was bulk-imported from `shortzz_database.sql`, not migration-managed) — adding new tables the "Laravel way" means writing fresh migrations against a DB that otherwise isn't migration-tracked.
- **`sendGift` (`app/Http/Controllers/WalletController.php:568-604`), read in full** — this is the one and only place coins move. Verified behavior:
  - Explicitly **blocks self-gifting** server-side (`if($user->id == $dataUser->id) return ...'you can not gift yourself!'`) — ruled out self-gift as a way to test battle gifting solo.
  - Balance check (`$user->coin_wallet < $gift->coin_price`) and both users' `->save()` calls are **not wrapped in a DB transaction and use no row locking** (`lockForUpdate()`). This is a genuine, pre-existing TOCTOU race: two concurrent `sendGift` requests from the same account can both read the pre-deduction balance, both pass the check, and both deduct — a real double-spend path, not a hypothetical one.
  - No idempotency key of any kind — a client-retried request (e.g. after a timeout where the first request actually succeeded) is processed again in full.
  - No gift event / transaction record is written anywhere — only the two wallet balances and two lifetime counters change, plus a notification row.

**Conclusion**: the spec's "never deduct twice / use DB transactions / idempotency keys" concerns are not hypothetical for this app — they describe a real gap in the live `sendGift` endpoint today, independent of PK Battle. This matters for scope: PK Battle scoring is built entirely on top of gifts that already flow through this one endpoint, so any double-spend risk in `sendGift` is a pre-existing risk to the whole app's economy, not something PK Battle introduces.

## 2. What already exists: PK Battle (built earlier this session, "Phase 4")

This is not a greenfield feature. A working cross-room PK Battle already ships. Verified by direct code reading (file:line references below).

### State machine
Defined in `lib/model/livestream/livestream.dart`:
```dart
enum LivestreamType { livestream, battle, dummy }          // line 234
enum BattleType { initiate, waiting, running, end }          // line 249
```
Four states, no `paused`/`reconnecting`/`cancelled`/`interrupted`. This is the entire state machine — smaller than the 11-state machine in the request spec.

### Invite flow
`livestream_screen_controller.dart`:
- `sendBattleInvite()` (line 2134): writes one field, `pendingBattleInviteFromId`, onto the target host's own `liveStreams/{hostId}` document. No separate invite document, no stored expiry/TTL.
- `_showIncomingBattleInviteDialog` (2147): driven by the existing `listenLiveStreamData` snapshot listener (1169–1174), which already runs on every live screen.
- `acceptBattleInvite()` (2187): one Firestore **batch** write to both rooms — sets `type: BATTLE`, `battleType: WAITING`, `battleCreatedAt`, `opponentRoomId` (each room points at the other host's user id — rooms are keyed by host id, there is no separate room-id concept), round counters, `firstGiftBonusClaimed: false`.
- Opponent discovery (`find_opponent_screen_controller.dart`, 60 lines): candidates = live rooms where `type != battle`, `isDummyLive != 1`, and a heartbeat timestamp is <60s old. No pagination, no server-side "already invited" guard (UI-local `Set` only).

### Rounds
Fixed at `AppRes.battleTotalRounds = 2` (`app_res.dart:56`). Round-local score is a **client-side subtraction trick**: `roundBaselineRed`/`roundBaselineBlue` (local `RxInt`s) snapshot cumulative coins at round start; the UI shows `cumulative - baseline`. This is not persisted — a client restart mid-round loses the baseline and would show the wrong number.

### Countdown & timer
Both are "timestamp-anchored but client-enforced": `battleCreatedAt` is the one value written once to Firestore; every device computes `battleCreatedAt + battleStartInSecond(10s)` or `+ battleDurationInMinutes(1min)` and runs its own local `Timer.periodic(100ms)` against that. When a client's local timer hits zero, **that client itself** writes the state transition (`battleType: running`, then later `end`). Two clients racing to write the same value is harmless today, but this is not server-authoritative in the sense the spec means — there is no single arbiter, and an offline/backgrounded client simply never fires its half (mitigated only by the other room's identical timer also covering it).

### Scoring
No dedicated score/event collection. Battle score **is** the sum of gift coin values: `updateUserStateToFirestore` increments `totalBattleCoin`/`currentBattleCoin` via `FieldValue.increment` whenever a gift lands with `GiftType.battle`. A "first gift bonus" transaction (`_claimFirstGiftBonusIfEligible`, 1509–1540) multiplies the first qualifying gift's value inside a Firestore transaction. There is no gift-to-points multiplier table — 1 coin always equals 1 battle point, because the `Gift` model (`settings_model.dart:451-485`) has only `id`, `coinPrice`, `image` — **no points/multiplier field exists today, anywhere, client or (as far as the model shape shows) backend.**

### Winner / end
`_endCrossRoomBattleType()` flips both rooms' `battleType` to `END`. Winner is computed **at display time only** (`battle_view.dart:399`, `isRedWin = red >= blue`) and is never written anywhere. `endCrossRoomBattleAndReset()` (called when the host dismisses the result) resets both rooms back to `initiate`/`livestream` and **zeroes everything** — round wins, opponent link, all of it. Once a battle ends and is dismissed, there is no record it ever happened.

### Explicitly absent (confirmed by full-repo grep)
- **Rematch**: zero references anywhere in the repo.
- **Battle history / analytics**: no persisted battle result, ever.
- **Disconnect/reconnect state**: `opponentLiveDocListener` only checks `if (!snapshot.exists) return` — if an opponent's room disappears mid-battle, nothing auto-ends this side's battle or shows a "reconnecting" state.
- **Admin terminate**: no admin battle controls found.

### Battle UI
`battle_view.dart` (738 lines) and `party_battle_view.dart` (300 lines) already render: split video feeds, a racing progress bar, center VS badge, round-win pills, a countdown/timer label, gift-combo badge, first-gift-bonus banner, and a post-battle winner tag with a "Next Round" button. Chat and the gift button come from the already-shared `LiveStreamBottomView`, overlaid regardless of battle state. **Visually this is already close to the requested TikTok PK layout.** The gap is behavioral/data (persistence, authority, reconnection), not visual.

### Gift send / wallet
`send_gift_sheet_controller.dart`: the Flutter-side balance check (line 71, `coinPrice > myUser.value?.coinWallet`) is against a **locally cached** wallet value, then calls the Laravel `sendGift` REST endpoint. The actual coin deduction happens server-side — **confirmed via direct VPS inspection (see §VPS inspection below) to have no DB transaction, no row locking, and no idempotency key**, a real double-spend race, not a hypothetical one. On the Flutter side, there is also no cross-screen lock preventing two rapid gift sends from both passing the stale local check before either response returns (`_isSendingGift` is scoped to one sheet instance only) — so the risk exists on both ends independently.

## 3. Gap analysis against the requested spec

| Spec section | Status |
|---|---|
| §1 Creator discovery | **Exists** (`find_opponent_screen`), lacks pagination/server-side de-dup of invites |
| §2 Invitations | **Partially exists** — works, but no persisted invite doc, no configurable/enforced expiry (10s hardcoded, not 15s, and not actually timed out server-side — it's just a dialog the UI shows) |
| §3 Co-host connection | **Exists** via Zego, real split-screen, real video — not simulated |
| §4 Battle configuration | **Partially exists** — duration/rounds are app-wide constants (`AppRes`), not configurable per-battle or in a config table |
| §5 Countdown/start | **Exists**, not server-authoritative (see above) |
| §6 Battle arena UI | **Exists**, visually close to spec already |
| §7 Viewer participation | **Exists** — gifting/liking/chat already work during battles |
| §8 Wallet/gifts | **Partially exists, with a confirmed real gap** — `sendGift` deducts server-side but with no DB transaction/row-lock and no idempotency key (verified by reading the live code, see §VPS inspection above); no dedicated battle-scoring-event ledger anywhere |
| §9 Scoring engine | **Partially exists** — real but simplistic (1 coin = 1 point, no multiplier table in Flutter or the DB, no Redis — confirmed not installed on the VPS — no event ledger/reconciliation) |
| §10 Socket events | **Does not exist, and can't cheaply start existing** — confirmed `BROADCAST_DRIVER=log` (broadcasts go to a log file, nowhere real), no queue worker, no Redis. A real push layer would mean standing up Reverb/Soketi or similar on the VPS — a genuine new piece of infrastructure, not a config flip. Firestore listeners remain the only real-time mechanism available without that work |
| §11 Timer management | **Partially exists** — timestamp-anchored but not server-enforced |
| §12 State machine | **Partially exists** — 4 states vs. the requested 11; no enforced-transition layer, any client can currently write any battle field |
| §13 Disconnection handling | **Mostly absent** |
| §14 Battle result | **Absent** — computed transiently, never persisted |
| §15 Rematch | **Absent** |
| §16 Battle history/analytics | **Absent** |
| §17 Admin functionality | **Absent** (no admin module found in this repo, and no admin-facing code found in the Laravel app's routes either) |
| §18 DB/API design | **Confirmed buildable, with a caveat**: the VPS has Laravel + MySQL, so new tables/endpoints ARE technically possible now with explicit permission — but the existing schema isn't migration-tracked (only 1 migration file; the live DB was bulk-imported), so new work would need to introduce real migrations against a database that otherwise isn't managed that way |
| §19 Security/perf | **Confirmed gap, not hypothetical**: `sendGift`'s missing transaction/lock is a live double-spend risk today, independent of PK Battle. No rate limiting anywhere observed in `routes/api.php`'s gift/wallet section |
| §20 Testing | **Absent** — no battle-related tests exist today; Laravel's `phpunit.xml` exists but no battle/gift tests were found in `app/`/`tests/` |

## 4. Constraints for any implementation plan

1. **Backend access is now real, but narrow by the user's own instruction**: read-only VPS inspection only has been authorized so far. No backend/infrastructure changes happen until the user explicitly confirms which architecture to proceed with.
2. **No Redis, no queue, no broadcasting exist today**, and installing/configuring them is infrastructure work on a live production VPS — a meaningfully different ask than editing this Flutter repo, and one that needs its own explicit go-ahead given the blast radius (a shared, already-serving-real-traffic box).
3. **The `sendGift` race condition is real and pre-existing.** Fixing it (wrap in `DB::transaction()` + `lockForUpdate()`, add an idempotency key column) is a small, surgical, low-risk change — but it is still a production backend edit and needs explicit confirmation before I touch it.
4. **"Server-authoritative" has two honest options now**: (a) keep Firestore as the real-time layer and use Firestore transactions + `serverTimestamp()` for battle timing/state (same conclusion as before VPS access, still true — Firestore security rules would be the real enforcement layer and aren't in this repo to verify), or (b) add new Laravel endpoints for battle state/scoring and have Flutter poll or mirror them into Firestore for display — meaningfully more "textbook production," meaningfully more work, and it means Laravel and Firestore both need to agree on who owns truth for live battle state. I recommend (a) for this pass — see recommendation below — with the `sendGift` fix as the one Laravel-side change worth making regardless of which path is chosen, since it's a real bug independent of PK Battle.
5. **No automated e2e testing of the live multi-device flow is possible in this development environment** — standing limitation all session (no two real devices, no second live account with followers to test with). This is unchanged by VPS access — it's a client-testing limitation, not a backend one.

## 5. Recommendation

**Keep Firestore as the live-battle real-time layer.** Standing up a real push backend (Reverb/Soketi + Redis + queue workers) on this VPS to literally match the spec's socket-event vocabulary would be a significant new infrastructure project, disproportionate to the actual gap — the existing Firestore-based battle system already delivers real-time sync that works, and rebuilding it on a backend that currently has zero real-time infrastructure (no Redis, no queue, log-only broadcasting) is a rewrite, not an integration. The honest "production-grade" improvements that are proportionate to this app's actual architecture are: (a) fix the `sendGift` race condition in Laravel (real bug, small fix, needs explicit confirmation before I edit production backend code), and (b) build out `IMPLEMENTATION_PLAN.md`'s six phases on the Flutter+Firestore side (gift-tier scoring, persisted battle history, rematch, reconnect handling, transaction-guarded invite races, tests) — all of which are real, working, and don't require new VPS infrastructure.

If the user wants the fuller "textbook" architecture (new Laravel battle/scoring endpoints, a real push layer) instead, that's a materially larger, separately-scoped project on top of a live production server, and should be scoped and approved as such, not folded silently into this pass.
