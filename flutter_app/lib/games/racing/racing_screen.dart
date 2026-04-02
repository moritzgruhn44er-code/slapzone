import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/game_message.dart';
import '../../core/network/nearby_service.dart';
import '../../core/state/game_state_provider.dart';
import '../../ui/theme/app_theme.dart';
import '../result_screen.dart';
import 'racing_game.dart';

class RacingScreen extends ConsumerStatefulWidget {
  const RacingScreen({super.key});

  @override
  ConsumerState<RacingScreen> createState() => _RacingScreenState();
}

class _RacingScreenState extends ConsumerState<RacingScreen> {
  late RacingGame _game;
  StreamSubscription? _msgSub;
  Timer? _inputTimer;

  int _lap1 = 0;
  int _lap2 = 0;
  double _raceTime = 0;
  String? _lapBanner;
  Timer? _bannerTimer;
  String _countdown = '3';
  bool _raceStarted = false;

  double _steer = 0;
  bool _braking = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _game = RacingGame(
      isHost: session.isHost,
      localPlayerNum: session.isHost ? 1 : 2,
    );

    _game.onLap = (playerNum, lap) {
      if (mounted) {
        setState(() {
          if (playerNum == 1) _lap1 = lap;
          else _lap2 = lap;
          _lapBanner = 'RUNDE $lap/${RacingGame.totalLaps} – ${playerNum == 1 ? "BLAU" : "ROT"}!';
        });
        _bannerTimer?.cancel();
        _bannerTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _lapBanner = null);
        });
      }
    };

    _game.onRaceOver = (winner) {
      if (mounted) {
        final l1 = _game.car1.lap;
        final l2 = _game.car2.lap;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              winner: winner,
              p1Score: l1,
              p2Score: l2,
              gameTitle: 'AUTO-RENNEN',
            ),
          ),
        );
      }
    };

    _game.onStateUpdate = (data) {
      final nearby = ref.read(nearbyServiceProvider);
      nearby.sendMessage(GameMessage(type: MessageType.gameState, data: data));
      if (mounted) {
        setState(() {
          _lap1 = _game.car1.lap;
          _lap2 = _game.car2.lap;
          _raceTime = _game.raceTime;
        });
      }
    };

    _listenToMessages();
    _startCountdown();

    // Client sends input 30x/sec
    _inputTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!ref.read(sessionProvider).isHost && _raceStarted) {
        final nearby = ref.read(nearbyServiceProvider);
        nearby.sendMessage(GameMessage(
          type: MessageType.playerInput,
          data: {'playerId': 2, 'steer': _steer, 'brake': _braking},
        ));
      }
    });
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _countdown = '2');
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _countdown = '1');
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() {
        _countdown = 'GO!';
        _raceStarted = true;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _countdown = '');
      });
    });
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
            _lap1 = _game.car1.lap;
            _lap2 = _game.car2.lap;
            _raceTime = _game.raceTime;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _inputTimer?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  String _fmt(double t) {
    final m = t ~/ 60;
    final s = (t % 60).toStringAsFixed(1);
    return '$m:${s.padLeft(4, '0')}';
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
            // HUD
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: SlapColors.bgCard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _LapInfo(name: p1Name, lap: _lap1, color: SlapColors.player1),
                  Text(
                    _fmt(_raceTime),
                    style: const TextStyle(color: SlapColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  _LapInfo(name: p2Name, lap: _lap2, color: SlapColors.player2),
                ],
              ),
            ),

            // Game
            Expanded(
              child: Stack(
                children: [
                  GameWidget(game: _game),
                  if (_countdown.isNotEmpty)
                    Center(
                      child: Text(
                        _countdown,
                        style: TextStyle(
                          color: _countdown == 'GO!' ? SlapColors.neonGreen : SlapColors.neonYellow,
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                        ),
                      ),
                    ),
                  if (_lapBanner != null)
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: SlapColors.neonYellow.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _lapBanner!,
                            style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Controls
            Container(
              height: 130,
              color: SlapColors.bgCard,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left steer
                  GestureDetector(
                    onTapDown: (_) { setState(() => _steer = -1); _game.setSteer(-1); },
                    onTapUp: (_) { if (_steer < 0) { setState(() => _steer = 0); _game.setSteer(0); } },
                    onTapCancel: () { if (_steer < 0) { setState(() => _steer = 0); _game.setSteer(0); } },
                    child: _ControlBtn(
                      icon: Icons.arrow_back_rounded,
                      color: SlapColors.neonBlue,
                      active: _steer < 0,
                    ),
                  ),

                  // Brake
                  GestureDetector(
                    onTapDown: (_) { setState(() => _braking = true); _game.setBrake(true); },
                    onTapUp: (_) { setState(() => _braking = false); _game.setBrake(false); },
                    onTapCancel: () { setState(() => _braking = false); _game.setBrake(false); },
                    child: _ControlBtn(
                      icon: Icons.stop_rounded,
                      color: SlapColors.neonOrange,
                      active: _braking,
                      label: 'BREMSE',
                    ),
                  ),

                  // Right steer
                  GestureDetector(
                    onTapDown: (_) { setState(() => _steer = 1); _game.setSteer(1); },
                    onTapUp: (_) { if (_steer > 0) { setState(() => _steer = 0); _game.setSteer(0); } },
                    onTapCancel: () { if (_steer > 0) { setState(() => _steer = 0); _game.setSteer(0); } },
                    child: _ControlBtn(
                      icon: Icons.arrow_forward_rounded,
                      color: SlapColors.neonBlue,
                      active: _steer > 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LapInfo extends StatelessWidget {
  final String name;
  final int lap;
  final Color color;
  const _LapInfo({required this.name, required this.lap, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(name, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          Text('Rd ${lap + 1}/${RacingGame.totalLaps}',
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      );
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool active;
  final String? label;
  const _ControlBtn({required this.icon, required this.color, required this.active, this.label});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.3) : SlapColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : color.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            if (label != null)
              Text(label!, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
