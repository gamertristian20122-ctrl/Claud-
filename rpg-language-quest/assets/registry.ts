import type { ImageSourcePropType } from 'react-native';

/**
 * Maps the asset keys used in lesson and character JSON to bundled files.
 *
 * React Native bundles only files named in a static `require()` call, so every
 * image and recording a lesson refers to needs one line here.
 */

const IMAGES: Record<string, ImageSourcePropType> = {
  'characters/blacksmith_marko.png': require('./characters/blacksmith_marko.png'),
  'backgrounds/forge.png': require('./backgrounds/forge.png'),
};

/**
 * Recorded NPC phrases, keyed by `DialogueExercise.audioFileName`.
 * A phrase with no entry is spoken by the device's text-to-speech voice.
 * To add a recording, put the file under `assets/audio/` and add, for example:
 *   'hr/blacksmith_01.mp3': require('./audio/hr/blacksmith_01.mp3'),
 */
const PHRASE_AUDIO: Record<string, number> = {};

/** Feedback sounds played when an answer is checked. */
export const FEEDBACK_SOUNDS: { correct: number; wrong: number } = {
  correct: require('./audio/sfx/correct.wav'),
  wrong: require('./audio/sfx/wrong.wav'),
};

export function getImage(key: string): ImageSourcePropType | undefined {
  return IMAGES[key];
}

export function getPhraseAudio(key: string): number | undefined {
  return PHRASE_AUDIO[key];
}
