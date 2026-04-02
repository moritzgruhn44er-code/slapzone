import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../ui/theme/app_theme.dart';
import '../../core/state/game_state_provider.dart';
import '../../core/network/nearby_service.dart';
import '../../core/models/game_message.dart';
import '../result_screen.dart';

class MathScreen extends ConsumerStatefulWidget {
  const MathScreen({super.key});

  @override
  ConsumerState<MathScreen> createState() => _MathScreenState();
}

class _MathScreenState extends ConsumerState<MathScreen> {
  static const int totalRounds = 8;
  static const int questionTime = 15;

  final _rng = Random();
  int _currentRound = 0;
  int _p1Score = 0;
  int _p2Score = 0;
  int _timeLeft = questionTime;
  Timer? _timer;
  StreamSubscription? _msgSub;

  late int _num1, _num2;
  late String _operator;
  late int _correctAnswer;

  String _p1Input = '';
  String _p2Input = '';
  bool _p1Submitted = false;
  bool _p2Submitted = false;
  bool _p1Locked = false;
  bool _p2Locked = false;
  DateTime? _lockTime1;
  DateTime? _lockTime2;
  bool _roundOver = false;

  @override
  void initState() {
    super.initState();
    _generateQuestion();
    _listenToMessages();
    _startRound();
  }

  void _generateQuestion() {
    final round = _currentRound;
    if (round < 2) {
      // Addition / Subtraktion einfach
      _num1 = _rng.nextInt(20) + 5;
      _num2 = _rng.nextInt(20) + 5;
      _operator = _rng.nextBool() ? '+' : '-';
    } else if (round < 4) {
      // Multiplikation
      _num1 = _rng.nextInt(10) + 2;
      _num2 = _rng.nextInt(10) + 2;
      _operator = '×';
    } else if (round < 6) {
      // Division (ohne Rest)
      _num2 = _rng.nextInt(9) + 2;
      _correctAnswer = _rng.nextInt(10) + 2;
      _num1 = _num2 * _correctAnswer;
      _operator = '÷';
      return; // correctAnswer already set
    } else {
      // Kombiniert
      final ops = ['+', '-', '×'];
      _operator = ops[_rng.nextInt(ops.length)];
      _num1 = _rng.nextInt(15) + 5;
      _num2 = _rng.nextInt(12) + 3;
    }

    switch (_operator) {
      case '+':
        _correctAnswer = _num1 + _num2;
        break;
      case '-':
        _correctAnswer = _num1 - _num2;
        break;
      case '×':
        _correctAnswer = _num1 * _num2;
        break;
      default:
        _correctAnswer = _num1 ~/ _num2;
    }
  }

  void _listenToMessages() {
    final nearby = ref.read(nearbyServiceProvider);
    _msgSub = nearby.messageStream.listen((msg) {
      if (!mounted) return;
      if (msg.type == MessageType.playerInput) {
        final answer = msg.data['answer'] as int?;
        if (answer != null && !_p2Submitted && !_roundOver) {
          setState(() {
            _p2Input = answer.toString();
            _p2Submitted = true;
            _p2Locked = true;
            _lockTime2 = DateTime.now();
          });
          _checkAnswers();
        }
      }
    });
  }

  void _startRound() {
    if (_currentRound >= totalRounds) {
      _endGame();
      return;
    }
    setState(() {
      _p1Input = '';
      _p2Input = '';
      _p1Submitted = false;
      _p2Submitted = false;
      _p1Locked = false;
      _p2Locked = false;
      _lockTime1 = null;
      _lockTime2 = null;
      _roundOver = false;
      _timeLeft = questionTime;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        t.cancel();
        _forceSubmit();
      }
    });
  }

  void _onNumpadTap(String val) {
    final session = ref.read(sessionProvider);
    final isP1 = session.isHost;
    if ((isP1 && _p1Locked) || (!isP1 && _p2Locked)) return;
    if (_roundOver) return;

    HapticFeedback.selectionClick();
    setState(() {
      if (val == '⌫') {
        if (isP1 && _p1Input.isNotEmpty) {
          _p1Input = _p1Input.substring(0, _p1Input.length - 1);
        } else if (!isP1 && _p2Input.isNotEmpty) {
          _p2Input = _p2Input.substring(0, _p2Input.length - 1);
        }
      } else if (val == '✓') {
        _submitAnswer();
      } else {
        if (isP1 && _p1Input.length < 6) {
          _p1Input += val;
        } else if (!isP1 && _p2Input.length < 6) {
          _p2Input += val;
        }
      }
    });
  }

  void _submitAnswer() {
    final session = ref.read(sessionProvider);
    final isP1 = session.isHost;
    final input = isP1 ? _p1Input : _p2Input;
    if (input.isEmpty) return;

    final answer = int.tryParse(input);
    if (answer == null) return;

    HapticFeedback.mediumImpact();
    final nearby = ref.read(nearbyServiceProvider);
    nearby.sendMessage(GameMessage.playerInput(
      playerId: isP1 ? 1 : 2,
      answer: answer,
    ));

    setState(() {
      if (isP1) {
        _p1Submitted = true;
        _p1Locked = true;
        _lockTime1 = DateTime.now();
      } else {
        _p2Submitted = true;
        _p2Locked = true;
        _lockTime2 = DateTime.now();
      }
    });
    _checkAnswers();
  }

  void _checkAnswers() {
    if (!_p1Locked || !_p2Locked) return;
    _evaluateRound();
  }

  void _forceSubmit() {
    setState(() {
      _p1Locked = true;
      _p2Locked = true;
    });
    _evaluateRound();
  }

  void _evaluateRound() {
    if (_roundOver) return;
    setState(() => _roundOver = true);
    _timer?.cancel();

    final p1Answer = int.tryParse(_p1Input);
    final p2Answer = int.tryParse(_p2Input);
    final p1Correct = p1Answer == _correctAnswer;
    final p2Correct = p2Answer == _correctAnswer;

    if (p1Correct && p2Correct) {
      final t1 = _lockTime1 ?? DateTime.now();
      final t2 = _lockTime2 ?? DateTime.now();
      if (t1.isBefore(t2)) {
        setState(() => _p1Score++);
      } else {
        setState(() => _p2Score++);
      }
    } else if (p1Correct) {
      setState(() => _p1Score++);
    } else if (p2Correct) {
      setState(() => _p2Score++);
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _currentRound++;
          _generateQuestion();
        });
        _startRound();
      }
    });
  }

  void _endGame() {
    final winner = _p1Score > _p2Score
        ? 1
        : _p2Score > _p1Score
            ? 2
            : 0;
    final session = ref.read(sessionProvider);
    if (session.isHost) {
      final nearby = ref.read(nearbyServiceProvider);
      nearby.sendMessage(GameMessage.gameOver(winner, [_p1Score, _p2Score]));
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          winner: winner,
          p1Score: _p1Score,
          p2Score: _p2Score,
          gameTitle: 'MATHE DUEL',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isP1 = session.isHost;

    return Scaffold(
      backgroundColor: SlapColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(session),
            _buildQuestion(),
            _buildAnswerDisplay(isP1),
            if (_roundOver) _buildRoundResult(),
            const Spacer(),
            _buildNumpad(isP1),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(SessionState session) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ScoreChip(
            name: session.player1?.name ?? 'P1',
            score: _p1Score,
            color: SlapColors.player1,
          ),
          Column(
            children: [
              Text(
                'Runde ${_currentRound + 1}/$totalRounds',
                style: const TextStyle(
                  color: SlapColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_timeLeft s',
                style: TextStyle(
                  color: _timeLeft <= 5
                      ? SlapColors.neonPink
                      : SlapColors.neonGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          _ScoreChip(
            name: session.player2?.name ?? 'P2',
            score: _p2Score,
            color: SlapColors.player2,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SlapColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SlapColors.neonGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: SlapColors.neonGreen.withOpacity(0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Text(
        '$_num1 $_operator $_num2 = ?',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: SlapColors.textPrimary,
          fontSize: 36,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
    ).animate(key: ValueKey(_currentRound)).fadeIn().scale();
  }

  Widget _buildAnswerDisplay(bool isP1) {
    final myInput = isP1 ? _p1Input : _p2Input;
    final mySubmitted = isP1 ? _p1Submitted : _p2Submitted;
    final opSubmitted = isP1 ? _p2Submitted : _p1Submitted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SlapColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: mySubmitted
                      ? SlapColors.neonGreen.withOpacity(0.5)
                      : SlapColors.neonGreen.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Deine Antwort',
                    style: TextStyle(
                      color: SlapColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    myInput.isEmpty ? '_' : myInput,
                    style: const TextStyle(
                      color: SlapColors.neonGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (mySubmitted)
                    const Icon(
                      Icons.check,
                      color: SlapColors.neonGreen,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SlapColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SlapColors.textMuted.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Gegner',
                    style: TextStyle(
                      color: SlapColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opSubmitted ? '✓' : '...',
                    style: TextStyle(
                      color: opSubmitted
                          ? SlapColors.neonPink
                          : SlapColors.textMuted,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundResult() {
    final p1Answer = int.tryParse(_p1Input);
    final p2Answer = int.tryParse(_p2Input);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SlapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Richtig: ',
            style: TextStyle(color: SlapColors.textSecondary),
          ),
          Text(
            '$_correctAnswer',
            style: const TextStyle(
              color: SlapColors.neonGreen,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildNumpad(bool isP1) {
    final locked = isP1 ? _p1Locked : _p2Locked;
    final keys = [
      '7', '8', '9',
      '4', '5', '6',
      '1', '2', '3',
      '⌫', '0', '✓',
    ];

    return Opacity(
      opacity: locked ? 0.3 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2,
          ),
          itemCount: keys.length,
          itemBuilder: (context, i) {
            final key = keys[i];
            final isConfirm = key == '✓';
            final isDelete = key == '⌫';
            return GestureDetector(
              onTap: locked ? null : () => _onNumpadTap(key),
              child: Container(
                decoration: BoxDecoration(
                  color: isConfirm
                      ? SlapColors.neonGreen.withOpacity(0.15)
                      : isDelete
                          ? SlapColors.neonPink.withOpacity(0.15)
                          : SlapColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isConfirm
                        ? SlapColors.neonGreen.withOpacity(0.5)
                        : isDelete
                            ? SlapColors.neonPink.withOpacity(0.5)
                            : SlapColors.textMuted.withOpacity(0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    key,
                    style: TextStyle(
                      color: isConfirm
                          ? SlapColors.neonGreen
                          : isDelete
                              ? SlapColors.neonPink
                              : SlapColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String name;
  final int score;
  final Color color;

  const _ScoreChip({
    required this.name,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}
