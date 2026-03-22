import React, { useState, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  StatusBar,
  Modal,
  ScrollView,
} from 'react-native';
import colors from '../theme/colors';
import MasterMo from '../components/MasterMo';
import TapWarScreen from '../games/TapWar/TapWarScreen';

const DIFFICULTY_LEVELS = [
  { id: 'easy', label: 'Anfänger', description: 'Mo schläft fast', emoji: '😴', color: colors.success },
  { id: 'medium', label: 'Normal', description: 'Mo ist aufgeweckt', emoji: '😏', color: colors.accent },
  { id: 'hard', label: 'Brutal', description: 'Mo zeigt keine Gnade', emoji: '😈', color: colors.primary },
];

export default function MasterMoScreen() {
  const [selectedDifficulty, setSelectedDifficulty] = useState('medium');
  const [activeGame, setActiveGame] = useState(null);
  const [lastResult, setLastResult] = useState(null);

  const currentDiff = DIFFICULTY_LEVELS.find(d => d.id === selectedDifficulty);

  const getResultComment = (result) => {
    if (!result) return null;
    if (result.winner === 'player') {
      return ['Glück gehabt.', 'Das war knapp.', 'Einmal ist keinmal.'][Math.floor(Math.random() * 3)];
    } else {
      return ['War nix.', 'Zu langsam.', 'Pathetic.'][Math.floor(Math.random() * 3)];
    }
  };

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar barStyle=light-content backgroundColor={colors.background} />
      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <Text style={styles.title}>Master Mo</Text>
          <Text style={styles.subtitle}>Trau dich, gegen die KI anzutreten.</Text>
        </View>

        <View style={styles.moSection}>
          <MasterMo
            comment={lastResult ? getResultComment(lastResult) : undefined}
            size=large
          />
        </View>

        {lastResult && (
          <View style={[
            styles.resultBanner,
            { borderColor: lastResult.winner === 'player' ? colors.success : colors.primary }
          ]}>
            <Text style={[
              styles.resultText,
              { color: lastResult.winner === 'player' ? colors.success : colors.primary }
            ]}>
              {lastResult.winner === 'player' ? '🏆 Du hast gewonnen!' : '💀 Master Mo gewinnt!'}
            </Text>
            <Text style={styles.resultScore}>
              Du: {lastResult.playerScore}  |  Mo: {lastResult.moScore}
            </Text>
          </View>
        )}

        <Text style={styles.sectionLabel}>SCHWIERIGKEITSGRAD</Text>
        <View style={styles.difficultyRow}>
          {DIFFICULTY_LEVELS.map((diff) => (
            <TouchableOpacity
              key={diff.id}
              style={[
                styles.diffButton,
                selectedDifficulty === diff.id && { borderColor: diff.color, backgroundColor: diff.color + '18' },
              ]}
              onPress={() => setSelectedDifficulty(diff.id)}
              activeOpacity={0.75}
            >
              <Text style={styles.diffEmoji}>{diff.emoji}</Text>
              <Text style={[
                styles.diffLabel,
                selectedDifficulty === diff.id && { color: diff.color },
              ]}>
                {diff.label}
              </Text>
              <Text style={styles.diffDesc}>{diff.description}</Text>
            </TouchableOpacity>
          ))}
        </View>

        <Text style={styles.sectionLabel}>SPIEL WÄHLEN</Text>
        <TouchableOpacity
          style={styles.gameButton}
          onPress={() => setActiveGame('tapwar')}
          activeOpacity={0.8}
        >
          <Text style={styles.gameEmoji}>👆</Text>
          <View style={styles.gameInfo}>
            <Text style={styles.gameName}>Tap War vs Mo</Text>
            <Text style={styles.gameDesc}>Mo tippt automatisch. Bist du schneller?</Text>
          </View>
          <View style={styles.playBtn}>
            <Text style={styles.playBtnText}>PLAY</Text>
          </View>
        </TouchableOpacity>
      </ScrollView>

      <Modal
        visible={activeGame !== null}
        animationType=slide
        statusBarTranslucent
        onRequestClose={() => setActiveGame(null)}
      >
        {activeGame === 'tapwar' && (
          <TapWarScreen
            onExit={(result) => {
              setActiveGame(null);
              if (result) setLastResult(result);
            }}
            masterMoMode
            difficulty={selectedDifficulty}
          />
        )}
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  container: { flex: 1 },
  content: { paddingHorizontal: 20, paddingBottom: 30 },
  header: { paddingTop: 16, marginBottom: 16 },
  title: {
    color: colors.text,
    fontSize: 28,
    fontWeight: '900',
    letterSpacing: -0.5,
  },
  subtitle: { color: colors.textMuted, fontSize: 14, marginTop: 4 },
  moSection: { alignItems: 'center', paddingVertical: 24 },
  resultBanner: {
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 14,
    marginBottom: 24,
    borderWidth: 1.5,
    alignItems: 'center',
  },
  resultText: { fontSize: 18, fontWeight: '800', marginBottom: 4 },
  resultScore: { color: colors.textMuted, fontSize: 14 },
  sectionLabel: {
    color: colors.textMuted,
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 1.5,
    marginBottom: 12,
  },
  difficultyRow: { flexDirection: 'row', gap: 8, marginBottom: 24 },
  diffButton: {
    flex: 1,
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 12,
    alignItems: 'center',
    borderWidth: 1.5,
    borderColor: colors.border,
  },
  diffEmoji: { fontSize: 22, marginBottom: 4 },
  diffLabel: { color: colors.text, fontSize: 12, fontWeight: '700', marginBottom: 2 },
  diffDesc: { color: colors.textMuted, fontSize: 10, textAlign: 'center' },
  gameButton: {
    backgroundColor: colors.surface,
    borderRadius: 14,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  gameEmoji: { fontSize: 28, marginRight: 14 },
  gameInfo: { flex: 1 },
  gameName: { color: colors.text, fontSize: 17, fontWeight: '700', marginBottom: 2 },
  gameDesc: { color: colors.textMuted, fontSize: 13 },
  playBtn: { backgroundColor: colors.primary, borderRadius: 8, paddingHorizontal: 14, paddingVertical: 8 },
  playBtnText: { color: colors.text, fontSize: 12, fontWeight: '800', letterSpacing: 1 },
});
