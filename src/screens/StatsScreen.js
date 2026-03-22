import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  StatusBar,
  ScrollView,
  TouchableOpacity,
  Alert,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import colors from '../theme/colors';

const STATS_KEY = '@slapzone_stats';

export const saveGameResult = async (game, winner, score1, score2) => {
  try {
    const raw = await AsyncStorage.getItem(STATS_KEY);
    const stats = raw ? JSON.parse(raw) : { games: [] };
    stats.games.push({
      game,
      winner,
      score1,
      score2,
      date: new Date().toISOString(),
    });
    await AsyncStorage.setItem(STATS_KEY, JSON.stringify(stats));
  } catch (e) {
    console.log('Stats save error:', e);
  }
};

export default function StatsScreen() {
  const [stats, setStats] = useState({ games: [] });

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    try {
      const raw = await AsyncStorage.getItem(STATS_KEY);
      if (raw) setStats(JSON.parse(raw));
    } catch (e) {}
  };

  const clearStats = () => {
    Alert.alert(
      'Stats löschen?',
      'Alle Spielstatistiken werden unwiderruflich gelöscht.',
      [
        { text: 'Abbrechen', style: 'cancel' },
        {
          text: 'Löschen',
          style: 'destructive',
          onPress: async () => {
            await AsyncStorage.removeItem(STATS_KEY);
            setStats({ games: [] });
          },
        },
      ]
    );
  };

  const p1Wins = stats.games.filter(g => g.winner === 'player1').length;
  const p2Wins = stats.games.filter(g => g.winner === 'player2').length;
  const total = stats.games.length;

  const gameBreakdown = stats.games.reduce((acc, g) => {
    acc[g.game] = (acc[g.game] || 0) + 1;
    return acc;
  }, {});

  const recentGames = [...stats.games].reverse().slice(0, 10);

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar barStyle=light-content backgroundColor={colors.background} />
      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <Text style={styles.title}>📊  Stats</Text>
          <TouchableOpacity onPress={clearStats} style={styles.clearBtn}>
            <Text style={styles.clearBtnText}>Löschen</Text>
          </TouchableOpacity>
        </View>

        {total === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyEmoji}>🎮</Text>
            <Text style={styles.emptyTitle}>Noch keine Spiele</Text>
            <Text style={styles.emptySubtitle}>Spiel ein Duell, um Stats zu sehen.</Text>
          </View>
        ) : (
          <>
            <View style={styles.overviewRow}>
              <View style={[styles.statCard, { borderColor: colors.playerLeft }]}>
                <Text style={[styles.statNumber, { color: colors.playerLeft }]}>{p1Wins}</Text>
                <Text style={styles.statLabel}>Spieler 1 Siege</Text>
              </View>
              <View style={styles.statCardCenter}>
                <Text style={styles.statNumberCenter}>{total}</Text>
                <Text style={styles.statLabelCenter}>Spiele gesamt</Text>
              </View>
              <View style={[styles.statCard, { borderColor: colors.playerRight }]}>
                <Text style={[styles.statNumber, { color: colors.playerRight }]}>{p2Wins}</Text>
                <Text style={styles.statLabel}>Spieler 2 Siege</Text>
              </View>
            </View>

            {Object.keys(gameBreakdown).length > 0 && (
              <>
                <Text style={styles.sectionLabel}>NACH SPIEL</Text>
                {Object.entries(gameBreakdown).map(([game, count]) => (
                  <View key={game} style={styles.breakdownRow}>
                    <Text style={styles.breakdownGame}>{game}</Text>
                    <Text style={styles.breakdownCount}>{count}x gespielt</Text>
                  </View>
                ))}
              </>
            )}

            <Text style={styles.sectionLabel}>LETZTE SPIELE</Text>
            {recentGames.map((g, i) => (
              <View key={i} style={styles.gameRow}>
                <Text style={styles.gameRowGame}>{g.game}</Text>
                <Text style={[
                  styles.gameRowWinner,
                  { color: g.winner === 'player1' ? colors.playerLeft : g.winner === 'player2' ? colors.playerRight : colors.accent }
                ]}>
                  {g.winner === 'player1' ? 'P1 gewinnt' : g.winner === 'player2' ? 'P2 gewinnt' : 'Unentschieden'}
                </Text>
                <Text style={styles.gameRowScore}>{g.score1} – {g.score2}</Text>
              </View>
            ))}
          </>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  container: { flex: 1 },
  content: { paddingHorizontal: 20, paddingBottom: 30 },
  header: {
    paddingTop: 16,
    marginBottom: 24,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  title: { color: colors.text, fontSize: 28, fontWeight: '900', letterSpacing: -0.5 },
  clearBtn: {
    backgroundColor: colors.surface,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderWidth: 1,
    borderColor: colors.border,
  },
  clearBtnText: { color: colors.primary, fontSize: 13, fontWeight: '600' },
  emptyState: { alignItems: 'center', paddingTop: 80 },
  emptyEmoji: { fontSize: 60, marginBottom: 16 },
  emptyTitle: { color: colors.text, fontSize: 20, fontWeight: '700', marginBottom: 8 },
  emptySubtitle: { color: colors.textMuted, fontSize: 14 },
  overviewRow: { flexDirection: 'row', gap: 10, marginBottom: 28 },
  statCard: {
    flex: 1,
    backgroundColor: colors.surface,
    borderRadius: 14,
    padding: 16,
    alignItems: 'center',
    borderWidth: 1.5,
  },
  statNumber: { fontSize: 36, fontWeight: '900' },
  statLabel: { color: colors.textMuted, fontSize: 11, fontWeight: '600', textAlign: 'center', marginTop: 4 },
  statCardCenter: {
    flex: 1,
    backgroundColor: colors.surface,
    borderRadius: 14,
    padding: 16,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  statNumberCenter: { color: colors.text, fontSize: 36, fontWeight: '900' },
  statLabelCenter: { color: colors.textMuted, fontSize: 11, fontWeight: '600', textAlign: 'center', marginTop: 4 },
  sectionLabel: {
    color: colors.textMuted,
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 1.5,
    marginBottom: 10,
    marginTop: 4,
  },
  breakdownRow: {
    backgroundColor: colors.surface,
    borderRadius: 10,
    padding: 12,
    marginBottom: 6,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  breakdownGame: { color: colors.text, fontSize: 14, fontWeight: '600' },
  breakdownCount: { color: colors.textMuted, fontSize: 13 },
  gameRow: {
    backgroundColor: colors.surface,
    borderRadius: 10,
    padding: 12,
    marginBottom: 6,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  gameRowGame: { color: colors.text, fontSize: 13, fontWeight: '600', flex: 1 },
  gameRowWinner: { fontSize: 12, fontWeight: '700', flex: 1, textAlign: 'center' },
  gameRowScore: { color: colors.textMuted, fontSize: 13, flex: 1, textAlign: 'right' },
});
