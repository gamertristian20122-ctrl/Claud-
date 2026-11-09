# itch.io page kit: Wax & Wane

> **OWNER ONLY: fill these in before you publish (nothing else on this page needs editing)**
> - Your itch.io username (the page lives at `<username>.itch.io/wax-and-wane`): `________`
> - Developer name shown on the page: `________`
> - Public contact email (optional on itch; use the same one as Google Play): `________`
> - Price: `________` (recommended: **$4.99 minimum**, "let people pay more" ticked; see section 2)

itch.io can go live the same day you upload, so it's where the first sales come from. Every number here matches
`facts.md`. The upload steps, file by file, are in `POST_IT.md`.

---

## 1. Page settings (Dashboard > Create new project)

| Field | What to enter |
|---|---|
| Title | Wax & Wane |
| Project URL | `wax-and-wane` |
| Short description or tagline | A twin-stick roguelite where your health bar is a burning candle. |
| Classification | Games |
| Kind of project | Downloadable |
| Release status | **Released** (2.0.0 is content-complete, with a true ending; not Early Access) |
| Pricing | Paid, $4.99, "Let people pay more" ticked (section 2) |
| Genre | Action |
| Made with | Godot |
| Platforms (ticked by the uploads) | Windows, Linux, Android |
| Inputs | Keyboard, Mouse, Xbox controller, Playstation controller, Touchscreen |
| Average session | About a half-hour (a run takes about 5 to 20 minutes) |
| Languages | English |
| Accessibility | Leave empty: the touch sticks can be swapped and aim assist turned on, but keys and buttons can't be remapped yet |
| Community | Comments |
| AI generation disclosure | **Yes.** Tick **Graphics**, **Sound**, **Text** and **Code** (see the note below) |
| Privacy policy | Paste the link from `PRIVACY.md` into the description (section 3 has the line) |

**Why each AI box is ticked** (same facts as the Steam disclosure in `steam_store.md` section 6):
- Graphics: Tallow, the house's own creatures, relics, rooms and effects were drawn by scripts written with
  Claude (an AI assistant) and checked one by one by the developer. The 0x72 tiles and creatures are hand-drawn.
- Sound: the trailer's narration is an AI voice (Kokoro TTS), and the sound effects and two jingles were
  layered or synthesized by AI-written scripts. The music is the human-made Ninja Adventure soundtrack (CC0).
- Text: the in-game names, lore lines and menus were written with the AI assistant and edited by the developer.
- Code: the game's code was written with the AI assistant.

**Tags** (itch allows 10):
`roguelite`, `roguelike`, `twin-stick-shooter`, `pixel-art`, `dungeon-crawler`, `bullet-hell`, `top-down-shooter`,
`procedural-generation`, `spooky`, `singleplayer`

**Images**
- Cover image: `docs/marketing/store_assets/itch/cover_630x500.png` (630 x 500).
- Screenshots, in this order: `store_assets/screenshots/06_low_wax`, `01_cellar_fight`, `02_boss_fight`,
  `03_chapel_light`, `04_seance`, `07_treasure` (all 1920 x 1080).
- First "screenshot": `loop_fight.gif` (itch shows GIFs moving; made by `./tools/make_trailer.sh all`).
- Trailer: the YouTube link of `trailer_60s.mp4` (the cut that ends on OUT NOW ON ITCH.IO), in the
  "Gameplay video or trailer" field.

---

## 2. Pricing and files

**Recommendation: $4.99 minimum, with "Let people pay more" ticked.**

1. $4.99 sits a dollar under the planned Steam price. Most itch buyers are on desktop and many of them also use
   Steam; pricing lower here is fine and rewards early fans.
2. itch takes 10% by default (you can change the split in your account's seller settings), and the payment
   processor takes a small fee on top. Expect about $4.00 per sale.
3. Launch sale: 20% off for the first 7 days ($3.99). itch lets you run sales any time, so use them around devlogs.
4. There is **no demo** in 2.0.0, so don't mention one. If you want one later, it has to be built first (a run
   that ends after the Crypt's guardian with a "get the full game" card, about half a day of work).

**Files to upload** (Edit game > Uploads; each one is a normal browser upload, up to 1 GB each)

| File | Size (about) | Tick |
|---|---|---|
| `build/WaxAndWane_2.0.0_windows.zip` | 48 MB | Windows |
| `build/WaxAndWane_2.0.0_linux.zip` | 38 MB | Linux |
| `build/WaxAndWane_v2.0.0.apk` | 38 MB | Android |
| `build/WaxAndWane_presskit_2.0.0.zip` (optional) | a few MB | none; set it as "free" (press kit, not the game) |

Give the uploads these display names: "Windows (64-bit)", "Linux (64-bit)", "Android phone (APK)". If you later
use the `butler` command-line uploader instead (`tools/upload_itch.sh`), it creates the same three channels.

**Android note:** Google is rolling out "developer verification" for apps installed from outside the Play Store
(Indonesia, Singapore and Thailand from Sept 30, 2026; worldwide in 2027). Once you have a Play Console account,
register the app's package name (`com.tallow.waxandwane`) and signing key there, so the itch APK keeps installing
on people's phones.

---

## 3. Page text (paste into the description box)

> **A twin-stick roguelite where your health bar is a burning candle.**
>
> You are Tallow, the last candle burning in the cellar of an old house, and at midnight the house wakes up. Your wax is your health and your clock. It reads 12:00 AM when you start and 2:00 AM when you're out: a full candle lasts eight minutes if nothing touches you. Every hit melts more of it. Kills, cleared rooms and wax drippings buy minutes back.
>
> As the wax goes, Tallow gets shorter and the light around you shrinks, so a bad run gets darker as it gets harder.
>
> **What's in the house**
> - Four floors, rebuilt every run from 69 hand-made rooms: the Cellar, the Crypt, the Chapel and the Belfry. Be done by 1:00 AM and a secret fifth floor opens: the Clock Tower, and the true ending
> - 64 relics. Twin Wick, Sharp Wick and Ember Heart together fire two piercing flames that set everything alight
> - 6 Candle Rites for collecting sets, 8 keepsakes you charge by clearing rooms, and the Smoke Altar, where power costs minutes off your candle for the rest of the night
> - 35 kinds of lodger, 13 guardians with versus cards and 6 house champions
> - 5 special rooms: the Seance, the Cracked Mirror, the Music Box, the Study and the Wax Font
> - 5 more candles to unlock, a secret Hollow on every floor, Tonight's Candle (one seeded house a night, the same for everyone), the Journal and 54 achievements
> - 3 save slots, each with its own difficulty level from 1 (Gentle, for learning) to 4 (Two O'Clock, brutal)
>
> **Which file do I want?**
> - Windows: download the Windows zip, unzip it, run `WaxAndWane.exe`. If Windows says "Windows protected your PC", click **More info**, then **Run anyway** (the game isn't code-signed yet; that's all the warning means).
> - Linux and Steam Deck desktop mode: download the Linux zip, unzip it, run `WaxAndWane.x86_64`.
> - Android: download the .apk on your phone and open it. When your phone asks, allow your browser to install apps. A newer APK from this page installs over it and keeps your save.
>
> **Controls:** keyboard and mouse, a gamepad, or touch with two thumbs on Android. Save and quit any time.
>
> **Privacy:** the game collects no data and never goes online. Policy: https://github.com/gamertristian20122-ctrl/Claud-/blob/ccr-37a74654-pp10xa/wax-and-wane/PRIVACY.md
>
> Made by one developer with Claude, an AI assistant (see the AI disclosure). Dungeon tiles and about 20 creatures by 0x72, music by Pixel-boy and AAA (Ninja Adventure), sound effects built from Kenney's packs, all CC0. Full credits and licences are in the game (Title > Credits).

**Add later, when the Steam page is live** (one line under "Controls"):

> **On Steam too:** [Wishlist Wax & Wane on Steam](paste the Steam store link here)

**Add later, when the Play listing is live:**

> **On Google Play:** [Wax & Wane on Google Play](paste the Play link here)

---

## 4. Devlog post #1

Post it the day the page goes live (Dashboard > Devlog > New post). Add `loop_fight.gif`.

**Title:** Your health bar is a candle

**Post type:** Game release

> Wax & Wane is a twin-stick roguelite about Tallow, a small living candle in a haunted house. It's out today for Windows, Linux and Android. This first devlog is about the rule the whole game hangs on.
>
> **The candle is the timer**
>
> Your wax is your health, and it's also the clock. The candle in the corner reads 12:00 AM when a run starts and 2:00 AM when you're out. It melts every second: a full candle lasts eight minutes if nothing ever touches you. Monsters melt it faster. Kills, cleared rooms and drippings put wax back.
>
> That one rule changes how you play. The clock keeps burning while you hide in a corner, so the only way to stay alive is to go and fight.
>
> **Three rules that keep it fair**
>
> - **Spilled Wax.** When you take a hit, about a third of the wax you lost splashes onto the floor as warm drops. You have two and a half seconds to grab them back before they cool.
> - **Kindling.** Kills less than 2.2 seconds apart chain into a streak. A x3 streak pours a minute back into the candle and x5 gives two. Getting hit douses the streak.
> - **Guttering.** Once per floor, a hit that would snuff you leaves you hanging on at one minute instead.
>
> Tallow also gets shorter as the wax goes, and your light shrinks with it. You can read how a run is going from the size of the candle without looking at the HUD.
>
> **What's in 2.0**
>
> - 64 relics, 6 Candle Rites and 8 keepsakes
> - 35 kinds of lodger, 13 guardians and 6 house champions
> - 5 special rooms, and a secret fifth floor with its own ending
> - 6 candles to play, Tonight's Candle, the Journal and 54 achievements
> - 3 save slots and 4 difficulty levels, from Gentle to Two O'Clock
> - Keyboard and mouse, gamepad and touch; save and continue; Windows, Linux and Android builds
>
> **What's next**
>
> A Steam page, and small free updates based on what you tell me.
>
> **One favour**
>
> Tell me in the comments which room got you and what time the clock said. That tells me more about the difficulty than anything else.

Optional, and only you can write it: one or two sentences in your own words about why you made this, before
"One favour". Readers can tell when a devlog has a person in it.

Devlog rhythm after this: one post a month, each about one thing (a new boss, a relic combo, a balance change
with before/after numbers).

---

## Sources
- [itch.io: Open revenue sharing (10% default)](https://itch.io/updates/open-revenue-sharing)
- [GamingOnLinux: itch.io AI generation disclosure, Nov 2024](https://gamingonlinux.com/2024/11/itchio-store-now-requires-ai-generated-content-disclosures-for-assets/page=1)
- [Google: Understanding Android developer verification](https://support.google.com/android-developer-console/answer/16561738?hl=en)
