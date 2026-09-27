import 'dart:async';
import 'dart:typed_data';

import 'transport.dart';

/// In-process fake for tests. Nodes only hear each other if linked and both started.
class MemoryTransport implements Transport {
  MemoryTransport(this.id);

  final String id;
  final _links = <MemoryTransport>{};
  final _received = StreamController<Uint8List>.broadcast();
  final _peers = StreamController<Set<String>>.broadcast();
  bool _running = false;

  @override
  Stream<Uint8List> get received => _received.stream;

  @override
  Stream<Set<String>> get peers => _peers.stream;

  Set<String> get _peerIds => _links.where((n) => n._running).map((n) => n.id).toSet();

  void connect(MemoryTransport other) {
    _links.add(other);
    other._links.add(this);
    _notifyBoth(other);
  }

  void disconnect(MemoryTransport other) {
    _links.remove(other);
    other._links.remove(this);
    _notifyBoth(other);
  }

  @override
  Future<void> start() async {
    _running = true;
    _notifyAll();
  }

  @override
  Future<void> stop() async {
    _running = false;
    _notifyAll();
  }

  @override
  Future<void> send(Uint8List data) async {
    if (!_running) return;
    for (final n in _links.where((n) => n._running)) {
      n._received.add(data);
    }
  }

  void _notifyBoth(MemoryTransport other) {
    if (_running && other._running) {
      _peers.add(_peerIds);
      other._peers.add(other._peerIds);
    }
  }

  void _notifyAll() {
    for (final n in _links.where((n) => n._running)) {
      n._peers.add(n._peerIds);
    }
    if (_running) _peers.add(_peerIds);
  }
}
