import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class Contact {
  Contact({required this.name, required this.signKey, required this.agreeKey});

  final String name;
  final Uint8List signKey;
  final Uint8List agreeKey;

  /// Returns null if the code is not two 32-byte keys in base64.
  static Contact? fromCode(String name, String code) {
    try {
      final bytes = base64Decode(code.trim());
      if (bytes.length != 64) return null;
      return Contact(
        name: name,
        signKey: Uint8List.fromList(bytes.sublist(0, 32)),
        agreeKey: Uint8List.fromList(bytes.sublist(32)),
      );
    } on FormatException {
      return null;
    }
  }

  String get code => base64Encode([...signKey, ...agreeKey]);
}

const _prefsKey = 'contacts';

Future<List<Contact>> loadContacts() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_prefsKey) ?? [];
  final contacts = <Contact>[];
  for (final item in raw) {
    final json = jsonDecode(item) as Map<String, dynamic>;
    final contact = Contact.fromCode(json['name'] as String, json['code'] as String);
    if (contact != null) contacts.add(contact);
  }
  return contacts;
}

Future<void> saveContacts(List<Contact> contacts) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(
    _prefsKey,
    contacts.map((c) => jsonEncode({'name': c.name, 'code': c.code})).toList(),
  );
}
