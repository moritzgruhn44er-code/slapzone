import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  StatusBar,
  Modal,
} from 'react-native';
import colors from '../theme/colors';
import TapWarScreen from '../games/TapWar/TapWarScreen';

export default function DuelScreen({ route }) {
  const [activeGame, setActiveGame] = useState(null);

  const games = [
    {
      id: 'tapwar',
      title: 'Tap War',
      description: 'Wer tippt mehr in 10 Sekunden?',
      emoji: '👆',
      color: colors.primary,
    },
    {
      id: 'reactionrush',
      title: 'Reaction Rush',
      emoji: '⚡',
      description: 'Kommt bald',
      disabled: true,
      color: colors.textMuted,
    },
    {
      id: 'mathsprint',
      title: 'Math Sprint',
      emoji: '➕',
      description: 'Kommt bald',
      disabled: true,
      color: colors.textMuted,
    },
  ];

  const renderGame = () => {
    if (activeGame === 'tapwar') {
      return <TapWarScreen onExit={() => setActiveGame(null)} />;
    }
    return null;
  };

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar barStyle=light-content backgroundColor={colors.background} />
      <View style={styles.container}>
        <View style={styles.header}>
          <Text style={styles.title}>⚔️  Duell</Text>
          <Text style={styles.subtitle}>Lokaler Mehrspieler-Modus</Text>
        </View>

        <View style={styles.playerBadges}>
          <View style={[styles.playerBadge, { backgroundColor: colors.playerLeft + '22', borderColor: colors.playerLeft }]}>
            <Text style={[styles.playerBadgeText, { color: colors.playerLeft }]}>👤 Spieler 1</Text>
          </View>
          <Text style={styles.vs}>VS</Text>
          <View style={[styles.playerBadge, { backgroundColor: colors.playerRight + '22', borderColor: colors.playerRight }]}>
            <Text style={[styles.playerBadgeText, { color: colors.playerRight }]}>👤 Spieler 2</Text>
          </View>
        </View>

        <Text style={styles.sectionLabel}>SPIEL AUSWÄHLEN</Text>

        {games.map((game) => (
          <TouchableOpacity
            key={game.id}
            style={[styles.gameButton, game.disabled && styles.gameButtonDisabled]}
            onPress={() => !game.disabled && setActiveGame(game.id)}
            disabled={game.disabled}
            activeOpacity={0.75}
          >
            <Text style={styles.gameEmoji}>{game.emoji}</Text>
            <View style={styles.gameInfo}>
              <Text style={[styles.gameName, { color: game.disabled ? colors.textMuted : colors.text }]}>
                {game.title}
              </Text>
              <Text style={styles.gameDesc}>{game.description}</Text>
            </View>
            {!game.disabled && (
              <View style={[styles.playBtn, { backgroundColor: game.color }]}>
                <Text style={styles.playBtnText}>PLAY</Text>
              </View>
            )}
          </TouchableOpacity>
        ))}
      </View>

      <Modal
        visible={activeGame !== null}
        animationType=slide
        statusBarTranslucent
        onRequestClose={() => setActiveGame(null)}
      >
        {renderGame()}
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: colors.background,
  },
  container: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 10,
  },
  header: {
    paddingTop: 16,
    marginBottom: 24,
  },
  title: {
    color: colors.text,
    fontSize: 28,
    fontWeight: '900',
    letterSpacing: -0.5,
  },
  subtitle: {
    color: colors.textMuted,
    fontSize: 14,
    marginTop: 4,
  },
  playerBadges: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 28,
    gap: 12,
  },
  playerBadge: {
    borderWidth: 1.5,
    borderRadius: 10,
    paddingHorizontal: 16,
    paddingVertical: 8,
    flex: 1,
    alignItems: 'center',
  },
  playerBadgeText: {
    fontSize: 13,
    fontWeight: '700',
  },
  vs: {
    color: colors.textMuted,
    fontSize: 18,
    fontWeight: '900',
    letterSpacing: 2,
  },
  sectionLabel: {
    color: colors.textMuted,
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 1.5,
    marginBottom: 12,
  },
  gameButton: {
    backgroundColor: colors.surface,
    borderRadius: 14,
    padding: 16,
    marginBottom: 10,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  gameButtonDisabled: {
    opacity: 0.4,
  },
  gameEmoji: {
    fontSize: 28,
    marginRight: 14,
  },
  gameInfo: {
    flex: 1,
  },
  gameName: {
    fontSize: 17,
    fontWeight: '700',
    marginBottom: 2,
  },
  gameDesc: {
    color: colors.textMuted,
    fontSize: 13,
  },
  playBtn: {
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 8,
    marginLeft: 10,
  },
  playBtnText: {
    color: colors.text,
    fontSize: 12,
    fontWeight: '800',
    letterSpacing: 1,
  },
});
