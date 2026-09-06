# SUMPAY — Dynamicization & Deployment-Readiness Assessment

This is the inspection-only deliverable requested before any code changes. It
traces where every major piece of displayed data actually comes from, separates
what is genuinely dynamic from what is simulated, and proposes an implementation
order. **No code has been changed.** Awaiting your approval before proceeding.

---

## 1. Current architecture assessment

SUMPAY already has a real, layered data architecture:

```
UI (screens/widgets)
  → Provider (Riverpod)
    → Repository (interface + implementation)
      → AppDatabase (SQLite via sqflite)  /  Mesh services  /  Location service
```

The layering is clean and mostly correct. The problem is **not** missing
architecture — it is that the architecture is currently **fed from bundled dummy
data**. Specifically:

- On startup, `main.dart` calls `DatabaseSeeder.seedIfEmpty(...)` with
  `DummyUsers.all`, `DummyMessages`, `DummyBroadcasts`, `DummySos`,
  `DummyAssignments`, and dummy packets. The seeder inserts these into the real
  SQLite tables **only if the tables are empty**.
- So for users, messages, broadcasts, SOS and volunteer tasks, the flow
  DB → repository → provider → UI is **real** — but the database is
  **pre-populated with fictional people and records**. That's the core issue.
- A few features skip the DB entirely and serve dummy objects **directly** from
  providers (network/mesh view, notifications, official/command statistics,
  map). These are the "pure fake" cases.

Two important nuances:

- **The mesh/SOS/chat *runtime* is real.** Live message send/receive, SOS
  packets, responder acks, multi-hop routing, dedup, delivery acks, the internet
  (Supabase) transport, and location capture are all genuine and already work on
  devices. The fakeness is in the **seeded historical/roster data and a few
  read-only dashboard views**, not in the live communication engine.
- **Registration is partly real already.** Residents can register and be
  persisted (`registrationProvider` → `ResidentRegistrationRepository`), and
  profile edits persist for registered residents. The gap is that login/session
  and the non-resident roles still resolve to dummy personas.

---

## 2. Hardcoded / demo-data inventory (by category)

### Authentication & identity  (HIGH severity)
- `authentication/data/dummy_users.dart` — fictional people: "Maria Liza
  Fernandez" (resident), "Jomar Delos Santos" (volunteer), "Kagawad Elena
  Rubio" (official), plus admin. Includes fake addresses, emergency contacts,
  medical info, barangay/purok.
- `auth_provider.dart`:
  - `currentUserProvider` **falls back to `DummyUsers.resident`** when no user
    is logged in — so the app always has a fictional "current user".
  - `login`/`_userForRole` resolves each role to a hardcoded `DummyUsers.*`.
  - `register(...)` fabricates a user from `DummyUsers.resident` rather than
    creating a genuinely new account.
  - `switchRole(...)` — a "switch persona" debug affordance for advisers.
  - Login does **not validate a password** against any stored credential.

### Users / roster
- `DummyUsers.all` seeded into the `users` table at first launch → the admin
  "all accounts" list and any roster shows these fictional users.

### Messages (community + area + direct)
- `messaging/data/dummy_messages.dart` — predefined conversations and threads.
- `DummyMessageRepository` returns `DummyMessages.*` directly; seeded into
  `messages` table. (Live send/receive is real; the *backlog* is fake.)

### SOS
- `sos/data/dummy_sos.dart` (`DummySos.all`) — seeded SOS records with
  **hardcoded coordinates** and fictional residents.
- `DummySosRepository` references dummy data.
- (Live SOS creation, location capture, packet routing, responder acks are
  real.)

### Broadcast
- `broadcast/data/dummy_broadcasts.dart` (`DummyBroadcasts.all`) — sample
  announcements with fixed priorities/timestamps, seeded into `broadcasts`.

### Network / Mesh view  (HIGH severity — pure fake, not DB)
- `iot/providers/network_provider.dart` serves **`DummyNetwork.status`,
  `.nodes`, `.packetLog` directly** — fake "connected devices", fake mesh nodes,
  fake packet log, fake signal strength/quality.
- This exists **in parallel to the real** `meshManagerProvider` /
  `connectivityProvider` from later sprints — so the Network screen shows
  fabricated data while a real mesh state is available but unused there.

### Notifications  (pure fake, no table)
- `notifications/providers/notification_provider.dart` initialises to
  `DummyNotifications.all`. There is **no notifications table** in the schema;
  notifications are not event-driven or persisted.

### Dashboards / statistics  (mixed)
- **Official / Command Center:** `command_provider.dart` →
  `commandStatisticsProvider` returns **`DummyCommand.statistics`** (fake
  residentsOnline, evacuees, activeIncidents, response times) and
  `DummyCommand.alerts`. Pure fake.
- **Admin user management:** uses real `.length` counts over the (seeded) users
  list — computation is real, but the underlying users are seeded dummies.
- **Volunteer:** reads via repository/provider (real flow) but over seeded task
  data (`DummyAssignments`).

### Map
- `map/` feature (`dummy_map.dart`, `map_provider.dart`) — an older standalone
  map view with dummy markers. (Separate from the real OSM tracking/SOS maps
  built in later sprints, which use live location.)

### Startup seeding (the central injection point)
- `main.dart` + `core/data/database_seeder.dart` — the mechanism that pushes all
  the above dummy datasets into the real DB on first run.

---

## 3. Functional vs simulated feature list

### Genuinely functional (real data flow today)
- Live community/area chat **send & receive** over mesh + internet (Supabase).
- SOS **creation**, real **GPS location capture** (with permission/accuracy
  handling), packet build, routing, TTL, hop count, dedup, delivery acks.
- Responder **accept** → real responder ack over mesh → resident receives →
  green floating status + OSM tracking (responder GPS captured on accept).
- Multi-hop routing, auto mesh discovery/connection, SUMPAY-only handshake.
- Real mesh state via `meshManagerProvider` + `connectivityProvider`.
- Resident **registration** persistence + **profile edit** persistence.
- SQLite persistence for users/messages/broadcasts/SOS/tasks (schema v5).
- Riverpod reactivity for the live flows.

### Simulated / needs conversion
- **Login/session** (no real credential check; falls back to dummy resident).
- **Non-resident accounts** (volunteer/official/admin are dummy personas).
- **Seeded roster/backlog** — users, message history, broadcasts, SOS history,
  tasks are fictional seed data.
- **Network screen** — pure `DummyNetwork` instead of the real mesh state.
- **Notifications** — pure dummy, not persisted, not event-driven.
- **Official/Command statistics** — pure `DummyCommand`.
- **Old `map/` feature** — dummy markers (likely orphaned/replaceable).

---

## 4. Database gaps
- **No `notifications` table** — needed to make notifications real, persisted,
  event-driven. (Schema is at v5; this would be a v6 migration.)
- **No credentials/auth storage** — login has nothing to validate against. If we
  keep local-only auth, we need at least a stored account record per user
  (residents already persist; other roles do not).
- **No network/mesh persistence** — acceptable; mesh state is inherently live,
  not stored. The fix is to read the live provider, not to add a table.
- Existing tables (users, messages, packets, broadcasts, sos_requests,
  volunteer_tasks, mesh_meta) are structurally fine; the issue is their
  **contents** (seeded dummies), not their shape.

## 5. Service / repository gaps
- **`Dummy*Repository` implementations** are wired as the active repositories in
  several places; they need to be replaced by (or switched to) the real
  SQLite-backed repositories as the default, with dummy kept only under test.
- **Notifications** has no repository/table at all.
- **Command/official statistics** has no real aggregation service — it needs a
  provider that computes from real SOS/users/mesh records.
- **Auth** needs a real login path that resolves a stored account (local now,
  backend-ready later) instead of `DummyUsers`.

## 6. State-management gaps
- `currentUserProvider` must not fall back to a dummy; it should expose
  `null`/unauthenticated and force login.
- `networkController`, `notificationController`, `commandStatisticsProvider`,
  and the map provider return static dummy state and must be repointed at the
  real providers/records.
- Most live flows are already reactive; the converted ones must keep that.

## 7. Security concerns
- **No password validation** on login — anyone "logs in" as a dummy.
- **Dummy personas grant role access** without authentication — role-based
  access is currently persona-switching, not enforced auth.
- The Supabase demo policy remains open (anon read/write) — acceptable for the
  demo, but flagged for backend hardening (auth + RLS) later.
- No hardcoded passwords/API keys were found in source (keys come via
  `--dart-define`), which is good. The `switchRole` persona-switcher is a
  demo-only affordance to remove/guard for deployment.

## 8. Deployment-readiness concerns
- A brand-new install currently **shows fictional people and history** because
  of seeding — a real deployment should start **empty** with proper empty
  states.
- Notifications and network/official dashboards would show fabricated data to
  real users.
- Login would let anyone in as a dummy. Session restoration ties to dummy users.
- Empty states exist as widgets (`state_views.dart`, `EmptyState`) and are used
  in places — but the seeded data means they're rarely exercised; after
  de-seeding, every list needs a verified empty state.

---

## 9. Recommended implementation order

Ordered by dependency and risk, smallest blast-radius first, each independently
verifiable:

1. **Stop auto-seeding dummy data** (`main.dart` + seeder): make seeding a
   no-op for production so a fresh install starts empty. Keep the seeder class
   for tests only. *This alone converts most DB-backed features to real+empty.*
2. **Authentication & current user:** remove the `DummyUsers.resident` fallback;
   make `currentUserProvider` unauthenticated-by-default; implement a real local
   login that validates a stored account; make `register` create genuine
   accounts for all roles (persisted). Preserve the UI.
3. **Verify empty states** across every list (chat, SOS, broadcasts, roster,
   tasks, notifications) now that data starts empty.
4. **Network screen → real mesh:** repoint `network_provider` from
   `DummyNetwork` to the live `meshManagerProvider`/`connectivityProvider`.
5. **Notifications → real & event-driven:** add a `notifications` table (v6
   migration) + repository/provider; generate notifications from real events
   (new SOS, SOS accepted, new broadcast, new message).
6. **Official/Command statistics → computed:** replace `DummyCommand` with a
   provider that aggregates real SOS/users/mesh records.
7. **Broadcast/SOS/messages backlog:** confirm they read live from DB with no
   dummy fallback; remove `Dummy*Repository` from production wiring.
8. **Old `map/` feature:** confirm orphaned and remove, or repoint to real data.
9. **Security pass:** guard/remove `switchRole`; ensure role access derives from
   the authenticated account; document the local-vs-backend auth boundary.
10. **Deployment sweep:** app restart, session restoration, permissions, empty
    states, offline behavior, and a data-lifecycle test per feature.

### Scope notes / decisions I need from you
- **Login model:** keep **local-only** auth for now (validate against a locally
  stored account), structured for later backend swap? Or do you want me to wire
  it to Supabase auth in this pass? (I recommend **local-only now** — smaller,
  safer, and the prompt says preserve local auth but make it backend-ready.)
- **Existing installs:** after de-seeding, existing test phones will still hold
  previously seeded dummy rows (seeding only skips when non-empty). Do you want a
  one-time **clean/reset** (bump DB version to wipe) so devices start truly
  empty, or leave existing data alone?
- **Non-resident registration:** should volunteers/officials be able to
  self-register (then await admin approval, which already exists), or are those
  accounts created only by the admin? This affects how I build their real-auth
  path.

---

## What I did NOT change
Nothing. This is inspection-only per your instruction. On approval, I'll
implement **component-by-component in the order above**, verifying compilation
and preserving existing functionality after each step, and report per the final
report format you specified.
