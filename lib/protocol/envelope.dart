import 'dart:typed_data';

const envelopeVersion = 1;
const initialTtl = 8;
const maxEnvelopeBytes = 200;

const _headerSize = 1 + 16 + 32 + 32 + 1 + 4 + 12;
const _tagSize = 16;
const _signatureSize = 64;

/// Wire format v1:
/// version | msg_id 16 | sender_key 32 | recipient_key 32 | ttl 1 | timestamp 4 |
/// nonce 12 | ciphertext+tag | signature 64
class Envelope {
  Envelope({
    required this.msgId,
    required this.senderKey,
    required this.recipientKey,
    required this.ttl,
    required this.timestamp,
    required this.nonce,
    required this.ciphertext,
    required this.signature,
  });

  final Uint8List msgId;
  final Uint8List senderKey;
  final Uint8List recipientKey;
  final int ttl;
  final int timestamp; // unix seconds
  final Uint8List nonce;
  final Uint8List ciphertext; // includes the 16-byte tag
  final Uint8List signature;

  String get msgIdHex =>
      msgId.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Header fields that must not change in transit. Used as AEAD associated data.
  Uint8List get aad => Uint8List.fromList([
        envelopeVersion,
        ...msgId,
        ...senderKey,
        ...recipientKey,
        ..._u32(timestamp),
      ]);

  /// Everything the signature covers. Excludes ttl, which relays change.
  Uint8List get signedBytes =>
      Uint8List.fromList([...aad, ...nonce, ...ciphertext]);

  Envelope withTtl(int newTtl) => Envelope(
        msgId: msgId,
        senderKey: senderKey,
        recipientKey: recipientKey,
        ttl: newTtl,
        timestamp: timestamp,
        nonce: nonce,
        ciphertext: ciphertext,
        signature: signature,
      );

  Envelope withSignature(Uint8List newSignature) => Envelope(
        msgId: msgId,
        senderKey: senderKey,
        recipientKey: recipientKey,
        ttl: ttl,
        timestamp: timestamp,
        nonce: nonce,
        ciphertext: ciphertext,
        signature: newSignature,
      );

  Uint8List encode() => Uint8List.fromList([
        envelopeVersion,
        ...msgId,
        ...senderKey,
        ...recipientKey,
        ttl,
        ..._u32(timestamp),
        ...nonce,
        ...ciphertext,
        ...signature,
      ]);

  /// Returns null if the bytes are not a valid v1 envelope.
  static Envelope? decode(Uint8List b) {
    if (b.length < _headerSize + _tagSize + _signatureSize) return null;
    if (b[0] != envelopeVersion) return null;
    final ciphertextEnd = b.length - _signatureSize;
    return Envelope(
      msgId: b.sublist(1, 17),
      senderKey: b.sublist(17, 49),
      recipientKey: b.sublist(49, 81),
      ttl: b[81],
      timestamp: ByteData.sublistView(b, 82, 86).getUint32(0),
      nonce: b.sublist(86, 98),
      ciphertext: b.sublist(_headerSize, ciphertextEnd),
      signature: b.sublist(ciphertextEnd),
    );
  }
}

Uint8List _u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();
