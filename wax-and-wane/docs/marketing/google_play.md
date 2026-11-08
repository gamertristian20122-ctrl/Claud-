# Google Play kit: Wax & Wane

> **OWNER ONLY: fill these in before you publish (nothing else on this page needs editing)**
> - Developer name shown on Play (Play Console account name): `________`
> - Public contact email (Store settings > Store listing contact details, required): `________`
>   (a separate address for the game is a good idea)
> - Price: `________` (recommended: **$2.99, a paid app**, see section 2; decide before the first upload)

Every number here matches `facts.md`. The step-by-step order (closed test, then production) is in `POST_IT.md`.

---

## 1. Store listing text (Grow users > Store presence > Main store listing)

**App name (limit 30):** `Wax & Wane: Candle Roguelite` (28 characters)
Backup: `Wax & Wane` (10). The longer one tells a stranger in search results what kind of game it is.

**Short description (limit 80):** `A twin-stick roguelite where your health bar is a candle burning toward 2 AM.` (77 characters)
Backup: `Shoot through a haunted house as a living candle whose wax is also your clock.` (78)

**Full description (limit 4,000; this one is 2,905).** Play shows plain text, so headings are plain lines.

```
Wax & Wane is a twin-stick roguelite where your health bar is a burning candle.

You are Tallow, the last candle in the cellar of an old house, and at midnight the house wakes up. Your wax is your health and your clock. The candle reads 12:00 AM when a run starts and 2:00 AM when you're out: a full candle lasts eight minutes if nothing touches you. Every hit melts more of it. Kills, cleared rooms and wax drippings buy minutes back. As the wax goes, Tallow gets shorter and your light shrinks, so a bad run gets darker as it gets harder.

Two thumbs, one candle
Your left thumb moves. Your right thumb shoots in any direction; hold it to keep firing. The bomb button breaks rocks and cracked walls. The game plays fully offline, and if you leave in the middle of a run it saves so you can carry on later. Keyboards and gamepads work too.

Four floors before two o'clock, and one secret
Fight room to room through the Cellar, the Crypt, the Chapel and the Belfry. Every floor is rebuilt each run from 69 hand-made rooms. Clear a room and the candelabras light up. Bells toll at 1:00, 1:30 and 1:45 so you can hear the night running out. Snuff the Belfry's guardian by 1:00 AM and a ladder of light opens to a secret fifth floor, the Clock Tower, and the true ending.

Builds that get out of hand
• 64 relics. Twin Wick gives you a second flame, Will-o'-Wisp makes your shots seek, Hot Drip leaves burning wax wherever you walk.
• 6 Candle Rites: hold three relics from the same Rite for a set bonus you can see on Tallow.
• 8 keepsakes: one charged item at a time. The Hand Bell freezes the house for three seconds. The Winding Key turns the clock back ten minutes.
• The Smoke Altar: buy a strong relic with minutes cut off the top of your candle for the rest of the night.

The house wants you snuffed
• 35 kinds of lodger, from hoppers that splash water on your flame to a treasure chest that bites
• 9 guardians, each with a versus card, and 6 house champions
• 5 special rooms: the Seance, the Cracked Mirror, the Music Box, the Study and the Wax Font
• Marked foes that pay out wax, coins or bombs, and omens that twist a floor and always pay you back

Reasons to light another candle
• 5 more candles to unlock: the Tea Light, the Party Candle, the Altar Pillar, the hard-mode Black Taper and the secret Moonwick
• Tonight's Candle: one seeded house each night, the same for every player, scored on your first try
• A secret Hollow on every floor, behind a cracked wall that seeps wax
• The Journal of everything you've met, and 52 achievements

One price buys the whole game. There are no ads and nothing else to buy.

Made by one developer with Claude (AI). Dungeon tiles and about 20 creatures by 0x72, music by Pixel-boy and AAA (Ninja Adventure), sound effects built from Kenney's packs, all CC0. Tallow, the house's own creatures and guardians, the relics and rooms were made for this game.
```

**Category:** Game > **Action**
**Tags** (Store settings > Tags, up to 5): pick from Google's list; aim for Roguelike, Shooter, Dungeon crawler,
Pixelated / retro and Offline (use the nearest names the Console offers).

**Graphics** (Main store listing > Graphics)

| Slot | File | Notes |
|---|---|---|
| App icon | `docs/marketing/icons/google_play_512.png` | 512 x 512, 32-bit PNG |
| Feature graphic | `docs/marketing/store_assets/google_play/feature_graphic_1024x500.png` | 1024 x 500, 24-bit PNG, no transparency |
| Phone screenshots | `docs/marketing/store_assets/google_play/phone16x9_01_..._1920x1080.png` to `_06_...` | 16:9 with the touch HUD (on-screen sticks and buttons). Upload all six, in number order: 01 shows the clock and the candle |
| 7-inch and 10-inch tablet screenshots | the same six `phone16x9_*` files | |
| Promo video | the YouTube link of `trailer_60s_play.mp4` (ends on GET IT ON GOOGLE PLAY) | see `videos.md` |

Play asks games for at least four 16:9 landscape screenshots of 1920 x 1080 or more before it will show the
game in its recommendations, which is why the phone set is 16:9 (the older 2160 x 1080 `phone_0N_*` files are
2:1 and only count as extras).

---

## 2. Monetisation: premium at $2.99 (decided before the first upload)

**Recommendation: a paid app at $2.99.** No in-app purchases, no ads.

Why:
1. **It needs no code.** The 2.0.0 build has no Google Play Billing and its only permission is vibration. A paid
   app works exactly as it is; a "free to try" version would need about two days of work first (the Play
   Billing plugin, a Restore purchase button, a free-part gate after the Crypt, licence-tester runs during the
   closed test, then new Data safety answers).
2. **It matches the other stores.** itch.io and Steam sell the whole game for one price too.
3. **It cannot be reversed the other way.** On Google Play a paid app can later be made free, but a free app can
   never be made paid. Starting paid keeps both doors open.
4. **The price fits phones.** Phone players expect less than PC players; $2.99 sits under itch.io ($4.99) and
   Steam ($5.99).
5. Take-home: roughly $2.10 to $2.40 per sale after tax and Google's fee. Google's games fee depends on the
   country and on the Play Games Level Up programme (roughly 15% to 25% in 2026); Play Console > Payments
   shows your real rate.

To sell a paid app you need a **payments profile** with your bank details (Play Console > Settings >
Payments profile). Do it before you set the price.

**The one catch: closed-test testers have to buy a paid app.** Google's testing page says so ("Testers must
purchase paid apps when participating in open or closed tests"; only internal tests install free, and internal
tests don't count toward the 12-tester rule). Three ways to keep that cheap for your friends:
1. During the closed test, set the price to the lowest one Play allows (about $0.99), and raise it to $2.99 the
   day before you publish to production. Changing a paid app's price is allowed at any time.
2. Try promo codes (Monetize > Promotions; up to 500 a quarter for a paid app). Google's page doesn't say whether
   they work before production, so test one code on your own second account first.
3. Or simply pay your testers back. You get about 70% of each purchase back as revenue anyway.

If you ever want "free with a one-time unlock" instead, it has to be decided before the first release (a free
app can't become paid), and the studio needs the two days of work above first.

---

## 3. Content rating (Policy > App content > Content rating, IARC questionnaire)

Category: **Game**. Answer honestly; the questionnaire sets the rating, so these are the answers, not a
promised result.

| Question area | Answer |
|---|---|
| Violence | **Yes, fantasy violence.** A candle shoots sparks at fantasy creatures (some are humanoid: skeletons, zombies, imps, a waxwork bride). Nothing is realistic; nobody real or modern is harmed |
| Blood | **Yes, cartoon blood.** When a creature dies it bursts into a few tiny pixel chunks and leaves a flat splat on the floor; some splats are red. No realistic blood, wounds or gore. If the form asks how blood looks, choose the cartoon / unrealistic answer |
| Fear | Mild: a haunted-house setting with spooky pixel-art creatures; no jump scares or horror imagery |
| Sexuality / nudity | No |
| Language | No |
| Controlled substances | No. "Tonics" are fantasy potions with no reference to real drugs, alcohol or tobacco |
| Crude humour | No |
| Gambling | **No real-money gambling, and no simulated casino games.** If asked about random rewards: chests and the in-game Music Box give a random small reward for in-game coins earned by playing; coins can never be bought |
| Users interact or chat | No |
| Shares location | No |
| Digital purchases | No (a paid app with no in-app purchases) |
| Unrestricted internet access | No (the game never goes online) |

Expect something like ESRB "E10+ Fantasy Violence" and PEGI 7; cartoon blood can raise it to PEGI 12. If it
comes back higher than you expected, read why before re-submitting.

---

## 4. Data safety and the other App content forms

**Data safety**
1. "Does your app collect or share any of the required user data types?" **No.**
2. The form then skips the security and deletion questions.

Why this is true: the Android build's only permission is vibrate (`export_presets.cfg`; `tools/build_aab.sh`
fails if the bundle asks for any other), so it cannot reach the internet. Saves and settings stay in the game's
own folder on the phone. Android's own Auto Backup is switched on, so a player who has phone backup turned on
gets their save back on a new phone; that copy goes from Android to the player's own Google account backup and
the developer can never read it, which `PRIVACY.md` says in plain words.

**Ads:** "Does your app contain ads?" **No.**
**App access:** "All functionality is available without special access."
**Target audience:** 13-15, 16-17 and 18+. Leave the under-13 groups unticked; ticking them puts the app under
Google's Families policy, which adds requirements the game wasn't built for.
**News app / Government / Financial features / Health:** No / No / None / No.
**Privacy policy URL** (App content > Privacy policy):
`https://github.com/gamertristian20122-ctrl/Claud-/blob/ccr-37a74654-pp10xa/wax-and-wane/PRIVACY.md`
Open it in a private browser tab first: it must load without logging in. The same policy is inside the game
(Title > Credits > Privacy), which Google also asks for. If the repository becomes private, paste the text of
`PRIVACY.md` into a free Google Sites page or your itch.io page and use that link instead.

---

## 5. Getting onto the store (short steps)

1. Make a **personal** Play Console account: $25 one-time fee, government ID and a phone number for identity checks.
2. Create the app: name, English (US), **Game**, **Paid** (section 2).
3. Get the Play-ready build: `build/WaxAndWane_v2.0.0.aab` (made by `./tools/build_aab.sh`, see section 6):
   - an **.aab** file (Google doesn't accept new apps as .apk), made with Godot's Gradle build;
   - **target API 36 (Android 16)**, required for new apps since Aug 31, 2026 (the script installs platform 36 and checks the bundle);
   - under Play App Signing, choose to **use your existing key** (the same one the itch APK uses), so a phone can update from either store.
4. Open a **closed testing** track, add 15 to 20 testers by email (12 is the minimum and some drop out), and send them the opt-in link (section 6).
5. Keep at least 12 testers opted in for **14 days in a row**. Opting out and back in restarts that tester's count.
6. On day 15, click "Apply for production" on the Dashboard and answer the questions about your testing. Google usually replies within 7 days.
7. Publish to production. Earliest realistic launch: about 3 to 4 weeks after the closed test starts.

Where to find testers: friends and family with Android phones first, then tester-swap groups (you test theirs,
they test yours). Ask them to really play, since Google asks about the feedback you got. Testers buy a paid app
even on the closed track: see the three ways to keep that cheap in section 2.

---

## 6. Uploading the build

**Which file:** `build/WaxAndWane_v2.0.0.aab`.
Only the **.aab** goes to Google Play. The .apk is for itch.io and your own phone; Play won't take it.
The upload is a normal browser upload (about 40 MB): Play Console works in Chrome on a phone or on the ROG Ally.

**Making it (the studio does this):**
```
./tools/build_aab.sh
```
One command. It installs what's missing, builds the bundle signed with your release key, and checks it.
It must end with `PLAY-READY`. The checks: target SDK 36, version code, package `com.tallow.waxandwane`,
the label "Wax & Wane", not debuggable, only the vibrate permission, 64-bit (arm64) only, 16 KB page
size support, and the right signing key. Re-check an old file with `./tools/build_aab.sh --verify FILE.aab`.

### First upload only: Play App Signing with the key you already have
Google re-signs the copy that players download. Give Google the **same key** your itch.io APK uses.
Then a phone can update from either store, and the bundles you upload are signed with that same key
(it is your **upload key** too), so there is nothing new to keep safe.

1. Play Console > your app > **Test and release** > **App integrity** > **Play app signing**
   (Play also asks this the first time you create a release).
2. Tap **Choose signing key** (or **Change app signing key**) and pick
   **Export and upload a key from Java keystore**. The wording may differ a little.
3. Play shows a download for the **PEPK tool** and an **encryption public key**. Download both and
   send them to the studio.
4. The studio runs Google's command on the computer that has the key
   (`FailedIdolsOfTheAbyss/keystore/release.keystore`, alias `failedidols`) and sends back one zip file.
5. Upload that zip on the same page and press **Save**.

Never send the keystore file or its password to anyone, and never put them in the game's public repo.
If step 2 feels too fiddly: keep Google's own key instead. Uploads still work, signed with your key.
The catch: the itch.io APK and the Play version can no longer update each other (a player would have
to uninstall first and would lose their save).

### Closed test (12 testers, 14 days)
1. **Test and release** > **Testing** > **Closed testing** > **Create track** (or use the ready-made one).
2. **Testers** tab: make an email list with 15 to 20 Google account emails (12 must stay opted in).
3. **Create new release** > upload the .aab > the release name fills in by itself > write 2 or 3 lines
   of "What's new" > **Next** > **Save and publish** (or **Send for review**).
4. Wait for Google's review: usually a few hours, sometimes a few days.
5. Copy the **opt-in link** from the Testers tab and send it to your testers. They tap
   **Become a tester**, then install Wax & Wane from the Play Store.
6. Every new build needs a higher version code (Play refuses a number it has seen). Bump the version
   as usual (see CLAUDE.md), run `./tools/build_aab.sh`, and upload the new .aab as a new release on
   the same track. Testers get it as a normal update.

Yellow warnings about "debug symbols" or a "deobfuscation file" are fine to ignore. Read the
**Pre-launch report** (Play tries the game on real phones): crashes there need fixing.

---

## Sources
- [Google: set up open, closed or internal tests (testers buy paid apps in closed tests)](https://support.google.com/googleplay/android-developer/answer/9845334)
- [Google: promo codes (paid apps, 500 a quarter)](https://support.google.com/googleplay/android-developer/answer/6321495)
- [Google: closed testing requirement for new personal accounts (12 testers, 14 days)](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Google: Play service fees (2026 changes by region)](https://support.google.com/googleplay/android-developer/answer/112622?hl=en)
- [Google: target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Google: User Data policy (privacy policy link in the Console and inside the app)](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Google: Data safety form ("collection" means sending data off the device)](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Google: preview assets and screenshots (16:9 for game recommendations)](https://support.google.com/googleplay/android-developer/answer/9866151)
- [Google: Android developer verification](https://support.google.com/android-developer-console/answer/16561738?hl=en)
- [Google: Use Play App Signing (upload your existing key)](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Android: support 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)
