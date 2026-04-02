import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

// ── Track definition ───────────────────────────────────────────────────────
class TrackCheckpoint {
  final Vector2 center;
  final double radius;
  const TrackCheckpoint(this.center, this.radius);
}

// Simple oval track (Track 1)
List<TrackCheckpoint> buildTrack1() => [
      TrackCheckpoint(Vector2(180, 80), 50),
      TrackCheckpoint(Vector2(300, 160), 45),
      TrackCheckpoint(Vector2(310, 300), 45),
      TrackCheckpoint(Vector2(280, 430), 45),
      TrackCheckpoint(Vector2(180, 490), 50),
      TrackCheckpoint(Vector2(80, 430), 45),
      TrackCheckpoint(Vector2(50, 300), 45),
      TrackCheckpoint(Vector2(80, 160), 45),
    ];

class RaceCar {
  Vector2 pos;
  double angle; // radians, 0 = up
  double speed = 0;
  double steer = 0;
  int lap = 0;
  int nextCheckpoint = 0;
  bool finished = false;
  double finishTime = 0;

  static const double maxSpeed = 220.0;
  static const double acceleration = 120.0;
  static const double brakeForce = 200.0;
  static const double friction = 0.97;
  static const double turnRate = 2.4; // rad/sec at max speed
  static const double carW = 14.0;
  static const double carH = 24.0;

  RaceCar({required this.pos, required this.angle});

  void update(double dt, bool gas, bool brake, double steerInput) {
    if (finished) return;

    if (gas) speed += acceleration * dt;
    if (brake) speed -= brakeForce * dt;
    speed *= pow(friction, dt * 60).toDouble();
    speed = speed.clamp(0, maxSpeed);

    final turnFactor = (speed / maxSpeed).clamp(0.2, 1.0);
    angle += steerInput * turnRate * turnFactor * dt;

    pos.x += sin(angle) * speed * dt;
    pos.y -= cos(angle) * speed * dt;
  }

  void clampToField(double w, double h) {
    pos.x = pos.x.clamp(0, w);
    pos.y = pos.y.clamp(0, h);
  }
}

// ── Flame Game ─────────────────────────────────────────────────────────────
class RacingGame extends FlameGame {
  static const double fieldW = 360;
  static const double fieldH = 580;
  static const int totalLaps = 3;

  final bool isHost;
  final int localPlayerNum;

  late RaceCar car1;
  late RaceCar car2;
  late List<TrackCheckpoint> checkpoints;
  double raceTime = 0;
  bool raceStarted = false;
  bool raceEnded = false;

  // Input
  bool localGas = true; // Auto-gas!
  bool localBrake = false;
  double localSteer = 0;
  bool remoteGas = true;
  bool remoteBrake = false;
  double remoteSteer = 0;

  // Callbacks
  Function(Map<String, dynamic>)? onStateUpdate;
  Function(int playerNum, int lap)? onLap;
  Function(int winner)? onRaceOver;

  // Visuals
  late _TrackComp _trackComp;
  late _CarComp _car1Comp;
  late _CarComp _car2Comp;
  late _HUDComp _hud;

  RacingGame({required this.isHost, required this.localPlayerNum});

  @override
  Color backgroundColor() => const Color(0xFF111111);

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedResolutionViewport(resolution: Vector2(fieldW, fieldH));

    checkpoints = buildTrack1();

    car1 = RaceCar(pos: Vector2(165, 500), angle: 0);
    car2 = RaceCar(pos: Vector2(195, 500), angle: 0);

    _trackComp = _TrackComp(checkpoints: checkpoints);
    _car1Comp = _CarComp(color: const Color(0xFF00D4FF), label: '1');
    _car2Comp = _CarComp(color: const Color(0xFFFF006E), label: '2');
    _hud = _HUDComp();

    addAll([_trackComp, _car1Comp, _car2Comp, _hud]);

    // Start race after 3 second countdown
    Future.delayed(const Duration(seconds: 3), () {
      raceStarted = true;
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!raceStarted || raceEnded) return;

    raceTime += dt;

    if (isHost) {
      _updateCar(car1, dt,
          gas: localPlayerNum == 1 ? localGas : remoteGas,
          brake: localPlayerNum == 1 ? localBrake : remoteBrake,
          steer: localPlayerNum == 1 ? localSteer : remoteSteer,
          playerNum: 1);
      _updateCar(car2, dt,
          gas: localPlayerNum == 2 ? localGas : remoteGas,
          brake: localPlayerNum == 2 ? localBrake : remoteBrake,
          steer: localPlayerNum == 2 ? localSteer : remoteSteer,
          playerNum: 2);

      _carCollision();

      onStateUpdate?.call({
        'c1': {'x': car1.pos.x, 'y': car1.pos.y, 'a': car1.angle, 's': car1.speed, 'lap': car1.lap},
        'c2': {'x': car2.pos.x, 'y': car2.pos.y, 'a': car2.angle, 's': car2.speed, 'lap': car2.lap},
        'time': raceTime,
      });
    }

    _car1Comp.position = car1.pos.clone();
    _car1Comp.angle = car1.angle;
    _car2Comp.position = car2.pos.clone();
    _car2Comp.angle = car2.angle;
    _hud.lap1 = car1.lap;
    _hud.lap2 = car2.lap;
    _hud.raceTime = raceTime;
  }

  void _updateCar(RaceCar car, double dt, {required bool gas, required bool brake, required double steer, required int playerNum}) {
    if (car.finished) return;
    car.update(dt, gas, brake, steer);
    car.clampToField(fieldW, fieldH);
    _checkCheckpoint(car, playerNum);
  }

  void _checkCheckpoint(RaceCar car, int playerNum) {
    if (car.nextCheckpoint >= checkpoints.length) return;
    final cp = checkpoints[car.nextCheckpoint];
    if ((car.pos - cp.center).length < cp.radius) {
      car.nextCheckpoint++;
      if (car.nextCheckpoint >= checkpoints.length) {
        car.nextCheckpoint = 0;
        car.lap++;
        onLap?.call(playerNum, car.lap);
        if (car.lap >= totalLaps) {
          car.finished = true;
          car.finishTime = raceTime;
          if (!raceEnded) {
            raceEnded = true;
            onRaceOver?.call(playerNum);
          }
        }
      }
    }
  }

  void _carCollision() {
    final diff = car1.pos - car2.pos;
    final dist = diff.length;
    if (dist < 20 && dist > 0.01) {
      final dir = diff / dist;
      car1.pos += dir * (20 - dist) / 2;
      car2.pos -= dir * (20 - dist) / 2;
      car1.speed *= 0.6;
      car2.speed *= 0.6;
    }
  }

  void applyRemoteInput(Map<String, dynamic> data) {
    if (!isHost) return;
    remoteSteer = (data['steer'] as num).toDouble();
    remoteBrake = data['brake'] as bool? ?? false;
  }

  void applyRemoteState(Map<String, dynamic> data) {
    if (isHost) return;
    final c1 = data['c1'] as Map<String, dynamic>;
    car1.pos = Vector2((c1['x'] as num).toDouble(), (c1['y'] as num).toDouble());
    car1.angle = (c1['a'] as num).toDouble();
    car1.speed = (c1['s'] as num).toDouble();
    car1.lap = (c1['lap'] as num).toInt();
    final c2 = data['c2'] as Map<String, dynamic>;
    car2.pos = Vector2((c2['x'] as num).toDouble(), (c2['y'] as num).toDouble());
    car2.angle = (c2['a'] as num).toDouble();
    car2.speed = (c2['s'] as num).toDouble();
    car2.lap = (c2['lap'] as num).toInt();
    raceTime = (data['time'] as num).toDouble();
  }

  void setSteer(double steer) => localSteer = steer;
  void setBrake(bool brake) => localBrake = brake;
}

// ── Visuals ─────────────────────────────────────────────────────────────────

class _TrackComp extends PositionComponent {
  final List<TrackCheckpoint> checkpoints;
  _TrackComp({required this.checkpoints});

  @override
  void render(Canvas canvas) {
    // Draw track surface (outer path)
    final trackPaint = Paint()..color = const Color(0xFF333333);
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw oval track
    final outerRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(30, 60, 300, 460),
      const Radius.circular(80),
    );
    final innerRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(90, 120, 180, 340),
      const Radius.circular(60),
    );

    canvas.drawRRect(outerRect, trackPaint);

    // Clear inner (grass)
    canvas.drawRRect(innerRect, Paint()..color = const Color(0xFF1A4A1A));

    // Track borders
    canvas.drawRRect(outerRect, linePaint);
    canvas.drawRRect(innerRect, linePaint);

    // Start/finish line
    canvas.drawRect(
      const Rect.fromLTWH(155, 470, 50, 6),
      Paint()..color = Colors.white.withOpacity(0.6),
    );

    // Checkpoints (faint)
    for (final cp in checkpoints) {
      canvas.drawCircle(
        cp.center.toOffset(),
        cp.radius,
        Paint()
          ..color = Colors.yellow.withOpacity(0.05)
          ..style = PaintingStyle.fill,
      );
    }
  }
}

class _CarComp extends PositionComponent {
  Color color;
  String label;

  _CarComp({required this.color, required this.label})
      : super(anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    const w = RaceCar.carW;
    const h = RaceCar.carH;
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = color,
    );
    // Windshield
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, -h * 0.15), width: w * 0.6, height: h * 0.2),
      Paint()..color = Colors.white.withOpacity(0.4),
    );
    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, h * 0.1));
  }
}

class _HUDComp extends PositionComponent {
  int lap1 = 0;
  int lap2 = 0;
  double raceTime = 0;

  @override
  void render(Canvas canvas) {
    // Nothing here – HUD is Flutter overlay
  }
}

extension on Vector2 {
  Offset toOffset() => Offset(x, y);
}
