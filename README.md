# Mulyankan — Phase 1

Blind, 5-minute exchange-value broadcasts for Nepal's recondition-motorcycle
trade. This is **Phase 1 only**, per the build brief: phone OTP auth,
create a request with photos, broadcast push, valuer quote entry, poster
live board, server-authoritative auto-close, and picking a winner.

Not built yet (by design — see `BUILD-PROMPT.md`'s Phase 2/3/4): Nepali
language toggle, B.S. date pickers, valuer accountability stats, price
intelligence, history screen, offline draft queue, admin web dashboard.

## Layout

- `backend/` — NestJS + PostgreSQL + Socket.IO API. See `backend/README.md`.
- `mobile/` — Flutter app (poster + valuer). See `mobile/README.md`.
- `docker-compose.yml` — local Postgres + MinIO (S3-compatible storage) for dev.

## Fastest path to a working demo

```bash
docker compose up -d          # Postgres + MinIO
cd backend
cp .env.example .env          # defaults work with the compose file above
npm install
npm run prisma:migrate
npm run start:dev
```

Then, in another terminal:

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api \
            --dart-define=WS_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` is the Android emulator's alias for the host machine's
`localhost`. Point it at your backend's real LAN IP if you're testing on a
physical device on the same Wi-Fi.

With no Sparrow SMS or Firebase project configured, the backend logs OTP
codes to its own console instead of texting them, and logs pushes instead
of sending them — the whole flow (including the live board and countdown)
still works end-to-end over the WebSocket connection. See each README for
how to wire up the real services.

## Why some "Phase 2" rules are already in the backend

Escalation at T-2:00 and Pass-with-a-reason are listed under the Phase 2
bullet in the brief, but they're one-line rules inside the same
auto-close scheduler and quote-submission path Phase 1 already needs —
splitting them out would have meant building (and testing) two versions
of the same code path. Everything else stayed out.
