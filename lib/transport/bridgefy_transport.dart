import 'dart:async';
import 'dart:typed_data';

import 'package:bridgefy/bridgefy.dart';

import 'transport.dart';

class BridgefyTransport with BridgefyDelegate implements Transport {
  BridgefyTransport(this.apiKey);

  final String apiKey;
  final _bridgefy = Bridgefy();
  final _received = StreamController<Uint8List>.broadcast();
  final _peers = StreamController<Set<String>>.broadcast();
  final _peerIds = <String>{};
  String _myUserId = '';

  @override
  Stream<Uint8List> get received => _received.stream;

  @override
  Stream<Set<String>> get peers => _peers.stream;

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
  void bridgefyDidStart({required String currentUserID}) => _myUserId = currentUserID;

  @override
  void bridgefyDidConnect({required String userID}) {
    _peerIds.add(userID);
    _peers.add({..._peerIds});
  }

  @override
  void bridgefyDidDisconnect({required String userID}) {
    _peerIds.remove(userID);
    _peers.add({..._peerIds});
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
  void bridgefyDidFailToStart({required BridgefyError error}) =>
      _received.addError(error);

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
      {required String userID, required BridgefyError error}) {}

  @override
  void bridgefyDidSendMessage({required String messageID}) {}

  @override
  void bridgefyDidFailSendingMessage(
      {required String messageID, BridgefyError? error}) {}

  @override
  void bridgefyDidSendDataProgress(
      {required String messageID, required int position, required int of}) {}
}
