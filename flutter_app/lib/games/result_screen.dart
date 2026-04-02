import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../ui/theme/app_theme.dart';
import '../core/state/game_state_provider.dart';
import '../lobby/lobby_screen.dart';
import '../lobby/game_select_screen.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final int winner; // 1, 2, oder 0 für Draw
  final int p1Score;
  final int p2Score;
  final String gameTitle;

  const ResultScreen({
    super.key,
    required this.winner,
    required this.p1Score,
    required this.p2Score,
    required this.gameTitle,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiCtrl;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(vsync: this, duration: 2.seconds)
      ..forward();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final p1Name = session.player1?.name ?? 'Spieler 1';
    final p2Name = session.player2?.name ?? 'Spieler 2';
    final isDraw = widget.winner == 0;

    final winnerName = isDraw
        ? 'UNENTSCHIEDEN'
        : widget.winner == 1
            ? p1Name
            : p2Name;
    final winnerColor = isDraw
        ? SlapColors.neonYellow
        : widget.winner == 1
            ? SlapColors.player1
            : SlapColors.player2;

    return Scaffold(
      backgroundColor: SlapColors.bg,
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    winnerColor.withOpacity(0.08),
                    SlapColors.bg,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Game Title
                  Text(
                    widget.gameTitle,
                    style: const TextStyle(
                      color: SlapColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 32),

                  // Trophy
                  Text(
                    isDraw ? '🤝' : '🏆',
                    style: const TextStyle(fontSize: 80),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0, 0),
                        end: const Offset(1, 1),
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                      )
                      .then()
                      .animate(onPlay: (c) => c.repeat())
                      .moveY(
                        begin: 0,
                        end: -10,
                        duration: 1.5.seconds,
                        curve: Curves.easeInOut,
                      )
                      .then()
                      .moveY(
                        begin: -10,
                        end: 0,
                        duration: 1.5.seconds,
                        curve: Curves.easeInOut,
                      ),

                  const SizedBox(height: 24),

                  // Winner Text
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [winnerColor, winnerColor.withOpacity(0.7)],
                    ).createShader(bounds),
                    child: Text(
                      isDraw ? 'DRAW!' : '$winnerName\nGEWINNT!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                        height: 1.2,
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms).scale(
                        begin: const Offset(0.8, 0.8),
                        duration: 400.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 40),

                  // Score Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: SlapColors.bgCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: winnerColor.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: winnerColor.withOpacity(0.1),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ScoreColumn(
                          name: p1Name,
                          score: widget.p1Score,
                          color: SlapColors.player1,
                          isWinner: widget.winner == 1,
                        ),
                        Container(
                          width: 2,
                          height: 60,
                          color: SlapColors.textMuted.withOpacity(0.3),
                        ),
                        _ScoreColumn(
                          name: p2Name,
                          score: widget.p2Score,
                          color: SlapColors.player2,
                          isWinner: widget.winner == 2,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),

                  const SizedBox(height: 40),

                  // Buttons
                  if (session.isHost) ...[
                    SlapButton(
                      label: '🎮  NÄCHSTES SPIEL',
                      color: SlapColors.neonGreen,
                      onTap: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GameSelectScreen(),
                        ),
                        (route) => false,
                      ),
                    ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3),
                    const SizedBox(height: 12),
                  ],
                  SlapButton(
                    label: '🏠  HAUPTMENÜ',
                    color: SlapColors.textSecondary,
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LobbyScreen(),
                      ),
                      (route) => false,
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String name;
  final int score;
  final Color color;
  final bool isWinner;

  const _ScoreColumn({
    required this.name,
    required this.score,
    required this.color,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isWinner)
          const Text('👑', style: TextStyle(fontSize: 20)),
        Text(
          name,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 42,
          ),
        ),
      ],
    );
  }
}
