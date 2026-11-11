import { Ionicons } from '@expo/vector-icons';
import { useAudioPlayer, useAudioPlayerStatus } from 'expo-audio';
import type { AudioPlayer } from 'expo-audio';
import * as Haptics from 'expo-haptics';
import * as Speech from 'expo-speech';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo,
  Animated,
  Easing,
  Image,
  ImageBackground,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { FEEDBACK_SOUNDS, getImage, getPhraseAudio } from '../assets/registry';
import type {
  Character,
  LessonPack,
  LessonResult,
  UserProgressState,
} from '../types/dialogue';

export interface DialogueQuestScreenProps {
  lesson: LessonPack;
  /** The NPC named by `lesson.characterId`. */
  character: Character;
  /** Progress at the moment the lesson opens. The screen owns it from then on. */
  initialProgress: UserProgressState;
  /** Called after every answer, so the caller can save progress straight away. */
  onProgressChange?: (progress: UserProgressState) => void;
  /** Called when the player leaves the summary at the end of the lesson. */
  onFinish: (result: LessonResult, progress: UserProgressState) => void;
  /** Called when the player closes the lesson before the end. */
  onExit: () => void;
  /** Plays NPC speech and the correct/wrong sounds. Defaults to `true`. */
  soundEnabled?: boolean;
  /** Vibrates on answers and taps. Defaults to `true`. */
  hapticsEnabled?: boolean;
}

type Phase = 'answering' | 'feedback' | 'summary';
type OptionState = 'idle' | 'correct' | 'wrong' | 'dimmed';

const COLORS = {
  stage: '#1A1216',
  scrim: 'rgba(20, 12, 16, 0.55)',
  sheet: '#1F1A26',
  sheetEdge: '#342C3F',
  option: '#2A2433',
  optionEdge: '#15111B',
  optionBorder: '#40374D',
  text: '#F6EFE6',
  textMuted: '#B3A8BF',
  ink: '#2A1D1A',
  inkMuted: '#6B5750',
  parchment: '#F8EEDC',
  parchmentEdge: '#D9C6A5',
  ember: '#FF8A3D',
  heart: '#FF5C6C',
  xp: '#FFD25E',
  track: 'rgba(255, 255, 255, 0.18)',
  correct: '#58C777',
  correctDeep: '#2F8F4E',
  correctSheet: '#143522',
  wrong: '#FF6B6B',
  wrongDeep: '#C23B43',
  wrongSheet: '#3B151A',
} as const;

/** How far the status sheet travels when it slides in, in points. */
const SHEET_TRAVEL = 360;
/** Pause before the NPC speaks a new line, so the bubble lands first. */
const SPEAK_DELAY_MS = 450;

function replay(player: AudioPlayer): void {
  // A seek can reject while the file is still loading; playing from the
  // current position is the right result in that case.
  player.seekTo(0).catch(() => undefined);
  player.play();
}

interface OptionButtonProps {
  label: string;
  state: OptionState;
  disabled: boolean;
  onPress: () => void;
}

function OptionButton({ label, state, disabled, onPress }: OptionButtonProps) {
  const press = useRef(new Animated.Value(0)).current;

  const pressTo = (toValue: number) => {
    Animated.spring(press, {
      toValue,
      useNativeDriver: true,
      speed: 40,
      bounciness: toValue === 0 ? 8 : 0,
    }).start();
  };

  const animatedStyle = {
    opacity: state === 'dimmed' ? 0.45 : 1,
    transform: [
      { translateY: press.interpolate({ inputRange: [0, 1], outputRange: [0, 3] }) },
      { scale: press.interpolate({ inputRange: [0, 1], outputRange: [1, 0.98] }) },
    ],
  };

  return (
    <Animated.View style={animatedStyle}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={label}
        accessibilityState={{ disabled, selected: state === 'correct' || state === 'wrong' }}
        disabled={disabled}
        onPress={onPress}
        onPressIn={() => pressTo(1)}
        onPressOut={() => pressTo(0)}
        style={[
          styles.option,
          state === 'correct' && styles.optionCorrect,
          state === 'wrong' && styles.optionWrong,
        ]}
      >
        <Text style={styles.optionText}>{label}</Text>
        {state === 'correct' && (
          <Ionicons name="checkmark-circle" size={22} color={COLORS.correct} />
        )}
        {state === 'wrong' && <Ionicons name="close-circle" size={22} color={COLORS.wrong} />}
      </Pressable>
    </Animated.View>
  );
}

export default function DialogueQuestScreen({
  lesson,
  character,
  initialProgress,
  onProgressChange,
  onFinish,
  onExit,
  soundEnabled = true,
  hapticsEnabled = true,
}: DialogueQuestScreenProps) {
  const insets = useSafeAreaInsets();
  const totalCount = lesson.exercises.length;

  const [exerciseIndex, setExerciseIndex] = useState(0);
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  const [phase, setPhase] = useState<Phase>(initialProgress.hearts > 0 ? 'answering' : 'summary');
  const [progress, setProgress] = useState<UserProgressState>(initialProgress);
  const [showTranslation, setShowTranslation] = useState(false);
  const [correctCount, setCorrectCount] = useState(0);
  const [xpEarned, setXpEarned] = useState(0);
  const [xpGain, setXpGain] = useState<number | null>(null);
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [reduceMotion, setReduceMotion] = useState(false);

  const exercise = lesson.exercises[exerciseIndex];
  const isSummary = phase === 'summary';
  const isCorrect = selectedIndex === exercise.correctOptionIndex;
  const answeredCount = exerciseIndex + (phase === 'answering' ? 0 : 1);
  const lessonCompleted = progress.hearts > 0;

  const bob = useRef(new Animated.Value(0)).current;
  const hop = useRef(new Animated.Value(0)).current;
  const bubble = useRef(new Animated.Value(0)).current;
  const sheet = useRef(new Animated.Value(0)).current;
  const xpFloat = useRef(new Animated.Value(0)).current;
  const heartShake = useRef(new Animated.Value(0)).current;
  const progressFill = useRef(new Animated.Value(0)).current;

  // ---- Sound ---------------------------------------------------------------

  const phraseSource = getPhraseAudio(exercise.audioFileName);
  const phrasePlayer = useAudioPlayer(phraseSource ?? null);
  const phraseStatus = useAudioPlayerStatus(phrasePlayer);
  const correctPlayer = useAudioPlayer(FEEDBACK_SOUNDS.correct);
  const wrongPlayer = useAudioPlayer(FEEDBACK_SOUNDS.wrong);
  const utterance = useRef(0);

  const hasRecording = phraseSource !== undefined;
  const isPhrasePlaying = hasRecording ? phraseStatus.playing : isSpeaking;
  const { locale, pitch, rate } = character.voiceProfile;
  const prompt = exercise.prompt;

  const playPhrase = useCallback(() => {
    if (!soundEnabled) {
      return;
    }
    if (hasRecording) {
      replay(phrasePlayer);
      return;
    }
    // No recording for this line: the device's own voice reads it. Each call
    // gets a number so a late "stopped" event from the line before cannot
    // switch off the indicator for this one.
    utterance.current += 1;
    const id = utterance.current;
    const end = () => {
      if (utterance.current === id) {
        setIsSpeaking(false);
      }
    };
    Speech.stop().catch(() => undefined);
    Speech.speak(prompt, {
      language: locale,
      pitch,
      rate,
      onStart: () => {
        if (utterance.current === id) {
          setIsSpeaking(true);
        }
      },
      onDone: end,
      onStopped: end,
      onError: end,
    });
  }, [soundEnabled, hasRecording, phrasePlayer, prompt, locale, pitch, rate]);

  // The NPC says each new line once, shortly after it appears.
  useEffect(() => {
    if (isSummary) {
      return undefined;
    }
    const timer = setTimeout(playPhrase, SPEAK_DELAY_MS);
    return () => {
      clearTimeout(timer);
      utterance.current += 1;
      setIsSpeaking(false);
      Speech.stop().catch(() => undefined);
    };
  }, [playPhrase, isSummary]);

  const buzz = useCallback(
    (kind: 'correct' | 'wrong' | 'tap') => {
      if (!hapticsEnabled) {
        return;
      }
      const request =
        kind === 'tap'
          ? Haptics.selectionAsync()
          : Haptics.notificationAsync(
              kind === 'correct'
                ? Haptics.NotificationFeedbackType.Success
                : Haptics.NotificationFeedbackType.Error,
            );
      // Devices with no vibration motor reject the request.
      request.catch(() => undefined);
    },
    [hapticsEnabled],
  );

  // ---- Motion --------------------------------------------------------------

  useEffect(() => {
    let mounted = true;
    AccessibilityInfo.isReduceMotionEnabled()
      .then((enabled) => {
        if (mounted) {
          setReduceMotion(enabled);
        }
      })
      .catch(() => undefined);
    const subscription = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduceMotion);
    return () => {
      mounted = false;
      subscription.remove();
    };
  }, []);

  useEffect(() => {
    if (reduceMotion) {
      bob.setValue(0);
      return undefined;
    }
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(bob, {
          toValue: 1,
          duration: 1100,
          easing: Easing.inOut(Easing.sin),
          useNativeDriver: true,
        }),
        Animated.timing(bob, {
          toValue: 0,
          duration: 1100,
          easing: Easing.inOut(Easing.sin),
          useNativeDriver: true,
        }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [bob, reduceMotion]);

  useEffect(() => {
    bubble.setValue(0);
    Animated.spring(bubble, {
      toValue: 1,
      useNativeDriver: true,
      speed: 14,
      bounciness: reduceMotion ? 0 : 7,
    }).start();
  }, [bubble, exerciseIndex, reduceMotion]);

  useEffect(() => {
    Animated.timing(progressFill, {
      toValue: answeredCount / totalCount,
      duration: 320,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [progressFill, answeredCount, totalCount]);

  const showSheet = () => {
    sheet.setValue(0);
    Animated.timing(sheet, {
      toValue: 1,
      duration: 260,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  };

  const celebrate = (gain: number) => {
    setXpGain(gain);
    xpFloat.setValue(0);
    Animated.timing(xpFloat, {
      toValue: 1,
      duration: 1100,
      easing: Easing.out(Easing.quad),
      useNativeDriver: true,
    }).start(({ finished }) => {
      if (finished) {
        setXpGain(null);
      }
    });
    if (!reduceMotion) {
      hop.setValue(0);
      Animated.sequence([
        Animated.timing(hop, {
          toValue: 1,
          duration: 130,
          easing: Easing.out(Easing.quad),
          useNativeDriver: true,
        }),
        Animated.spring(hop, { toValue: 0, useNativeDriver: true, speed: 16, bounciness: 12 }),
      ]).start();
    }
  };

  const shakeHearts = () => {
    if (reduceMotion) {
      return;
    }
    heartShake.setValue(0);
    Animated.sequence(
      [1, -1, 1, -1, 0].map((toValue) =>
        Animated.timing(heartShake, { toValue, duration: 55, useNativeDriver: true }),
      ),
    ).start();
  };

  // ---- Answers -------------------------------------------------------------

  const handleSelect = (optionIndex: number) => {
    if (phase !== 'answering') {
      return;
    }
    const correct = optionIndex === exercise.correctOptionIndex;
    const next: UserProgressState = correct
      ? {
          ...progress,
          xp: progress.xp + exercise.xpReward,
          streakCount: progress.streakCount + 1,
        }
      : {
          ...progress,
          streakCount: 0,
          hearts: Math.max(0, progress.hearts - 1),
        };

    setSelectedIndex(optionIndex);
    setProgress(next);
    setPhase('feedback');
    onProgressChange?.(next);
    showSheet();

    if (correct) {
      setCorrectCount((count) => count + 1);
      setXpEarned((earned) => earned + exercise.xpReward);
      celebrate(exercise.xpReward);
      buzz('correct');
    } else {
      shakeHearts();
      buzz('wrong');
    }
    if (soundEnabled) {
      replay(correct ? correctPlayer : wrongPlayer);
    }
  };

  const handleContinue = () => {
    buzz('tap');
    const isLast = exerciseIndex === totalCount - 1;
    if (progress.hearts <= 0 || isLast) {
      setPhase('summary');
      return;
    }
    setExerciseIndex(exerciseIndex + 1);
    setSelectedIndex(null);
    setShowTranslation(false);
    setPhase('answering');
  };

  const handleFinish = () => {
    onFinish(
      {
        lessonId: lesson.lessonId,
        completed: lessonCompleted,
        correctCount,
        totalCount,
        xpEarned,
      },
      progress,
    );
  };

  const optionState = (optionIndex: number): OptionState => {
    if (phase === 'answering' || selectedIndex === null) {
      return 'idle';
    }
    if (optionIndex === exercise.correctOptionIndex) {
      return 'correct';
    }
    return optionIndex === selectedIndex ? 'wrong' : 'dimmed';
  };

  // ---- Render --------------------------------------------------------------

  const portrait = getImage(character.portraitAssetPath);
  const backdrop = getImage(character.backgroundAssetPath);

  const stage = (
    <>
      <View style={styles.scrim} />
      <View style={[styles.hud, { marginTop: insets.top + 8 }]}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Leave lesson"
          hitSlop={10}
          onPress={onExit}
          style={({ pressed }) => [styles.hudClose, pressed && styles.pressed]}
        >
          <Ionicons name="close" size={24} color={COLORS.text} />
        </Pressable>
        <View
          accessibilityRole="progressbar"
          accessibilityLabel="Lesson progress"
          accessibilityValue={{ min: 0, max: totalCount, now: answeredCount }}
          style={styles.track}
        >
          <Animated.View
            style={[
              styles.trackFill,
              { transformOrigin: 'left', transform: [{ scaleX: progressFill }] },
            ]}
          />
        </View>
        <Animated.View
          accessible
          accessibilityLabel={`${progress.hearts} hearts`}
          style={[
            styles.stat,
            {
              transform: [
                {
                  translateX: heartShake.interpolate({
                    inputRange: [-1, 1],
                    outputRange: [-5, 5],
                  }),
                },
              ],
            },
          ]}
        >
          <Ionicons name="heart" size={18} color={COLORS.heart} />
          <Text style={styles.statText}>{progress.hearts}</Text>
        </Animated.View>
        <View accessible accessibilityLabel={`Streak ${progress.streakCount}`} style={styles.stat}>
          <Ionicons name="flame" size={18} color={COLORS.ember} />
          <Text style={styles.statText}>{progress.streakCount}</Text>
        </View>
        <View accessible accessibilityLabel={`${progress.xp} XP`} style={styles.stat}>
          <Ionicons name="flash" size={18} color={COLORS.xp} />
          <Text style={styles.statText}>{progress.xp}</Text>
        </View>
      </View>

      {!isSummary && (
        <Animated.View
          style={[
            styles.bubble,
            {
              opacity: bubble,
              transform: [
                { translateY: bubble.interpolate({ inputRange: [0, 1], outputRange: [10, 0] }) },
                { scale: bubble.interpolate({ inputRange: [0, 1], outputRange: [0.95, 1] }) },
              ],
            },
          ]}
        >
          <View style={styles.bubbleRow}>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Play phrase"
              accessibilityState={{ disabled: !soundEnabled, busy: isPhrasePlaying }}
              disabled={!soundEnabled}
              hitSlop={6}
              onPress={() => {
                buzz('tap');
                playPhrase();
              }}
              style={({ pressed }) => [
                styles.speaker,
                isPhrasePlaying && styles.speakerActive,
                !soundEnabled && styles.speakerMuted,
                pressed && styles.pressed,
              ]}
            >
              <Ionicons
                name={soundEnabled ? 'volume-high' : 'volume-mute'}
                size={22}
                color={COLORS.parchment}
              />
            </Pressable>
            <Text style={styles.prompt} accessibilityLanguage={lesson.targetLanguage}>
              {exercise.prompt}
            </Text>
          </View>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={showTranslation ? 'Hide translation' : 'Reveal translation'}
            onPress={() => {
              buzz('tap');
              setShowTranslation((shown) => !shown);
            }}
            style={({ pressed }) => [styles.translation, pressed && styles.pressed]}
          >
            <Ionicons
              name={showTranslation ? 'eye-off-outline' : 'eye-outline'}
              size={16}
              color={COLORS.inkMuted}
            />
            <Text style={showTranslation ? styles.translationText : styles.translationHint}>
              {showTranslation ? exercise.translation : 'Tap to reveal translation'}
            </Text>
          </Pressable>
          <View style={styles.bubbleTail} />
        </Animated.View>
      )}

      <View style={styles.actor}>
        {xpGain !== null && (
          <Animated.Text
            style={[
              styles.xpFloat,
              {
                opacity: xpFloat.interpolate({
                  inputRange: [0, 0.15, 0.7, 1],
                  outputRange: [0, 1, 1, 0],
                }),
                transform: [
                  {
                    translateY: xpFloat.interpolate({
                      inputRange: [0, 1],
                      outputRange: [0, -40],
                    }),
                  },
                ],
              },
            ]}
          >
            +{xpGain} XP
          </Animated.Text>
        )}
        <Animated.View
          style={[
            styles.portraitWrap,
            {
              transform: [
                {
                  translateY: Animated.add(
                    bob.interpolate({ inputRange: [0, 1], outputRange: [0, -5] }),
                    hop.interpolate({ inputRange: [0, 1], outputRange: [0, -16] }),
                  ),
                },
              ],
            },
          ]}
        >
          {portrait !== undefined ? (
            <Image
              source={portrait}
              resizeMode="contain"
              accessibilityIgnoresInvertColors
              accessibilityLabel={`${character.name}, ${character.title}`}
              style={styles.portrait}
            />
          ) : (
            <View style={styles.portraitFallback}>
              <Text style={styles.portraitInitial}>{character.name.charAt(0)}</Text>
            </View>
          )}
        </Animated.View>
        <View style={styles.nameplate}>
          <Text style={styles.nameplateName}>{character.name}</Text>
          <Text style={styles.nameplateTitle}>{character.title}</Text>
        </View>
      </View>
    </>
  );

  return (
    <View style={styles.root}>
      {backdrop !== undefined ? (
        <ImageBackground source={backdrop} resizeMode="cover" style={styles.stage}>
          {stage}
        </ImageBackground>
      ) : (
        <View style={styles.stage}>{stage}</View>
      )}

      <View style={styles.sheet}>
        {isSummary ? (
          <View style={[styles.summary, { paddingBottom: insets.bottom + 20 }]}>
            <Ionicons
              name={lessonCompleted ? 'trophy' : 'heart-dislike'}
              size={44}
              color={lessonCompleted ? COLORS.xp : COLORS.heart}
            />
            <Text accessibilityRole="header" style={styles.summaryTitle}>
              {lessonCompleted ? 'Quest complete!' : 'Out of hearts'}
            </Text>
            <Text style={styles.summaryLesson}>{lesson.title}</Text>
            <View style={styles.summaryStats}>
              <View style={styles.summaryStat}>
                <Text style={styles.summaryValue}>
                  {correctCount}/{totalCount}
                </Text>
                <Text style={styles.summaryLabel}>Correct</Text>
              </View>
              <View style={styles.summaryStat}>
                <Text style={styles.summaryValue}>+{xpEarned}</Text>
                <Text style={styles.summaryLabel}>XP earned</Text>
              </View>
            </View>
            <Pressable
              accessibilityRole="button"
              onPress={handleFinish}
              style={({ pressed }) => [
                styles.cta,
                { backgroundColor: COLORS.ember, borderBottomColor: '#C25F1E' },
                pressed && styles.ctaPressed,
              ]}
            >
              <Text style={styles.ctaText}>{lessonCompleted ? 'Finish' : 'Back to map'}</Text>
            </Pressable>
          </View>
        ) : (
          <ScrollView
            contentContainerStyle={[styles.options, { paddingBottom: insets.bottom + 24 }]}
            showsVerticalScrollIndicator={false}
          >
            <Text style={styles.meta}>
              {lesson.title} · {lesson.cefrLevel}
            </Text>
            <Text accessibilityRole="header" style={styles.instruction}>
              {exercise.instruction}
            </Text>
            {exercise.options.map((option, optionIndex) => (
              <OptionButton
                key={`${exercise.id}-${optionIndex}`}
                label={option}
                state={optionState(optionIndex)}
                disabled={phase !== 'answering'}
                onPress={() => handleSelect(optionIndex)}
              />
            ))}
          </ScrollView>
        )}
      </View>

      {phase === 'feedback' && (
        <Animated.View
          accessibilityLiveRegion="polite"
          style={[
            styles.status,
            {
              paddingBottom: insets.bottom + 16,
              backgroundColor: isCorrect ? COLORS.correctSheet : COLORS.wrongSheet,
              borderTopColor: isCorrect ? COLORS.correctDeep : COLORS.wrongDeep,
              transform: [
                {
                  translateY: sheet.interpolate({
                    inputRange: [0, 1],
                    outputRange: [SHEET_TRAVEL, 0],
                  }),
                },
              ],
            },
          ]}
        >
          <View style={styles.statusHeader}>
            <Ionicons
              name={isCorrect ? 'checkmark-circle' : 'close-circle'}
              size={28}
              color={isCorrect ? COLORS.correct : COLORS.wrong}
            />
            <Text style={[styles.statusTitle, { color: isCorrect ? COLORS.correct : COLORS.wrong }]}>
              {isCorrect ? 'Correct!' : 'Not quite'}
            </Text>
            {isCorrect && <Text style={styles.statusXp}>+{exercise.xpReward} XP</Text>}
          </View>
          {!isCorrect && (
            <Text style={styles.statusAnswer}>
              <Text style={styles.statusAnswerLabel}>Correct answer: </Text>
              {exercise.options[exercise.correctOptionIndex]}
            </Text>
          )}
          <Text style={styles.statusTip}>{exercise.grammarTip}</Text>
          <Pressable
            accessibilityRole="button"
            onPress={handleContinue}
            style={({ pressed }) => [
              styles.cta,
              {
                backgroundColor: isCorrect ? COLORS.correct : COLORS.wrong,
                borderBottomColor: isCorrect ? COLORS.correctDeep : COLORS.wrongDeep,
              },
              pressed && styles.ctaPressed,
            ]}
          >
            <Text style={styles.ctaText}>Continue</Text>
          </Pressable>
        </Animated.View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: COLORS.stage,
  },
  pressed: {
    opacity: 0.7,
  },

  // Stage (top half)
  stage: {
    flex: 1,
    backgroundColor: COLORS.stage,
  },
  scrim: {
    ...StyleSheet.absoluteFill,
    backgroundColor: COLORS.scrim,
  },
  hud: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 16,
  },
  hudClose: {
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  track: {
    flex: 1,
    height: 12,
    borderRadius: 6,
    backgroundColor: COLORS.track,
    overflow: 'hidden',
  },
  trackFill: {
    flex: 1,
    borderRadius: 6,
    backgroundColor: COLORS.ember,
  },
  stat: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
  },
  statText: {
    color: COLORS.text,
    fontSize: 15,
    fontWeight: '700',
    fontVariant: ['tabular-nums'],
  },
  bubble: {
    marginTop: 16,
    marginHorizontal: 16,
    padding: 14,
    borderRadius: 18,
    borderWidth: 2,
    borderColor: COLORS.parchmentEdge,
    backgroundColor: COLORS.parchment,
  },
  bubbleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  speaker: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.ink,
  },
  speakerActive: {
    backgroundColor: COLORS.ember,
  },
  speakerMuted: {
    opacity: 0.4,
  },
  prompt: {
    flex: 1,
    color: COLORS.ink,
    fontSize: 20,
    lineHeight: 27,
    fontWeight: '700',
  },
  translation: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    minHeight: 36,
    marginTop: 8,
    paddingTop: 8,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: COLORS.parchmentEdge,
  },
  translationHint: {
    flex: 1,
    color: COLORS.inkMuted,
    fontSize: 14,
    fontWeight: '600',
  },
  translationText: {
    flex: 1,
    color: COLORS.ink,
    fontSize: 15,
    lineHeight: 21,
    fontStyle: 'italic',
  },
  bubbleTail: {
    position: 'absolute',
    bottom: -9,
    alignSelf: 'center',
    width: 16,
    height: 16,
    borderRightWidth: 2,
    borderBottomWidth: 2,
    borderColor: COLORS.parchmentEdge,
    backgroundColor: COLORS.parchment,
    transform: [{ rotate: '45deg' }],
  },
  actor: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'flex-end',
    // The answer sheet overlaps the stage by its corner radius.
    paddingBottom: 34,
    paddingTop: 14,
  },
  portraitWrap: {
    flex: 1,
    maxHeight: 168,
    aspectRatio: 1,
    alignItems: 'center',
    justifyContent: 'flex-end',
  },
  portrait: {
    width: '100%',
    height: '100%',
  },
  portraitFallback: {
    width: 96,
    height: 96,
    borderRadius: 48,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.option,
  },
  portraitInitial: {
    color: COLORS.text,
    fontSize: 40,
    fontWeight: '800',
  },
  xpFloat: {
    position: 'absolute',
    // Starts over the portrait and stops short of the speech bubble.
    top: 60,
    zIndex: 1,
    color: COLORS.xp,
    fontSize: 24,
    fontWeight: '900',
    textShadowColor: 'rgba(0, 0, 0, 0.7)',
    textShadowOffset: { width: 0, height: 2 },
    textShadowRadius: 4,
  },
  nameplate: {
    marginTop: 6,
    paddingVertical: 5,
    paddingHorizontal: 16,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: COLORS.ember,
    backgroundColor: 'rgba(20, 12, 16, 0.85)',
    alignItems: 'center',
  },
  nameplateName: {
    color: COLORS.text,
    fontSize: 16,
    fontWeight: '800',
  },
  nameplateTitle: {
    color: COLORS.ember,
    fontSize: 12,
    fontWeight: '600',
  },

  // Answer sheet (bottom half)
  sheet: {
    flex: 1,
    marginTop: -22,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    borderTopWidth: 1,
    borderColor: COLORS.sheetEdge,
    backgroundColor: COLORS.sheet,
    overflow: 'hidden',
  },
  options: {
    paddingTop: 18,
    paddingHorizontal: 16,
    gap: 10,
  },
  meta: {
    color: COLORS.textMuted,
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.6,
    textTransform: 'uppercase',
  },
  instruction: {
    marginBottom: 4,
    color: COLORS.text,
    fontSize: 19,
    lineHeight: 25,
    fontWeight: '800',
  },
  option: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    minHeight: 54,
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 14,
    borderWidth: 2,
    borderBottomWidth: 5,
    borderColor: COLORS.optionBorder,
    borderBottomColor: COLORS.optionEdge,
    backgroundColor: COLORS.option,
  },
  optionCorrect: {
    borderColor: COLORS.correct,
    borderBottomColor: COLORS.correctDeep,
    backgroundColor: COLORS.correctSheet,
  },
  optionWrong: {
    borderColor: COLORS.wrong,
    borderBottomColor: COLORS.wrongDeep,
    backgroundColor: COLORS.wrongSheet,
  },
  optionText: {
    flex: 1,
    color: COLORS.text,
    fontSize: 17,
    lineHeight: 23,
    fontWeight: '600',
  },

  // Status sheet (after an answer)
  status: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    paddingTop: 16,
    paddingHorizontal: 16,
    gap: 10,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    borderTopWidth: 2,
  },
  statusHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  statusTitle: {
    flex: 1,
    fontSize: 22,
    fontWeight: '900',
  },
  statusXp: {
    color: COLORS.xp,
    fontSize: 16,
    fontWeight: '800',
  },
  statusAnswer: {
    color: COLORS.text,
    fontSize: 17,
    lineHeight: 23,
    fontWeight: '700',
  },
  statusAnswerLabel: {
    color: COLORS.textMuted,
    fontWeight: '600',
  },
  statusTip: {
    color: COLORS.text,
    fontSize: 15,
    lineHeight: 21,
  },
  cta: {
    alignSelf: 'stretch',
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 52,
    marginTop: 6,
    borderRadius: 14,
    borderBottomWidth: 4,
  },
  ctaPressed: {
    borderBottomWidth: 1,
    marginTop: 9,
  },
  ctaText: {
    color: '#141014',
    fontSize: 17,
    fontWeight: '900',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
  },

  // Summary (end of lesson)
  summary: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingTop: 20,
    paddingHorizontal: 20,
    gap: 6,
  },
  summaryTitle: {
    marginTop: 4,
    color: COLORS.text,
    fontSize: 26,
    fontWeight: '900',
  },
  summaryLesson: {
    color: COLORS.textMuted,
    fontSize: 15,
    fontWeight: '600',
  },
  summaryStats: {
    alignSelf: 'stretch',
    flexDirection: 'row',
    gap: 12,
    marginVertical: 14,
  },
  summaryStat: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 12,
    borderRadius: 14,
    borderWidth: 2,
    borderColor: COLORS.optionBorder,
    backgroundColor: COLORS.option,
  },
  summaryValue: {
    color: COLORS.text,
    fontSize: 22,
    fontWeight: '900',
    fontVariant: ['tabular-nums'],
  },
  summaryLabel: {
    color: COLORS.textMuted,
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.6,
    textTransform: 'uppercase',
  },
});
