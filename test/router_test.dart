import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermyx/contacts.dart';
import 'package:hermyx/crypto/identity.dart';
import 'package:hermyx/crypto/seal.dart';
import 'package:hermyx/mesh/router.dart';
import 'package:hermyx/transport/memory_transport.dart';

class Node {
  Node(this.identity, this.transport, this.contacts);

  final Identity identity;
  final MemoryTransport transport;
  final List<Contact> contacts;
  final inbox = <String>[];
  late final MeshRouter router;
  int clock = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  Contact get asContact => Contact(
      name: 'node', signKey: identity.signPublic, agreeKey: identity.agreePublic);

  static Future<Node> create(int n, List<Contact> contacts) async {
    final identity = await Identity.fromSeeds(
      Uint8List.fromList(List.filled(32, n)),
      Uint8List.fromList(List.filled(32, n + 100)),
    );
    final node = Node(identity, MemoryTransport('n$n'), contacts);
    node.router = MeshRouter(
      transport: node.transport,
      me: identity,
      findContact: (key) => node.contacts
          .where((c) => c.signKey.toString() == key.toString())
          .firstOrNull,
      onMessage: (from, text) => node.inbox.add(text),
      nowSeconds: () => node.clock,
    );
    return node;
  }
}

Future<void> settle() => Future.delayed(const Duration(milliseconds: 100));

Future<List<Node>> threeNodes() async {
  final a = await Node.create(1, []);
  final b = await Node.create(2, []);
  final c = await Node.create(3, []);
  a.contacts.add(c.asContact);
  c.contacts.add(a.asContact);
  a.transport.connect(b.transport);
  b.transport.connect(c.transport);
  return [a, b, c];
}

void main() {
  test('message crosses a relay when both ends are online', () async {
    final [a, b, c] = await threeNodes();
    for (final n in [a, b, c]) {
      await n.router.start();
    }
    await a.router.send('hi c', c.asContact);
    await settle();
    expect(c.inbox, ['hi c']);
    expect(b.inbox, isEmpty); // relay cannot read it
  });

  test('store-and-forward: relay carries it to a node that joins later', () async {
    final [a, b, c] = await threeNodes();
    await a.router.start();
    await b.router.start();
    await a.router.send('late', c.asContact);
    await settle();
    expect(c.inbox, isEmpty);

    await c.router.start(); // c comes into range
    await settle();
    expect(c.inbox, ['late']);
  });

  test('duplicates are delivered once', () async {
    final [a, b, c] = await threeNodes();
    b.transport.connect(a.transport); // already linked, harmless
    a.transport.connect(c.transport); // direct path as well as via b
    for (final n in [a, b, c]) {
      await n.router.start();
    }
    await a.router.send('once', c.asContact);
    await settle();
    expect(c.inbox, ['once']);
  });

  test('expired envelopes are dropped', () async {
    final [a, _, c] = await threeNodes();
    a.transport.connect(c.transport);
    await c.router.start();
    await a.router.start();
    final env = await seal('old', a.identity, c.asContact);
    c.clock += maxAgeSeconds + 10;
    await a.transport.send(env.encode());
    await settle();
    expect(c.inbox, isEmpty);
  });

  test('envelope with ttl 0 is not relayed', () async {
    final [a, b, c] = await threeNodes();
    for (final n in [b, c]) {
      await n.router.start();
    }
    await a.router.start();
    final env = (await seal('short', a.identity, c.asContact)).withTtl(0);
    await a.transport.send(env.encode());
    await settle();
    expect(c.inbox, isEmpty);
  });

  test('over-long text is refused', () async {
    final [a, _, c] = await threeNodes();
    expect(() => a.router.send('x' * (maxTextBytes + 1), c.asContact),
        throwsArgumentError);
  });

  test('garbage bytes are ignored', () async {
    final [a, b, c] = await threeNodes();
    await b.router.start();
    await a.router.start();
    await a.transport.send(Uint8List.fromList(List.filled(300, 7)));
    await settle();
    expect(b.inbox, isEmpty);
    expect(c.inbox, isEmpty);
  });
}
