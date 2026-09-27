# Function Index

<!-- One entry per function. Format:
### path/to/file.ext::function_name
What it does, in 1–2 lines.
-->

### lib/protocol/envelope.dart::Envelope
V1 message envelope carrying version, msg_id, sender/recipient public keys, TTL, timestamp, encrypted payload, and signature. Methods: encode to bytes, decode from bytes, withTtl, withSignature, signedBytes for signing/verification.

### lib/crypto/identity.dart::Identity
Device identity: keypair (public/private Ed25519 and X25519) and contact code (human-scannable). Methods: loadOrCreate from secure storage, fromSeeds for testing.

### lib/crypto/seal.dart::seal
Encrypts a message with a shared secret (ChaCha20-Poly1305) and signs it with sender's Ed25519 key. Returns encrypted envelope bytes.

### lib/crypto/seal.dart::verifySignature
Verifies an Ed25519 signature on message bytes using the sender's public key.

### lib/crypto/seal.dart::open
Decrypts a sealed envelope and verifies the sender's signature. Returns plaintext if authentic, throws if tampered.

### lib/contacts.dart::Contact
Contact record: nickname and public key for E2E messaging. Method: fromCode to parse contact code and import their public key.

### lib/contacts.dart::loadContacts
Loads contacts list from secure storage (or empty if first run).

### lib/contacts.dart::saveContacts
Persists contacts list to secure storage.

### lib/transport/transport.dart::Transport
Interface for message transport abstraction. Methods: start/stop, send (bytes to recipient), received (stream of incoming bytes), peers (list of reachable peer IDs).

### lib/transport/bridgefy_transport.dart::BridgefyTransport
Bridgefy mesh transport: sends messages in broadcast mode; app layer addresses via recipient_key in envelope.

### lib/transport/memory_transport.dart::MemoryTransport
In-memory test transport: two instances can connect/disconnect and exchange bytes locally (no real network).

### lib/mesh/router.dart::MeshRouter
Routes messages over Transport, deduplicates by msg_id, applies TTL / hop limits, and stores messages for relay to late-arriving peers. Entry point for app to send/receive.

### lib/chat_log.dart::ChatLog
In-memory chat history. Stores sent and received messages grouped by contact.

### lib/chat_log.dart::ChatMessage
Individual message record: timestamp, sender/recipient, plaintext, delivery state.

### lib/ui/home_screen.dart::HomeScreen
Main UI screen: list of contacts, button to add contact via QR scan, entry point to chat.

### lib/ui/chat_screen.dart::ChatScreen
Chat conversation UI with a contact: message list, text input, send button, auto-scroll.

### lib/main.dart::main
App entry point: initializes device identity, loads contacts, starts MeshRouter, builds home screen.
