import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/game_message.dart';
import '../../core/network/nearby_service.dart';
import '../../core/state/game_state_provider.dart';
import '../../ui/theme/app_theme.dart';
import '../result_screen.dart';
import 'football_game.dart';

class FootballScreen extends ConsumerStatefulWidget {
  const FootballScreen({super.key});

  @override
  ConsumerState<FootballScreen> createState() => _FootballScreenState();
}

class _FootballScreenState extends ConsumerState<FootballScreen> {
  late FootballGame _game;
  StreamSubscription? _msgSub;
  Timer? _inputTimer;

  int _score1 = 0;
  int _score2 = 0;
  int _timeLeft = 120;
  String? _goalBanner;
  Timer? _bannerTimer;

  // Joystick state
  Offset? _joystickCenter;
  Offset _joystickDelta = Offset.zero;
  bool _joystickActive = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _game = FootballGame(
      isHost: session.isHost,
      localPlayerNum: session.isHost ? 1 : 2,
    );

    _game.onGoal = (scorer, s1, s2) {
      if (mounted) {
        setState(() {
          _score1 = s1;
          _score2 = s2;
          _goalBanner = scorer == 1 ? '⚽ BLAU TRIFFT!' : '⚽ ROT TRIFFT!';
        });
        _bannerTimer?.cancel();
        _bannerTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _goalBanner = null);
        });
      }
    };

    _game.onGameOver = (winner, s1, s2) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              winner: winner,
              p1Score: s1,
              p2Score: s2,
              gameTitle: 'FUSSBALL 1v1',
            ),
          ),
        );
      }
    };

    _game.onStateUpdate = (data) {
      final nearby = ref.read(nearbyServiceProvider);
      nearby.sendMessage(GameMessage(
        type: MessageType.gameState,
        data: data,
      ));
      if (mounted) {
        setState(() {
          _score1 = (_game.score1);
          _score2 = (_game.score2);
          _timeLeft = _game.timeLeft.ceil();
        });
      }
    };

    _listenToMessages();

    if (session.isHost) {
      _startInputTimer();
    }
  }

  void _listenToMessages() {
    final nearby = ref.read(nearbyServiceProvider);
    _msgSub = nearby.messageStream.listen((msg) {
      if (!mounted) return;
      if (msg.type == MessageType.playerInput) {
        _game.applyRemoteInput(msg.data);
      }
      if (msg.type == MessageType.gameState) {
        _game.applyRemoteState(msg.data);
        if (mounted) {
          setState(() {
            _score1 = _game.score1;
            _score2 = _game.score2;
            _timeLeft = _game.timeLeft.ceil();
          });
        }
      }
    });
  }

  void _startInputTimer() {
    // Client sends input 20x/sec
    _inputTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final session = ref.read(sessionProvider);
      if (!session.isHost) {
        final nearby = ref.read(nearbyServiceProvider);
        final j = _joystickDelta;
        nearby.sendMessage(GameMessage.playerInput(
          playerId: 2,
          joystickX: j.dx,
          joystickY: j.dy,
        ));
      }
    });
  }

  void _updateJoystick(Offset delta) {
    final maxR = 40.0;
    final len = delta.distance;
    final clamped = len > maxR ? delta / len * maxR : delta;
    setState(() => _joystickDelta = clamped / maxR);
    _game.setJoystick(
      _game.localJoystick..setValues(_joystickDelta.dx, _joystickDelta.dy),
    );

    // Client sends input immediately on change
    final session = ref.read(sessionProvider);
    if (!session.isHost) {
      final nearby = ref.read(nearbyServiceProvider);
      nearby.sendMessage(GameMessage.playerInput(
        playerId: 2,
        joystickX: _joystickDelta.dx,
        joystickY: _joystickDelta.dy,
      ));
    }
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _inputTimer?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  String _formatTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final p1Name = session.player1?.name ?? 'P1';
    final p2Name = session.player2?.name ?? 'P2';

    return Scaffold(
      backgroundColor: SlapColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Scoreboard
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ScoreBox(name: p1Name, score: _score1, color: SlapColors.player1),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: SlapColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatTime(_timeLeft),
                      style: const TextStyle(
                        color: SlapColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _ScoreBox(name: p2Name, score: _score2, color: SlapColors.player2),
                ],
              ),
            ),

            // Game field
            Expanded(
              child: Stack(
                children: [
                  GameWidget(game: _game),
                  if (_goalBanner != null)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        decoration: BoxDecoration(
                          color: SlapColors.neonYellow.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _goalBanner!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Joystick area
            Container(
              height: 160,
              color: SlapColors.bgCard,
              child: GestureDetector(
                onPanStart: (d) {
                  setState(() {
                    _joystickCenter = d.localPosition;
                    _joystickActive = true;
                  });
                },
                onPanUpdate: (d) {
                  if (_joystickCenter != null) {
                    _updateJoystick(d.localPosition - _joystickCenter!);
                  }
                },
                onPanEnd: (_) {
                  setState(() {
                    _joystickActive = false;
                    _joystickDelta = Offset.zero;
                  });
                  _game.setJoystick(_game.localJoystick..setZero());
                },
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        'JOYSTICK – ziehe zum Bewegen',
                        style: TextStyle(
                          color: SlapColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_joystickCenter != null && _joystickActive)
                      ...[
                        // Base circle
                        Positioned(
                          left: _joystickCenter!.dx - 40,
                          top: _joystickCenter!.dy - 40,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: SlapColors.textMuted,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        // Thumb
                        Positioned(
                          left: _joystickCenter!.dx + _joystickDelta.dx * 40 - 20,
                          top: _joystickCenter!.dy + _joystickDelta.dy * 40 - 20,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: SlapColors.neonBlue,
                            ),
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String name;
  final int score;
  final Color color;

  const _ScoreBox({required this.name, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
