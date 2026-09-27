import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../contacts.dart';
import '../protocol/envelope.dart';
import 'identity.dart';

final _aead = Chacha20.poly1305Aead();

Future<SecretKey> _sharedKey(Identity me, Uint8List theirAgreeKey) async {
  final shared = await X25519().sharedSecretKey(
    keyPair: me.agreeKeyPair,
    remotePublicKey: SimplePublicKey(theirAgreeKey, type: KeyPairType.x25519),
  );
  return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
    secretKey: shared,
    // cryptography_flutter's Android HMAC uses SecretKeySpec, which rejects an
    // empty key; HKDF's spec default for an omitted salt is a zero-filled
    // block the length of the hash output, so use that explicitly.
    nonce: Uint8List(32),
    info: utf8.encode('hermyx-v1'),
  );
}

/// Encrypts [text] for [to] and signs the result.
Future<Envelope> seal(String text, Identity me, Contact to) async {
  final random = Random.secure();
  Uint8List randomBytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => random.nextInt(256)));

  final unsigned = Envelope(
    msgId: randomBytes(16),
    senderKey: me.signPublic,
    recipientKey: to.signKey,
    ttl: initialTtl,
    timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    nonce: randomBytes(12),
    ciphertext: Uint8List(0),
    signature: Uint8List(0),
  );
  final box = await _aead.encrypt(
    utf8.encode(text),
    secretKey: await _sharedKey(me, to.agreeKey),
    nonce: unsigned.nonce,
    aad: unsigned.aad,
  );
  final withCipher = Envelope(
    msgId: unsigned.msgId,
    senderKey: unsigned.senderKey,
    recipientKey: unsigned.recipientKey,
    ttl: unsigned.ttl,
    timestamp: unsigned.timestamp,
    nonce: unsigned.nonce,
    ciphertext: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    signature: Uint8List(0),
  );
  final signature = await Ed25519().sign(withCipher.signedBytes, keyPair: me.signKeyPair);
  return withCipher.withSignature(Uint8List.fromList(signature.bytes));
}

/// Checks the sender's signature. Any relay can do this: the sender key is in the envelope.
Future<bool> verifySignature(Envelope env) {
  return Ed25519().verify(
    env.signedBytes,
    signature: Signature(
      env.signature,
      publicKey: SimplePublicKey(env.senderKey, type: KeyPairType.ed25519),
    ),
  );
}

/// Decrypts an envelope from [from]. Returns null if anything does not check out.
Future<String?> open(Envelope env, Identity me, Contact from) async {
  if (!_same(env.senderKey, from.signKey)) return null;
  if (!_same(env.recipientKey, me.signPublic)) return null;
  if (!await verifySignature(env)) return null;
  final tagStart = env.ciphertext.length - 16;
  try {
    final clear = await _aead.decrypt(
      SecretBox(
        env.ciphertext.sublist(0, tagStart),
        nonce: env.nonce,
        mac: Mac(env.ciphertext.sublist(tagStart)),
      ),
      secretKey: await _sharedKey(me, from.agreeKey),
      aad: env.aad,
    );
    return utf8.decode(clear);
  } on SecretBoxAuthenticationError {
    return null;
  } on FormatException {
    return null;
  }
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
