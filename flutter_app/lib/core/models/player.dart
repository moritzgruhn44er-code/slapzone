import 'package:flutter/material.dart';
import '../../ui/theme/app_theme.dart';

enum PlayerRole { host, client }

class Player {
  final String id;
  final String name;
  final int playerNumber; // 1 oder 2
  final PlayerRole role;
  int score;
  int totalWins;

  Player({
    required this.id,
    required this.name,
    required this.playerNumber,
    required this.role,
    this.score = 0,
    this.totalWins = 0,
  });

  Color get color =>
      playerNumber == 1 ? SlapColors.player1 : SlapColors.player2;

  String get emoji => playerNumber == 1 ? '🔵' : '🔴';

  Player copyWith({int? score, int? totalWins}) => Player(
        id: id,
        name: name,
        playerNumber: playerNumber,
        role: role,
        score: score ?? this.score,
        totalWins: totalWins ?? this.totalWins,
      );
}
