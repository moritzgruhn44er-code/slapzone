import 'dart:convert';

enum MessageType {
  gameStart,
  playerInput,
  gameState,
  roundResult,
  gameOver,
  lobbyReady,
  playerJoined,
  ping,
  pong,
}

class GameMessage {
  final MessageType type;
  final Map<String, dynamic> data;
  final int timestamp;

  GameMessage({
    required this.type,
    required this.data,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory GameMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = MessageType.values.firstWhere(
      (e) => e.name.toUpperCase() == typeStr.replaceAll('_', '').toUpperCase(),
      orElse: () => MessageType.ping,
    );
    return GameMessage(
      type: type,
      data: Map<String, dynamic>.from(json),
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': _typeToString(type),
        'timestamp': timestamp,
        ...data,
      };

  String toJsonString() => jsonEncode(toJson());

  static String _typeToString(MessageType t) {
    switch (t) {
      case MessageType.gameStart:
        return 'GAME_START';
      case MessageType.playerInput:
        return 'PLAYER_INPUT';
      case MessageType.gameState:
        return 'GAME_STATE';
      case MessageType.roundResult:
        return 'ROUND_RESULT';
      case MessageType.gameOver:
        return 'GAME_OVER';
      case MessageType.lobbyReady:
        return 'LOBBY_READY';
      case MessageType.playerJoined:
        return 'PLAYER_JOINED';
      case MessageType.ping:
        return 'PING';
      case MessageType.pong:
        return 'PONG';
    }
  }

  // Factory constructors für alle Nachrichtentypen
  factory GameMessage.gameStart(String game) => GameMessage(
        type: MessageType.gameStart,
        data: {'game': game},
      );

  factory GameMessage.playerInput({
    required int playerId,
    double joystickX = 0,
    double joystickY = 0,
    bool shoot = false,
    bool tap = false,
    int? answer,
  }) =>
      GameMessage(
        type: MessageType.playerInput,
        data: {
          'playerId': playerId,
          'joystick': {'x': joystickX, 'y': joystickY},
          'shoot': shoot,
          'tap': tap,
          if (answer != null) 'answer': answer,
        },
      );

  factory GameMessage.roundResult(int winner, List<int> scores) => GameMessage(
        type: MessageType.roundResult,
        data: {'winner': winner, 'scores': scores},
      );

  factory GameMessage.gameOver(int winner, List<int> finalScore) => GameMessage(
        type: MessageType.gameOver,
        data: {'winner': winner, 'finalScore': finalScore},
      );
}
