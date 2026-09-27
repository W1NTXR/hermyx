# Hermyx — Architecture Decisions

_Last updated: 2026-09-26_

## D1. Transport SDK: start with Bridgefy (prototype)
- Bridgefy fits the "hop phone-to-phone until delivered" model out of the box (BLE mesh, multi-hop, E2E, iOS + Android + Flutter/RN).
- Ditto considered: stronger for data sync / attachments / cloud sync, but it's a sync DB, not a messaging mesh — relays store others' data and addressing must be hand-built.
- iPhone <-> Android offline = BLE only. iOS background BLE is restricted -> design for store-and-forward, not live paths.

## D2. Future: physical relay beacons (planned, not now)
- Concept: Phone --BLE--> Beacon ==LoRa (km range)==> Beacon --BLE--> Phone.
- Hardware candidates: ESP32-S3 / nRF52840 + SX1262 (Heltec V3, LilyGO T-Beam, RAK WisBlock). Battery + solar.
- Beacons cannot join a Bridgefy mesh (closed, phone-only) -> beacons require our own protocol.
- First step when we get there: prototype with Meshtastic firmware before writing custom firmware.
- India: LoRa in 865–867 MHz licence-exempt band, respect power limits.
- Side benefit: fixed beacons with a known BLE service UUID help wake iOS apps in background.

## D3. Rules to follow NOW so beacons can be added later
1. **Own the message envelope.** Define our own packet format (version, msg_id, sender_key, recipient_key, ttl, timestamp, encrypted payload, signature). Bridgefy only carries it as opaque bytes.
2. **App-layer E2E encryption** with our own keys (X25519 + ChaCha20-Poly1305/AES-GCM). Never rely on the SDK's encryption alone; every relay (phone or beacon) is untrusted.
3. **Identity = public key**, not a Bridgefy user ID.
4. **Transport abstraction.** A `Transport` interface (send, receive, peers) with `BridgefyTransport` as the first implementation; later `BeaconBleTransport`, `LoRaTransport`, `InternetTransport`.
5. **Own dedup / TTL / store-and-forward queue** in our layer, keyed by msg_id.
6. **Keep text payloads small** (target < ~200 bytes after encryption) so they fit LoRa. Attachments = separate, phone-only path.
7. **Version the protocol** from v1 so beacon firmware and apps can evolve independently.