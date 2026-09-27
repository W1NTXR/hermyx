import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermyx/protocol/envelope.dart';

Uint8List _bytes(int n, int v) => Uint8List.fromList(List.filled(n, v));

void main() {
  test('encode then decode gives the same envelope', () {
    final env = Envelope(
      msgId: _bytes(16, 1),
      senderKey: _bytes(32, 2),
      recipientKey: _bytes(32, 3),
      ttl: 8,
      timestamp: 1790000000,
      nonce: _bytes(12, 4),
      ciphertext: _bytes(20, 5),
      signature: _bytes(64, 6),
    );
    final back = Envelope.decode(env.encode())!;
    expect(back.encode(), env.encode());
    expect(back.ttl, 8);
    expect(back.timestamp, 1790000000);
    expect(back.msgIdHex, env.msgIdHex);
  });

  test('decode rejects short input and unknown versions', () {
    expect(Envelope.decode(_bytes(10, 1)), isNull);
    expect(Envelope.decode(_bytes(300, 9)), isNull);
  });

  test('changing ttl does not change signed bytes', () {
    final env = Envelope(
      msgId: _bytes(16, 1),
      senderKey: _bytes(32, 2),
      recipientKey: _bytes(32, 3),
      ttl: 8,
      timestamp: 1,
      nonce: _bytes(12, 4),
      ciphertext: _bytes(20, 5),
      signature: _bytes(64, 6),
    );
    expect(env.withTtl(3).signedBytes, env.signedBytes);
  });
}
