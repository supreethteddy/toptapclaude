# TopTap — Detailed Responses & Clarifications

Source: `TopTap Correction List Final.docx` (extracted to `docx_text.txt`)

Purpose: provide precise answers and evidence for items that require clarification in the correction list. For each reference I include: the doc requirement, what I observed in code, file references, and the explicit clarification or action needed from the development/product team.

---

## How to read this file
- "Doc text" is copied/summarized from the original list.
- "Observed" is what we found in the codebase (file paths provided).
- "Evidence" shows the exact files and short code pointers where behavior exists or is missing.
- "Clarify / Action" lists what we need from the team (data, decision, or implementation instructions).

---

## L-11 — Live: Call feature
- Doc text: "The call options are not working properly. Full call functionality inside live to be checked and fixed." (L-11)

- Observed:
  - Live UI contains video-request and co-host audio/video toggles.
  - Relevant controller methods: `acceptJoinRequest`, `onVideoRequestSend`, `toggleVideo`, `coHostVideoToggle`, `coHostAudioToggle`, `publishCoHostStream` in
    - `lib/screen/live_stream/livestream_screen/livestream_screen_controller.dart`
  - UI controls appear in
    - `lib/screen/live_stream/livestream_screen/view/live_stream_bottom_view.dart`
    - `lib/screen/live_stream/livestream_screen/audience/widget/live_stream_join_sheet.dart`

- Evidence (quick pointers):
  - `LivestreamScreenController.acceptJoinRequest` contains logic to accept/convert audience -> co-host.
  - `publishCoHostStream(int streamId)` updates Firestore `coHostIds` and triggers feed updates.
  - `onVideoRequestSend(Livestream liveData)` toggles video-request flag.

- Clarify / Action required:
  1. Are there backend/Firestore security rules or server-side listeners required to complete a co-host publish that may be failing in production? Provide the server-side contract or sample documents expected by `coHostIds` updates.
  2. Provide a reproducible failure case: does the call fail at (a) sending request, (b) accepting request, or (c) during the actual media stream publish (Zego/Agora)?
  3. If the issue is media (Zego/Agora), share logs or network traces; otherwise the code paths above show where to add additional logging/try/catch.

---

## L-12 — Live: PK Game (Battle)
- Doc text: "Babul is unable to locate the PK Game feature anywhere in the live interface. Development team to confirm whether PK Game has been built. If built, specify exactly where and how it is accessed. If not built, it must be implemented as per the original requirement." (L-12)

- Observed:
  - There is a "battle" flow in the live module implemented as `BattleType` and `startBattle()` logic.
  - A Start Battle icon/button is present in
    - `lib/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart` (the flash icon triggers `controller.startBattle()`)
  - Supporting files: `lib/screen/live_stream/livestream_screen/view/battle_view.dart` and `battle_start_countdown_overlay.dart` implement the battle UI elements.

- Evidence:
  - `LivestreamScreenController.startBattle()` updates liveData with `battleType: BattleType.waiting` and sets `battleDuration`.
  - `BattleView` shows UI for the battle state including coins and a timer.

- Clarify / Action required:
  1. Confirm whether the product labeling should show the feature as "PK Game" or "Battle" — the code uses "Battle" icons/strings. If "PK Game" is required, assets/text must be updated.
  2. Confirm expected access path: should the start-battle button be visible to all hosts, or only under specific conditions? Current code shows the Start Battle button only when `canStartBattle` is true (co-host exists and other conditions). Confirm whether that matches product expectation.
  3. If testers cannot locate PK in the app despite code being present, provide exact repro steps and the account roles/state expected (co-host present, sufficient viewers, etc.). We can then add an explicit entry point or help tooltip in UI.

---

## L-13 — Live: Guest call
- Doc text: "Babul is unable to locate the guest call feature in the live interface. Development team to confirm whether it has been built and where it is accessed, or whether it is still pending." (L-13)

- Observed:
  - Guest invite/request flows exist in `members_sheet.dart` and `LivestreamScreenController.onInvite` and `acceptJoinRequest`.
  - The join sheet and member profile actions allow inviting audience members and accepting requested users into co-host.
  - There is no single explicit "guest call" button labeled as such; the flow is via requests/invites and co-host publish.

- Evidence:
  - `members_sheet.dart`: Requests / Invited / Co-hosts tabs with Accept/Refuse/Invite UI.
  - `livestream_screen_controller.dart`: `onInvite`, `acceptJoinRequest`, and `publishCoHostStream` implement state transitions.

- Clarify / Action required:
  1. Define "guest call" exact UX: Should a viewer tap a "Join as guest" button on the feed to send a request, and should hosts have a single-screen guest-call interface to accept and directly place their video into the stream? Or is the current tab-based acceptance sufficient?
  2. If the expected UX is a one-tap host "Accept guest" that immediately initiates the guest media publish, confirm whether `publishCoHostStream` is sufficient or if additional signaling is required (e.g., sending a push notification + WebRTC offer). If the latter, provide the signaling design.

---

## H-03 — Help Center: Live Chat Support
- Doc text: "Babul needs to know how this feature is intended to work — is it connected to a live agent, a chatbot, or a ticket system?" (H-03)

- Observed:
  - Current code shows `openLiveChat()` in `lib/screen/help_center_screen/help_center_controller.dart` which only shows a snackbar: "Connecting you to our support team..." — no further chat integration.

- Evidence:
  - `help_center_controller.dart` -> `openLiveChat()` uses `Get.snackbar` only.

- Clarify / Action required:
  1. Decide the intended support integration: choose one of the following and provide integration details:
     - Live agent chat (e.g., Zendesk, Intercom) — provide SDK keys and required screens.
     - Chatbot (rule-based or AI) — provide API endpoints and fallback flow.
     - Ticketing system (open a create-ticket screen and send to backend) — provide API spec for ticket creation.
  2. If product wants a simple in-app chat window, specify whether it should open a new screen or an external app link; we will implement accordingly.

---

## H-04 — Help Center: Community Forum
- Doc text: "Babul needs an explanation of what this section is and how it is meant to be used." (H-04)

- Observed:
  - `openForum()` launches `https://community.TapTop.com` via external browser using `_launchURL` in `help_center_controller.dart`.

- Evidence:
  - Single function `openForum()` calls `_launchURL('https://community.TapTop.com')`.

- Clarify / Action required:
  1. Confirm whether this forum is fully external (i.e., not single sign-on) or should be integrated (SAML/SSO or deep link with token). If SSO is needed, provide the token-exchange URL and method.
  2. Confirm whether the app needs an in-app webview instead of opening the external browser.

---

## U-02 — Video Quality: HD recording and upload
- Doc text: "Videos shot in-app and uploaded are only standard quality, not HD. Babul asks whether HD recording and HD upload/playback can be enabled. Development team to confirm what is currently supported and what is possible." (U-02)

- Observed:
  - The code base uses camera/microphone and uses `MediaPickerHelper` / `camera_edit_screen` and `video_compress` for processing.
  - `common/config/app_config.dart` contains `defaultVideoQuality = 720` which suggests default HD-ish but not 1080p.
  - `camera_edit_screen_controller` falls back to compressing video if server rejects (comments show fallback to lower quality).
  - `video_upload_controller` uploads files as-is; no explicit parameter for `quality=HD` is passed to server.

- Evidence:
  - `lib/common/config/app_config.dart` has `defaultVideoQuality = 720`.
  - `lib/common/functions/media_picker_helper.dart` uses `video_compress` and calls `compressVideoLowQuality` in fallback paths.

- Clarify / Action required:
  1. Decide target support level: 720p (current default), 1080p, or higher.
  2. Confirm server-side upload limits (max file size) and whether the server accepts larger HD files without extra parameters. Provide server upload policy or max file sizes.
  3. If higher-quality recording is required, we need to: (a) set camera capture target to 1080p, (b) avoid compressing/downsizing in the pipeline, and (c) ensure server supports larger uploads and CDN playback. Share server constraints so we can implement and test.

---

## G-01 — GIF (GIPHY) search
- Doc text: "GIF section is empty — no GIFs are loading in the GIPHY search area." (G-01)

- Observed:
  - `GifSheetController` fetches trending/search GIFs using `GiphyService.instance.trending/search(apiKey: setting?.giphyKey ?? '')`.
  - If `setting?.giphyKey` is missing or empty, the controller passes an empty key to the service and likely receives empty results.

- Evidence:
  - `lib/screen/gif_sheet/gif_sheet_controller.dart` lines show `String apiKey = setting?.giphyKey ?? '';` before API calls.
  - `SessionManager.instance.getSettings()` determines `setting` which comes from app settings API.

- Clarify / Action required:
  1. Confirm whether a valid GIPHY API key is set in the server settings or admin panel. If not, we must add it.
  2. If the app should gracefully show a message when no key is present, confirm the desired text or fallback (e.g., hide GIF button or show a message).

---

## L-07 — Members: Audience tab removal request
- Doc text: "The Audience tab inside Members is not required — remove it. The audience count/list opened from the eye icon on the top right is sufficient." (L-07)

- Observed:
  - `members_sheet.dart` includes `CustomTabSwitcher` items: Requests, Audience, Invited, Co-hosts.

- Evidence:
  - The `CustomTabSwitcher(items: [LKey.requests.tr, LKey.audience.tr, LKey.invited.tr, LKey.coHosts.tr])` call in `members_sheet.dart` shows the tab remains.

- Clarify / Action required:
  1. Confirm the desired final tab list for hosts (Requests / Invited / Co-hosts) and whether the Audience list should be accessible only via the eye icon.
  2. If confirmed, we will remove the Audience tab from `members_sheet.dart` and adjust tab indices and related search behavior.

---

## L-02 / L-03 (Goal and likes placement)
- Doc text: reposition UI elements: move Goal to top toolbar row (L-02) and move likes counter to bottom of live screen (L-03).

- Observed:
  - `LiveGoalProgressWidget` is currently rendered below the host header in `live_stream_host_top_view.dart`.
  - Like counter is part of the header row (username, heart icon, count).

- Evidence:
  - `LiveGoalProgressWidget(controller: controller)` is below the header row inside the same widget file.

- Clarify / Action required:
  1. Provide final pixel positioning or a mock image showing the exact desired placement (goal icon position in the top toolbar row and likes counter at the bottom). We can then implement layout changes across the host top view and the bottom overlay.

---

## Final notes and next steps
1. I created this file to document evidence and the specific clarifications we need from product/dev teams.
2. For items requiring external data (GIPHY key, server upload limits, SSO token for forum), please provide those values or indicate that we should read them from admin settings.
3. If you want, I can: (a) open a PR with UI fixes for the non-ambiguous items (remove Audience tab, change Cancel button text already OK), or (b) implement developer-side logging for call/guest flows to help debug failing scenarios.

---

If you approve, I will:
- update the `TopTap_Correction_Audit_Report.md` to link to the exact clarification sections in this file,
- implement straightforward UI fixes (e.g., remove Audience tab), and
- add logging instrumentation to `LivestreamScreenController` to capture failures in `acceptJoinRequest` / `publishCoHostStream`.

Please tell me which items you'd like me to act on now, and provide any missing keys or server constraints if available.