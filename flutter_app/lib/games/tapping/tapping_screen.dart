import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../ui/theme/app_theme.dart';
import '../../core/state/game_state_provider.dart';
import '../../core/network/nearby_service.dart';
import '../../core/models/game_message.dart';
import '../result_screen.dart';

class TappingScreen extends ConsumerStatefulWidget {
  const TappingScreen({super.key});

  @override
  ConsumerState<TappingScreen> createState() => _TappingScreenState();
}

class _TappingScreenState extends ConsumerState<TappingScreen>
    with TickerProviderStateMixin {
  static const int gameDuration = 15;
  static const int suddenDeathDuration = 5;

  int _p1Taps = 0;
  int _p2Taps = 0;
  int _timeLeft = gameDuration;
  bool _isRunning = false;
  bool _isFinished = false;
  bool _isSuddenDeath = false;
  Timer? _timer;
  Timer? _syncTimer;
  StreamSubscription? _msgSub;

  late AnimationController _pulseCtrl1;
  late AnimationController _pulseCtrl2;

  @override
  void initState() {
    super.initState();
    _pulseCtrl1 = AnimationController(vsync: this, duration: 100.ms);
    _pulseCtrl2 = AnimationController(vsync: this, duration: 100.ms);
    _listenToMessages();
    _startCountdown();
  }

  void _listenToMessages() {
    final nearby = ref.read(nearbyServiceProvider);
    _msgSub = nearby.messageStream.listen((msg) {
      if (!mounted) return;
      if (msg.type == MessageType.playerInput) {
        final tap = msg.data['tap'] as bool? ?? false;
        if (tap && _isRunning && !_isFinished) {
          setState(() => _p2Taps++);
          _pulseCtrl2.forward().then((_) => _pulseCtrl2.reverse());
        }
      }
      if (msg.type == MessageType.gameState) {
        // Sync von Host
        final p1 = msg.data['p1'] as int? ?? _p1Taps;
        final p2 = msg.data['p2'] as int? ?? _p2Taps;
        setState(() {
          _p1Taps = p1;
          _p2Taps = p2;
        });
      }
    });
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isRunning = true);
        _startTimer();
        _startSyncTimer();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        t.cancel();
        _onTimeUp();
      }
    });
  }

  void _startSyncTimer() {
    final session = ref.read(sessionProvider);
    if (!session.isHost) return;
    // Host sendet alle 200ms den GameState
    _syncTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_isRunning || _isFinished) return;
      final nearby = ref.read(nearbyServiceProvider);
      nearby.sendMessage(GameMessage(
        type: MessageType.gameState,
        data: {'p1': _p1Taps, 'p2': _p2Taps, 'timeLeft': _timeLeft},
      ));
    });
  }

  void _onTimeUp() {
    if (_p1Taps == _p2Taps && !_isSuddenDeath) {
      setState(() {
        _isSuddenDeath = true;
        _timeLeft = suddenDeathDuration;
        _isRunning = true;
      });
      _startTimer();
      return;
    }
    setState(() {
      _isRunning = false;
      _isFinished = true;
    });
    _sendResult();
  }

  void _sendResult() {
    final session = ref.read(sessionProvider);
    if (!session.isHost) return;
    int winner;
    if (_p1Taps > _p2Taps) {
      winner = 1;
    } else if (_p2Taps > _p1Taps) {
      winner = 2;
    } else {
      winner = 0; // Draw
    }
    final nearby = ref.read(nearbyServiceProvider);
    nearby.sendMessage(GameMessage.gameOver(winner, [_p1Taps, _p2Taps]));

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _navigateToResult(winner);
    });
  }

  void _onLocalTap() {
    if (!_isRunning || _isFinished) return;
    HapticFeedback.lightImpact();
    final session = ref.read(sessionProvider);
    final isP1 = session.isHost;
    setState(() {
      if (isP1) {
        _p1Taps++;
        _pulseCtrl1.forward().then((_) => _pulseCtrl1.reverse());
      } else {
        _p2Taps++;
        _pulseCtrl2.forward().then((_) => _pulseCtrl2.reverse());
      }
    });
    final nearby = ref.read(nearbyServiceProvider);
    nearby.sendMessage(GameMessage.playerInput(
      playerId: isP1 ? 1 : 2,
      tap: true,
    ));
  }

  void _navigateToResult(int winner) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          winner: winner,
          p1Score: _p1Taps,
          p2Score: _p2Taps,
          gameTitle: 'TAPPING WAR',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _syncTimer?.cancel();
    _msgSub?.cancel();
    _pulseCtrl1.dispose();
    _pulseCtrl2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final total = _p1Taps + _p2Taps;
    final p1Ratio = total == 0 ? 0.5 : _p1Taps / total;

    return Scaffold(
      backgroundColor: SlapColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildScoreBar(p1Ratio),
            _buildTimer(),
            if (_isSuddenDeath) _buildSuddenDeathBanner(),
            Expanded(
              child: Row(
                children: [
                  _buildTapZone(
                    isLeft: true,
                    taps: _p1Taps,
                    name: session.player1?.name ?? 'P1',
                    color: SlapColors.player1,
                    pulse: _pulseCtrl1,
                  ),
                  _buildTapZone(
                    isLeft: false,
                    taps: _p2Taps,
                    name: session.player2?.name ?? 'P2',
                    color: SlapColors.player2,
                    pulse: _pulseCtrl2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👆', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text(
            'TAPPING WAR',
            style: TextStyle(
              color: SlapColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBar(double p1Ratio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_p1Taps',
                style: const TextStyle(
                  color: SlapColors.player1,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              Text(
                '$_p2Taps',
                style: const TextStyle(
                  color: SlapColors.player2,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: 100.ms,
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: (_p1Taps * 100).toInt() + 1,
                    child: Container(color: SlapColors.player1),
                  ),
                  Expanded(
                    flex: (_p2Taps * 100).toInt() + 1,
                    child: Container(color: SlapColors.player2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    final isLow = _timeLeft <= 5;
    return AnimatedContainer(
      duration: 300.ms,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      decoration: BoxDecoration(
        color: isLow
            ? SlapColors.neonPink.withOpacity(0.15)
            : SlapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _isRunning ? '$_timeLeft' : (_isFinished ? 'FERTIG!' : 'BEREIT...'),
        style: TextStyle(
          color: isLow ? SlapColors.neonPink : SlapColors.neonYellow,
          fontSize: 32,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildSuddenDeathBanner() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: SlapColors.neonOrange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SlapColors.neonOrange),
      ),
      child: const Text(
        '⚡ SUDDEN DEATH ⚡',
        style: TextStyle(
          color: SlapColors.neonOrange,
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 2,
        ),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          color: SlapColors.neonOrange,
          duration: 800.ms,
        );
  }

  Widget _buildTapZone({
    required bool isLeft,
    required int taps,
    required String name,
    required Color color,
    required AnimationController pulse,
  }) {
    final session = ref.read(sessionProvider);
    final isMyZone =
        (isLeft && session.isHost) || (!isLeft && !session.isHost);

    return Expanded(
      child: GestureDetector(
        onTapDown: isMyZone ? (_) => _onLocalTap() : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05 + pulse.value * 0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: color.withOpacity(0.3 + pulse.value * 0.5),
                  width: 2 + pulse.value * 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(pulse.value * 0.4),
                    blurRadius: 30,
                    spreadRadius: pulse.value * 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isMyZone)
                    Text(
                      '👆',
                      style: TextStyle(
                        fontSize: 64 + pulse.value * 12,
                      ),
                    )
                  else
                    const Text('👀', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$taps',
                    style: TextStyle(
                      color: color,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (isMyZone && _isRunning)
                    Text(
                      'TIPPEN!',
                      style: TextStyle(
                        color: color.withOpacity(0.6),
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
