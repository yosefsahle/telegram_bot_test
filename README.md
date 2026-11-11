# Digital Lottery Platform — Database + Phase 1 Foundation

This is an additive foundation package for the existing PHP/MySQL Telegram registration bot. It intentionally does not replace or modify the existing registration webhook, `users` table, or registration logic.

## Locked product settings
- Languages: `en` (English), `am` (Amharic), `ti` (Tigrinya), `om` (Oromo)
- Currency: ETB only
- Temporary ticket reservation duration: 10 minutes (to be applied in the Phase 3 reservation service; no ticket sales are enabled in this Phase 1 package)
- Runtime: PHP + MySQL/MariaDB on cPanel

## Database design included
Participants and session auth; admin users, roles and permissions; campaigns and translations/media; orders and order-ticket snapshots; fixed numbered ticket inventory; payment methods/translations, payments, evidence and verification history; in-person draws, witnesses and winners; notification queue/log; audit logs.

The existing registration table remains untouched. `lottery_participants.legacy_registration_user_id` is an optional link to the existing `users.id`; the integration lookup expects the known registration schema `users.user_id` (Telegram ID) and `users.phone_number`.

## Installation
1. Back up the current database and existing bot files.
2. Create a new MySQL database backup snapshot before migration.
3. Import `database/schema.sql` into the same database as the current registration bot. It only creates `lottery_*` tables and seeds role/permission names.
4. Put the `app/` directory outside `public_html` if possible. Put `public/` content in a dedicated subdirectory/domain for the Mini App/API.
5. Copy `.env.example` to a configuration file outside the web root and set database credentials, the existing bot token, and exact allowed HTTPS origin. Do not publish the bot token.
6. Configure PHP to load those values into environment variables (cPanel PHP-FPM/Apache environment configuration or a private bootstrap include). This package deliberately does not include a public `.env` loader.
7. Ensure PHP 8.1+, PDO MySQL, OpenSSL, JSON and HTTPS are available.
8. Set the Telegram bot's Mini App URL only after the domain is deployed and HTTPS works.

## Phase 1 endpoints
- `GET /api/v1/health`
- `POST /api/v1/auth/telegram` — validates raw Telegram `initData`, links an existing registration row by `users.user_id`, upserts the participant mirror, and issues an opaque bearer token.
- `GET /api/v1/me` — returns the authenticated participant.
- `PATCH /api/v1/me` — updates only the participant language (`en`, `am`, `ti`, `om`).
- `POST /api/v1/auth/logout` — revokes the current session.

Telegram `initData` is verified on the server using Telegram's HMAC-SHA-256 procedure and a 5-minute freshness window by default. `initDataUnsafe` and client-submitted Telegram IDs are never used for authentication. See `https://core.telegram.org/bots/webapps`.

## Important integration boundary
The original registration bot source ZIP was not available in the files attached to this implementation session. Therefore this package is an additive foundation and the bot webhook has deliberately not been edited. The bot's existing registration behavior remains unchanged. To wire the actual `/start` menu button / persistent menu to the Mini App and verify exact DB compatibility, provide the current working bot ZIP (including its config sample and SQL schema, with secrets removed). Then the bot integration can be merged and regression-tested against the actual source.

## Security / production checklist before exposure
- Restrict API CORS to the exact Mini App origin; do not use `*`.
- Keep `app/`, database dumps, logs and payment evidence outside public web paths.
- Use HTTPS only; protect bot token and DB credentials.
- Configure rate limiting at hosting/WAF level for auth endpoints.
- This Phase 1 package does not yet implement admin login, campaign CRUD, ticket reservations, payment upload/review, or draws. These are subsequent phases.
- Legal/regulatory approval must be confirmed before accepting paid entries or publishing real campaigns.

## Note about MySQL versions
The schema uses InnoDB, foreign keys, JSON columns, and CHECK constraints. On older MariaDB/MySQL releases CHECK constraints may be ignored; application validation remains required. Test the import on a backup/staging database first.
