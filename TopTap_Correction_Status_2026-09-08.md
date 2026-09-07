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
| L-11 | Call options inside LIVE not working | **Done (re-tested)** | Full guest flow re-tested end to end: viewer taps **Guest** → host sees request → Accept → viewer's camera/mic publish → split-screen. Host mic / camera / flip / comments toggles verified. Viewer-side "Guest" button added at the bottom so the option is easy to find. |
| L-12 | PK Game — built? where? | **Answered + Done** | PK was built (it was labelled "Battle" and only appeared as a small flash icon once a co-host existed, which is why it could not be found). There is now a permanent **PK** button in the host control row. Flow: host accepts/invites a guest → tap PK → 10 s countdown → 1-minute PK with gift coins scored per side → winner shown. If no guest is on screen the button explains what is missing. |
| L-13 | Guest call — built? where? | **Answered + Done** | Built. Viewer: **Guest** button (bottom bar) or the camera icon at the top → "request sent". Host: **Guests** sheet → Requests → Accept, or Invited → Invite a viewer (viewer gets a Join / Cancel popup). Accepted guests go live in split screen with the host. |
| L-14 | Full re-verification of the live module | **Done** | Host start, viewer join, comments, likes, gifts, goal, guest request/accept/invite, co-host controls, PK, end stream and viewer exit re-tested on two Android emulators. |

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

## Items that need the client / server side

1. Deploy the backend change and run the SQL in `Toptap_backend/DEPLOY_NOTES_2026-09-08.md` (adds support phone / support username / community URL settings).
2. In the admin panel: GIPHY API key, real support email, support phone, and create the `toptapsupport` user account.
3. Google Play upload key: a new upload keystore was generated for this build. If the app is already on Play under a different key, that key must be used instead.
