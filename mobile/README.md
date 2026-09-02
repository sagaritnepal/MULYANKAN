# Mulyankan mobile (Phase 1)

Flutter app covering both roles from one account: **Poster** (create a
request, watch the live board, pick a winner) and **Valuer** (inbox,
blind quote entry).

## Run it

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api \
            --dart-define=WS_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` is the Android emulator's alias for the host's `localhost`
(the backend must be running — see `../backend/README.md`). For a
physical device, use the host machine's LAN IP instead.

## Structure

- `lib/core/` — API client (Dio, with auto token refresh), the Socket.IO
  wrapper (`socket_service.dart`), `ServerClock` (countdown sync per rule
  #1), the photo upload pipeline (compress → presign → direct PUT), NPR
  lakh-grouping formatter, and push notification plumbing.
- `lib/state/auth_provider.dart` — Riverpod auth + showroom state.
- `lib/features/auth/` — OTP request/verify, first-time showroom setup.
- `lib/features/poster/` — Home, New Valuation form, Live Board (the
  screen the whole product hinges on), Result (pick winner + record
  outcome).
- `lib/features/valuer/` — Inbox, Quote Entry (blind — the API structurally
  never sends this screen anyone else's numbers).
- `lib/widgets/` — `CountdownText` (server-clock-driven), `PricePad`
  (±5,000/±10,000 adjusters), `PhotoSlotGrid` (6 required photos,
  camera-first, parallel background upload).

## Enabling push notifications

The app runs fully without this — the live board and inbox update over
the WebSocket connection regardless. Push just adds background wake-up
when the app is killed. To turn it on:

1. Create a Firebase project and register this app
   (`com.reconboard.reconboard`).
2. Download `google-services.json` into `android/app/`.
3. `android/app/build.gradle.kts` already applies the Google Services
   Gradle plugin automatically once that file exists — no other changes
   needed.
4. Rebuild. `PushService.initialize()` (in `lib/core/push_service.dart`)
   will pick it up, request notification permission, and upload the FCM
   token to `PATCH /me`.

## Known environment note (Windows)

If the project and Gradle/pub caches live on different drive letters,
the Kotlin incremental compiler can crash with "this and base files have
different roots". `android/gradle.properties` sets
`kotlin.incremental=false` to work around it — safe to remove if your
setup doesn't hit it.

## What's deliberately not here yet

Nepali/English language toggle, Bikram Sambat date pickers, valuer
accountability stats (response rate, leaderboard), price intelligence,
History and My Results screens, offline draft queue, admin web. All
Phase 2/3 per `BUILD-PROMPT.md`.
