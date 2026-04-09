# Firestore Development Seeding

This project includes a standalone Node.js seeding utility for development/test data in Firestore.

## Prerequisites

- Node.js 18+
- A Firebase service-account JSON with Firestore access
- Firestore project configured and reachable from your environment

## Credentials setup

1. Copy environment template:
   ```bash
   cp .env.example .env
   ```
2. Set `FIREBASE_SERVICE_ACCOUNT_PATH` to your service-account JSON file path (absolute or repo-relative).
3. Optionally set `FIREBASE_PROJECT_ID` (otherwise it will be read from the service account).

> Do **not** commit your real `.env` or service-account JSON.

## Install dependencies

```bash
npm install
```

## Run seed (without clearing existing data)

```bash
npm run seed
```

## Clear approved collections and reseed

```bash
npm run seed:clear
```

`--clear` only deletes documents from these approved collections:

- `users`
- `traveller_accounts`
- `groups`
- `travellers`
- `traveller_requests`
- `documents`
- `flights`
- `flight_segments`
- `hotels`
- `rooms`
- `tasks`
- `notifications`
- `activity_logs`
- `password_reset_requests`

## Seed structure

- `scripts/firebaseAdmin.js`: Firebase Admin initialization from environment credentials.
- `scripts/helpers.js`: deterministic utility helpers (dates, IDs, random sampling, age calculations).
- `scripts/seedData.js`: generates realistic, relational seed payload across all approved collections.
- `scripts/seed.js`: optional clear + batched Firestore write + summary output.

## Schema assumptions (short)

- Top-level collection names and enum values strictly follow the approved schema.
- Traveller age category is computed from group departure date.
- Domestic groups always set traveller `passportValidityStatus` to `not_applicable`.
- International groups include a mixed distribution of `valid`, `warning`, and `invalid` passport statuses.
- All cross-links are generated from existing seeded entities to avoid orphaned references.

## Script output summary

The script prints a JSON summary after completion, e.g.:

```json
{
  "totalCollections": 14,
  "totalDocuments": 600,
  "counts": {
    "users": 14,
    "traveller_accounts": 55,
    "groups": 10,
    "travellers": 120,
    "traveller_requests": 20,
    "documents": 380,
    "flights": 14,
    "flight_segments": 20,
    "hotels": 10,
    "rooms": 42,
    "tasks": 45,
    "notifications": 40,
    "activity_logs": 80,
    "password_reset_requests": 24
  }
}
```
