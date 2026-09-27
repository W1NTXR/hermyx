import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../contacts.dart';
import '../crypto/identity.dart';
import '../crypto/seal.dart';
import '../protocol/envelope.dart';
import '../transport/transport.dart';

const maxTextBytes = 160;
const maxAgeSeconds = 24 * 60 * 60;
const _maxStored = 200;
const _maxClockSkewSeconds = 10 * 60;

/// Dedup, TTL and store-and-forward on top of a [Transport].
class MeshRouter {
  MeshRouter({
    required this.transport,
    required this.me,
    required this.findContact,
    required this.onMessage,
    int Function()? nowSeconds,
  }) : _now = nowSeconds ?? (() => DateTime.now().millisecondsSinceEpoch ~/ 1000);

  final Transport transport;
  final Identity me;
  final Contact? Function(Uint8List signKey) findContact;
  final void Function(Contact from, String text) onMessage;
  final int Function() _now;

  final _seen = <String>{};
  final _stored = <String, Envelope>{}; // insertion order = oldest first
  var _knownPeers = <String>{};
  final _subs = <StreamSubscription<dynamic>>[];

  Future<void> start() async {
    _subs.add(transport.received.listen(_onBytes));
    _subs.add(transport.peers.listen(_onPeers));
    await transport.start();
  }

  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await transport.stop();
  }

  /// Encrypts, stores and broadcasts. Returns the envelope size in bytes.
  Future<int> send(String text, Contact to) async {
    if (utf8.encode(text).length > maxTextBytes) {
      throw ArgumentError('Message is longer than $maxTextBytes bytes');
    }
    final env = await seal(text, me, to);
    _seen.add(env.msgIdHex);
    _store(env);
    final bytes = env.encode();
    await transport.send(bytes);
    return bytes.length;
  }

  Future<void> _onBytes(Uint8List bytes) async {
    final env = Envelope.decode(bytes);
    if (env == null || _seen.contains(env.msgIdHex)) return;
    if (_expired(env) || env.timestamp > _now() + _maxClockSkewSeconds) return;
    if (!await verifySignature(env)) return;
    // A second copy may have arrived while we were verifying.
    if (!_seen.add(env.msgIdHex)) return;

    if (_same(env.recipientKey, me.signPublic)) {
      final from = findContact(env.senderKey);
      if (from == null) return;
      final text = await open(env, me, from);
      if (text != null) onMessage(from, text);
      return;
    }
    if (env.ttl <= 0) return;
    final relayed = env.withTtl(env.ttl - 1);
    _store(relayed);
    await transport.send(relayed.encode());
  }

  // Push everything we hold to peers we have not seen before.
  Future<void> _onPeers(Set<String> peers) async {
    final hasNewPeer = peers.any((p) => !_knownPeers.contains(p));
    _knownPeers = peers;
    if (!hasNewPeer) return;
    _stored.removeWhere((_, env) => _expired(env));
    for (final env in _stored.values.toList()) {
      await transport.send(env.encode());
    }
  }

  void _store(Envelope env) {
    _stored[env.msgIdHex] = env;
    if (_stored.length > _maxStored) _stored.remove(_stored.keys.first);
  }

  bool _expired(Envelope env) => _now() - env.timestamp > maxAgeSeconds;
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
