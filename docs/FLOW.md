# Code Flow

_As of progress log entry: 2026-09-27 — "Fixed Android build (Java, Gradle, desugaring, packaging)" (see CONTEXT.md). No `lib/` files have changed since the 2026-09-26 "Phase 0 implementation" entry that created them. When updating this doc, only read progress log entries in CONTEXT.md newer than the one above — no need to re-scan the repo unless one of those entries touched `lib/`._

Written for: the project owner (backend dev, Python/C++ background, new to Flutter/Android/iOS) to understand how the app's code flows across files and events.

## The big picture

There's no request/response cycle here like a backend service. Flutter apps are event-driven and long-lived: one `main()` runs once at startup, builds an object graph, and then everything else happens in response to events — button taps, incoming bytes, timers — for as long as the app is open. Think of it more like a C++ program with an event loop (Qt/GLib style) than a Flask app.

There are three architectural layers, and they don't know about each other except through interfaces:

```
UI (Flutter widgets)          — what the user sees/taps
     |
MeshRouter                    — business logic: dedup, TTL, encrypt/decrypt, store-and-forward
     |
Transport (interface)         — "send bytes to nearby devices", nothing more
     |
BridgefyTransport / MemoryTransport
```

## 1. Startup — lib/main.dart

This is your `main()`/`if __name__ == "__main__"` equivalent. It runs exactly once, top to bottom, then hands control to the UI event loop via `runApp()`.

Sequence in `main.dart:17-56`:

1. `Identity.loadOrCreate()` → `lib/crypto/identity.dart:28` — reads the device's Ed25519/X25519 key seeds from secure storage, or generates and saves new ones if this is a fresh install.
2. `loadContacts()` → `lib/contacts.dart:33` — reads the saved contact list (name + public keys) from `SharedPreferences` (Android/iOS's key-value store, roughly like a tiny local JSON db).
3. `ChatLog()` → `lib/chat_log.dart:15` — an empty in-memory message store (lost on restart — noted in CONTEXT.md as a known gap).
4. `BridgefyTransport(apiKey)` → constructed but not started yet.
5. `MeshRouter(...)` → wires everything together. This is the key line: the router is handed the transport, the identity, a callback to look up a contact by public key, and a callback (`onMessage`) to run when a decrypted message arrives. That callback is literally `log.add(...)` — this is how the router talks back to the UI without importing anything UI-related.
6. Permissions + `router.start()` — asks Android for Bluetooth permissions, then starts the mesh.
7. `runApp(MaterialApp(...))` — hands off to Flutter's widget tree, passing all the objects built above down into `HomeScreen`.

Nothing after `main()` runs top-to-bottom again. Everything past this point is a reaction to something: a tap, a stream event, a timer.

## 2. The data layer (plain data + pure functions)

These files have no Flutter dependency — they're the part of the codebase closest to what you already know:

- `lib/protocol/envelope.dart` — the wire format (D3 in Architecture.md). `encode()`/`decode()` are just byte-packing, like a `struct` with manual serialization in C++.
- `lib/crypto/identity.dart` — keypair generation/loading.
- `lib/crypto/seal.dart` — `seal()` (encrypt+sign) and `open()` (verify+decrypt). Pure crypto functions, no I/O beyond what's passed in.
- `lib/contacts.dart` — `Contact` model + load/save to disk.

## 3. Transport — lib/transport/transport.dart

An abstract class — Dart's version of a C++ pure virtual base / Python `ABC`. It defines 4 members any transport must provide: `start()`, `stop()`, `send(bytes)`, and two streams: `received` and `peers`.

Streams are the one truly new concept here. A `Stream` is like an async iterator / generator that anyone can subscribe to (`.listen(callback)`), and a `StreamController` (used in `lib/transport/bridgefy_transport.dart:13-14`) is the producer side — code elsewhere calls `.add(value)` on it, and every listener's callback fires. It's conceptually close to a pub/sub channel or an `asyncio.Queue` with multiple consumers, except push-based rather than pulled.

- `lib/transport/bridgefy_transport.dart` — wraps the real Bridgefy BLE mesh SDK. Bridgefy calls back into `bridgefyDidReceiveData(...)` (`:61`) whenever bytes arrive over Bluetooth from any nearby phone; that handler just pushes the bytes onto the `_received` stream. Same pattern for peer connect/disconnect → `_peers` stream.
- `lib/transport/memory_transport.dart` — a fake, in-process transport used only in tests, where you manually `.connect()` two instances to simulate two phones being in BLE range.

## 4. MeshRouter — lib/mesh/router.dart

This is the real "business logic" layer, and it's plain Dart — no UI, no Bridgefy import. It only talks to `Transport`.

`start()` (`:37`) subscribes to the transport's two streams (`received` → `_onBytes`, `peers` → `_onPeers`), then starts the transport. From here on, `_onBytes` and `_onPeers` are the two event handlers that drive everything the router does — there's no polling loop.

## 5. UI — lib/ui/home_screen.dart and lib/ui/chat_screen.dart

Flutter's UI model: a `StatefulWidget` holds a `State` object; `build()` returns a description of the widget tree (not the actual pixels — Flutter diffs it against last time and repaints only what changed, similar in spirit to React). Calling `setState(...)` schedules a re-run of `build()`. `StreamBuilder` and `ListenableBuilder` are widgets that auto-rebuild themselves whenever a stream emits or a `ChangeNotifier` (like `ChatLog`) calls `notifyListeners()` — that's the entire "reactive UI" mechanism in this app, no other state management library involved.

## Flow trace A: sending a message

1. User types in `chat_screen.dart`, taps send → `_send()` (`:23`) fires (event: `onPressed`/`onSubmitted`).
2. `widget.router.send(text, contact)` → `router.dart:52`.
3. Router calls `seal(text, me, to)` → `seal.dart:26`: derives a shared key (X25519 + HKDF), encrypts with ChaCha20-Poly1305, signs with Ed25519 → returns an `Envelope`.
4. Router marks the msg_id as seen (dedup), stores it (for store-and-forward), then `envelope.encode()` → raw bytes → `transport.send(bytes)`.
5. `BridgefyTransport.send()` (`:35`) broadcasts the bytes over BLE to whoever's in range. Addressing is done at our layer (`recipient_key` inside the envelope), not by Bridgefy.
6. Back in `chat_screen.dart:28`, the UI immediately appends the message to `ChatLog` as "mine" and calls `setState` — this is optimistic local echo, independent of delivery.

## Flow trace B: receiving a message (including relaying)

1. Some nearby phone's Bridgefy SDK delivers bytes → `bridgefyDidReceiveData()` (`bridgefy_transport.dart:61`) → pushed onto the `received` stream.
2. Router's `_onBytes()` (`router.dart:64`) fires automatically (it subscribed to that stream in step "start").
3. Decode envelope, drop if already seen / expired / signature invalid (dedup + TTL + auth, per D3 in Architecture.md).
4. If it's addressed to me (`recipientKey == my public key`): look up the sender via `findContact` callback (wired in `main.dart`), `open()` it → `seal.dart:73` decrypts, then calls `onMessage(from, text)` — which is the `log.add(...)` callback from `main.dart:28`.
5. `ChatLog.add()` (`chat_log.dart:20`) calls `notifyListeners()`.
6. If `ChatScreen` for that contact happens to be open, its `ListenableBuilder` (`chat_screen.dart:51`) rebuilds automatically and the new bubble appears — no manual "refresh" call anywhere.
7. If it's not addressed to me: decrement TTL, store it, and re-broadcast (`transport.send`) — this is the phone acting as a relay hop for someone else's message.
8. Separately, `_onPeers()` (`router.dart:86`) fires whenever Bridgefy reports a new nearby peer, and re-sends everything currently stored — this is the store-and-forward mechanic: a message keeps getting rebroadcast to newly-seen peers until its TTL/age runs out.
