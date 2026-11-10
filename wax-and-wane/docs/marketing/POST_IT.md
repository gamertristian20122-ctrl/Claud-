# Post it: Wax & Wane 2.9.0, store by store

A step-by-step list for putting the game on itch.io (today), Google Play (closed test, then everyone) and
Steam (Coming Soon, then release). Short steps, one thing each. Do them in this order.

**Where things are**
- **Texts and pictures**: in the game's GitHub folder. On your phone or the ROG Ally, open
  `github.com/gamertristian20122-ctrl/Claud-/tree/ccr-37a74654-pp10xa/wax-and-wane/docs/marketing`.
  Tap a `.md` file to read and copy text. Tap a picture, then the download button, to save it.
- **Game files** (APK, AAB, zips, videos): not in the GitHub folder (too big). Claude sends each one in the chat
  when the build is done. Tap the file to download it. If one is too big for the chat, ask Claude to put it on
  a GitHub release of the repository (Releases page, a normal download) or in your Google Drive.
- **Every number** in the store texts comes from `facts.md`, made from the game's code.

---

## 0. First, Claude (the studio) makes the 2.9.0 files

You only need to say "build and send the release" (2.9.0 is built and sent already). Claude then:
1. Merges the fixes, sets the version (now **2.9.0**) in the three places (CLAUDE.md > Releasing a build), runs
   the checks and plays the tours.
2. Makes and sends you these files:

| File | What it is | Size (about) | Goes to |
|---|---|---|---|
| `build/WaxAndWane_v2.9.0.apk` | Android game, signed with your key | 38 MB | itch.io, your phone |
| `build/WaxAndWane_v2.9.0.aab` | Android bundle, must end with PLAY-READY | 40 MB | Google Play only |
| `build/WaxAndWane_2.9.0_windows.zip` | Windows game | 48 MB | itch.io, Steam, the ROG Ally test |
| `build/WaxAndWane_2.9.0_linux.zip` | Linux / Steam Deck game | 38 MB | itch.io, Steam |
| `build/WaxAndWane_2.9.0_web.zip` | The whole game, played in a browser (itch.io kind "HTML", frame 1280 x 720) | 22 MB | Only a page you keep private or share by link (friends, press). It is the full game, not a demo: do not make it a free public page |
| `build/videos/trailer_60s.mp4` | trailer ending OUT NOW ON ITCH.IO | 47 MB | YouTube, itch.io, socials |
| `build/videos/trailer_60s_play.mp4` | trailer ending GET IT ON GOOGLE PLAY | 47 MB | YouTube (link for Play) |
| `build/videos/trailer_60s_steam.mp4` | trailer ending WISHLIST ON STEAM | 47 MB | Steam |
| `build/videos/short_a_candle_is_the_timer.mp4`, `short_b_every_fire_relic.mp4`, `short_c_one_minute_left.mp4` | 3 vertical shorts | 6-8 MB each | TikTok, YouTube Shorts, Reels |
| `build/videos/loop_fight.gif` | 6-second loop | 1.1 MB | Steam text, itch.io screenshots |
| `build/videos/trailer_60s.srt` (and `_play`, `_steam`) | subtitles for YouTube | tiny | YouTube |
| `build/WaxAndWane_presskit_2.0.0.zip` | press kit (`./tools/press_kit.sh`) | a few MB | itch.io, press emails |

The videos are optional. On 2026-11-10 you chose to skip the trailer: leave every video row and video step
out. If you ever post one, add the trailer-voice sentence to the AI disclosure (`steam_store.md` section 6).

3. Makes the cuts with the other endings: `CTA=play ./tools/make_trailer.sh edit --only trailer` and
   `CTA=steam ./tools/make_trailer.sh edit --only trailer` (no re-recording; `videos.md`).

---

## 1. Decide these once (only you can)

| Decision | Recommended | Where it is used |
|---|---|---|
| Developer name shown on the stores | your name or a studio name | the OWNER block at the top of each store file |
| Public contact email | a new address just for the game | Google Play (required), Steam support, press kit |
| Prices | itch.io **$4.99**, Google Play **$2.99** (paid app), Steam **$5.99** | `itch_page.md` 2, `google_play.md` 2, `steam_store.md` 8 |
| Keep the GitHub repository public? | Decide before you sell. Public: anyone can read the code and build the game, but `LICENSE` says it may not be copied or sold. Private: safer; then host the privacy policy elsewhere (step 2.11 below) | `LICENSE`, `PRIVACY.md` |

The Google Play price type (paid or free) **cannot be changed from free to paid later**. Paid is the plan.

---

## 2. itch.io (today, free to start, itch keeps 10%)

1. Make an itch.io account at **itch.io/register** (free). Use the same name you want on the page.
2. Settings > **Payouts**: choose how itch pays you (PayPal or bank) and fill in the **tax interview**.
   itch.io needs both before it can sell anything.
3. Dashboard > **Create new project**. Fill in the fields from `itch_page.md` section 1 (title, URL
   `wax-and-wane`, tagline, Downloadable, **Released**, Action, Godot, inputs, languages).
4. **Pricing**: Paid, **$4.99**, tick "Let people pay more".
5. **Uploads** > Upload files, one at a time (each up to 1 GB, a normal browser upload):
   - `WaxAndWane_2.9.0_windows.zip` > tick **Windows**, name it "Windows (64-bit)"
   - `WaxAndWane_2.9.0_linux.zip` > tick **Linux**, name it "Linux (64-bit)"
   - `WaxAndWane_v2.9.0.apk` > tick **Android**, name it "Android phone (APK)"
   - Optional: `WaxAndWane_presskit_2.0.0.zip` > no platform, mark it as free ("press kit").
   (Or Claude can push all three with `ITCH_USER=yourname ./tools/upload_itch.sh` once you have given it an
   itch.io API key through the secure key form; never paste a key into the chat.)
6. **Description**: copy the whole block from `itch_page.md` section 3 (from "A twin-stick roguelite..."
   to "...Title > Credits.").
7. **Genre / tags**: the 10 tags in `itch_page.md` section 1.
8. **AI generation disclosure**: **Yes**, tick **Graphics, Sound, Text, Code** (why: `itch_page.md` section 1).
9. **Cover image**: `store_assets/itch/cover_630x500.png`.
   **Screenshots**, in this order: `screenshots/06_low_wax_1920x1080.png`, `01_cellar_fight`, `02_boss_fight`,
   `03_chapel_light`, `04_seance`, `07_treasure`, then `loop_fight.gif`.
   **Trailer**: upload `trailer_60s.mp4` to YouTube first (section 5 below), then paste the link.
10. **Visibility**: Draft first. Open the page, download each file once and check it opens. Then set
    **Public**. A 7-day 20% launch sale is optional (Edit game > Sales).
11. **Privacy link**: already in the description. If the GitHub repository goes private, paste the text of
    `PRIVACY.md` into a free Google Sites page (sites.google.com) and change the link to that page.
12. Post **devlog #1** the same day: text in `itch_page.md` section 4 (Dashboard > Devlog > New post,
    type "Game release", add `loop_fight.gif`).

Windows players see "Windows protected your PC" the first time (the game isn't code-signed). The itch
description already tells them: More info > Run anyway. Code signing costs about $100-400 a year; skip it for now.

---

## 3. Google Play (about 3 to 4 weeks: account, 14-day closed test, then everyone)

**Cost: $25 once.** Google takes about 15% of each sale.

### 3a. Account (week 1)
1. Go to **play.google.com/console** > sign up > **Personal** account > pay **$25**.
2. Verify your identity (ID photo + phone). Google can take a few days.
3. Settings > **Payments profile**: add your bank details (needed to sell a paid app).

### 3b. Create the app
4. **Create app**: name `Wax & Wane: Candle Roguelite`, language English (United States), **Game**, **Paid**.
5. Monetize > **App pricing**: for the closed test set the **lowest price Play allows** (testers have to buy a
   paid app, even in the test). You raise it to $2.99 before going public (step 18).

### 3c. App content (Policy > App content), every form
6. **Privacy policy**: paste
   `https://github.com/gamertristian20122-ctrl/Claud-/blob/ccr-37a74654-pp10xa/wax-and-wane/PRIVACY.md`
   (check it opens in a private browser tab, without logging in).
7. **Ads**: No.
8. **App access**: All functionality is available without special access.
9. **Content rating**: start the IARC questionnaire, category **Game**, answers in `google_play.md`
   section 3 (fantasy violence: yes; cartoon blood: yes, small red splats; fear: mild; gambling: no real
   money; purchases: no; no chat, no location, no internet).
10. **Target audience**: 13-15, 16-17, 18+ (not under 13).
11. **Data safety**: "Does your app collect or share user data?" **No**. (Why: `google_play.md` section 4.)
12. **News app** No, **Government app** No, **Financial features** None, **Health** No.

### 3d. Store listing (Grow users > Store presence > Main store listing)
13. Texts from `google_play.md` section 1: app name, short description (77 characters), full description
    (the whole block).
14. Pictures:
    - App icon: `docs/marketing/icons/google_play_512.png`
    - Feature graphic: `store_assets/google_play/feature_graphic_1024x500.png`
    - Phone screenshots (all six, in order): `store_assets/google_play/phone16x9_01_cellar_fight_1920x1080.png`
      to `phone16x9_06_relic_aloft_1920x1080.png`
    - 7-inch and 10-inch tablet screenshots: the same six files
    - Video: the YouTube link of `trailer_60s_play.mp4` (section 5 below)
15. Store settings: category **Action**, up to 5 tags (Roguelike, Shooter, Dungeon crawler, Pixelated/retro,
    Offline, or the nearest Play offers), your contact email.

### 3e. Closed test (14 days)
16. Test and release > Testing > **Closed testing** > Create release > upload **`WaxAndWane_v2.9.0.aab`**
    (a browser upload, works on the phone or the ROG Ally). The first time, Play asks about **app signing**:
    follow `google_play.md` section 6 ("use your existing key"; Claude makes the zip Play asks for).
    Release notes: "2.9.0: the full house: 64 relics, 16 guardians, 6 candles, nights of 4 to 7 floors, the Clock Tower."
    Testers tab: add 15-20 Google account emails. Send them the opt-in link.
17. Keep 12 or more testers opted in for **14 days in a row**. Ask them to play and tell you what they think.
    Read the **Pre-launch report** in Play Console; tell Claude about any crash it shows.

### 3f. Go public
18. Day 15: Dashboard > **Apply for production**, answer the questions about the test (Google answers in up
    to about 7 days). Then set the price to **$2.99** (Monetize > App pricing).
19. Test and release > **Production** > Create release > add the same AAB from the library > roll out.
20. When it is live: add the Play link to the itch.io page (`itch_page.md`, "Add later" line) and to your bios.

---

## 4. Steam (Coming Soon now, release months later)

**Cost: $100 per game** (Steam Direct). Valve pays it back once the game earns $1,000 on Steam.
Valve takes 30%.

### 4a. Account (start now: tax and bank checks take 15 to 30 days)
1. **partner.steamgames.com** > sign up with your Steam account > pay the **$100** Steam Direct fee.
2. Fill in the company / identity, **tax interview** and **bank** details.

### 4b. The store page (Coming Soon)
3. **Test the Windows build on the ROG Ally first** (it is a Windows 11 PC):
   download `WaxAndWane_2.9.0_windows.zip`, unzip it, run `WaxAndWane.exe` (More info > Run anyway), and play
   one run with the Ally's own buttons, including the menus (title, Candle Box, Journal, Settings, pause,
   results). If everything works without touching the screen, you can tick **Full Controller Support**;
   otherwise **Partial**. If it runs smoothly, the system requirements in `steam_store.md` section 7 are fine.
4. Steamworks > your app > **Store page**. Paste from `steam_store.md`:
   - Name and **short description**: section 2 (283 characters).
   - **About This Game**: section 3 (the BBCode block). Upload `loop_fight.gif` first with "Insert image".
     Delete the last sentence (the wishlist line) on release day.
   - **Tags**: section 4, in that order.
   - **Genre** Action, Indie; **features**: section 5 (Single-player, controller support from step 3,
     Family Sharing). Leave **Steam Achievements** and **Steam Cloud** unticked for now.
   - **Languages**: English (interface, subtitles).
   - **Content survey** and **AI disclosure**: section 6 (paste the two text blocks; Live-Generated: No).
   - **System requirements**: section 7.
   - **Price**: $5.99 (section 8). **Release date**: a season, for example "Summer 2027".
5. **Graphics** (Store page > Graphical assets), all from `store_assets/steam/`:
   header `header_capsule_920x430.png`, small `small_capsule_462x174.png`, main `main_capsule_1232x706.png`,
   vertical `vertical_capsule_748x896.png`, page background `page_background_1438x810.png` (optional);
   library: `library_capsule_600x900.png`, `library_header_920x430.png`, `library_hero_3840x1240.png`,
   `library_logo_1280x246.png` (position: left bottom). Screenshots: `store_assets/screenshots/01_...` to
   `09_...` in order; mark 02, 05, 07 and 09 as suitable for all ages.
   Icons: `docs/marketing/icons/steam_client_256.png`, `steam_community_184.png`.
6. **Trailer**: `trailer_60s_steam.mp4`.
7. Submit the store page for review (1 to 5 days), then **Publish as Coming Soon**. Add "Wishlist on Steam"
   to the itch.io page (`itch_page.md`, "Add later" line) and your bios.

### 4c. The build (any time before release)
8. Steamworks > App Admin > SteamPipe > **Depots**: make two depots, Windows and Linux.
9. Upload the game. Two ways:
   - **SteamPipe GUI on the ROG Ally** (easiest): download the Steamworks SDK from the partner site, run
     `tools/SteamPipeGUI` from it, log in, pick the depots, point them at the unzipped Windows and Linux
     folders, Upload.
   - **steamcmd**, also on the ROG Ally (`steamcmd.exe` in the SDK's `tools/ContentBuilder/builder` folder), with
     the build scripts in `tools/steam/` (each file says what to fill in). Use a separate Steam **build account**
     (Users & Permissions, only the "Edit App Metadata" and "Publish App Changes to Steam" rights). You type its
     password and Steam Guard code yourself in that window; never in the chat or a file.
10. Builds page: set the new build live on a **beta branch** with a password first, install it through Steam on
    the ROG Ally, play a run.
11. **Steam Cloud** (optional, no code): App Admin > Cloud: quota 1 MB, 10 files, and the two Auto-Cloud rows in
    `steam_store.md` section 5 (`WaxAndWane` folder, `*.cfg`). Test on two PCs, then tick Steam Cloud on the page.

### 4d. Release day
12. Builds page: set the tested build live on the **default** branch.
13. Discounting: a 20% launch discount for 7 days (`steam_store.md` section 9).
14. Press **Release App**. Post the launch short and a devlog the same day.

Steam achievements come later, in an update with the GodotSteam plugin, 67 achievements created in Steamworks and
their icons (`steam_store.md` section 5). Until then the page only says the achievements are in the game.

---

## 5. Videos (YouTube first, the stores link to it)

1. YouTube > Create > Upload `trailer_60s.mp4`. Title, description and subtitles: `videos.md` "Where to post".
   On the Details page, *Altered or synthetic content*: **Yes** (the narrator is an AI voice).
2. Upload `trailer_60s_play.mp4` the same way (unlisted is fine): that link goes into Google Play.
3. Shorts: `short_a`, `short_b`, `short_c` to TikTok, YouTube Shorts and Instagram Reels, one a day; captions in
   `videos.md`. Turn on each app's **AI-generated content** label (TikTok: More options; Instagram: Advanced
   settings > Add AI label).

---

## 6. What it costs

| Item | Cost | When |
|---|---|---|
| itch.io | free; itch keeps 10% of each sale (you can change it) | today |
| Google Play developer account | **$25** once | week 1 |
| Google Play fee | about 15% of each sale | after launch |
| Closed-test testers buying the paid app | lowest Play price per tester (about $1), or pay them back | weeks 1-3 |
| Steam Direct | **$100** per game, paid back at $1,000 earned | now (tax checks take 15-30 days) |
| Steam fee | 30% of each sale | after release |
| Windows code signing | about $100-400 a year | optional, not needed now |
| Mac build | $99 a year (Apple) | skip for now |

---

## 7. If something goes wrong

- itch.io page says "no files": the uploads must each have a platform ticked (step 2.5).
- Play says the bundle is not signed right: send Claude the exact message; never send the keystore or its password.
- Play rejects the privacy link: open it in a private tab; if it asks for a login, the repository is private:
  use the Google Sites copy (step 2.11).
- Steam page review comes back with changes: paste Valve's note to Claude; the fix is usually one line in
  `steam_store.md`.
- A player says Windows won't start the game: ask for their PC model; the game falls back to Direct3D 11 on its
  own when OpenGL is broken, so it's usually SmartScreen (More info > Run anyway).
