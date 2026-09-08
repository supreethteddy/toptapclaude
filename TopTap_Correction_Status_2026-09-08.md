# TopTap — Correction List Status (build 2.1.0, 8 Sep 2026)

Reply to *TopTap Correction & Change Request List* (Beyond AI Tech LLP / Babul, 06 Aug 2026).
Every reference has a written status as the document requires. "Done" means implemented in
source and verified on an Android emulator by the development team; the client verifies on the
next APK.

## A. Live streaming interface

| Ref | Change | Status | What was done |
|-----|--------|--------|---------------|
| L-01 | Guest join requests listed one by one, host taps Accept | **Done** | Requests arrive live in **Guests > Requests** (people icon at the bottom-left, and the new "add guest" button in the host control row, both show a red count badge). Each row has Accept / Refuse. Requests also appear inline in the comment stream with Accept / Refuse. |
| L-02 | Goal feature moved to the top toolbar row | **Done** | Goal is now a compact chip (flag + progress bar + 0/100) inside the top toolbar, between the host name and the viewer count. |
| L-03 | Likes received moved to the bottom | **Done** | Heart + count now sits at the bottom-left of the LIVE screen (host and audience). Removed from the host name row. |
| L-04 | Daily ranking + host's own rank next to host name | **Done** | "#N Today" chip next to the host name. Tap it to open **Daily Ranking** (top hosts by coins received today, host highlighted). Ranking updates instantly when a gift is sent. |
| L-05 | Members > Co-hosts tab shows current co-hosts | **Done** | Co-hosts tab lists everyone currently on screen with mic / camera / remove controls. |
| L-06 | Members > Invited shows guests to collect/add | **Done** | Invited tab shows the pending invites on top and, below it, **"Viewers you can invite"** with an Invite button per viewer, so guests are collected from one place. |
| L-07 | Remove the Audience tab | **Done** | Tabs are now Requests / Invited / Co-hosts. The audience list opens from the eye icon (viewer count) at the top-right. |
| L-08 | Requests tab lists incoming join requests | **Done** | Same list as L-01; live-updating, searchable, with the pending count in the tab title. |
| L-09 | Blank button in End Stream popup must read Cancel | **Done** | Button now reads "Cancel" with a visible grey background (it had a white-on-white label in the old APK). |
| L-10 | Blinking red ring on profile picture when the user is live | **Done** | Red blinking ring + "LIVE" pill on avatars in the reels sidebar, feed posts, the stories row and profile pages. Tapping the ring opens that LIVE as a viewer. |
| L-11 | Call options inside LIVE not working | **Done (re-tested)** | The "call" options are the guest (co-host) flow. Re-tested: viewer taps **Guest** → host sees the request (badge + inline Accept/Refuse) → Accept → viewer becomes a co-host and appears under Co-hosts with mic / camera / remove controls. Host mic, camera, flip and comment toggles verified. A viewer-side **Guest** button was added at the bottom so the option is easy to find. Real camera/audio publishing between two phones must be confirmed on physical devices (emulators cannot stream real video). |
| L-12 | PK Game — built? where? | **Answered + Done** | PK was built (it was labelled "Battle" and only appeared as a small flash icon once a co-host existed, which is why it could not be found). There is now a permanent **PK** button in the host control row. Flow: host accepts/invites a guest → tap PK → 10 s countdown → 1-minute PK with gift coins scored per side → winner shown. If no guest is on screen the button explains what is missing. |
| L-13 | Guest call — built? where? | **Answered + Done** | Built. Viewer: **Guest** button (bottom bar) or the camera icon at the top → "request sent". Host: **Guests** sheet → Requests → Accept, or Invited → Invite a viewer (viewer gets a Join / Cancel popup). Accepted guests go live in split screen with the host. |
| L-14 | Full re-verification of the live module | **Done** | Verified on an Android 15 emulator: go live, title edit, goal chip, viewer join, guest request → Accept → co-host (Requests / Invited / Co-hosts tabs), PK button gating, daily ranking updates, likes counter, end-stream popup and summary, viewer screen with Guest button and exit. Real two-phone video/PK playback still needs a physical-device pass because emulators cannot publish real camera video. |

## B. Help Center & support

| Ref | Change | Status | What was done |
|-----|--------|--------|---------------|
| H-01 | Send Email not working | **Done** | Opens the mail app with the support address from admin > Settings > *Help Email*, subject and the user's username pre-filled. If no mail app exists the address is copied. **Action for client:** replace the placeholder `1236@shortzz.com` with the real support email in the admin panel. |
| H-02 | Call Support not working | **Done** | The old build dialled a placeholder (`+1-800-TAPTOP`). Call Support now dials the number entered in admin > Settings > *Support Phone* and is hidden until a number is set. **Action for client:** enter the support phone number (backend update needed, see deploy notes). |
| H-03 | How does Live Chat Support work? | **Answered + Done** | It is an in-app chat with the official **TopTap Support** account (username `toptapsupport`, changeable in admin). Support staff log in with that account and answer from the normal Messages screen — no external chatbot or ticket tool. Until the account exists, the app offers email instead. |
| H-04 | What is the Community Forum? | **Answered** | It is a link to an external community website. No forum exists yet, so the entry is hidden until a URL is entered in admin > Settings > *Community Forum URL*. FAQ now opens an in-app FAQ instead of a dead link. |

## C. GIF section

| Ref | Change | Status | What was done |
|-----|--------|--------|---------------|
| G-01 | GIFs not loading | **Done (needs key)** | Two causes fixed: (1) the app read the GIPHY key before settings were downloaded, so it was always empty on first launch; (2) no GIPHY key is saved in the admin panel. The app now reads the key correctly and shows "GIFs are not available — key not configured" instead of an empty grid. **Action for client:** enter a GIPHY API key in admin > Settings > GIF. |

## D. Upload / create reel

| Ref | Change | Status | What was done |
|-----|--------|--------|---------------|
| U-01 | "@" in caption shows no user list | **Done** | The video upload caption now shows user suggestions while typing "@", tapping inserts the @username and the mentioned users are tagged (and notified) on the post. |
| U-02 | HD recording / upload / playback | **Answered + Done** | Camera capture raised from 720p to **1080p (Full HD)**. Uploads are sent at original quality (server compression flag is off). Playback uses the uploaded file, so 1080p content plays in 1080p; the Playback settings screen lets users choose Auto / quality. Recording above 1080p (4K) is possible on request but doubles upload size. |

## E. Language settings

| Ref | Change | Status | What was done |
|-----|--------|--------|---------------|
| S-01 | Expand the language list | **Done** | The server already provides 18 active languages (Arabic, Chinese, Danish, English, French, German, Greek, Hindi, Indonesian, Italian, Japanese, Korean, Norwegian, Polish, Portuguese, Russian, Spanish, Turkish). The old APK showed only three because it was built before the languages were added. More languages can be added from admin > Languages (CSV upload). |
| S-02 | Country flag per language | **Done** | Each language row now shows its flag. |

## Answers to the questions section

- **L-12** PK Game: yes, built. Host control row → **PK** button (needs one guest/co-host on screen).
- **L-13** Guest call: yes, built. Viewer → **Guest** button; host → **Guests** sheet (Requests / Invited).
- **H-03** Live Chat Support: in-app chat with the support user account; answered by staff from the app.
- **H-04** Community Forum: external link, hidden until a forum URL is configured.
- **U-02** HD: recording is now 1080p; upload and playback keep that quality.

## Extra defects found and fixed during verification (not in the client list)

| # | Problem | Fix |
|---|---------|-----|
| X-1 | **Android 15 blocker:** the profile-photo crop screen drew its toolbar under the status bar, so the Confirm / Cancel buttons could not be tapped. New users must add a photo to finish their profile, so they were stuck. | Cropper theme opts out of edge-to-edge enforcement; buttons are reachable again. |
| X-2 | App could sit on the splash screen forever when the settings download failed (network not ready at cold start). | Splash retries with back-off and falls back to cached settings. |
| X-3 | "Go Live" refused with "need 1 follower" even after the user gained followers, because it used the follower count cached at login. | Follower count is refreshed from the server before the check. |
| X-4 | Snackbar messages were lower-cased ("pk", "live"). | Messages keep their casing. |
| X-5 | Empty LIVE list showed a leftover placeholder text overlapping the message. | Removed. |
| X-6 | Live-stream tabs still referenced an Audience tab index after removal. | Tab indices rebuilt. |

## Things the client should know before launch (not fixable from the app alone)

1. **DeepAR watermark.** Every video recorded in the app carries a "DeepAR.ai" watermark because the DeepAR licence key in the admin panel is a free/trial key. A paid DeepAR licence removes it.
2. **Firestore is open.** The Firebase database that powers LIVE, chat and rankings accepts reads and writes from anyone without login. Security rules should be tightened before a public launch (we can supply rules).
3. **AdMob is on test ad units** (the consent dialog says "Publisher Test Ads"). Real ad unit IDs are needed in the admin panel.
4. **RevenueCat key is a placeholder** ("Invalid API Key" in logs), so in-app coin purchases through RevenueCat will not work until the real key is set in `const_res.dart`.
5. **Profile completion is mandatory** (name, username, bio, email, phone and photo) before a new user can use the app. This is stricter than TikTok and will cost sign-ups; we recommend making bio/phone/photo optional.
6. The backend is served over plain HTTP (`http://194.164.151.34`). Google Play accepts it (cleartext is enabled in the manifest), but HTTPS is strongly recommended.

## Items that need the client / server side

1. Deploy the backend change and run the SQL in `Toptap_backend/DEPLOY_NOTES_2026-09-08.md` (adds support phone / support username / community URL settings).
2. In the admin panel: GIPHY API key, real support email, support phone, and create the `toptapsupport` user account.
3. Google Play upload key: a new upload keystore was generated for this build. If the app is already on Play under a different key, that key must be used instead.
