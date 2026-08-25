# Ammct — Cricket Tournament SaaS Platform

A multi-tenant SaaS backend and Flutter mobile app for running cricket tournaments:
organizations, tournaments, teams, players, live ball-by-ball scoring, stats, points tables, and a
live player auction. This repo currently contains **M1 — Foundation**: monorepo scaffolding, auth,
multi-tenancy/RBAC guards, CRUD for organizations/tournaments/teams/players, and a Flutter Android
admin app that logs in, selects/creates an org, and manages tournaments/teams/players against that
API end to end.

Later milestones (fixtures, live scoring, stats/points table, live auction, public fan view) are
described in the project plan and are not part of this milestone.

## Stack

- **Backend**: NestJS + TypeORM + PostgreSQL, JWT auth, `@nestjs/swagger` for API docs.
- **Infra**: Docker Compose (Postgres 16, Redis 7, optional Adminer).
- **Mobile**: Flutter (Riverpod + go_router), Android only for now — no iOS/Windows-desktop
  toolchain on this dev machine.

## Repo layout

```
apps/backend/     NestJS API
apps/mobile/       Flutter app (Android)
infra/             docker-compose.yml (Postgres, Redis, Adminer)
```

## Running M1 locally

Prerequisites: Docker Desktop, Node.js v24+, npm v11+.

### 1. Start Postgres + Redis

```powershell
cd infra
docker compose up -d
```

This starts Postgres on `localhost:5433` (mapped to the container's internal 5432 — moved off the
default host port because another local Postgres install may already be using it; db `cricket_dev`,
user/password `cricket`/`cricket` by default — override via a `.env` file in `infra/` or environment
variables) and Redis on `localhost:6379`. Optionally start Adminer (DB browser UI at `localhost:8080`) with:

```powershell
docker compose --profile tools up -d
```

### 2. Install dependencies

From the repo root (npm workspaces installs `apps/backend` too):

```powershell
npm install
```

### 3. Configure environment

```powershell
cd apps/backend
Copy-Item .env.example .env
```

Edit `.env` if you changed the default Postgres credentials, and set real values for
`JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET`.

### 4. Run database migrations

```powershell
cd apps/backend
npm run migration:run
```

### 5. Start the API in watch mode

```powershell
npm run start:dev
```

The API listens on `http://localhost:3000` by default. Swagger UI is at
`http://localhost:3000/api-docs` and the raw OpenAPI spec at `http://localhost:3000/api-json`.

### Generating a new migration

After changing an entity:

```powershell
npm run migration:generate -- src/database/migrations/<DescriptiveName>
```

## Mobile app

`apps/mobile/` is a Flutter app (Android target only for now — this dev environment has no Visual
Studio/iOS toolchain, so Windows-desktop and iOS builds aren't set up). It covers M1's admin flow:
login/register, org selection (or creating a first organization), and tournament/team/player CRUD
against the backend above.

State management is Riverpod (`flutter_riverpod`, no codegen), navigation is `go_router` with
role-based route shells (`/auth/*`, `/admin/*`; `/public/*`, `/team/*`, `/score/*`, `/auction/*`
are reserved for later milestones once those backend modules exist), and networking is a
hand-written `Dio`-based `ApiClient` (`lib/core/network/`) with a JWT-attach + refresh-on-401
interceptor backed by `flutter_secure_storage`. DTOs are hand-written Dart models matching the
backend's DTOs/entities directly — the OpenAPI-to-Dart codegen pipeline described in the project
plan is a nice-to-have for a later milestone, not set up yet.

### Prerequisites

- Flutter SDK (3.35+) with the Android toolchain installed and `flutter doctor` green for Android.
- The backend running locally (see above) — the mobile app talks to it over HTTP.

### 1. Install Dart/Flutter dependencies

```powershell
cd apps/mobile
flutter pub get
```

> **Sandboxed-shell note**: in this specific development sandbox, `flutter.bat` can't find
> `git`/`where` unless the Windows System32 paths are prepended to `PATH` first in every
> PowerShell invocation:
> ```powershell
> $env:Path = "$env:SystemRoot\System32;$env:SystemRoot\System32\WindowsPowerShell\v1.0;D:\flutter\bin;$env:Path"
> ```
> This is a quirk of this sandboxed shell session only — a normal PowerShell/terminal session on
> Windows (with Flutter's `bin` directory on `PATH` the usual way) does not need this workaround.

### 2. Configure the API base URL

The app defaults to `http://10.0.2.2:3000` — the special alias an Android emulator uses to reach
`localhost` on the host machine, matching the backend's default dev port. Override it at build/run
time if needed (e.g. a physical device on the same Wi-Fi, or a non-default backend port):

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000
```

### 3. Run against an Android emulator

Once an Android emulator (or physical device with USB debugging) is available:

```powershell
cd apps/mobile
flutter emulators --launch <emulator_id>   # or open one from Android Studio's AVD Manager
flutter run
```

No emulator is set up in this environment yet (disk space was kept tight deliberately — no AVD
system image has been downloaded). `flutter analyze` and `flutter pub get` are the verification
bar for M1's mobile scaffolding; running the app on a real emulator is the next step once one is
available.

### Static analysis

```powershell
cd apps/mobile
flutter analyze
```

## Status

M1 (Foundation) — backend + mobile — is complete. Scoring, auction, fixtures, stats, and
points-table modules (and their corresponding Flutter screens) are future milestones and are
intentionally not implemented yet.
