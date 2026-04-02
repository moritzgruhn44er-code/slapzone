import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../network/nearby_service.dart';

// ── NearbyService Provider ────────────────────────────────────────────────
final nearbyServiceProvider = Provider<NearbyService>((ref) {
  final service = NearbyService();
  ref.onDispose(service.dispose);
  return service;
});

// ── Session State ─────────────────────────────────────────────────────────
enum GameType { tapping, quiz, math, football, racing }

class SessionState {
  final Player? player1;
  final Player? player2;
  final bool isHost;
  final ConnectionStatus connectionStatus;
  final GameType? selectedGame;
  final int latencyMs;

  const SessionState({
    this.player1,
    this.player2,
    this.isHost = false,
    this.connectionStatus = ConnectionStatus.idle,
    this.selectedGame,
    this.latencyMs = 0,
  });

  SessionState copyWith({
    Player? player1,
    Player? player2,
    bool? isHost,
    ConnectionStatus? connectionStatus,
    GameType? selectedGame,
    int? latencyMs,
  }) =>
      SessionState(
        player1: player1 ?? this.player1,
        player2: player2 ?? this.player2,
        isHost: isHost ?? this.isHost,
        connectionStatus: connectionStatus ?? this.connectionStatus,
        selectedGame: selectedGame ?? this.selectedGame,
        latencyMs: latencyMs ?? this.latencyMs,
      );

  bool get isConnected => connectionStatus == ConnectionStatus.connected;
  Player? get localPlayer => isHost ? player1 : player2;
  Player? get remotePlayer => isHost ? player2 : player1;
}

class SessionNotifier extends StateNotifier<SessionState> {
  final NearbyService _nearby;

  SessionNotifier(this._nearby) : super(const SessionState()) {
    _nearby.statusStream.listen((status) {
      state = state.copyWith(connectionStatus: status);
    });
  }

  void setHost(String name) {
    state = state.copyWith(
      isHost: true,
      player1: Player(
        id: 'host',
        name: name,
        playerNumber: 1,
        role: PlayerRole.host,
      ),
    );
    _nearby.startAdvertising(name);
  }

  void setClient(String name) {
    state = state.copyWith(
      isHost: false,
      player2: Player(
        id: 'client',
        name: name,
        playerNumber: 2,
        role: PlayerRole.client,
      ),
    );
    _nearby.startDiscovery(name);
  }

  void connectToHost(String endpointId) {
    final name = state.player2?.name ?? 'Player 2';
    _nearby.requestConnection(name, endpointId);
  }

  void remotePlayerJoined(String name) {
    if (state.isHost) {
      state = state.copyWith(
        player2: Player(
          id: 'client',
          name: name,
          playerNumber: 2,
          role: PlayerRole.client,
        ),
      );
    }
  }

  void selectGame(GameType game) {
    state = state.copyWith(selectedGame: game);
  }

  void addScore(int playerNumber, int points) {
    if (playerNumber == 1 && state.player1 != null) {
      state = state.copyWith(
        player1: state.player1!.copyWith(
          score: state.player1!.score + points,
        ),
      );
    } else if (playerNumber == 2 && state.player2 != null) {
      state = state.copyWith(
        player2: state.player2!.copyWith(
          score: state.player2!.score + points,
        ),
      );
    }
  }

  void resetScores() {
    state = state.copyWith(
      player1: state.player1?.copyWith(score: 0),
      player2: state.player2?.copyWith(score: 0),
    );
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final nearby = ref.watch(nearbyServiceProvider);
  return SessionNotifier(nearby);
});
