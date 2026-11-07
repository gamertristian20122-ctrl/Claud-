# Google Play kit: Wax & Wane

**[CHECK]** = depends on v2.0. **[NEED]** = only you know it.

---

## 1. Store listing text

**App name (limit 30):** `Wax & Wane: Candle Roguelite` (28 characters)
Backup: `Wax & Wane` (10). The longer one tells a stranger in search results what kind of game it is.

**Short description (limit 80):** `A twin-stick roguelite where your health bar is a candle burning toward 2 AM.` (77 characters)
Backup: `Shoot through a haunted house as a living candle whose wax is also your clock.` (78)

**Full description (limit 4,000; this one is about 2,400).** Play shows plain text, so headings are plain lines.

```
Wax & Wane is a twin-stick roguelite where your health bar is a burning candle.

You are Tallow, the last candle in the cellar of an old house, and at midnight the house wakes up. Your wax is your health and your clock. The candle reads 12:00 AM when a run starts and 2:00 AM when you're out. Every hit melts more of it. Kills, cleared rooms and wax drippings buy minutes back. As the wax goes, Tallow gets shorter and your light shrinks, so a bad run gets darker as it gets harder.

Two thumbs, one candle
Your left thumb moves. Your right thumb shoots in any direction; hold it to keep firing. The bomb button breaks rocks and cracked walls. The game plays fully offline, and if you leave in the middle of a run it saves so you can carry on later.

Four floors before two o'clock
Fight room to room through the Cellar, the Crypt, the Chapel and the Belfry. Every floor is rebuilt each run from hand-made rooms. Clear a room and the candelabras light up. Bells toll at 1:00, 1:30 and 1:45 so you can hear the night running out.

Builds that get out of hand
• Around 64 relics. Twin Wick gives you a second flame, Will-o'-Wisp makes your shots seek, Hot Drip leaves burning wax wherever you walk.
• Candle Rites: hold three relics from the same Rite for a set bonus you can see on Tallow.
• Keepsakes: one charged item at a time. The Hand Bell freezes the house for three seconds. The Winding Key turns the clock back ten minutes.
• The Smoke Altar: buy a strong relic with minutes cut off the top of your candle for the rest of the night.

The house wants you snuffed
• 32+ kinds of monster, from hoppers that splash water on your flame to a treasure chest that bites
• Marked foes that glow, take more killing, and pay out wax, coins or bombs
• 8 bosses, each with a versus card, up to the Hour Fiend and its sweeping clock hands
• Omens that twist a floor and always pay you back

Reasons to light another candle
• Four more candles to unlock: the Tea Light, the Party Candle, the Altar Pillar and the hard-mode Black Taper
• Tonight's Candle: one seeded house each night, the same for every player, scored on your first try
• A secret Hollow on every floor, behind a cracked wall that seeps wax

Free to try
The Cellar and the Crypt are free. One purchase unlocks the whole house. There are no ads.

Made by one developer. Pixel art built on 0x72's free DungeonTileset II, sound effects by Kenney.
```

[CHECK: relic, monster and boss counts, and that save & continue shipped. If you ship premium instead of free-to-try, replace the "Free to try" block with: "One price buys the whole game. There are no ads and nothing else to buy."]

**Category:** Game > **Action**
**Tags** (Store settings > Tags, up to 5): pick from Google's list, aiming for Roguelike, Shooter, Dungeon crawler, Pixelated/retro, Offline [CHECK the exact names offered in the Console].
**Contact details:** an email address (required, shown publicly). Use a separate address for the game, e.g. `[NEED]@gmail.com`.

**Graphics** (as listed on the Play Console upload screens; check there before exporting)
- App icon: 512 x 512 PNG (32-bit), under 1 MB
- Feature graphic: 1024 x 500, JPG or 24-bit PNG (no transparency)
- Phone screenshots: 2 to 8, landscape 1920 x 1080 works. Put the clock-and-candle shot first.
- Optional: 7-inch and 10-inch tablet screenshots (same 1920 x 1080 shots are fine)
- Promo video: the YouTube link of the trailer

---

## 2. Monetisation: free to try with a one-time unlock (recommended)

**Recommendation:** free download with the Cellar and the Crypt playable, plus one in-app purchase, "Light the whole house", at **$3.99**, which unlocks everything for good. No ads.

Why:
1. Your sales come from short videos watched on phones. A free game installs in two taps from a TikTok link; a price on the store page is where most curious viewers leave.
2. More installs means more ratings, and Play shows apps with more ratings and installs to more people.
3. One app needs one closed test. A separate free "demo" app would need its own 12 testers for 14 days, because the rule is per app.
4. Take-home per unlock is roughly $2.70 to $3.10 after tax and Google's fee. Google's fee for games changed in 2026 and depends on the country and on whether you join the Play Games Level Up programme (roughly 15% to 25%); Play Console > Payments shows your real rate.

What it costs you:
- The game needs Google Play Billing (Godot's official Play Billing plugin), a "Restore purchase" button, and testing with licence testers during the closed test. That's real work for the integrator; plan a day for it.

**Decide before the first release.** On Google Play a paid app can later be made free, but a free app can never be made paid. So:
- Unlock built and tested by the time the closed test starts: go free with the unlock.
- Not ready: launch as a **premium app at $2.99** and keep it premium. A cheaper price than PC fits what phone players expect.

---

## 3. Content rating (Policy > App content > Content rating, IARC questionnaire)

Category: **Game**. Answer honestly; the questionnaire sets the rating, so these are the answers, not a promised result.

| Question area | Answer |
|---|---|
| Violence | Yes: cartoon/fantasy violence against fantasy creatures (skeletons, zombies, demons). Not realistic, no blood or gore [CHECK v2.0 stains], no violence against realistic humans |
| Fear | Yes, mild: a haunted-house setting with spooky pixel-art monsters; no jump-scare horror |
| Sexuality / nudity | No |
| Language | No |
| Controlled substances | No. "Tonics" are fantasy potions with no reference to real drugs, alcohol or tobacco |
| Crude humour | No |
| Gambling | No real or simulated gambling. Random chest loot is earned in play and never bought with money |
| Users interact or chat | No |
| Shares location | No |
| Digital purchases | Yes if you ship the unlock; No if premium |
| Unrestricted internet access | No |

Expect something like ESRB "E10+ Fantasy Violence" and PEGI 7. If it comes back higher, read why before re-submitting.

---

## 4. Data safety and the other App content forms

**Data safety**
1. "Does your app collect or share any of the required user data types?" **No.**
2. The form then skips the security and deletion questions.

Why this is true: the Android build's only permission is vibrate (checked in `export_presets.cfg`), so it can't reach the internet at all. Saves and settings stay in the game's own folder on the phone and are deleted on uninstall.
[CHECK if you add the unlock: Play Billing talks to the Play Store app, and the plugin adds the billing permission. Read Google's Data safety help on payments before you answer, and re-check the permission list in the final build.]

**Ads:** "Does your app contain ads?" **No.**
**App access:** "All functionality is available without special access."
**Target audience:** 13-15, 16-17 and 18+. Leave the under-13 groups unticked; ticking them puts the app under Google's Families policy, which adds extra requirements the game wasn't built for.
**News app / Government / Financial features / Health:** No / No / None / No.
**Privacy policy URL:** required. Paste the text below into a page on your itch.io site or a free Google Sites page and link it.

```
Wax & Wane privacy policy (last updated [DATE])

Wax & Wane does not collect, store or share any personal information. The game works offline. It has no ads, analytics or accounts. Your save file and settings stay on your device and are deleted when you uninstall the game.

[Only if you sell the unlock:] Purchases are processed by Google Play under Google's privacy policy. The game only asks Google Play whether the unlock has been bought.

Questions: [EMAIL]
```

---

## 5. Getting onto the store (short steps)

1. Make a **personal** Play Console account: $25 one-time fee, government ID and a phone number for identity checks.
2. Create the app: name, English (US), **Game**, Free (or Paid, see section 2).
3. Ask the integrator for a Play-ready build:
   - an **.aab** file (Google doesn't accept new apps as .apk), which needs Godot's Gradle build turned on;
   - **target API 36 (Android 16)**, required for new apps since Aug 31, 2026. The container currently has Android platform 34, so platform 36 must be installed first [CHECK];
   - under Play App Signing, choose to **use your existing key** (the same one the itch APK uses), so a phone can update from either store.
4. Open a **closed testing** track, add 15 to 20 testers by email (12 is the minimum and some drop out), and send them the opt-in link.
5. Keep at least 12 testers opted in for **14 days in a row**. Opting out and back in restarts that tester's count.
6. On day 15, click "Apply for production" on the Dashboard and answer the questions about your testing. Google usually replies within 7 days.
7. Publish to production. Earliest realistic launch: about 3 to 4 weeks after the closed test starts.

Where to find testers: friends and family with Android phones first, then tester-swap groups (you test theirs, they test yours). Ask them to really play, since Google asks about the feedback you got.

---

## Sources
- [Google: closed testing requirement for new personal accounts (12 testers, 14 days)](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Google: Play service fees (2026 changes by region)](https://support.google.com/googleplay/android-developer/answer/112622?hl=en)
- [Google: target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Google: Android developer verification](https://support.google.com/android-developer-console/answer/16561738?hl=en)
