import React from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  StatusBar,
  SafeAreaView,
} from 'react-native';
import colors from '../theme/colors';
import GameCard from '../components/GameCard';

export default function HomeScreen({ navigation }) {
  const games = [
    {
      id: 'tapwar',
      title: 'Tap War',
      description: 'Wer tippt schneller? 10 Sekunden entscheiden.',
      emoji: '👆',
      badge: 'HOT',
      screen: 'TapWar',
    },
    {
      id: 'coming1',
      title: 'Reaction Rush',
      description: 'Blitzschnelle Reaktion gefragt. Kommt bald.',
      emoji: '⚡',
      disabled: true,
    },
    {
      id: 'coming2',
      title: 'Memory Clash',
      description: 'Gedächtnisduell gegen den Gegner. Kommt bald.',
      emoji: '🧠',
      disabled: true,
    },
    {
      id: 'coming3',
      title: 'Math Sprint',
      description: 'Mathe-Battle – schneller rechnen gewinnt. Kommt bald.',
      emoji: '➕',
      disabled: true,
    },
  ];

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar barStyle=light-content backgroundColor={colors.background} />
      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <Text style={styles.logo}>DUOCLASH</Text>
          <Text style={styles.tagline}>Wähle dein Spiel</Text>
        </View>
        <View style={styles.section}>
          <Text style={styles.sectionLabel}>VERFÜGBARE SPIELE</Text>
          {games.map((game) => (
            <GameCard
              key={game.id}
              title={game.title}
              description={game.description}
              emoji={game.emoji}
              badge={game.badge}
              disabled={game.disabled}
              onPress={() => {
                if (game.screen) {
                  navigation.navigate('Duell', { game: game.id });
                }
              }}
            />
          ))}
        </View>
      </ScrollView>
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
    backgroundColor: colors.background,
  },
  content: {
    paddingHorizontal: 20,
    paddingBottom: 30,
  },
  header: {
    paddingTop: 20,
    paddingBottom: 28,
  },
  logo: {
    color: colors.primary,
    fontSize: 32,
    fontWeight: '900',
    letterSpacing: 4,
    textTransform: 'uppercase',
  },
  tagline: {
    color: colors.textMuted,
    fontSize: 14,
    fontWeight: '500',
    marginTop: 4,
    letterSpacing: 0.5,
  },
  section: {
    marginBottom: 24,
  },
  sectionLabel: {
    color: colors.textMuted,
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 1.5,
    marginBottom: 12,
  },
});
