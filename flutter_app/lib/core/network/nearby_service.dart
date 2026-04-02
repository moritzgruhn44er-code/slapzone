import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/game_message.dart';

enum ConnectionStatus {
  idle,
  advertising,
  discovering,
  connecting,
  connected,
  disconnected,
  error,
}

class DiscoveredDevice {
  final String endpointId;
  final String name;

  const DiscoveredDevice({required this.endpointId, required this.name});
}

class NearbyService {
  static const String _serviceId = 'com.slapzone.app';
  static const Strategy _strategy = Strategy.P2P_POINT_TO_POINT;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _messageController = StreamController<GameMessage>.broadcast();
  final _devicesController = StreamController<List<DiscoveredDevice>>.broadcast();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<GameMessage> get messageStream => _messageController.stream;
  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;

  ConnectionStatus _status = ConnectionStatus.idle;
  ConnectionStatus get status => _status;

  String? _connectedEndpointId;
  String? get connectedEndpointId => _connectedEndpointId;

  final List<DiscoveredDevice> _discoveredDevices = [];

  // Latenz-Messung
  final Map<int, int> _pingTimestamps = {};
  int _latencyMs = 0;
  int get latencyMs => _latencyMs;

  void _updateStatus(ConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  // ── HOST: Advertising starten ─────────────────────────────────────────────
  Future<void> startAdvertising(String userName) async {
    _updateStatus(ConnectionStatus.advertising);
    try {
      await Nearby().startAdvertising(
        userName,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
      debugPrint('[Nearby] Advertising as $userName');
    } catch (e) {
      debugPrint('[Nearby] Advertising error: $e');
      _updateStatus(ConnectionStatus.error);
    }
  }

  // ── CLIENT: Discovery starten ─────────────────────────────────────────────
  Future<void> startDiscovery(String userName) async {
    _updateStatus(ConnectionStatus.discovering);
    _discoveredDevices.clear();
    try {
      await Nearby().startDiscovery(
        userName,
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          if (!_discoveredDevices.any((d) => d.endpointId == id)) {
            _discoveredDevices.add(DiscoveredDevice(endpointId: id, name: name));
            _devicesController.add(List.from(_discoveredDevices));
            debugPrint('[Nearby] Found: $name ($id)');
          }
        },
        onEndpointLost: (id) {
          _discoveredDevices.removeWhere((d) => d.endpointId == id);
          _devicesController.add(List.from(_discoveredDevices));
        },
        serviceId: _serviceId,
      );
    } catch (e) {
      debugPrint('[Nearby] Discovery error: $e');
      _updateStatus(ConnectionStatus.error);
    }
  }

  // ── CLIENT: Verbindung anfragen ───────────────────────────────────────────
  Future<void> requestConnection(String userName, String endpointId) async {
    _updateStatus(ConnectionStatus.connecting);
    try {
      await Nearby().requestConnection(
        userName,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      debugPrint('[Nearby] Connect error: $e');
      _updateStatus(ConnectionStatus.error);
    }
  }

  // ── Verbindungs-Callbacks ─────────────────────────────────────────────────
  void _onConnectionInitiated(String id, ConnectionInfo info) {
    debugPrint('[Nearby] Connection initiated: ${info.endpointName}');
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (_, __) {},
    );
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      _connectedEndpointId = id;
      _updateStatus(ConnectionStatus.connected);
      debugPrint('[Nearby] Connected to $id');
      _startPingLoop();
    } else {
      _updateStatus(ConnectionStatus.error);
      debugPrint('[Nearby] Connection failed: $status');
    }
  }

  void _onDisconnected(String id) {
    _connectedEndpointId = null;
    _updateStatus(ConnectionStatus.disconnected);
    debugPrint('[Nearby] Disconnected from $id');
  }

  // ── Nachrichten ───────────────────────────────────────────────────────────
  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      try {
        final str = String.fromCharCodes(payload.bytes!);
        final json = jsonDecode(str) as Map<String, dynamic>;
        final msg = GameMessage.fromJson(json);

        if (msg.type == MessageType.ping) {
          sendMessage(GameMessage(type: MessageType.pong, data: {'ts': msg.data['ts']}));
          return;
        }
        if (msg.type == MessageType.pong) {
          final ts = msg.data['ts'] as int?;
          if (ts != null && _pingTimestamps.containsKey(ts)) {
            _latencyMs = DateTime.now().millisecondsSinceEpoch - _pingTimestamps[ts]!;
            _pingTimestamps.remove(ts);
          }
          return;
        }

        _messageController.add(msg);
      } catch (e) {
        debugPrint('[Nearby] Parse error: $e');
      }
    }
  }

  Future<void> sendMessage(GameMessage message) async {
    final id = _connectedEndpointId;
    if (id == null) return;
    try {
      final bytes = utf8.encode(message.toJsonString());
      await Nearby().sendBytesPayload(id, Uint8List.fromList(bytes));
    } catch (e) {
      debugPrint('[Nearby] Send error: $e');
    }
  }

  // ── Ping Loop ─────────────────────────────────────────────────────────────
  void _startPingLoop() {
    Timer.periodic(const Duration(seconds: 2), (t) {
      if (_status != ConnectionStatus.connected) {
        t.cancel();
        return;
      }
      final ts = DateTime.now().millisecondsSinceEpoch;
      _pingTimestamps[ts] = ts;
      sendMessage(GameMessage(type: MessageType.ping, data: {'ts': ts}));
    });
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    await Nearby().stopAllEndpoints();
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    _connectedEndpointId = null;
    _updateStatus(ConnectionStatus.idle);
  }

  void dispose() {
    _statusController.close();
    _messageController.close();
    _devicesController.close();
  }
}
