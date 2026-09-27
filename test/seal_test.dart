import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermyx/contacts.dart';
import 'package:hermyx/crypto/identity.dart';
import 'package:hermyx/crypto/seal.dart';
import 'package:hermyx/protocol/envelope.dart';

Future<Identity> _identity(int n) => Identity.fromSeeds(
      Uint8List.fromList(List.filled(32, n)),
      Uint8List.fromList(List.filled(32, n + 100)),
    );

Contact _contactOf(Identity i, String name) =>
    Contact(name: name, signKey: i.signPublic, agreeKey: i.agreePublic);

void main() {
  late Identity alice, bob, eve;

  setUp(() async {
    alice = await _identity(1);
    bob = await _identity(2);
    eve = await _identity(3);
  });

  test('recipient can open what the sender sealed', () async {
    final env = await seal('hello bob', alice, _contactOf(bob, 'bob'));
    expect(await open(env, bob, _contactOf(alice, 'alice')), 'hello bob');
  });

  test('contact code round trips', () async {
    final contact = Contact.fromCode('alice', alice.contactCode)!;
    expect(contact.signKey, alice.signPublic);
    expect(contact.agreeKey, alice.agreePublic);
    expect(Contact.fromCode('x', 'not base64!!'), isNull);
  });

  test('a small message fits the LoRa budget', () async {
    final env = await seal('meet at gate 3', alice, _contactOf(bob, 'bob'));
    expect(env.encode().length, lessThanOrEqualTo(maxEnvelopeBytes));
  });

  test('wrong recipient cannot open it', () async {
    final env = await seal('secret', alice, _contactOf(bob, 'bob'));
    expect(await open(env, eve, _contactOf(alice, 'alice')), isNull);
  });

  test('tampered ciphertext is rejected', () async {
    final env = await seal('secret', alice, _contactOf(bob, 'bob'));
    final bytes = env.encode();
    bytes[bytes.length - 70] ^= 1; // inside ciphertext
    final bad = Envelope.decode(bytes)!;
    expect(await verifySignature(bad), isFalse);
    expect(await open(bad, bob, _contactOf(alice, 'alice')), isNull);
  });

  test('a claimed sender who did not sign is rejected', () async {
    final env = await seal('secret', eve, _contactOf(bob, 'bob'));
    final forged = Envelope(
      msgId: env.msgId,
      senderKey: alice.signPublic, // eve pretends to be alice
      recipientKey: env.recipientKey,
      ttl: env.ttl,
      timestamp: env.timestamp,
      nonce: env.nonce,
      ciphertext: env.ciphertext,
      signature: env.signature,
    );
    expect(await open(forged, bob, _contactOf(alice, 'alice')), isNull);
  });

  test('relay changing ttl keeps the signature valid', () async {
    final env = await seal('hi', alice, _contactOf(bob, 'bob'));
    expect(await verifySignature(env.withTtl(2)), isTrue);
  });
}
