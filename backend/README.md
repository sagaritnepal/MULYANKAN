# Mulyankan backend (Phase 1)

NestJS + SQL Server + Socket.IO. Implements: phone OTP auth, showrooms,
valuation requests with photos, push broadcast, blind quoting, the live
board, server-authoritative auto-close + T-2:00 escalation, and deciding a
winner.

## Setup

```bash
cp .env.example .env
npm install
```

Then create the database once — Prisma Migrate does **not** auto-create
the database for SQL Server the way it does for Postgres/MySQL:

```bash
docker compose up -d sqlserver   # or point DATABASE_URL at an existing instance
docker exec -it $(docker compose ps -q sqlserver) \
  /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong!Passw0rd' -C \
  -Q "CREATE DATABASE reconboard;"
```

(If your image's tools live at `/opt/mssql-tools/bin/sqlcmd` instead of
`mssql-tools18`, use that path — it varies by image tag. Already have a
SQL Server / LocalDB instance instead of Docker? Just run the same
`CREATE DATABASE reconboard;` against it and point `DATABASE_URL` there.)

```bash
npm run prisma:migrate    # applies the schema
npm run start:dev
```

Needs a reachable SQL Server (see `../docker-compose.yml` for a local one)
and, optionally, an S3-compatible bucket for photo uploads (MinIO locally;
Cloudflare R2 or Backblaze B2 in prod).

### Why SQL Server needed schema changes

SQL Server has no native scalar-array column (Postgres' `UserRole[]` on
`User.roles`), so roles are a join table (`UserRoleAssignment`) instead —
see `prisma/schema.prisma`. It's also strict about foreign keys that could
form cascade cycles or multiple cascade paths (notably `User` ↔
`Showroom`, and `Decision` being reachable from `ValuationRequest` both
directly and via `Quote`) — every relation sets its `onDelete`/`onUpdate`
explicitly rather than relying on provider-specific defaults.

### Local object storage (MinIO)

`docker compose up -d` starts MinIO on `:9000` (API) and `:9001` (console,
`minioadmin` / `minioadmin`). Before uploading photos, create the bucket
named in `.env` (`S3_BUCKET`, default `reconboard-photos`) and set it to
allow public reads, either from the console or:

```bash
docker run --rm --network host minio/mc \
  sh -c "mc alias set local http://localhost:9000 minioadmin minioadmin && \
         mc mb local/reconboard-photos && \
         mc anonymous set download local/reconboard-photos"
```

### Real OTP delivery (Sparrow SMS)

Set `OTP_PROVIDER=sparrow`, `SPARROW_SMS_TOKEN`, and `SPARROW_SMS_FROM` in
`.env`. Until then, `OTP_PROVIDER=console` (the default) logs the code
instead of sending an SMS — fine for local development.

### Real push (Firebase Cloud Messaging)

Set `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and
`FIREBASE_PRIVATE_KEY` (a service account) in `.env`. Until then, pushes
are logged to the server console instead of sent — the mobile app still
works because the live board and inbox also update over WebSocket.

## Business rules enforced server-side (not just in the UI)

- **Blind bidding** (rule #2): a valuer's API responses never include other
  quotes — see `RequestsService.findForRole` and `QuotesService`'s return
  values. The WebSocket gateway only puts the poster's socket in the
  `board:*` room, so `quote.created`/`quote.updated` structurally can't
  reach a valuer regardless of client behavior.
- **Server-authoritative countdown** (rule #1): every response and socket
  message carries a `serverNow`, and the client resyncs off it.
- **Late quotes rejected server-side** (rule #3): `QuotesService` compares
  `closesAt` to `Date.now()`, never anything the client sends.
- **One live quote per valuer, revisions logged** (rule #4): unique
  constraint on `(requestId, valuerUserId)` plus a `QuoteRevision` audit row
  on every submit.
- **Auto-close and escalation run on the server clock** (rules #6, #7): a
  5-second cron sweep (`RequestsSchedulerService`) closes expired requests
  and escalates under-quoted ones — no client needs to be connected.
- **Can't quote your own showroom** (rule #8): checked in
  `QuotesService.upsert`.
- **Zero-quote requests close as `expired`**, offering rebroadcast (rule #9).

## API

See `src/*/*.controller.ts` for the concrete routes; the shape follows
`BUILD-PROMPT.md`'s API section with two intentional additions:
`GET /requests/mine` (poster's own request list, for the Home screen) and
`POST /showrooms` / `POST /showrooms/join` (a user has to belong to a
showroom before anything else makes sense — not itemized in the original
list but required by rule #8).
