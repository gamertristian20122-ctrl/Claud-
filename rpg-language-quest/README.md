# RPG Language Quest

An offline-first language-learning game for phones. Each lesson is a talk with
an RPG character: the character speaks in the language you are learning, and
you pick the right reply. Built with Expo (SDK 58), React Native and TypeScript.

First languages: Croatian and Serbian. This first slice holds one Croatian
lesson, "The Blacksmith's Order" (A1, nominative and accusative).

## Run it

```
npm install
npx expo start        # then open in Expo Go, or press w for the browser
npx tsc --noEmit      # typecheck
```

## Layout

| Path | What it holds |
| --- | --- |
| `types/dialogue.ts` | Types for characters, exercises, lesson packs and player progress |
| `components/DialogueQuestScreen.tsx` | The lesson screen: character stage on top, answer sheet below |
| `data/sample_lesson_croatian.json` | The sample lesson |
| `data/characters.json` | The characters that lessons refer to by `characterId` |
| `lib/lessonPack.ts` | Checks lesson and character JSON when it is loaded |
| `assets/registry.ts` | Maps the asset keys used in JSON to bundled files |
| `App.tsx` | Loads the sample lesson and shows the screen |

## Add a lesson

1. Copy `data/sample_lesson_croatian.json` and change the content. Each
   exercise needs 3 or 4 options, and `correctOptionIndex` counts from 0.
2. If the lesson uses a new character, add it to `data/characters.json`, put
   its portrait and backdrop under `assets/`, and add one line for each file in
   `assets/registry.ts`.
3. Load the file with `parseLessonPack`. It throws a clear error if a field is
   missing or wrong.

## Speech

No voice recordings are in the project yet. Until a recording exists for a
phrase, the phone's own text-to-speech voice reads it, using the character's
`voiceProfile` (`hr-HR` for Croatian). To use a recording, put the file under
`assets/audio/` and add its `audioFileName` key to `PHRASE_AUDIO` in
`assets/registry.ts`; the screen then plays the file with `expo-audio`.

## Not built yet

Progress is kept in memory only: it is lost when the app closes. There is no
lesson map, and no Serbian content.

## Credits

- Character sprite and forge backdrop: **Pixel Crawler** packs by Anokolisa
  (Free Pack and Forge). The terms allow use in commercial projects; the art
  must not be resold as an asset pack. Full text: `assets/licenses/PixelCrawler_Terms.txt`.
  The blacksmith currently uses the pack's knight sprite as a stand-in.
- Correct and wrong sounds: generated for this project.
