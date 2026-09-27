# Project Context

## Current State
- Phase: Phase 0 (Foundations) — real-phone testing in progress; Android send crash fixed, diagnosing "0 nearby peers" issue and a Bridgefy SDK receiver-leak crash
- Working: v1 envelope, device identity keypair management, E2E encryption (seal/open), Transport abstraction (Bridgefy + memory), MeshRouter (dedup, TTL, store-and-forward), contacts, in-memory chat log, basic chat UI, debug logging in Bridgefy callbacks, connection-churn tracking with a restart-recommended warning dialog (mitigation for a Bridgefy SDK receiver leak); 17 tests passing; flutter analyze clean; package ID com.w1ntxr.hermyx; Bridgefy API key in env.json; 220 MB debug APK builds
- Broken / pending: One Android + one iOS device tested, neither discovers the other (0 nearby peers); Android crashes with "IllegalStateException: Too many receivers, total of 1000, registered for pid" from inside the Bridgefy SDK (Nordic BleManager leaks a BroadcastReceiver per connect/disconnect/failed-secure-connection event, never unregisters it) — mitigated with a churn counter + restart warning, not fixed (third-party SDK bug); also hit javax.crypto.AEADBadTagException inside Bridgefy's own CryptoManagerImpl.decryptMetadata (internal mesh handshake decryption, not our app-layer crypto), matching an unresolved upstream report (bridgefy/bridgefy_flutter#45) of Android<->iOS-specific discovery/delivery failure — unconfirmed hypothesis that this, the "0 nearby peers" bug, and the receiver-leak crash share one root cause: a cross-platform handshake divergence in Bridgefy's native SDKs; not yet tested Android-to-Android to isolate this; if confirmed, this could block the Phase 0 exit criterion on the current transport choice (Architecture.md D1); iOS build/signing untried; messages in-memory only (not persisted); AGP 8.11.1 + Kotlin 2.2.20 will soon be unsupported (upgrade later; not blocking); Bridgefy free-tier limits/billing untested
- Next step: User to decide whether to run an Android-to-Android test (to confirm/rule out the cross-platform-specific handshake hypothesis) and/or file a Bridgefy support ticket / comment on GitHub issue #45 — paused for now, no action taken yet; otherwise continue diagnosing peer discovery via logcat as previously planned

## Progress Log
<!-- Newest first. Format:
### YYYY-MM-DD — short title
- Done:
- Files:
- Next:
-->

### 2026-09-27 — Found Bridgefy internal decryption error (AEADBadTagException) + matching upstream GitHub issue; cross-platform handshake suspected as root cause
- Done: While diagnosing "0 nearby peers" between the Android phone and iPhone, found a new Android log error: javax.crypto.AEADBadTagException ("error:1e000065:Cipher functions:OPENSSL_internal:BAD_DECRYPT") thrown from inside Bridgefy's own me.bridgefy.crypto.internal.CryptoManagerImpl.decryptMetadata. This is Bridgefy's internal mesh handshake/session-metadata decryption — separate from and unaffected by our app-layer E2E crypto in lib/crypto/seal.dart (ChaCha20-Poly1305, per Architecture.md D3 rule 2). Searched Bridgefy's GitHub tracker and found bridgefy/bridgefy_flutter#45 ("Cross-platform compatibility issue between iOS and Android"), open since June 2025 with zero maintainer response, reporting the same symptom: Android<->iOS discovery/delivery silently fails while same-platform pairs (iOS<->iOS) work fine. Working hypothesis, unconfirmed: the "0 nearby peers" bug, this AEADBadTagException, and the earlier-diagnosed "Too many receivers, total of 1000" crash may all be symptoms of one root cause — Bridgefy's iOS and Android native SDKs diverging in their cross-platform secure-connection handshake, failing specifically between Android and iOS and never same-platform. Not yet tested Android-to-Android to isolate whether the bug is cross-platform-specific. This is significant because Architecture.md D1 chose Bridgefy specifically for its iOS+Android model, and Roadmap.md Phase 0's exit criterion is a cross-platform test; if this upstream bug is real and unfixed, it may block that exit criterion on the current transport choice. No code changed — user chose to log this finding and pause; no support ticket or Android-to-Android test taken yet, that decision is deferred to later.
- Files: None (diagnosis only)
- Next: User to decide whether to run an Android-to-Android test (to confirm/rule out the cross-platform-specific handshake hypothesis) and/or file a Bridgefy support ticket / comment on GitHub issue #45.

### 2026-09-27 — Diagnosed Bridgefy receiver-leak crash; added restart-warning mitigation
- Done: Diagnosed Android crash "IllegalStateException: Too many receivers, total of 1000, registered for pid" as coming from inside the Bridgefy SDK — Nordic's BleManager registers a BroadcastReceiver on every BLE connect but never unregisters it, leaking one receiver per connect/disconnect/failed-secure-connection event until Android's 1000-receiver-per-process cap is hit. This is a third-party SDK bug, not patchable directly. Added a mitigation: BridgefyTransport now tracks connection churn and exposes a restartRecommended stream that fires once churn crosses a threshold (700); HomeScreen subscribes to it and shows an AlertDialog telling the user to restart the app before hitting the OS cap.
- Files: lib/transport/bridgefy_transport.dart, lib/ui/home_screen.dart
- Next: Check logcat for a pattern of repeated "failed to establish secure connection" vs "connected to" log lines during a test session to confirm whether repeated failed secure-connection retries are both the receiver-leak source and the cause of the "0 nearby peers" bug; then continue diagnosing peer discovery.

### 2026-09-27 — Fixed Android send crash: empty salt in HKDF
- Done: Fixed PlatformException "Empty key" / IllegalArgumentException in cryptography_flutter HMAC on Android when sending a message. Root cause: _sharedKey() passed nonce: const [] (empty salt) to Hkdf.deriveKey; cryptography_flutter's Android HMAC uses javax.crypto.SecretKeySpec which rejects zero-length keys. Changed nonce to Uint8List(32) (zero-filled 32-byte salt per HKDF spec default); behavior/security unchanged, crashes avoided. flutter analyze clean; all 17 tests still pass.
- Files: lib/crypto/seal.dart
- Next: Rebuild and reinstall APK, retry sending on real Android device to confirm fix.

### 2026-09-27 — Added debug logging to diagnose peer discovery issue
- Done: Added debugPrint calls to BridgefyTransport delegate callbacks (bridgefyDidStart, bridgefyDidConnect, bridgefyDidDisconnect, bridgefyDidFailToStart, bridgefyDidFailToEstablishSecureConnection) to track Bridgefy mesh connectivity state.
- Files: lib/transport/bridgefy_transport.dart
- Next: Run flutter run on both test phones (one Android, one iOS) and collect console output to determine why peer discovery returns 0 peers.

### 2026-09-27 — Fixed Android build (Java, Gradle, desugaring, packaging)
- Done: Resolved Java version mismatch (Temurin JDK 21 @ /Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home); pinned permission_handler to ^12.0.1 (14.x requires compileSdk 37 unavailable); enabled core library desugaring (coreLibraryDesugaringEnabled + coreLibraryDesugaring desugar_jdk_libs:2.1.5) for Bridgefy SDK; added packaging exclude for duplicate META-INF/versions/9/OSGI-INF/MANIFEST.MF. flutter build apk --debug --dart-define-from-file=env.json succeeds (220 MB debug APK); flutter analyze clean; all 17 tests pass.
- Files: android/app/build.gradle.kts, pubspec.yaml, pubspec.lock
- Next: Test on two real Android phones (Phase 0 exit: reliable delivery 3+ hops)

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
