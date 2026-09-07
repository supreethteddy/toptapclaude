# TopTap Feature Status Report

Source: `TopTap Correction List Final.docx` (extracted to `docx_text.txt`)

Purpose: For every referenced item in the doc, indicate whether the feature is working (Yes / No / Partial / Needs Clarification), provide a brief explanation, and point to the relevant code files. Use this report for verification and prioritization.

---

## A. LIVE STREAMING INTERFACE

- L-01 — Live guest join requests
  - Working?: Yes
  - Explanation: Requests tab lists incoming join requests; host can Accept/Refuse.
  - Files: `lib/screen/live_stream/livestream_screen/widget/members_sheet.dart`, `lib/screen/live_stream/livestream_screen/livestream_screen_controller.dart`

- L-02 — Goal feature position
  - Working?: Partial
  - Explanation: Goal widget exists but is placed below header, not inside the top toolbar as requested.
  - Files: `lib/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart`

- L-03 — Likes received location
  - Working?: No
  - Explanation: Like count still displays next to host name; not moved to bottom.
  - Files: `lib/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart`

- L-04 — Ranking display
  - Working?: No
  - Explanation: No ranking/host-rank UI found in the live header.
  - Files: (none found) — requires implementation.

- L-05 — Members: Co-hosts tab
  - Working?: Yes
  - Explanation: Co-hosts tab present and populated from `coHostList`.
  - Files: `lib/screen/live_stream/livestream_screen/widget/members_sheet.dart`

- L-06 — Members: Invited tab
  - Working?: Yes
  - Explanation: Invited tab exists with Invite/Cancel actions.
  - Files: `lib/screen/live_stream/livestream_screen/widget/members_sheet.dart`

- L-07 — Members: Audience tab removal
  - Working?: No (Not compliant)
  - Explanation: Audience tab still present in members sheet; doc requests its removal.
  - Files: `lib/screen/live_stream/livestream_screen/widget/members_sheet.dart`

- L-08 — Members: Requests tab
  - Working?: Yes
  - Explanation: Requests tab lists incoming requests and action buttons.
  - Files: `lib/screen/live_stream/livestream_screen/widget/members_sheet.dart`, `livestream_screen_controller.dart`

- L-09 — End stream popup (Cancel label)
  - Working?: Yes
  - Explanation: Stop dialog uses `LKey.cancel.tr` for negative button.
  - Files: `lib/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart`

- L-10 — Feed live indicator (blinking red ring)
  - Working?: No
  - Explanation: No feed/profile live indicator found in feed/reel widgets.
  - Files: (none found) — UI addition required.

- L-11 — Live call feature
  - Working?: Partial / Needs clarification
  - Explanation: Call-related controls and methods exist (`onVideoRequestSend`, `acceptJoinRequest`, `publishCoHostStream`), but testers reported call options not fully working. Requires runtime verification and logs.
  - Files: `lib/screen/live_stream/livestream_screen/livestream_screen_controller.dart`, `view/live_stream_bottom_view.dart`, `audience/widget/live_stream_join_sheet.dart`

- L-12 — PK Game (Battle)
  - Working?: Partial
  - Explanation: Battle/PK flow exists (`startBattle()`, `BattleView`), but UI labels use "Battle"; testers might not recognize it as "PK Game".
  - Files: `lib/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart`, `view/battle_view.dart`

- L-13 — Guest call
  - Working?: Partial / Needs clarification
  - Explanation: Invite/request -> promote to co-host exists, but no explicitly labeled "guest call" one-tap flow; behavior depends on publish path.
  - Files: `lib/screen/live_stream/livestream_screen/widget/members_sheet.dart`, `livestream_screen_controller.dart`

- L-14 — Live module full verification
  - Working?: Needs Clarification / Pending
  - Explanation: Many features present but must be tested end-to-end; some UI placements differ from doc.
  - Files: multiple live module files referenced above.

---

## B. HELP CENTER & SUPPORT

- H-01 — Send Email
  - Working?: Yes
  - Explanation: `mailto:` flow implemented; depends on device email app.
  - Files: `lib/screen/help_center_screen/help_center_controller.dart`

- H-02 — Call Support
  - Working?: Yes
  - Explanation: `tel:` flow implemented; depends on device dialer.
  - Files: `lib/screen/help_center_screen/help_center_controller.dart`

- H-03 — Live Chat Support
  - Working?: No (Placeholder)
  - Explanation: Currently shows a snackbar; not connected to chat backend or SDK.
  - Files: `lib/screen/help_center_screen/help_center_controller.dart`

- H-04 — Community Forum
  - Working?: Yes (external)
  - Explanation: Opens external forum URL in browser; SSO/deep-link not implemented.
  - Files: `lib/screen/help_center_screen/help_center_controller.dart`

---

## C. GIF SECTION

- G-01 — GIF / GIPHY search
  - Working?: Partial
  - Explanation: GIF UI and controller exist; actual GIFs require a valid `giphyKey` in app settings. Without it, lists are empty.
  - Files: `lib/screen/gif_sheet/gif_sheet.dart`, `lib/screen/gif_sheet/gif_sheet_controller.dart`, `model/general/settings_model.dart`

---

## D. UPLOAD / CREATE REEL SECTION

- U-01 — Create Reel caption mention (@)
  - Working?: Yes
  - Explanation: `DetectableTextField` mention autocomplete implemented in Create Feed/Reel screens.
  - Files: `lib/screen/create_feed_screen/widget/feed_text_field_view.dart`, `create_feed_screen_controller.dart`

- U-01b — Video Upload screen caption mention
  - Working?: No
  - Explanation: `VideoUploadScreen` uses a plain caption field without mention support.
  - Files: `lib/screen/video_upload_screen/video_upload_screen.dart`, `video_upload_controller.dart`

- U-02 — HD recording / upload/playback
  - Working?: Partial / No explicit support
  - Explanation: Camera/editor has default `defaultVideoQuality = 720` in config; upload controller sends files as-is. No explicit HD upload flag. Server limits unknown.
  - Files: `lib/common/config/app_config.dart`, `lib/common/functions/media_picker_helper.dart`, `lib/screen/video_upload_screen/video_upload_controller.dart`

---

## E. LANGUAGE SETTINGS

- S-01 — Language options
  - Working?: Yes (via settings)
  - Explanation: Languages load from settings; if settings absent, 3 demo languages seeded.
  - Files: `lib/screen/select_language_screen/select_language_screen_controller.dart`, `select_language_screen.dart`

- S-02 — Language display with flag
  - Working?: No
  - Explanation: UI shows language title/subtitle only; no flag icons present.
  - Files: `lib/screen/select_language_screen/select_language_screen.dart`

---

## Notes & Next Steps
- Items marked "Partial" or "Needs Clarification" require either product decisions (labeling, UX) or runtime verification with logs (call/guest flows).
- I can (pick one):
  - Implement non-ambiguous fixes (remove Audience tab, add flags, add mention UI to `VideoUploadScreen`), or
  - Add logging and small instrumentation to help debug call/guest failures.

If you want this file adjusted (more/less detail), tell me and I will update it.