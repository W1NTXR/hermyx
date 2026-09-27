import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device identity. The Ed25519 public key is the identity; the X25519 key is for encryption.
class Identity {
  Identity._(this.signKeyPair, this.agreeKeyPair, this.signPublic, this.agreePublic);

  final SimpleKeyPair signKeyPair;
  final SimpleKeyPair agreeKeyPair;
  final Uint8List signPublic;
  final Uint8List agreePublic;

  /// What you give a friend so they can add you: both public keys, base64.
  String get contactCode => base64Encode([...signPublic, ...agreePublic]);

  static Future<Identity> fromSeeds(Uint8List signSeed, Uint8List agreeSeed) async {
    final sign = await Ed25519().newKeyPairFromSeed(signSeed);
    final agree = await X25519().newKeyPairFromSeed(agreeSeed);
    final signPub = (await sign.extractPublicKey()).bytes;
    final agreePub = (await agree.extractPublicKey()).bytes;
    return Identity._(sign, agree, Uint8List.fromList(signPub), Uint8List.fromList(agreePub));
  }

  static Future<Identity> loadOrCreate() async {
    const storage = FlutterSecureStorage();
    var signSeed = await storage.read(key: 'sign_seed');
    var agreeSeed = await storage.read(key: 'agree_seed');
    if (signSeed == null || agreeSeed == null) {
      signSeed = base64Encode(_randomBytes(32));
      agreeSeed = base64Encode(_randomBytes(32));
      await storage.write(key: 'sign_seed', value: signSeed);
      await storage.write(key: 'agree_seed', value: agreeSeed);
    }
    return fromSeeds(base64Decode(signSeed), base64Decode(agreeSeed));
  }
}

Uint8List _randomBytes(int n) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(n, (_) => random.nextInt(256)));
}
