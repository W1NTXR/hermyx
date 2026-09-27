import 'package:flutter/material.dart';

import '../chat_log.dart';
import '../contacts.dart';
import '../mesh/router.dart';
import '../protocol/envelope.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.contact, required this.router, required this.log});

  final Contact contact;
  final MeshRouter router;
  final ChatLog log;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  String? _note;

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    try {
      final size = await widget.router.send(text, widget.contact);
      widget.log.add(widget.contact, ChatMessage(text, mine: true));
      _input.clear();
      setState(() => _note = size > maxEnvelopeBytes
          ? 'Sent, but $size bytes is over the $maxEnvelopeBytes byte LoRa target'
          : null);
    } on ArgumentError {
      setState(() => _note = 'Too long: keep it under $maxTextBytes bytes');
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.contact.name)),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: widget.log,
              builder: (context, _) {
                final messages = widget.log.of(widget.contact);
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    return Align(
                      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Card(
                        color: m.mine ? Theme.of(context).colorScheme.primaryContainer : null,
                        child: Padding(padding: const EdgeInsets.all(10), child: Text(m.text)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_note != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(_note!)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Message'),
                    ),
                  ),
                  IconButton(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
