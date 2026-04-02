import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../ui/theme/app_theme.dart';
import '../../core/state/game_state_provider.dart';
import '../../core/network/nearby_service.dart';
import '../../core/models/game_message.dart';
import '../result_screen.dart';

class QuizQuestion {
  final String question;
  final List<String> answers;
  final int correctIndex;
  final String category;

  const QuizQuestion({
    required this.question,
    required this.answers,
    required this.correctIndex,
    required this.category,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        question: json['question'] as String,
        answers: List<String>.from(json['answers'] as List),
        correctIndex: json['correct'] as int,
        category: json['category'] as String? ?? 'Allgemein',
      );
}

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  static const int totalRounds = 10;
  static const int questionTime = 10;

  List<QuizQuestion> _questions = [];
  int _currentRound = 0;
  int _p1Score = 0;
  int _p2Score = 0;
  int _timeLeft = questionTime;
  Timer? _timer;
  StreamSubscription? _msgSub;

  int? _p1Answer;
  int? _p2Answer;
  bool _roundOver = false;
  bool _locked1 = false;
  bool _locked2 = false;
  DateTime? _lockTime1;
  DateTime? _lockTime2;
  bool _gameOver = false;

  QuizQuestion? get _currentQuestion =>
      _questions.isEmpty ? null : _questions[_currentRound];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _listenToMessages();
  }

  Future<void> _loadQuestions() async {
    try {
      final raw = await rootBundle.loadString('assets/questions.json');
      final list = (jsonDecode(raw) as List)
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList()
        ..shuffle();
      setState(() => _questions = list.take(totalRounds).toList());
      _startRound();
    } catch (_) {
      // Fallback-Fragen wenn JSON fehlt
      _questions = _fallbackQuestions();
      _startRound();
    }
  }

  void _listenToMessages() {
    final nearby = ref.read(nearbyServiceProvider);
    _msgSub = nearby.messageStream.listen((msg) {
      if (!mounted) return;
      if (msg.type == MessageType.playerInput) {
        final answer = msg.data['answer'] as int?;
        if (answer != null && !_locked2 && !_roundOver) {
          setState(() {
            _p2Answer = answer;
            _locked2 = true;
            _lockTime2 = DateTime.now();
          });
          _checkAnswers();
        }
      }
      if (msg.type == MessageType.gameState) {
        // Sync von Host
        final round = msg.data['round'] as int? ?? _currentRound;
        final p1 = msg.data['p1Score'] as int? ?? _p1Score;
        final p2 = msg.data['p2Score'] as int? ?? _p2Score;
        setState(() {
          _currentRound = round;
          _p1Score = p1;
          _p2Score = p2;
        });
      }
    });
  }

  void _startRound() {
    if (_currentRound >= totalRounds) {
      _endGame();
      return;
    }
    setState(() {
      _p1Answer = null;
      _p2Answer = null;
      _locked1 = false;
      _locked2 = false;
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
        _forceRoundEnd();
      }
    });
  }

  void _onLocalAnswer(int index) {
    final session = ref.read(sessionProvider);
    final isP1 = session.isHost;
    if ((isP1 && _locked1) || (!isP1 && _locked2)) return;
    if (_roundOver) return;

    HapticFeedback.mediumImpact();
    final nearby = ref.read(nearbyServiceProvider);
    nearby.sendMessage(GameMessage.playerInput(
      playerId: isP1 ? 1 : 2,
      answer: index,
    ));

    setState(() {
      if (isP1) {
        _p1Answer = index;
        _locked1 = true;
        _lockTime1 = DateTime.now();
      } else {
        _p2Answer = index;
        _locked2 = true;
        _lockTime2 = DateTime.now();
      }
    });
    _checkAnswers();
  }

  void _checkAnswers() {
    if (!_locked1 || !_locked2) return;
    _evaluateRound();
  }

  void _forceRoundEnd() {
    setState(() {
      _locked1 = true;
      _locked2 = true;
    });
    _evaluateRound();
  }

  void _evaluateRound() {
    if (_roundOver) return;
    final q = _currentQuestion!;
    setState(() => _roundOver = true);
    _timer?.cancel();

    bool p1Correct = _p1Answer == q.correctIndex;
    bool p2Correct = _p2Answer == q.correctIndex;

    if (p1Correct && p2Correct) {
      // Wer zuerst geantwortet hat
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

    final session = ref.read(sessionProvider);
    if (session.isHost) {
      final nearby = ref.read(nearbyServiceProvider);
      nearby.sendMessage(GameMessage(
        type: MessageType.gameState,
        data: {
          'round': _currentRound,
          'p1Score': _p1Score,
          'p2Score': _p2Score,
        },
      ));
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _currentRound++);
        _startRound();
      }
    });
  }

  void _endGame() {
    setState(() => _gameOver = true);
    final session = ref.read(sessionProvider);
    if (session.isHost) {
      final winner = _p1Score > _p2Score
          ? 1
          : _p2Score > _p1Score
              ? 2
              : 0;
      final nearby = ref.read(nearbyServiceProvider);
      nearby.sendMessage(GameMessage.gameOver(winner, [_p1Score, _p2Score]));
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final winner = _p1Score > _p2Score
            ? 1
            : _p2Score > _p1Score
                ? 2
                : 0;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              winner: winner,
              p1Score: _p1Score,
              p2Score: _p2Score,
              gameTitle: 'QUIZ BATTLE',
            ),
          ),
        );
      }
    });
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
    final q = _currentQuestion;

    if (q == null) {
      return const Scaffold(
        backgroundColor: SlapColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: SlapColors.neonPurple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SlapColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(session),
            _buildProgressBar(),
            _buildTimer(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildQuestionCard(q),
                    const SizedBox(height: 24),
                    _buildAnswers(q, session),
                  ],
                ),
              ),
            ),
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
          Text(
            'Runde ${_currentRound + 1}/$totalRounds',
            style: const TextStyle(
              color: SlapColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
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

  Widget _buildProgressBar() {
    return LinearProgressIndicator(
      value: _currentRound / totalRounds,
      backgroundColor: SlapColors.bgCard,
      valueColor: const AlwaysStoppedAnimation(SlapColors.neonPurple),
      minHeight: 4,
    );
  }

  Widget _buildTimer() {
    final isLow = _timeLeft <= 3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: AnimatedContainer(
        duration: 200.ms,
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isLow
              ? SlapColors.neonPink.withOpacity(0.2)
              : SlapColors.bgCard,
          border: Border.all(
            color: isLow ? SlapColors.neonPink : SlapColors.neonPurple,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            '$_timeLeft',
            style: TextStyle(
              color: isLow ? SlapColors.neonPink : SlapColors.neonPurple,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SlapColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SlapColors.neonPurple.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: SlapColors.neonPurple.withOpacity(0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: SlapColors.neonPurple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              q.category.toUpperCase(),
              style: const TextStyle(
                color: SlapColors.neonPurple,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            q.question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SlapColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate(key: ValueKey(_currentRound)).fadeIn().slideY(begin: -0.2);
  }

  Widget _buildAnswers(QuizQuestion q, SessionState session) {
    final isP1 = session.isHost;
    final myAnswered = isP1 ? _locked1 : _locked2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: q.answers.length,
      itemBuilder: (context, i) {
        Color? bgColor;
        Color borderColor = SlapColors.neonPurple.withOpacity(0.3);

        if (_roundOver) {
          if (i == q.correctIndex) {
            bgColor = SlapColors.neonGreen.withOpacity(0.2);
            borderColor = SlapColors.neonGreen;
          } else if ((isP1 && _p1Answer == i) || (!isP1 && _p2Answer == i)) {
            bgColor = SlapColors.neonPink.withOpacity(0.2);
            borderColor = SlapColors.neonPink;
          }
        } else if ((isP1 && _p1Answer == i) || (!isP1 && _p2Answer == i)) {
          bgColor = SlapColors.neonPurple.withOpacity(0.2);
          borderColor = SlapColors.neonPurple;
        }

        return GestureDetector(
          onTap: myAnswered ? null : () => _onLocalAnswer(i),
          child: AnimatedContainer(
            duration: 200.ms,
            decoration: BoxDecoration(
              color: bgColor ?? SlapColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  q.answers[i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: SlapColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ).animate(key: ValueKey('$_currentRound-$i')).fadeIn(delay: (i * 80).ms).scale();
      },
    );
  }

  List<QuizQuestion> _fallbackQuestions() => [
        const QuizQuestion(
          question: 'Was ist die Hauptstadt von Deutschland?',
          answers: ['Hamburg', 'München', 'Berlin', 'Frankfurt'],
          correctIndex: 2,
          category: 'Geografie',
        ),
        const QuizQuestion(
          question: 'Wer hat die Relativitätstheorie entwickelt?',
          answers: ['Newton', 'Einstein', 'Hawking', 'Tesla'],
          correctIndex: 1,
          category: 'Wissenschaft',
        ),
        const QuizQuestion(
          question: 'Wie viele Planeten hat unser Sonnensystem?',
          answers: ['7', '8', '9', '10'],
          correctIndex: 1,
          category: 'Astronomie',
        ),
        const QuizQuestion(
          question: 'In welchem Jahr fiel die Berliner Mauer?',
          answers: ['1987', '1988', '1989', '1990'],
          correctIndex: 2,
          category: 'Geschichte',
        ),
        const QuizQuestion(
          question: 'Welches ist das längste Fluss der Welt?',
          answers: ['Amazonas', 'Nil', 'Mississippi', 'Yangtze'],
          correctIndex: 1,
          category: 'Geografie',
        ),
        const QuizQuestion(
          question: 'Wer hat Windows gegründet?',
          answers: ['Steve Jobs', 'Elon Musk', 'Bill Gates', 'Mark Zuckerberg'],
          correctIndex: 2,
          category: 'Technik',
        ),
        const QuizQuestion(
          question: 'Wie viele Saiten hat eine Standard-Gitarre?',
          answers: ['4', '5', '6', '7'],
          correctIndex: 2,
          category: 'Musik',
        ),
        const QuizQuestion(
          question: 'Welches Land hat die meisten Einwohner?',
          answers: ['USA', 'Indien', 'China', 'Russland'],
          correctIndex: 1,
          category: 'Geografie',
        ),
        const QuizQuestion(
          question: 'Wer spielte Iron Man im MCU?',
          answers: ['Chris Evans', 'Chris Hemsworth', 'Robert Downey Jr.', 'Mark Ruffalo'],
          correctIndex: 2,
          category: 'Film',
        ),
        const QuizQuestion(
          question: 'Wie viele Minuten hat eine Stunde?',
          answers: ['30', '45', '60', '90'],
          correctIndex: 2,
          category: 'Allgemein',
        ),
      ];
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
