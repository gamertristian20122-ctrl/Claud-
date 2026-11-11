import { StatusBar } from 'expo-status-bar';
import { useState } from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import DialogueQuestScreen from './components/DialogueQuestScreen';
import charactersJson from './data/characters.json';
import lessonJson from './data/sample_lesson_croatian.json';
import { findCharacter, parseCharacters, parseLessonPack } from './lib/lessonPack';
import { MAX_HEARTS } from './types/dialogue';
import type { UserProgressState } from './types/dialogue';

const lesson = parseLessonPack(lessonJson);
const character = findCharacter(parseCharacters(charactersJson), lesson.characterId);

const NEW_PLAYER: UserProgressState = {
  xp: 0,
  streakCount: 0,
  hearts: MAX_HEARTS,
  unlockedLessons: [lesson.lessonId],
};

export default function App() {
  const [progress, setProgress] = useState<UserProgressState>(NEW_PLAYER);
  // A new number remounts the screen, which starts the lesson again.
  const [attempt, setAttempt] = useState(0);

  // There is no map screen yet, so leaving a lesson starts it again with full
  // hearts. XP is kept.
  const restart = (latest: UserProgressState) => {
    setProgress({ ...latest, streakCount: 0, hearts: MAX_HEARTS });
    setAttempt((count) => count + 1);
  };

  return (
    <SafeAreaProvider>
      <StatusBar style="light" />
      <DialogueQuestScreen
        key={attempt}
        lesson={lesson}
        character={character}
        initialProgress={progress}
        onProgressChange={setProgress}
        onFinish={(_result, latest) => restart(latest)}
        onExit={() => restart(progress)}
      />
    </SafeAreaProvider>
  );
}
