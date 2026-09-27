# Project Context

## Current State
- Phase: Phase 0 (Foundations) — code complete, not yet tested on real phones
- Working: v1 envelope, device identity keypair management, E2E encryption (seal/open), Transport abstraction (Bridgefy + memory), MeshRouter (dedup, TTL, store-and-forward), contacts, in-memory chat log, basic chat UI; 17 tests passing; flutter analyze clean; package ID com.w1ntxr.hermyx; Bridgefy API key in env.json
- Broken / pending: Android build fails (Java 25 vs Gradle 8.14, needs JDK 17/21 or Gradle 8.15+); iOS build/signing untried; messages in-memory only (not persisted)
- Next step: Fix Java/Gradle, test on two real phones (Phase 0 exit)

## Progress Log
<!-- Newest first. Format:
### YYYY-MM-DD — short title
- Done:
- Files:
- Next:
-->

### 2026-09-27 — Package ID, Bridgefy API key setup, check-docs hook fix
- Done: Renamed package/bundle ID to com.w1ntxr.hermyx (Android + iOS); created env.json (gitignored) for user-supplied Bridgefy API key; added env.example.json template; changed flutter run to use --dart-define-from-file=env.json; fixed .claude/hooks/check-docs.sh to use git status --porcelain -uall
- Files: android/app/build.gradle.kts, android/app/src/main/kotlin/com/w1ntxr/hermyx/MainActivity.kt, ios/Runner.xcodeproj/project.pbxproj, .gitignore, env.example.json, .claude/hooks/check-docs.sh
- Next: Fix Java/Gradle version mismatch, run on two real phones (Phase 0 exit)

### 2026-09-26 — Phase 0 implementation: core protocol, crypto, transport, router, UI
- Done: Implemented v1 envelope, device identity (Ed25519 + X25519), E2E seal/open (ChaCha20-Poly1305), Transport interface (Bridgefy + memory test), MeshRouter (dedup, TTL, store-and-forward), contacts, ChatLog, HomeScreen + ChatScreen UI; 17 tests passing; flutter analyze clean
- Files: lib/protocol/envelope.dart, lib/crypto/identity.dart, lib/crypto/seal.dart, lib/contacts.dart, lib/transport/ (3 files), lib/mesh/router.dart, lib/chat_log.dart, lib/ui/ (2 files), lib/main.dart (replaced template), pubspec.yaml, AndroidManifest.xml, ios/Runner/Info.plist
- Next: Fix Java/Gradle mismatch, register package ID, obtain Bridgefy API key, test Phase 0 exit (two phones, 3+ hops)

### 2026-09-26 — Project setup and planning
- Done: Established Architecture decisions (D1–D3) and Roadmap phases; documented project context
- Files: Architecture.md, Roadmap.md, CONTEXT.md, CLAUDE.md
- Next: Install Flutter SDK
