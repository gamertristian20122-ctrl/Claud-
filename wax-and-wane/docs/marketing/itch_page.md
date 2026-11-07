# itch.io page kit: Wax & Wane

itch.io can go live the same day you upload, so it's where the first sales come from.
**[CHECK]** = depends on v2.0. **[NEED]** = only you know it.

---

## 1. Page settings (Dashboard > Create new project)

| Field | What to enter |
|---|---|
| Title | Wax & Wane |
| Project URL | `[NEED: yourname].itch.io/wax-and-wane` |
| Short description or tagline | A twin-stick roguelite where your health bar is a burning candle. |
| Classification | Games |
| Kind of project | Downloadable |
| Release status | Released (or "In development" if you upload before v2.0 is final) |
| Genre | Action |
| Made with | Godot |
| Platforms (tick by upload) | Windows, Linux, Android [CHECK: Mac only if you build one] |
| Inputs | Keyboard, Mouse, Xbox controller, Playstation controller, Touchscreen [CHECK pad] |
| Average session | About a half-hour [NEED: change to match real run times] |
| Languages | English |
| Community | Comments on |
| AI generation disclosure | Yes. Tick **Graphics**, **Sound** and **Code**. Same reason as the Steam page: the art and music scripts were written by an AI assistant. [CHECK each v2.0 stream's notes] |

**Tags** (itch allows 10):
`roguelite`, `roguelike`, `twin-stick-shooter`, `pixel-art`, `dungeon-crawler`, `bullet-hell`, `top-down-shooter`, `procedural-generation`, `spooky`, `singleplayer`

**Images**
- Cover image: 630 x 500 (itch's recommended size). Tallow, the flame and the logo, nothing else.
- Screenshots: 4 to 6, same picks as the Steam list. Put the low-wax "tiny light circle" shot first.
- Optional: a GIF of the clock and the shrinking candle as the first screenshot. itch shows GIFs moving.

---

## 2. Pricing

**Recommendation: $4.99 minimum, with "Let people pay more" ticked.**

1. The free demo (below) covers people who want to try first, so the full game doesn't need to be pay-what-you-want.
2. $4.99 sits a dollar under the planned Steam price. Most itch buyers are on desktop and many of them also use Steam; pricing lower here is fine and rewards early fans.
3. itch takes 10% by default (you can change the split in your account's seller settings), and the payment processor takes a small fee on top. Expect about $4.00 per sale.
4. Launch sale: 20% off for the first 7 days ($3.99). itch lets you run sales any time, so use them around devlogs.

**Files to upload**

| File | Price flag |
|---|---|
| `WaxAndWane_v2.0_windows.zip` | paid |
| `WaxAndWane_v2.0_linux.zip` | paid |
| `WaxAndWane_v2.0_android.apk` | paid |
| `WaxAndWane_Demo_windows.zip` | tick "This file is a demo and can be downloaded for free" |
| `WaxAndWane_Demo_android.apk` | demo, free |

Demo scope: the Cellar and the Crypt with one boss each [CHECK what the demo build allows]. Stop the demo after the Crypt boss with a screen that says where to buy the full game.

**Later experiment:** a browser demo on its own free page. Browser games get far more clicks on itch's browse pages. Only do it if the Godot web export runs smoothly on a normal laptop and a phone [CHECK].

**Android note:** Google is rolling out "developer verification" for apps installed from outside the Play Store (Indonesia, Singapore and Thailand from Sept 30, 2026; worldwide in 2027). Once you have a Play Console account, register the app's package name (`com.tallow.waxandwane`) and signing key there, so the itch APK keeps installing on people's phones.

---

## 3. Page text (paste into the description box)

> **A twin-stick roguelite where your health bar is a burning candle.**
>
> You are Tallow, the last candle burning in the cellar of an old house, and at midnight the house wakes up. Your wax is your health and your clock. It reads 12:00 AM when you start and 2:00 AM when you're out. Every hit melts more of it. Kills, cleared rooms and wax drippings buy minutes back.
>
> As the wax goes, Tallow gets shorter and the light around you shrinks, so a bad run gets darker as it gets harder.
>
> **In the full game**
> - Four floors, rebuilt every run: the Cellar, the Crypt, the Chapel and the Belfry
> - Around 64 relics [CHECK]. Twin Wick, Sharp Wick and Ember Heart together fire two piercing flames that set everything alight
> - Candle Rites for collecting sets, Keepsakes you charge by clearing rooms, and the Smoke Altar, where power costs minutes off your candle for the rest of the night
> - 8 bosses [CHECK], from Old Rot in the Cellar to the Hour Fiend in the Belfry
> - Four more candles to unlock, a secret Hollow on every floor, and Tonight's Candle: one seeded house a night, the same for everyone
>
> **Which file do I want?**
> - Windows or Linux: download the zip, unzip it, run the game.
> - Android: download the .apk on your phone and open it. When your phone asks, allow your browser to install apps.
> - Not sure yet? Grab the free demo (the Cellar and the Crypt).
>
> **Controls:** keyboard and mouse, a gamepad, or touch with two thumbs on Android.
>
> **On Steam soon:** [Wishlist Wax & Wane on Steam](STEAM_LINK)
>
> Made by [NEED: your name], one person with an AI coding assistant. Dungeon tiles and creatures by 0x72 (CC0), sound effects by Kenney (CC0). Full credits are in the game.

---

## 4. Devlog post #1

Post it the day the page goes live (Dashboard > Devlog > New post). Add 2 GIFs: the shrinking candle, and a Kindling streak pouring minutes back.

**Title:** Your health bar is a candle

**Post type:** Game release (or "Announcement" if it's the demo first)

> Wax & Wane is a twin-stick roguelite about Tallow, a small living candle in a haunted house. This first devlog is about the rule the whole game hangs on.
>
> **The candle is the timer**
>
> Your wax is your health, and it's also the clock. The candle in the corner reads 12:00 AM when a run starts and 2:00 AM when you're out. It melts every second: a full candle lasts about nine and a half minutes if nothing ever touches you. Monsters melt it faster. Kills, cleared rooms and drippings put wax back.
>
> That one rule changes how you play. The clock keeps burning while you hide in a corner, so the only way to stay alive is to go and fight.
>
> **Three rules that keep it fair**
>
> - **Spilled Wax.** When you take a hit, half the wax you lost splashes onto the floor as warm drops. You have four seconds to grab them back before they cool.
> - **Kindling.** Kills less than 2.2 seconds apart chain into a streak. A x3 streak pours a minute back into the candle and x5 gives two. Getting hit douses the streak.
> - **Guttering.** Once per floor, a hit that would snuff you leaves you hanging on at one minute instead.
>
> Tallow also gets shorter as the wax goes, and your light shrinks with it. You can read how a run is going from the size of the candle without looking at the HUD.
>
> **What's in 2.0** [CHECK every line against the final build]
>
> - Around 64 relics and 32+ kinds of monster
> - 8 bosses, each with a versus card
> - Stains that stay on the floor, more sound, decorated rooms with flickering light
> - Keyboard and mouse, gamepad, save and continue, achievements
> - Windows and Linux builds next to the Android one
>
> **What's next**
>
> [NEED: one or two lines on the next update, e.g. a journal, new rooms, balance changes.]
>
> [NEED: one or two sentences in your own words about why you made this. Readers can tell when a devlog has no person in it.]
>
> **One favour**
>
> If you play the demo, tell me in the comments which room got you and what time the clock said. That tells me more about the difficulty than anything else.
>
> The game is coming to Steam too. Steam emails everyone who [wishlisted it](STEAM_LINK) on launch day, and following here gets you the next devlog.

Devlog rhythm after this: one post a month, each about one thing (a new boss, a relic combo, a balance change with before/after numbers).

---

## Sources
- [itch.io: Open revenue sharing (10% default)](https://itch.io/updates/open-revenue-sharing)
- [GamingOnLinux: itch.io AI generation disclosure, Nov 2024](https://gamingonlinux.com/2024/11/itchio-store-now-requires-ai-generated-content-disclosures-for-assets/page=1)
- [Google: Understanding Android developer verification](https://support.google.com/android-developer-console/answer/16561738?hl=en)
