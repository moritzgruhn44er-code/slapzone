import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class FootballGame extends FlameGame {
  static const double fieldW = 360;
  static const double fieldH = 580;
  static const double goalW = 110;
  static const double goalH = 18;
  static const double playerR = 18.0;
  static const double ballR = 10.0;
  static const double playerSpeed = 210.0;
  static const double friction = 0.97;
  static const double maxBallSpeed = 550.0;

  final bool isHost;
  final int localPlayerNum;

  // State
  Vector2 ballPos = Vector2(fieldW / 2, fieldH / 2);
  Vector2 ballVel = Vector2.zero();
  Vector2 p1Pos = Vector2(fieldW / 2, fieldH * 0.28);
  Vector2 p2Pos = Vector2(fieldW / 2, fieldH * 0.72);
  int score1 = 0;
  int score2 = 0;
  double timeLeft = 120.0;
  bool gameEnded = false;

  // Input
  Vector2 localJoystick = Vector2.zero();
  Vector2 remoteJoystick = Vector2.zero();
  double p1InvTimer = 0;
  double p2InvTimer = 0;

  // Callbacks
  Function(Map<String, dynamic>)? onStateUpdate;
  Function(int scorer, int s1, int s2)? onGoal;
  Function(int winner, int s1, int s2)? onGameOver;

  // Visual
  late _FieldComp _field;
  late _PlayerComp _p1Comp;
  late _PlayerComp _p2Comp;
  late _BallComp _ballComp;

  FootballGame({required this.isHost, required this.localPlayerNum});

  @override
  Color backgroundColor() => const Color(0xFF0D3B0D);

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedResolutionViewport(resolution: Vector2(fieldW, fieldH));

    _field = _FieldComp();
    _p1Comp = _PlayerComp(color: const Color(0xFF00D4FF), label: '1');
    _p2Comp = _PlayerComp(color: const Color(0xFFFF006E), label: '2');
    _ballComp = _BallComp();

    addAll([_field, _p1Comp, _p2Comp, _ballComp]);
    _updateVisuals();
  }

  void _updateVisuals() {
    _ballComp.position = ballPos;
    _p1Comp.position = p1Pos;
    _p2Comp.position = p2Pos;
    _p1Comp.isInvulnerable = p1InvTimer > 0;
    _p2Comp.isInvulnerable = p2InvTimer > 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameEnded) return;

    p1InvTimer = max(0, p1InvTimer - dt);
    p2InvTimer = max(0, p2InvTimer - dt);

    if (isHost) {
      _hostUpdate(dt);
    }
    _updateVisuals();
  }

  void _hostUpdate(double dt) {
    timeLeft -= dt;
    if (timeLeft <= 0 && !gameEnded) {
      gameEnded = true;
      final winner = score1 > score2 ? 1 : score2 > score1 ? 2 : 0;
      onGameOver?.call(winner, score1, score2);
      return;
    }

    final j1 = localPlayerNum == 1 ? localJoystick : remoteJoystick;
    final j2 = localPlayerNum == 2 ? localJoystick : remoteJoystick;

    p1Pos += j1 * playerSpeed * dt;
    p2Pos += j2 * playerSpeed * dt;

    p1Pos.x = p1Pos.x.clamp(playerR, fieldW - playerR);
    p1Pos.y = p1Pos.y.clamp(playerR, fieldH - playerR);
    p2Pos.x = p2Pos.x.clamp(playerR, fieldW - playerR);
    p2Pos.y = p2Pos.y.clamp(playerR, fieldH - playerR);

    ballVel *= pow(friction, dt * 60).toDouble();
    ballPos += ballVel * dt;

    _wallBounce();
    _playerBallCollision(p1Pos, p1InvTimer > 0);
    _playerBallCollision(p2Pos, p2InvTimer > 0);
    _playerCollision();

    if (isHost) {
      onStateUpdate?.call({
        'ball': {'x': ballPos.x, 'y': ballPos.y},
        'bvx': ballVel.x, 'bvy': ballVel.y,
        'p1': {'x': p1Pos.x, 'y': p1Pos.y},
        'p2': {'x': p2Pos.x, 'y': p2Pos.y},
        'score': [score1, score2],
        'timeLeft': timeLeft,
      });
    }
  }

  void _wallBounce() {
    final goalLeft = (fieldW - goalW) / 2;
    final goalRight = goalLeft + goalW;

    // Top wall / goal
    if (ballPos.y - ballR <= goalH) {
      if (ballPos.x >= goalLeft && ballPos.x <= goalRight) {
        _scoreGoal(1);
        return;
      }
      ballPos.y = goalH + ballR;
      ballVel.y = ballVel.y.abs();
    }
    // Bottom wall / goal
    if (ballPos.y + ballR >= fieldH - goalH) {
      if (ballPos.x >= goalLeft && ballPos.x <= goalRight) {
        _scoreGoal(2);
        return;
      }
      ballPos.y = fieldH - goalH - ballR;
      ballVel.y = -ballVel.y.abs();
    }
    // Left/right
    if (ballPos.x - ballR <= 0) {
      ballPos.x = ballR;
      ballVel.x = ballVel.x.abs();
    }
    if (ballPos.x + ballR >= fieldW) {
      ballPos.x = fieldW - ballR;
      ballVel.x = -ballVel.x.abs();
    }
  }

  void _playerBallCollision(Vector2 pPos, bool invulnerable) {
    final diff = ballPos - pPos;
    final dist = diff.length;
    final minDist = playerR + ballR;
    if (dist < minDist && dist > 0.01) {
      final dir = diff / dist;
      ballPos = pPos + dir * minDist;
      final relVel = ballVel.dot(dir);
      if (relVel < 0) {
        ballVel -= dir * (relVel * 1.6);
      }
      ballVel += dir * 80;
      if (ballVel.length > maxBallSpeed) {
        ballVel.scaleTo(maxBallSpeed);
      }
    }
  }

  void _playerCollision() {
    final diff = p1Pos - p2Pos;
    final dist = diff.length;
    if (dist < playerR * 2 && dist > 0.01) {
      final dir = diff / dist;
      final overlap = playerR * 2 - dist;
      p1Pos += dir * (overlap / 2);
      p2Pos -= dir * (overlap / 2);
      p1InvTimer = max(p1InvTimer, 0.5);
      p2InvTimer = max(p2InvTimer, 0.5);
    }
  }

  void _scoreGoal(int scorer) {
    if (scorer == 1) score1++;
    else score2++;
    onGoal?.call(scorer, score1, score2);
    _resetPositions();
  }

  void _resetPositions() {
    ballPos = Vector2(fieldW / 2, fieldH / 2);
    ballVel = Vector2.zero();
    p1Pos = Vector2(fieldW / 2, fieldH * 0.28);
    p2Pos = Vector2(fieldW / 2, fieldH * 0.72);
  }

  void applyRemoteInput(Map<String, dynamic> data) {
    if (!isHost) return;
    final j = data['joystick'] as Map<String, dynamic>;
    remoteJoystick = Vector2(
      (j['x'] as num).toDouble(),
      (j['y'] as num).toDouble(),
    );
  }

  void applyRemoteState(Map<String, dynamic> data) {
    if (isHost) return;
    final b = data['ball'] as Map<String, dynamic>;
    ballPos = Vector2((b['x'] as num).toDouble(), (b['y'] as num).toDouble());
    ballVel = Vector2((data['bvx'] as num).toDouble(), (data['bvy'] as num).toDouble());
    final p1 = data['p1'] as Map<String, dynamic>;
    p1Pos = Vector2((p1['x'] as num).toDouble(), (p1['y'] as num).toDouble());
    final p2 = data['p2'] as Map<String, dynamic>;
    p2Pos = Vector2((p2['x'] as num).toDouble(), (p2['y'] as num).toDouble());
    final scores = data['score'] as List;
    score1 = (scores[0] as num).toInt();
    score2 = (scores[1] as num).toInt();
    timeLeft = (data['timeLeft'] as num).toDouble();
  }

  void setJoystick(Vector2 j) => localJoystick = j;
}

// ── Visuals ────────────────────────────────────────────────────────────────

class _FieldComp extends PositionComponent {
  _FieldComp() : super(size: Vector2(FootballGame.fieldW, FootballGame.fieldH));

  @override
  void render(Canvas canvas) {
    final w = FootballGame.fieldW;
    final h = FootballGame.fieldH;
    final gW = FootballGame.goalW;
    final gH = FootballGame.goalH;
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final goalPaint1 = Paint()..color = const Color(0xFF00D4FF).withOpacity(0.7);
    final goalPaint2 = Paint()..color = const Color(0xFFFF006E).withOpacity(0.7);

    // Field border
    canvas.drawRect(Rect.fromLTWH(2, gH, w - 4, h - gH * 2), linePaint);
    // Center line
    canvas.drawLine(Offset(2, h / 2), Offset(w - 2, h / 2), linePaint);
    // Center circle
    canvas.drawCircle(Offset(w / 2, h / 2), 48, linePaint);
    // Goals
    canvas.drawRect(Rect.fromLTWH((w - gW) / 2, 0, gW, gH), goalPaint2);
    canvas.drawRect(Rect.fromLTWH((w - gW) / 2, h - gH, gW, gH), goalPaint1);
    // Goal posts
    final postPaint = Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH((w - gW) / 2, 0, gW, gH), postPaint);
    canvas.drawRect(Rect.fromLTWH((w - gW) / 2, h - gH, gW, gH), postPaint);
  }
}

class _PlayerComp extends PositionComponent {
  Color color;
  String label;
  bool isInvulnerable = false;

  _PlayerComp({required this.color, required this.label})
      : super(anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final r = FootballGame.playerR;
    final paint = Paint()..color = isInvulnerable ? Colors.white : color;
    canvas.drawCircle(Offset.zero, r, paint);
    canvas.drawCircle(
        Offset.zero, r,
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: Colors.white, fontSize: r * 0.9, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}

class _BallComp extends PositionComponent {
  _BallComp() : super(anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final r = FootballGame.ballR;
    canvas.drawCircle(Offset.zero, r, Paint()..color = Colors.white);
    canvas.drawCircle(Offset.zero, r,
        Paint()..color = Colors.black.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 1);
  }
}
