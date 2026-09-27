import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_log.dart';
import '../contacts.dart';
import '../crypto/identity.dart';
import '../mesh/router.dart';
import '../transport/transport.dart';
import '../transport/bridgefy_transport.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.identity,
    required this.contacts,
    required this.router,
    required this.transport,
    required this.log,
    this.startError,
  });

  final Identity identity;
  final List<Contact> contacts; // shared with the router, so adds are seen by it
  final MeshRouter router;
  final Transport transport;
  final ChatLog log;
  final String? startError;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final transport = widget.transport;
    if (transport is BridgefyTransport) {
      transport.restartRecommended.listen((_) => _showRestartWarning());
    }
  }

  Future<void> _showRestartWarning() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart recommended'),
        content: const Text(
          'This session has cycled through a lot of Bluetooth connections. '
          'Close and reopen the app to avoid a system Bluetooth crash.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _addContact() async {
    final name = TextEditingController();
    final code = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: code, decoration: const InputDecoration(labelText: 'Their code')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (added != true || !mounted) return;
    final contact = Contact.fromCode(name.text.trim(), code.text);
    if (contact == null || contact.name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Needs a name and a valid code')));
      return;
    }
    setState(() => widget.contacts.add(contact));
    await saveContacts(widget.contacts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hermyx'),
        actions: [
          StreamBuilder<Set<String>>(
            stream: widget.transport.peers,
            initialData: widget.transport is BridgefyTransport
                ? (widget.transport as BridgefyTransport).currentPeers
                : const {},
            builder: (context, snap) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('${snap.data!.length} nearby')),
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton(onPressed: _addContact, child: const Icon(Icons.person_add)),
      body: ListView(
        children: [
          if (widget.startError != null)
            ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(widget.startError!),
            ),
          ListTile(
            title: const Text('My code (send this to a friend)'),
            subtitle: Text(widget.identity.contactCode),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => Clipboard.setData(ClipboardData(text: widget.identity.contactCode)),
            ),
          ),
          const Divider(),
          for (final c in widget.contacts)
            ListTile(
              title: Text(c.name),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(contact: c, router: widget.router, log: widget.log),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
