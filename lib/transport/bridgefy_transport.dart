import 'dart:async';
import 'dart:typed_data';

import 'package:bridgefy/bridgefy.dart';
import 'package:flutter/foundation.dart';

import 'transport.dart';

// Each BLE connect/disconnect leaks one Android BroadcastReceiver inside the
// Bridgefy SDK (registered by Nordic's BleManager, never unregistered). The
// process-wide cap is 1000; warn well below it since other plugins register
// receivers too.
const _churnWarningThreshold = 700;

class BridgefyTransport with BridgefyDelegate implements Transport {
  BridgefyTransport(this.apiKey);

  final String apiKey;
  final _bridgefy = Bridgefy();
  final _received = StreamController<Uint8List>.broadcast();
  final _peers = StreamController<Set<String>>.broadcast();
  final _restartRecommended = StreamController<void>.broadcast();
  final _peerIds = <String>{};
  String _myUserId = '';
  int _connectionChurn = 0;
  bool _warnedRestart = false;

  @override
  Stream<Uint8List> get received => _received.stream;

  @override
  Stream<Set<String>> get peers => _peers.stream;

  /// Fires once when connection churn nears the OS receiver-registration cap.
  Stream<void> get restartRecommended => _restartRecommended.stream;

  /// Current peer snapshot for listeners that subscribe after discovery starts.
  Set<String> get currentPeers => Set.unmodifiable(_peerIds);

  void _trackConnectionChurn() {
    _connectionChurn++;
    if (!_warnedRestart && _connectionChurn >= _churnWarningThreshold) {
      _warnedRestart = true;
      _restartRecommended.add(null);
    }
  }

  @override
  Future<void> start() async {
    await _bridgefy.initialize(apiKey: apiKey, delegate: this);
    await _bridgefy.start();
  }

  @override
  Future<void> stop() => _bridgefy.stop();

  // Broadcast on purpose: our own layer does the addressing via recipient_key.
  @override
  Future<void> send(Uint8List data) async {
    await _bridgefy.send(
      data: data,
      transmissionMode: BridgefyTransmissionMode(
        type: BridgefyTransmissionModeType.broadcast,
        uuid: _myUserId,
      ),
    );
  }

  @override
  void bridgefyDidStart({required String currentUserID}) {
    _myUserId = currentUserID;
    debugPrint('Bridgefy: started, userID=$currentUserID');
  }

  @override
  void bridgefyDidConnect({required String userID}) {
    debugPrint('Bridgefy: connected to $userID');
    _peerIds.add(userID);
    _peers.add({..._peerIds});
    _trackConnectionChurn();
  }

  @override
  void bridgefyDidDisconnect({required String userID}) {
    debugPrint('Bridgefy: disconnected from $userID');
    _peerIds.remove(userID);
    _peers.add({..._peerIds});
    _trackConnectionChurn();
  }

  @override
  void bridgefyDidReceiveData({
    required Uint8List data,
    required String messageId,
    required BridgefyTransmissionMode transmissionMode,
  }) {
    _received.add(data);
  }

  @override
  void bridgefyDidFailToStart({required BridgefyError error}) {
    debugPrint('Bridgefy: failed to start — $error');
    _received.addError(error);
  }

  @override
  void bridgefyDidStop() {}

  @override
  void bridgefyDidFailToStop({required BridgefyError error}) {}

  @override
  void bridgefyDidDestroySession() {}

  @override
  void bridgefyDidFailToDestroySession() {}

  @override
  void bridgefyDidEstablishSecureConnection({required String userID}) {}

  @override
  void bridgefyDidFailToEstablishSecureConnection(
      {required String userID, required BridgefyError error}) {
    debugPrint('Bridgefy: failed to establish secure connection with $userID — $error');
    _trackConnectionChurn();
  }

  @override
  void bridgefyDidSendMessage({required String messageID}) {}

  @override
  void bridgefyDidFailSendingMessage(
      {required String messageID, BridgefyError? error}) {}

  @override
  void bridgefyDidSendDataProgress(
      {required String messageID, required int position, required int of}) {}
}
