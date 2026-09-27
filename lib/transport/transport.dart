import 'dart:typed_data';

/// Carries opaque bytes to nearby nodes. Knows nothing about envelopes or keys.
abstract class Transport {
  Future<void> start();
  Future<void> stop();
  Future<void> send(Uint8List data);
  Stream<Uint8List> get received;

  /// Emits the full set of currently connected peer ids whenever it changes.
  Stream<Set<String>> get peers;
}
