import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Vibration,
  useWindowDimensions,
  StatusBar,
  Animated,
} from 'react-native';
import colors from '../../theme/colors';

const GAME_DURATION = 10;

const MASTER_MO_SPEEDS = {
  easy: 3,
  medium: 6,
  hard: 9,
};

function CounterDisplay({ count, color, label, side }) {
  const scaleAnim = useRef(new Animated.Value(1)).current;

  const pulse = () => {
    Animated.sequence([
      Animated.timing(scaleAnim, { toValue: 1.15, duration: 60, useNativeDriver: true }),
      Animated.timing(scaleAnim, { toValue: 1, duration: 80, useNativeDriver: true }),
    ]).start();
  };

  useEffect(() => {
    if (count > 0) pulse();
  }, [count]);

  return (
    <View style={[styles.counterWrapper, side === 'right' && styles.counterWrapperRight]}>
      <Text style={[styles.playerLabel, { color }]}>{label}</Text>
      <Animated.Text style={[styles.counter, { color, transform: [{ scale: scaleAnim }] }]}>
        {count}
      </Animated.Text>
      <Text style={[styles.tapHint, { color: color + '88' }]}>
        {side === 'left' ? '◀ TIPPE HIER' : 'TIPPE HIER ▶'}
      </Text>
    </View>
  );
}

export default function TapWarScreen({ onExit, masterMoMode = false, difficulty = 'medium' }) {
  const { width, height } = useWindowDimensions();

  const [phase, setPhase] = useState('countdown'); // countdown | playing | result
  const [countdown, setCountdown] = useState(3);
  const [timeLeft, setTimeLeft] = useState(GAME_DURATION);
  const [p1Count, setP1Count] = useState(0);
  const [p2Count, setP2Count] = useState(0);
  const [winner, setWinner] = useState(null);

  const p1Ref = useRef(0);
  const p2Ref = useRef(0);
  const playingRef = useRef(false);
  const moIntervalRef = useRef(null);

  // Countdown phase
  useEffect(() => {
    if (phase !== 'countdown') return;
    if (countdown <= 0) {
      setPhase('playing');
      return;
    }
    const t = setTimeout(() => setCountdown(c => c - 1), 1000);
    return () => clearTimeout(t);
  }, [phase, countdown]);

  const endGame = useCallback(() => {
    const final1 = p1Ref.current;
    const final2 = p2Ref.current;
    let w = null;
    if (final1 > final2) w = 'player1';
    else if (final2 > final1) w = 'player2';
    else w = 'tie';
    setWinner(w);
    setPhase('result');
  }, []);

  // Game timer
  useEffect(() => {
    if (phase !== 'playing') return;
    playingRef.current = true;

    if (masterMoMode) {
      const speed = MASTER_MO_SPEEDS[difficulty] || 6;
      const interval = Math.floor(1000 / speed);
      moIntervalRef.current = setInterval(() => {
        if (playingRef.current) {
          p2Ref.current += 1;
          setP2Count(p2Ref.current);
        }
      }, interval);
    }

    const timer = setInterval(() => {
      setTimeLeft(t => {
        if (t <= 1) {
          clearInterval(timer);
          if (moIntervalRef.current) clearInterval(moIntervalRef.current);
          playingRef.current = false;
          setTimeout(() => endGame(), 50);
          return 0;
        }
        return t - 1;
      });
    }, 1000);

    return () => {
      clearInterval(timer);
      if (moIntervalRef.current) clearInterval(moIntervalRef.current);
      playingRef.current = false;
    };
  }, [phase]);

  const handleP1Tap = () => {
    if (phase !== 'playing') return;
    p1Ref.current += 1;
    setP1Count(p1Ref.current);
    try { Vibration.vibrate(20); } catch (_) {}
  };

  const handleP2Tap = () => {
    if (phase !== 'playing' || masterMoMode) return;
    p2Ref.current += 1;
    setP2Count(p2Ref.current);
    try { Vibration.vibrate(20); } catch (_) {}
  };

  const handleExit = () => {
    if (moIntervalRef.current) clearInterval(moIntervalRef.current);
    playingRef.current = false;
    if (onExit) {
      if (masterMoMode && phase === 'result') {
        onExit({
          winner: winner === 'player1' ? 'player' : winner === 'player2' ? 'mo' : 'tie',
          playerScore: p1Ref.current,
          moScore: p2Ref.current,
        });
      } else {
        onExit(null);
      }
    }
  };

  const resetGame = () => {
    if (moIntervalRef.current) clearInterval(moIntervalRef.current);
    playingRef.current = false;
    p1Ref.current = 0;
    p2Ref.current = 0;
    setP1Count(0);
    setP2Count(0);
    setTimeLeft(GAME_DURATION);
    setCountdown(3);
    setWinner(null);
    setPhase('countdown');
  };

  const timerPercent = timeLeft / GAME_DURATION;
  const timerColor = timeLeft > 5 ? colors.success : timeLeft > 2 ? colors.accent : colors.primary;

  const p1Name = masterMoMode ? 'Du' : 'Spieler 1';
  const p2Name = masterMoMode ? '🤖 Mo' : 'Spieler 2';
  const p1Color = colors.playerLeft;
  const p2Color = masterMoMode ? colors.accent : colors.playerRight;

  // Countdown screen
  if (phase === 'countdown') {
    return (
      <View style={[styles.fullScreen, { backgroundColor: colors.background }]}>
        <StatusBar hidden />
        <TouchableOpacity style={styles.exitBtn} onPress={handleExit}>
          <Text style={styles.exitBtnText}>X</Text>
        </TouchableOpacity>
        <View style={styles.countdownContainer}>
          <Text style={styles.getReady}>BEREIT?</Text>
          <Text style={styles.countdownNumber}>
            {countdown === 0 ? 'LOS!' : countdown}
          </Text>
          <Text style={styles.countdownSub}>
            {masterMoMode ? 'Du vs Master Mo (' + difficulty + ')' : 'Spieler 1 vs Spieler 2'}
          </Text>
        </View>
      </View>
    );
  }

  // Result screen
  if (phase === 'result') {
    const isP1Winner = winner === 'player1';
    const isP2Winner = winner === 'player2';
    const isTie = winner === 'tie';

    return (
      <View style={[styles.fullScreen, { backgroundColor: colors.background }]}>
        <StatusBar hidden />
        <View style={styles.resultScreen}>
          <Text style={styles.resultTitle}>
            {isTie ? 'UNENTSCHIEDEN' : (isP1Winner ? p1Name : p2Name) + ' GEWINNT!'}
          </Text>

          <View style={styles.resultScores}>
            <View style={[styles.resultPlayer, isP1Winner && styles.resultPlayerWin, { borderColor: p1Color }]}>
              <Text style={[styles.resultPlayerName, { color: p1Color }]}>{p1Name}</Text>
              <Text style={[styles.resultPlayerScore, { color: isP1Winner ? p1Color : colors.textMuted }]}>
                {p1Count}
              </Text>
              <Text style={styles.resultPlayerLabel}>TAPS</Text>
            </View>

            <Text style={styles.resultVs}>VS</Text>

            <View style={[styles.resultPlayer, isP2Winner && styles.resultPlayerWin, { borderColor: p2Color }]}>
              <Text style={[styles.resultPlayerName, { color: p2Color }]}>{p2Name}</Text>
              <Text style={[styles.resultPlayerScore, { color: isP2Winner ? p2Color : colors.textMuted }]}>
                {p2Count}
              </Text>
              <Text style={styles.resultPlayerLabel}>TAPS</Text>
            </View>
          </View>

          {!isTie && (
            <Text style={styles.resultMargin}>
              Vorsprung: {Math.abs(p1Count - p2Count)} Taps
            </Text>
          )}

          <View style={styles.resultActions}>
            <TouchableOpacity style={styles.rematchBtn} onPress={resetGame}>
              <Text style={styles.rematchBtnText}>NOCHMAL</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.homeBtn} onPress={handleExit}>
              <Text style={styles.homeBtnText}>ZURUECK</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    );
  }

  // Playing screen
  return (
    <View style={[styles.gameScreen, { width, height }]}>
      <StatusBar hidden />

      <View style={styles.timerBarContainer}>
        <View style={[styles.timerBarFill, {
          width: (timerPercent * 100) + '%',
          backgroundColor: timerColor,
        }]} />
        <Text style={[styles.timerText, { color: timerColor }]}>{timeLeft}s</Text>
      </View>

      <View style={styles.splitContainer}>
        <TouchableOpacity
          style={[styles.playerZone, styles.playerZoneLeft, { width: width / 2, height: height - 50 }]}
          onPress={handleP1Tap}
          activeOpacity={1}
        >
          <CounterDisplay count={p1Count} color={p1Color} label={p1Name} side="left" />
        </TouchableOpacity>

        <View style={styles.divider} />

        <TouchableOpacity
          style={[styles.playerZone, styles.playerZoneRight, { width: width / 2, height: height - 50 }]}
          onPress={handleP2Tap}
          activeOpacity={1}
          disabled={masterMoMode}
        >
          {masterMoMode && (
            <View style={styles.moOverlay} pointerEvents="none">
              <Text style={styles.moEmoji}>🤖</Text>
            </View>
          )}
          <CounterDisplay count={p2Count} color={p2Color} label={p2Name} side="right" />
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  fullScreen: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  exitBtn: {
    position: 'absolute',
    top: 50,
    right: 20,
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.surfaceElevated,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 10,
  },
  exitBtnText: {
    color: colors.textMuted,
    fontSize: 16,
    fontWeight: '700',
  },
  countdownContainer: {
    alignItems: 'center',
  },
  getReady: {
    color: colors.textMuted,
    fontSize: 16,
    fontWeight: '700',
    letterSpacing: 4,
    marginBottom: 16,
  },
  countdownNumber: {
    color: colors.primary,
    fontSize: 120,
    fontWeight: '900',
    lineHeight: 130,
  },
  countdownSub: {
    color: colors.textMuted,
    fontSize: 14,
    marginTop: 16,
    fontWeight: '500',
  },
  gameScreen: {
    backgroundColor: colors.background,
    overflow: 'hidden',
  },
  timerBarContainer: {
    height: 50,
    backgroundColor: colors.surface,
    justifyContent: 'center',
    alignItems: 'center',
    position: 'relative',
    overflow: 'hidden',
  },
  timerBarFill: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    opacity: 0.25,
  },
  timerText: {
    fontSize: 22,
    fontWeight: '900',
    letterSpacing: 1,
  },
  splitContainer: {
    flex: 1,
    flexDirection: 'row',
  },
  playerZone: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  playerZoneLeft: {
    backgroundColor: '#FF3B3010',
  },
  playerZoneRight: {
    backgroundColor: '#007AFF10',
  },
  divider: {
    width: 2,
    backgroundColor: colors.border,
  },
  counterWrapper: {
    alignItems: 'center',
  },
  counterWrapperRight: {
    alignItems: 'center',
  },
  playerLabel: {
    fontSize: 16,
    fontWeight: '800',
    letterSpacing: 1,
    marginBottom: 8,
    textTransform: 'uppercase',
  },
  counter: {
    fontSize: 88,
    fontWeight: '900',
    lineHeight: 96,
  },
  tapHint: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 2,
    marginTop: 16,
  },
  moOverlay: {
    position: 'absolute',
    top: 20,
    alignItems: 'center',
  },
  moEmoji: {
    fontSize: 40,
  },
  resultScreen: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 30,
  },
  resultTitle: {
    color: colors.text,
    fontSize: 26,
    fontWeight: '900',
    textAlign: 'center',
    marginBottom: 36,
    letterSpacing: -0.5,
  },
  resultScores: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    marginBottom: 20,
  },
  resultPlayer: {
    backgroundColor: colors.surface,
    borderRadius: 16,
    padding: 24,
    alignItems: 'center',
    borderWidth: 2,
    minWidth: 120,
  },
  resultPlayerWin: {
    backgroundColor: colors.surfaceElevated,
  },
  resultPlayerName: {
    fontSize: 14,
    fontWeight: '700',
    marginBottom: 8,
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  resultPlayerScore: {
    fontSize: 56,
    fontWeight: '900',
    lineHeight: 60,
  },
  resultPlayerLabel: {
    color: colors.textMuted,
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 2,
    marginTop: 4,
  },
  resultVs: {
    color: colors.textMuted,
    fontSize: 20,
    fontWeight: '900',
    letterSpacing: 2,
  },
  resultMargin: {
    color: colors.textMuted,
    fontSize: 14,
    marginBottom: 32,
    fontWeight: '500',
  },
  resultActions: {
    gap: 12,
    alignItems: 'center',
    marginTop: 16,
  },
  rematchBtn: {
    backgroundColor: colors.primary,
    borderRadius: 14,
    paddingHorizontal: 40,
    paddingVertical: 16,
  },
  rematchBtnText: {
    color: colors.text,
    fontSize: 17,
    fontWeight: '800',
    letterSpacing: 1,
  },
  homeBtn: {
    backgroundColor: colors.surface,
    borderRadius: 14,
    paddingHorizontal: 40,
    paddingVertical: 14,
    borderWidth: 1,
    borderColor: colors.border,
  },
  homeBtnText: {
    color: colors.textMuted,
    fontSize: 15,
    fontWeight: '600',
  },
});
