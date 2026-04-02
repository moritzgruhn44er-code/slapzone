import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../ui/theme/app_theme.dart';
import '../core/state/game_state_provider.dart';
import '../core/models/game_message.dart';
import '../core/network/nearby_service.dart';
import '../games/tapping/tapping_screen.dart';
import '../games/quiz/quiz_screen.dart';
import '../games/math/math_screen.dart';
import '../games/football/football_screen.dart';
import '../games/racing/racing_screen.dart';

class GameSelectScreen extends ConsumerWidget {
  const GameSelectScreen({super.key});

  static const _games = [
    _GameInfo(
      type: GameType.tapping,
      title: 'TAPPING WAR',
      emoji: '👆',
      desc: '15 Sek. – Wer hämmert schneller?',
      color: SlapColors.neonBlue,
    ),
    _GameInfo(
      type: GameType.quiz,
      title: 'QUIZ BATTLE',
      emoji: '🧠',
      desc: '10 Runden – Allgemeinwissen',
      color: SlapColors.neonPurple,
    ),
    _GameInfo(
      type: GameType.math,
      title: 'MATHE DUEL',
      emoji: '➕',
      desc: '8 Runden – Wer rechnet schneller?',
      color: SlapColors.neonGreen,
    ),
    _GameInfo(
      type: GameType.football,
      title: 'FUSSBALL 1v1',
      emoji: '⚽',
      desc: '2 Min – Top-Down Fußball',
      color: SlapColors.neonYellow,
    ),
    _GameInfo(
      type: GameType.racing,
      title: 'AUTO-RENNEN',
      emoji: '🏎️',
      desc: '3 Runden – Drift & Vollgas',
      color: SlapColors.neonOrange,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: SlapColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: SlapColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SPIEL WÄHLEN',
          style: TextStyle(
            color: SlapColors.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _games.length,
        itemBuilder: (context, i) {
          final game = _games[i];
          return _GameCard(
            game: game,
            onTap: game.comingSoon
                ? null
                : () => _startGame(context, ref, game),
          ).animate().fadeIn(delay: (i * 80).ms).slideX(begin: 0.3);
        },
      ),
    );
  }

  void _startGame(BuildContext context, WidgetRef ref, _GameInfo game) {
    ref.read(sessionProvider.notifier).selectGame(game.type);
    final nearby = ref.read(nearbyServiceProvider);
    nearby.sendMessage(GameMessage.gameStart(game.type.name));

    Widget screen;
    switch (game.type) {
      case GameType.tapping:
        screen = const TappingScreen();
        break;
      case GameType.quiz:
        screen = const QuizScreen();
        break;
      case GameType.math:
        screen = const MathScreen();
        break;
      case GameType.football:
        screen = const FootballScreen();
        break;
      case GameType.racing:
        screen = const RacingScreen();
        break;
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _GameCard extends StatelessWidget {
  final _GameInfo game;
  final VoidCallback? onTap;

  const _GameCard({required this.game, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: SlapColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: disabled
                  ? SlapColors.textMuted
                  : game.color.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: game.color.withOpacity(0.15),
                      blurRadius: 20,
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: game.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    game.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          game.title,
                          style: TextStyle(
                            color: game.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        if (disabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: SlapColors.textMuted.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'BALD',
                              style: TextStyle(
                                color: SlapColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.desc,
                      style: const TextStyle(
                        color: SlapColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!disabled)
                Icon(Icons.play_circle_filled, color: game.color, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameInfo {
  final GameType type;
  final String title;
  final String emoji;
  final String desc;
  final Color color;
  final bool comingSoon;

  const _GameInfo({
    required this.type,
    required this.title,
    required this.emoji,
    required this.desc,
    required this.color,
    this.comingSoon = false,
  });
}
