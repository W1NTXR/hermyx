import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'chat_log.dart';
import 'contacts.dart';
import 'crypto/identity.dart';
import 'mesh/router.dart';
import 'transport/bridgefy_transport.dart';
import 'ui/home_screen.dart';

// Pass with: flutter run --dart-define=BRIDGEFY_API_KEY=...
const _bridgefyApiKey = String.fromEnvironment('BRIDGEFY_API_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final identity = await Identity.loadOrCreate();
  final contacts = await loadContacts();
  final log = ChatLog();
  final transport = BridgefyTransport(_bridgefyApiKey);
  final router = MeshRouter(
    transport: transport,
    me: identity,
    findContact: (key) => _findByKey(contacts, key),
    onMessage: (from, text) => log.add(from, ChatMessage(text, mine: false)),
  );

  String? startError;
  if (_bridgefyApiKey.isEmpty) {
    startError = 'No Bridgefy key. Run with --dart-define=BRIDGEFY_API_KEY=...';
  } else {
    try {
      // iOS asks for Bluetooth itself when Bridgefy starts.
      if (Platform.isAndroid) await _askAndroidPermissions();
      await router.start();
    } catch (e) {
      startError = 'Could not start mesh: $e';
    }
  }

  runApp(MaterialApp(
    title: 'Hermyx',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: HomeScreen(
      identity: identity,
      contacts: contacts,
      router: router,
      transport: transport,
      log: log,
      startError: startError,
    ),
  ));
}

Contact? _findByKey(List<Contact> contacts, Uint8List key) {
  for (final c in contacts) {
    if (c.signKey.length == key.length && _sameBytes(c.signKey, key)) return c;
  }
  return null;
}

bool _sameBytes(Uint8List a, Uint8List b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<void> _askAndroidPermissions() async {
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.locationWhenInUse,
  ].request();
}
