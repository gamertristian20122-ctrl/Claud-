/**
 * Data contracts for RPG dialogue lessons.
 *
 * Lesson content lives in JSON files under `data/`. Nothing in these types
 * points at a bundled file directly: asset fields hold keys that
 * `assets/registry.ts` resolves, because React Native can only bundle files
 * that are named in a static `require()` call.
 */

/** ISO 639-1 codes of the languages the app teaches. */
export type TargetLanguage = 'hr' | 'sr';

/** Common European Framework of Reference levels. */
export type CefrLevel = 'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2';

/** How an NPC sounds when a phrase has no recorded audio file. */
export interface VoiceProfile {
  /** BCP 47 tag passed to the device's text-to-speech voice, e.g. `hr-HR`. */
  locale: string;
  /** Voice pitch. `1` is the normal pitch. */
  pitch: number;
  /** Speaking rate. `1` is the normal rate; beginners do better below it. */
  rate: number;
}

export interface Character {
  id: string;
  name: string;
  /** Short role shown on the nameplate under the name, e.g. "Blacksmith". */
  title: string;
  /** Key of the portrait image in `assets/registry.ts`. */
  portraitAssetPath: string;
  /** Key of the stage backdrop in `assets/registry.ts`. */
  backgroundAssetPath: string;
  voiceProfile: VoiceProfile;
}

export interface DialogueExercise {
  id: string;
  /** What the NPC says, in the target language. */
  prompt: string;
  /** English translation of `prompt`, hidden until the player asks for it. */
  translation: string;
  /** English instruction that tells the player what to answer. */
  instruction: string;
  /**
   * Key of the recorded phrase in `assets/registry.ts`. When the registry has
   * no file for the key, the phrase is spoken with the character's
   * `voiceProfile` instead.
   */
  audioFileName: string;
  /** Three or four replies in the target language. */
  options: string[];
  /** Index into `options` of the one correct reply. */
  correctOptionIndex: number;
  /** Explanation shown after the player answers. */
  grammarTip: string;
  /** XP granted for a correct answer. */
  xpReward: number;
}

export interface LessonPack {
  lessonId: string;
  title: string;
  targetLanguage: TargetLanguage;
  cefrLevel: CefrLevel;
  characterId: string;
  exercises: DialogueExercise[];
}

export interface UserProgressState {
  xp: number;
  /** Correct answers in a row. A wrong answer resets it to zero. */
  streakCount: number;
  hearts: number;
  /** `lessonId` of every lesson the player can open. */
  unlockedLessons: string[];
}

/** Hearts a player starts with, and the most they can hold. */
export const MAX_HEARTS = 5;

/** What the player did in one finished (or failed) lesson. */
export interface LessonResult {
  lessonId: string;
  /** `false` when the player ran out of hearts before the last exercise. */
  completed: boolean;
  correctCount: number;
  totalCount: number;
  xpEarned: number;
}
