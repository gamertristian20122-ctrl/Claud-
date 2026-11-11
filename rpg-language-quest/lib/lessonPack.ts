import type {
  CefrLevel,
  Character,
  DialogueExercise,
  LessonPack,
  TargetLanguage,
  VoiceProfile,
} from '../types/dialogue';

/**
 * Runtime checks for lesson JSON. Content is written by hand, so a bad file
 * must fail loudly when it is loaded, not halfway through a lesson.
 */

const TARGET_LANGUAGES: readonly TargetLanguage[] = ['hr', 'sr'];
const CEFR_LEVELS: readonly CefrLevel[] = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
const MIN_OPTIONS = 3;
const MAX_OPTIONS = 4;

type JsonObject = Record<string, unknown>;

function asObject(value: unknown, where: string): JsonObject {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error(`${where}: expected an object`);
  }
  return value as JsonObject;
}

function asText(value: unknown, where: string): string {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`${where}: expected a non-empty string`);
  }
  return value;
}

function asPositiveNumber(value: unknown, where: string): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
    throw new Error(`${where}: expected a number above zero`);
  }
  return value;
}

function asList(value: unknown, where: string): unknown[] {
  if (!Array.isArray(value)) {
    throw new Error(`${where}: expected a list`);
  }
  return value;
}

function asOneOf<T extends string>(value: unknown, allowed: readonly T[], where: string): T {
  const match = allowed.find((item) => item === value);
  if (match === undefined) {
    throw new Error(`${where}: expected one of ${allowed.join(', ')}`);
  }
  return match;
}

function parseExercise(raw: unknown, where: string): DialogueExercise {
  const o = asObject(raw, where);
  const options = asList(o.options, `${where}.options`).map((option, i) =>
    asText(option, `${where}.options[${i}]`),
  );
  if (options.length < MIN_OPTIONS || options.length > MAX_OPTIONS) {
    throw new Error(`${where}.options: expected ${MIN_OPTIONS} to ${MAX_OPTIONS} options`);
  }
  if (new Set(options).size !== options.length) {
    throw new Error(`${where}.options: two options are the same`);
  }
  const correctOptionIndex = o.correctOptionIndex;
  if (
    typeof correctOptionIndex !== 'number' ||
    !Number.isInteger(correctOptionIndex) ||
    correctOptionIndex < 0 ||
    correctOptionIndex >= options.length
  ) {
    throw new Error(`${where}.correctOptionIndex: does not point at an option`);
  }
  return {
    id: asText(o.id, `${where}.id`),
    prompt: asText(o.prompt, `${where}.prompt`),
    translation: asText(o.translation, `${where}.translation`),
    instruction: asText(o.instruction, `${where}.instruction`),
    audioFileName: asText(o.audioFileName, `${where}.audioFileName`),
    options,
    correctOptionIndex,
    grammarTip: asText(o.grammarTip, `${where}.grammarTip`),
    xpReward: asPositiveNumber(o.xpReward, `${where}.xpReward`),
  };
}

export function parseLessonPack(raw: unknown): LessonPack {
  const o = asObject(raw, 'lesson');
  const exercises = asList(o.exercises, 'lesson.exercises').map((exercise, i) =>
    parseExercise(exercise, `lesson.exercises[${i}]`),
  );
  if (exercises.length === 0) {
    throw new Error('lesson.exercises: expected at least one exercise');
  }
  return {
    lessonId: asText(o.lessonId, 'lesson.lessonId'),
    title: asText(o.title, 'lesson.title'),
    targetLanguage: asOneOf(o.targetLanguage, TARGET_LANGUAGES, 'lesson.targetLanguage'),
    cefrLevel: asOneOf(o.cefrLevel, CEFR_LEVELS, 'lesson.cefrLevel'),
    characterId: asText(o.characterId, 'lesson.characterId'),
    exercises,
  };
}

function parseVoiceProfile(raw: unknown, where: string): VoiceProfile {
  const o = asObject(raw, where);
  return {
    locale: asText(o.locale, `${where}.locale`),
    pitch: asPositiveNumber(o.pitch, `${where}.pitch`),
    rate: asPositiveNumber(o.rate, `${where}.rate`),
  };
}

export function parseCharacters(raw: unknown): Character[] {
  return asList(raw, 'characters').map((item, i) => {
    const where = `characters[${i}]`;
    const o = asObject(item, where);
    return {
      id: asText(o.id, `${where}.id`),
      name: asText(o.name, `${where}.name`),
      title: asText(o.title, `${where}.title`),
      portraitAssetPath: asText(o.portraitAssetPath, `${where}.portraitAssetPath`),
      backgroundAssetPath: asText(o.backgroundAssetPath, `${where}.backgroundAssetPath`),
      voiceProfile: parseVoiceProfile(o.voiceProfile, `${where}.voiceProfile`),
    };
  });
}

export function findCharacter(characters: readonly Character[], characterId: string): Character {
  const character = characters.find((item) => item.id === characterId);
  if (character === undefined) {
    throw new Error(`No character with id "${characterId}"`);
  }
  return character;
}
