# unConnect — Roadmap

_Last updated: 2026-09-26_

## Vision
Cross-platform (iOS + Android), peer-to-peer, end-to-end encrypted chat that works **without internet or cell signal**, built first for **events and concert venues** — where thousands of people are packed together and networks are jammed.

## Why venues first
- High phone density = a naturally strong phone-to-phone mesh.
- Cellular / Wi-Fi routinely overloaded at concerts, festivals, stadiums.
- Clear, bounded use cases: find friends, coordinate meetups, get organizer updates.
- Short sessions (a few hours) = battery and background limits are manageable.

## Guiding principles
- **Offline-first.** Internet is never required.
- **Private by default.** App-layer E2E encryption; every relay is untrusted.
- **Transport-agnostic.** Bridgefy is the first transport, not the foundation (see `architecture-decisions.md`, D3).
- **Small messages.** Text-first, compact packets.

---

## Phase 0 — Foundations
- [ ] Pick app framework (Flutter or React Native — both supported by Bridgefy)
- [ ] Bridgefy dev account + API key; confirm free-tier limits
- [ ] Define v1 message envelope (version, msg_id, sender_key, recipient_key, ttl, timestamp, encrypted payload, signature)
- [ ] Identity = keypair generated on device (X25519 / Ed25519)
- [ ] `Transport` interface + `BridgefyTransport` implementation
- [ ] Local encrypted storage for messages and contacts

**Exit:** two phones exchange an encrypted envelope over Bridgefy.

## Phase 1 — MVP: 1:1 offline chat
- [ ] Add contact by scanning a QR code (exchanges public keys offline)
- [ ] 1:1 chat over multi-hop mesh
- [ ] Store-and-forward queue, dedup by msg_id, TTL / hop limit
- [ ] Message states: queued → relayed → delivered (receipts)
- [ ] Bluetooth permission onboarding for iOS and Android
- [ ] Basic chat UI

**Exit:** a message reliably crosses 3+ hops between iPhone and Android in a room test.

## Phase 2 — Venue features
- [ ] Group chats for friend groups (E2E group keys)
- [ ] "Meet me at…" quick messages / landmark pins (no GPS dependency)
- [ ] Nearby friends indicator (which contacts are reachable via mesh)
- [ ] Signed organizer broadcasts (verified announcements, read-only channel)
- [ ] Event mode: join an event via QR at the entrance
- [ ] Battery saver mode + clear "keep app open to help the mesh" messaging

**Exit:** feature-complete for a friends-group-at-a-concert scenario.

## Phase 3 — Field testing
- [ ] Test with 10 → 30 → 100+ devices (college fests, local gigs)
- [ ] Measure: delivery rate, latency, hop count, battery drain per hour
- [ ] iOS background behaviour in real crowds
- [ ] Tune TTL, retry, flood/relay limits for high density (BLE congestion)
- [ ] Anti-spam / rate limiting on relays

**Exit:** target metrics met (see below) at a 100+ device test.

## Phase 4 — Beta & launch
- [ ] Security review of crypto and protocol
- [ ] Beta at a real event (partner with an organizer)
- [ ] App Store / Play Store submission (Bluetooth usage justification, privacy policy)
- [ ] Decide whether to stay on Bridgefy commercially or move to own BLE mesh

---

## Later (not planned yet)
- **Relay devices / beacons** (BLE + LoRa) to extend range and speed up delivery across large venues. Design notes in `architecture-decisions.md` (D2). No work scheduled — Phase 0–1 choices keep this door open.
- Internet sync when a device regains connectivity
- Photo/attachment sharing between nearby phones

## Target metrics (initial guesses — revise after Phase 3)
| Metric | Target |
|---|---|
| Delivery rate within venue | ≥ 90% |
| Median delivery time (≤ 5 hops) | < 30 s |
| Battery drain in event mode | < 10% / hour |

## Key risks
| Risk | Mitigation |
|---|---|
| iOS background BLE limits | Store-and-forward; encourage app in foreground; event mode |
| BLE congestion in dense crowds | Tune TTL / relay limits; test at scale in Phase 3 |
| Bridgefy lock-in / pricing | Own envelope + Transport abstraction from Phase 0 |
| Spam / abuse on open mesh | Rate limiting, signed messages, contact-only DMs by default |
| Low adoption (mesh needs users) | Organizer partnerships; QR onboarding at venue entry |