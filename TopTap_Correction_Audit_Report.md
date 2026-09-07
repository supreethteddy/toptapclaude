# TopTap Correction Audit Report

Source: extracted from `d:\Newtoptap\docx_text.txt` (`TopTap Correction List Final.docx`)

## Purpose
This report maps each documented correction request to the current codebase status, with reference numbers, question details, explanation, and relevant file locations.

---

## Summary Table

| Ref | Area | Status | Notes |
| --- | --- | --- | --- |
| L-01 | Live guest join requests | Implemented | Requests tab exists in members sheet |
| L-02 | Live goal position | Partially implemented | Goal present but not in top toolbar |
| L-03 | Likes received location | Not implemented | Like count still next to host name |
| L-04 | Ranking display | Missing | No host ranking UI present |
| L-05 | Members co-hosts tab | Implemented | Co-hosts tab shows current co-hosts |
| L-06 | Members invited tab | Implemented | Invited list exists |
| L-07 | Members audience tab | Not compliant | Audience tab still present |
| L-08 | Members requests tab | Implemented | Request list works |
| L-09 | End stream popup | Implemented | Cancel label present |
| L-10 | Live feed indicator | Missing | No live red ring seen |
| L-11 | Live call feature | Partial | Call UI exists, requires functional verification |
| L-12 | PK Game | Present but unclear | Battle button exists, not clearly labeled PK |
| L-13 | Guest call | Partial | Guest invite exists, no clear guest call UI |
| L-14 | Live module verification | Pending | Full end-to-end test required |
| H-01 | Help Center email | Implemented | `mailto:` flow present |
| H-02 | Help Center call | Implemented | `tel:` flow present |
| H-03 | Help Chat | Placeholder | Only snackbar, not real chat |
| H-04 | Community forum | Implemented | External URL launch |
| G-01 | GIF GIPHY search | Implemented* | Needs valid `giphyKey` |
| U-01 | Caption mention | Implemented | Create/Reel screen only |
| U-02 | HD upload support | Not implemented | No explicit HD setting detected |
| S-01 | Language options | Implemented | Uses settings language list |
| S-02 | Language flags | Missing | No country flag icons shown |

---

## A. LIVE STREAMING INTERFACE

### L-01 Live – guest join requests
- **Doc requirement:** When viewers request to join live as a guest, their requests must appear as a list on this screen, one by one as they arrive. Host taps Accept against the person he wants to bring in. Currently this list is not displayed.
- **Current status:** Implemented.
- **Explanation:** `lib/screen/live_stream/livestream_screen/widget/members_sheet.dart` contains a `Requests` tab with a list of incoming join requests and Accept/Refuse actions.
- **Relevant code:** `MembersSheet` and `LivestreamScreenController.requestList`

### L-02 Live – Goal feature position
- **Doc requirement:** Move the Goal feature (flag icon with 0/100 progress bar) to the marked area at the top toolbar row.
- **Current status:** Partially implemented.
- **Explanation:** The goal widget is present in `lib/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart`, but it remains below the main header row rather than inside the top toolbar area.

### L-03 Live – Likes received
- **Doc requirement:** Move the likes received counter (heart with count next to host name) to the bottom of the live screen.
- **Current status:** Not implemented as requested.
- **Explanation:** The like counter is still shown next to the host name in `live_stream_host_top_view.dart`.

### L-04 Live – Ranking display
- **Doc requirement:** Daily ranking and the host's own current ranking must be displayed next to the host name / edit icon area.
- **Current status:** Missing.
- **Explanation:** No ranking UI element is present in the current live host header controls.

### L-05 Members – Co-hosts tab
- **Doc requirement:** Tapping this tab must show the co-hosts currently present in the live.
- **Current status:** Implemented.
- **Explanation:** `members_sheet.dart` includes a `Co-hosts` tab, and the `coHostList` is populated and displayed.

### L-06 Members – Invited tab
- **Doc requirement:** Tapping Invited must show people who want to come in as guests, so the host can collect and add guests from here.
- **Current status:** Implemented.
- **Explanation:** `members_sheet.dart` includes an `Invited` tab and shows invited users, with Cancel actions available.

### L-07 Members – Audience tab
- **Doc requirement:** The Audience tab inside Members is not required — remove it. The audience count/list opened from the eye icon on the top right is sufficient.
- **Current status:** Not compliant.
- **Explanation:** `members_sheet.dart` still includes an `Audience` tab as part of the host tab list.

### L-08 Members – Requests tab
- **Doc requirement:** This tab is for people sending a request to join the live. Must list incoming join requests correctly.
- **Current status:** Implemented.
- **Explanation:** The `Requests` tab in `members_sheet.dart` lists `controller.requestList`, which is updated from live user states.

### L-09 Live – End stream popup
- **Doc requirement:** The blank white button in the End This Stream confirmation popup has no label. It must read `Cancel`.
- **Current status:** Implemented.
- **Explanation:** In `lib/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart`, `StopLiveStreamSheet` uses `LKey.cancel.tr` for the negative button.

### L-10 Feed – Live indicator
- **Doc requirement:** When a user is live, their profile picture on the feed must show a blinking red ring/circle to indicate the live status.
- **Current status:** Missing.
- **Explanation:** No live-feed profile picture indicator or blinking red ring implementation was found in feed/reel/post profile widgets.

### L-11 Live – Call feature
- **Doc requirement:** The call options are not working properly. Full call functionality inside live to be checked and fixed.
- **Current status:** Partially implemented; further verification needed.
- **Explanation:** Live/video request controls exist through controller methods and UI buttons in the live module, but the document indicates the call flow is not fully working.

### L-12 Live – PK Game
- **Doc requirement:** PK Game feature must be located. If built, specify where and how it is accessed. If not built, it must be implemented.
- **Current status:** Present but not clearly labeled.
- **Explanation:** `live_stream_host_top_view.dart` includes a battle start button and `controller.startBattle()`. This appears to correspond to PK/Battle functionality.

### L-13 Live – Guest call
- **Doc requirement:** Confirm whether the guest call feature is built, and where it is accessed.
- **Current status:** Partially present but unclear.
- **Explanation:** Guest invite/join request flows exist, but there is no clearly labeled dedicated guest call button or entry point in the live interface.

### L-14 Live module – full verification
- **Doc requirement:** Retest every live module feature end-to-end and confirm all built features are present, visible, and working.
- **Current status:** Pending full test.
- **Explanation:** Many live features exist, but UI placement and exact requested behavior differ from the document.

---

## B. HELP CENTER & SUPPORT

### H-01 Help Center – Send Email
- **Doc requirement:** `Send Email` option is not working.
- **Current status:** Implemented.
- **Explanation:** `HelpCenterController.sendEmail()` constructs a `mailto:` URI and attempts to launch it.

### H-02 Help Center – Call Support
- **Doc requirement:** `Call Support` option is not working.
- **Current status:** Implemented.
- **Explanation:** `HelpCenterController.callSupport()` constructs a `tel:` URI and launches the dialer if available.

### H-03 Help Center – Live Chat Support
- **Doc requirement:** Babul needs to know how this feature is intended to work — live agent, chatbot, or ticket system?
- **Current status:** Placeholder only.
- **Explanation:** `HelpCenterController.openLiveChat()` currently shows a snackbar and does not open a real chat interface.

### H-04 Help Center – Community Forum
- **Doc requirement:** Explain what this section is and how it is meant to be used.
- **Current status:** Implemented as external link.
- **Explanation:** `openForum()` launches `https://community.TapTop.com` via external browser.

---

## C. GIF SECTION

### G-01 GIF – GIPHY search
- **Doc requirement:** GIF section is empty; no GIFs are loading in GIPHY search.
- **Current status:** Implemented, but dependent on GIPHY API key.
- **Explanation:** `lib/screen/gif_sheet/gif_sheet_controller.dart` fetches trending/search GIFs using `setting?.giphyKey`. If the key is absent or invalid, the list remains empty.

---

## D. UPLOAD / CREATE REEL SECTION

### U-01 Create Reel – Caption mention (@)
- **Doc requirement:** Typing `@` must bring up the user list for mention suggestions.
- **Current status:** Implemented for feed/reel creation.
- **Explanation:** `lib/screen/create_feed_screen/widget/feed_text_field_view.dart` uses `DetectableTextField`, and `CreateFeedScreen` displays mention autocomplete.

### U-01 Video Upload screen mention support
- **Doc requirement:** Mention suggestions must appear in caption entry.
- **Current status:** Missing in upload screen.
- **Explanation:** `lib/screen/video_upload_screen/video_upload_screen.dart` provides a plain caption field without mention autocomplete.

### U-02 Video quality – shoot & upload
- **Doc requirement:** Videos shot in-app and uploaded are only standard quality, not HD. Confirm whether HD recording/upload/playback can be enabled.
- **Current status:** Not explicitly supported.
- **Explanation:** `video_upload_controller.dart` does not configure HD quality. Video quality appears to depend on the source file and existing camera/editor behavior.

---

## E. LANGUAGE SETTINGS

### S-01 Language options
- **Doc requirement:** Only a few languages are currently available — expand the language list.
- **Current status:** Implemented from settings.
- **Explanation:** `select_language_screen_controller.dart` loads active languages from `SessionManager.instance.getSettings()?.languages`. If settings are absent, only 3 demo languages are seeded.

### S-02 Language display
- **Doc requirement:** Each language must display a country flag.
- **Current status:** Missing.
- **Explanation:** `select_language_screen.dart` shows language titles and subtitles only, with no flag icon.

---

## Questions from the document

### L-12 Has the PK Game been built? If yes, where is it accessed from in the live interface?
- **Answer:** PK/Battle appears to be built in `lib/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart` through the battle button and `controller.startBattle()`, but the interface does not label it clearly as PK Game.

### L-13 Has the guest call feature been built? If yes, where is it accessed from?
- **Answer:** Guest invite/join request flows exist, but there is no clearly labeled guest call button or dedicated guest call screen.

### H-03 How does Live Chat Support work in the app?
- **Answer:** It does not currently connect to a live agent. It only shows a snackbar message.

### H-04 What is the Community Forum section and how is it used?
- **Answer:** It launches an external forum URL (`https://community.TapTop.com`).

### U-02 Is HD recording and HD upload/playback supported? If not, can it be enabled?
- **Answer:** There is no explicit HD recording/upload setting in the current code. Upload relies on the existing video file, so HD support would require camera/editor-side quality control or explicit upload parameters.

---

## Recommended next actions
- Move the live goal widget into the top toolbar row and move likes counter to the live bottom area.
- Remove the `Audience` tab from `MembersSheet` and keep audience access via the eye icon.
- Add a visible live indicator (red ring) on feed profile pictures.
- Convert `Live Chat Support` from snackbar placeholder to a real chat flow or a clear support process.
- Add mention autocomplete to the video upload caption UI.
- Add flag icons to `SelectLanguageScreen` language rows.
- Confirm the PK and guest call flows with the development team and clarify UI labels.

---

## File locations referenced
- `lib/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart`
- `lib/screen/live_stream/livestream_screen/widget/members_sheet.dart`
- `lib/screen/help_center_screen/help_center_screen.dart`
- `lib/screen/help_center_screen/help_center_controller.dart`
- `lib/screen/gif_sheet/gif_sheet.dart`
- `lib/screen/gif_sheet/gif_sheet_controller.dart`
- `lib/screen/create_feed_screen/create_feed_screen.dart`
- `lib/screen/create_feed_screen/widget/feed_text_field_view.dart`
- `lib/screen/video_upload_screen/video_upload_screen.dart`
- `lib/screen/video_upload_screen/video_upload_controller.dart`
- `lib/screen/select_language_screen/select_language_screen.dart`
- `lib/screen/select_language_screen/select_language_screen_controller.dart`
