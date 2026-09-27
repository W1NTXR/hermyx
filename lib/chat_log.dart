import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'contacts.dart';

class ChatMessage {
  ChatMessage(this.text, {required this.mine});

  final String text;
  final bool mine;
}

/// In-memory chat history. Lost on restart (prototype).
class ChatLog extends ChangeNotifier {
  final _byContact = <String, List<ChatMessage>>{};

  List<ChatMessage> of(Contact c) => _byContact[base64Encode(c.signKey)] ?? [];

  void add(Contact c, ChatMessage m) {
    _byContact.putIfAbsent(base64Encode(c.signKey), () => []).add(m);
    notifyListeners();
  }
}
