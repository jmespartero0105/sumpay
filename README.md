# SUMPAY

**Smart Unified Mesh Platform for Area Yielding-Response**

An offline-first, mobile-to-IoT emergency communication system for barangays.
This repository is the **Flutter UI prototype** (front-end only) prepared for a
college capstone project. Backend services, the LoRa link, the Bluetooth /
Wi-Fi Direct mesh, the database and cloud sync are represented by placeholder
services and dummy JSON data, ready to be replaced after adviser approval.

---

## Communication architecture

```
Resident Mobile App
        |
(Optional Bluetooth / Wi-Fi Direct extension)   <- only when no gateway is in range
        |
ESP32 Gateway Node
        |
LoRa Network (primary backbone)
        |
Barangay Command Node
        |
Officials / Volunteers
```

The mesh is an **extension**, not the primary link. The app is **offline-first**;
the internet is only used for optional cloud synchronisation once connectivity
returns.

---

## Requirements

- Flutter SDK **3.22+** (Dart 3.4+), stable channel
- Android Studio or VS Code with the Flutter and Dart plugins
- An Android emulator or physical device (phone or tablet)

Check your setup:

```bash
flutter --version
flutter doctor
```

## Run the app

```bash
flutter pub get
flutter run
```

Build a release APK:

```bash
flutter build apk --release
```

---

## Prototype notes

- **Login** accepts any non-empty credentials. Use the role selector
  (Resident / Volunteer / Official) to preview each experience. You can also
  switch roles later from **Profile → Prototype role preview**.
- The **Network** screen has a swap-transport action (top-right) to demonstrate
  LoRa / mesh / offline / internet states.
- **Lottie** animations degrade gracefully: if an asset in `assets/lottie/` is
  missing, an animated icon fallback is shown instead, so the app always runs.

---

## Project structure

```
lib/
  main.dart                 # Entry point: DB init + seed, ProviderScope
  core/
    app.dart                # MaterialApp.router + theme + responsive wrapper
    constants/              # App constants, enums, route paths
    data/                   # SQLite: AppDatabase, schema, seeder, base Repository
    router/                 # GoRouter config (shell + full-screen routes)
    theme/                  # Colours, typography, Material 3 themes
    utils/                  # Formatters, responsive helpers
    widgets/                # Shared widgets (cards, chips, dialogs, avatar...)
  features/
    <feature>/
      presentation/         # Screens
      widgets/              # Feature-specific widgets
      models/               # Data models (with fromJson/toJson)
      providers/            # Riverpod providers / controllers
      data/                 # Dummy seed data + loaders
        repositories/       # Repository interface + dummy implementation
```

### Clean Architecture layers

- **Presentation** — screens under `presentation/` and controllers under
  `providers/` (Riverpod `StateNotifier`s and derived providers).
- **Domain (models)** — plain Dart models under `models/`, each with
  `fromJson`/`toJson` and, for persisted entities, `toDbRow`/`fromDbRow`.
- **Data** — repositories under `data/repositories/` expose an interface plus a
  `Dummy*` implementation; the SQLite layer lives in `core/data/`. Controllers
  depend on the repository interface, so swapping the dummy source for a live
  backend touches only the data layer.

### Persistence (SQLite)

`core/data/app_database.dart` opens `sumpay.db` on start-up and creates six
tables (`users`, `messages`, `packets`, `broadcasts`, `sos_requests`,
`volunteer_tasks`). `database_seeder.dart` mirrors the bundled dummy data into
those tables on first launch (idempotently). The database is exposed to the app
through `appDatabaseProvider`, overridden in `ProviderScope` once initialisation
completes.

The SOS, broadcast, volunteer and messaging controllers seed their initial state
from their feature repository (`data/repositories/*.dart`) rather than reaching
into the dummy data directly, so replacing a repository implementation is all
that is needed to swap in a live source. Repositories exist for the six core
entities: User, Message, Packet, Broadcast, SOS and Volunteer Task.

Features: `splash`, `onboarding`, `authentication`, `dashboard`, `sos`,
`messaging`, `broadcast`, `volunteer`, `admin` (official), `iot` (network),
`map`, `notifications`, `history`, `profile`, `settings`, `about`.

### Nearby device discovery (Phase 2)

The `iot` feature includes offline peer discovery over the Bluetooth /
Wi-Fi Direct mesh extension, built on the `nearby_connections` plugin:

- `data/services/nearby_service.dart` — `NearbyService`, a thin wrapper over the
  plugin covering runtime permissions, advertising, discovery, connect,
  accept/reject and disconnect.
- `models/nearby_device.dart` — `NearbyDevice` (device information per peer).
- `models/nearby_connection_state.dart` — `NearbyConnectionState`, the immutable
  aggregate the UI watches (engine state, permissions, discovered + connected
  lists, errors).
- `providers/nearby_provider.dart` — `NearbyController` / `nearbyProvider`
  orchestrating the service via Riverpod, plus `connectedDevicesProvider` and
  `discoveredDevicesProvider`.
- `presentation/nearby_device_screen.dart` — the Nearby Devices screen
  (route `/nearby`), reachable from the Home quick actions and the Network
  screen's app bar.

Phase 2 stops at discovery and connection management — **no data is sent across
a connection yet** (messaging arrives in a later phase). Requires a physical
Android device with Bluetooth, Wi-Fi and location switched on.

### Direct offline messaging (Phase 3)

Once two devices are connected (Phase 2), they can exchange text messages
directly over the Bluetooth / Wi-Fi Direct link — fully offline, no internet:

- `messaging/models/message_packet.dart` — `MessagePacket`, the small
  self-describing envelope (JSON over UTF-8 bytes) that travels across the link;
  supports `message` and `ack` kinds.
- `messaging/data/transport/nearby_transport.dart` — `NearbyTransport`, bridging
  the raw byte transport (`NearbyService.sendBytes` / `onPayloadReceived`) and
  typed packets; exposes an `incoming` stream and `sendMessage` / `sendAck`.
- `messaging/data/repositories/chat_repository.dart` — `ChatRepository`,
  persisting messages to the SQLite `messages` table (one conversation per
  endpoint, `nearby:<endpointId>`), with load / save / status-update / dedup.
- `messaging/providers/nearby_chat_provider.dart` — `NearbyChatController` and a
  `.family` provider keyed by endpoint; loads history, sends optimistically,
  updates delivery status, appends inbound messages, and tracks live connection
  status.
- `messaging/presentation/nearby_chat_screen.dart` — the chat UI (route
  `/nearby/chat`): message bubbles, timestamps, delivery status, a live
  connection banner, and a composer disabled when disconnected. Opened via the
  **Message** button on a connected device in the Nearby screen.

`NearbyService` gained real payload support: `sendBytes` and an
`onPayloadReceived` stream, wired through `acceptConnection`'s BYTES callback.
Delivery status flows sending → delivered (on peer ack) or failed. Messages
persist across app restarts and reconnections.

### Multi-hop mesh routing (Phase 4)

Messages no longer require a direct connection to their recipient — they hop
across intermediate phones until they reach the destination.

- `messaging/models/mesh_packet.dart` — `MeshPacket`, the routing envelope
  carrying UUID, sender id, destination id, hop count, TTL, priority, timestamp,
  payload and the ordered device-id path.
- `iot/data/mesh/routing_cache.dart` — `RoutingCache`: seen-UUID duplicate
  detection (with expiry) plus learned next-hop route hints.
- `iot/data/mesh/relay_service.dart` — `RelayService`: the store-and-forward
  core. Drops duplicates, decrements TTL, increments hop count, delivers packets
  addressed to this device, and floods everything else to other neighbours.
- `messaging/data/transport/nearby_transport.dart` — rewritten to route through
  the relay and exchange device ids via a hello handshake, so peers can address
  each other across hops.
- Each device has a persistent mesh id (`core/data/device_identity.dart`, stored
  in the `mesh_meta` table). Messages carry hop count, relayed status and path,
  shown in the chat bubbles.

Every phone automatically forwards packets it has not seen before, so a message
from A can reach C through B without A and C being directly connected. Database
schema is at version 2 (adds `mesh_meta` and mesh columns on `messages`); a
migration upgrades existing installs. LoRa is intentionally not implemented.

### Administrator role & user management

SUMPAY has a fourth, super-user role — **Administrator** — on top of resident,
volunteer and official, implementing role-based access control (RBAC):

- `UserRole.admin` with capability getters (`canBroadcast`, `canManageUsers`,
  `canApproveUsers`, `requiresApproval`) in `core/constants/app_enums.dart`.
- `AccountStatus` enum (active / pending / rejected / deactivated) on `AppUser`.
- **Approval flow:** newly registered **officials and volunteers are pending**
  until an administrator confirms them; residents (and admins) are active
  immediately.
- `features/admin/` gains a SQLite-backed `UserManagementRepository`, a
  `UserManagementController`/provider, a **User Management screen**
  (route `/admin/users`) that lists accounts by status, confirms or rejects
  pending ones (officials flagged for confirmation), deactivates/reactivates,
  and a **Register user** bottom sheet.
- Reached from the administrator's dashboard quick actions.

Database schema is at version 3 (adds a `status` column on `users`); a migration
upgrades existing installs.

### Community chat

Alongside the direct 1-to-1 peer chat, SUMPAY has a **mesh-wide community chat**
that every connected device shares:

- `messaging/providers/community_chat_provider.dart` — `CommunityChatController`
  loads the shared thread, sends messages to the mesh broadcast destination, and
  appends inbound community messages (persisted to SQLite so they survive
  restarts). Any role can post.
- `messaging/presentation/community_chat_screen.dart` — the group-chat UI
  (route `/community`): sender-labelled bubbles, a live connected-device banner,
  and a composer. Reached from the **Community chat** dashboard quick action.

It rides the existing multi-hop mesh: a community message is flooded to the
broadcast destination, so every node (and relays in between) delivers and
forwards it. Community messages are tagged with a fixed `community` conversation
id, keeping them separate from directed peer chats. No schema change is required.

### User identity management (Phase 2.1)

Residents register on this device and become unique, persisted users; the other
roles remain demo accounts for testing.

- `authentication/data/repositories/resident_registration_repository.dart` —
  persists a registered resident to the SQLite `users` table with a generated
  unique resident id (e.g. `RES-3F2A9C`) and remembers it via a pointer in
  `mesh_meta`, so identity survives restarts. No authentication.
- `authentication/providers/registration_provider.dart` —
  `RegistrationController` builds the resident from the registration form,
  generates the id, persists it, and exposes the registered resident
  (`registeredResidentProvider`, the current-user service for residents).
- The existing registration screen now routes its submit through this provider,
  and the splash screen restores a registered resident on launch.
- Barangay Official, Volunteer, and Administrator remain seeded demo accounts.
- Community chat messages now show the sender's **name, role, and timestamp**;
  role travels over the mesh in the message packet and is persisted via a new
  `sender_role` column (schema v4).

Database schema is at version 4 (adds `sender_role` on `messages`); a migration
upgrades existing installs.

### Emergency location sharing (Phase 2.2)

The device location is captured only when a resident sends an SOS. There is no
live tracking and no map SDK yet; clean interfaces are in place for one later.

- `sos/models/sos_location_model.dart` — `SosLocationModel`, a plugin-free value
  object holding latitude, longitude, accuracy, and capture time (with
  coordinate/accuracy labels and JSON encode/decode).
- `sos/data/services/location_permission_handler.dart` — wraps the permission
  flow, returning app-level outcomes (`granted`, `denied`, `deniedForever`,
  `serviceDisabled`) and opening app / location settings.
- `sos/data/services/location_service.dart` — one-shot `capture()` using
  `geolocator` (`^13.0.2`); no streaming. Confines the plugin to this class.
- `sos/providers/location_provider.dart` — Riverpod `LocationController` /
  `locationProvider` for on-demand capture, plus `locationServiceProvider`.
- `SosRequest` gains `accuracy` and `locationCapturedAt` (alongside the existing
  lat/lng) and a `capturedLocation` helper. `sos/data/repositories/sos_store.dart`
  persists SOS history to SQLite, including the captured location.
- The SOS screen requests permission only at send time (with graceful dialogs
  for denied / permanently denied / services off), shows the coordinates, an
  accuracy indicator, a refresh button, a map preview placeholder, and a
  "Location attached" status.
- `sos/widgets/map_preview_placeholder.dart` — `MapPreviewPlaceholder` and
  `MapActionButtons` are the seam where a real map SDK (Google Maps /
  OpenStreetMap) will plug in later; today they render placeholders.
- The Official dashboard shows each SOS with resident, emergency, coordinates,
  and time received; the Volunteer (responder) dashboard shows resident name,
  emergency type, coordinates, a distance placeholder, a map preview, and
  open-map / navigation placeholders.

The SOS packet is structured so the captured location will travel through the
existing mesh routing system once SOS-over-mesh transmission is wired; this
phase does not yet transmit SOS over the mesh.

Database schema is at version 4 and also adds `accuracy` and
`location_captured_at` to `sos_requests`; the same v4 migration upgrades existing
installs. If a migration error appears on launch, uninstall the app and run
again to rebuild the database.

### Automatic mesh formation (Phase 3)

On startup the app forms the mesh automatically, with no manual Connect button.
A settings toggle (**Automatic mesh connection**, default on) lets users turn
auto-connect off and connect manually instead.

- `iot/data/mesh/mesh_formation.dart` — the managers:
  - `DiscoveryManager` filters discovered peers to genuine SUMPAY devices (only
    endpoints advertising the `com.sumpay.app` service are connectable).
  - `ConnectionManager` auto-dials connectable peers while preventing duplicate
    connections, enforcing a maximum connection count, and retrying failures
    with capped exponential backoff; it also frees an endpoint for redial on
    disconnect.
  - `HeartbeatMonitor` periodically checks each link, deriving a round-trip-time
    based quality and flagging dead links (consecutive missed beats) for
    reconnection.
- `iot/providers/mesh_manager_provider.dart` — `MeshManager` orchestrates the
  above on top of the existing `NearbyController`: on startup it advertises and
  discovers, then continuously reconciles connections and monitors health. It
  reacts to the auto-connect setting and is instantiated app-wide from the root
  widget so formation begins at launch.
- `iot/models/mesh_manager_state.dart` — `MeshManagerState`, `MeshStatus`,
  `ConnectionQuality`, and `LinkHealth`.
- The IoT network screen shows a mesh-formation card: mesh status, connected
  devices (with per-link latency and quality bars), discovery status, and
  overall signal quality.

Note on signal quality: Nearby Connections does not expose radio signal strength
(RSSI), so connection quality is an honest proxy derived from heartbeat
round-trip latency and reliability, not a dBm reading. The heartbeat exposes a
send-ping hook where a dedicated control packet can later be sent once the
transport offers a raw control channel; until then link liveness is inferred
from the connection state.

### Secure mesh membership (Phase 4)

Only genuine SUMPAY devices are admitted to the mesh, enforced at two gates.

- First gate — **service id**: Nearby Connections runs on `com.sumpay.app`, so
  devices advertising a different service are never discovered as peers.
- Second gate — **membership handshake**: `iot/data/mesh/mesh_membership.dart`
  defines `MeshMembership` (service id, mesh id `sumpay-mesh-ph`, a shared
  membership token, and the protocol version), the `MeshHandshake` exchanged on
  connect, and a `MembershipVerifier`.

On every new link the transport sends a `MeshHandshake` (token, mesh id,
protocol version, device id, app version) and verifies the peer's handshake
before admitting it. A peer is rejected, disconnected, and never added to the
routing table if it presents an invalid handshake packet, an unknown
application (wrong or missing token), a different mesh id, an incompatible
protocol version, or a duplicate device already admitted via another endpoint.
Rejections are surfaced in **debug logs only**; there is no user-facing UI for
rejected devices.

Because the handshake format changed, all devices must run this build to mesh
together (an older raw-hello device is treated as an invalid handshake).

Security note: application verification is a shared-secret scheme (a token
embedded in the app), which stops other applications and casual impostors. It is
not cryptographic attestation: an attacker who extracted the token could replay
it. Unforgeable membership would require a signed key exchange, which is future
work.

### Mesh routing reliability (Phase 5)

Reliability is added as a layer *around* the existing routing engine; the engine
itself (`relay_service.dart`, `routing_cache.dart`, `mesh_packet.dart`) is not
modified. It already provides duplicate suppression (seen-UUID cache), TTL
expiration, hop-count tracking, and the packet cache, so those are reused as-is.

- `iot/providers/packet_reliability_provider.dart` — `PacketReliabilityController`
  adds an outgoing packet queue, an offline queue (packets are held when no peer
  is connected and automatically resent once the mesh is reachable), automatic
  retry/resend with capped backoff, and delivery tracking. Acknowledgements mark
  a packet delivered; the relay's own forward outcomes mark it forwarded.
  `TrackedPacket` holds per-packet attempts/status, and `ReliabilityStats`
  aggregates the counts.
- The controller reuses the existing `DeliveryStatus` values, mapping packet
  state onto Pending (`queued`/`sending`), Forwarded (`relayed`), Delivered, and
  Failed, and the IoT network screen shows these four counts using the existing
  delivery-status colours and icons rather than new indicators.

The routing engine architecture is unchanged: this layer only decides when to
(re)hand a packet to the engine and records the resulting status.

### Emergency SOS system (Phase 6)

SOS now travels the mesh as a first-class, high-priority emergency packet.

- Seven emergency categories (`EmergencyType`): Medical, Fire, Rescue, Flood,
  Earthquake, Supply, Custom. Each carries a predefined priority, so residents
  never choose a priority manually: Medical/Fire/Rescue/Earthquake are Critical,
  Flood and Custom are High, Supply is Normal. Choosing a category auto-sets the
  priority; the SOS screen shows it read-only.
- `sos/models/sos_packet.dart` — `SosPacket` carries the resident-facing and
  lifecycle fields (SOS id, resident id/name, emergency type, priority, status,
  timestamp, optional location and actor). The transport fields required by the
  spec map to the enclosing `MeshPacket`: Packet ID = mesh uuid, Hop Count/TTL =
  mesh hop/ttl, Priority = mesh priority, Timestamp = mesh timestamp. Status
  lifecycle: Sent -> Relayed -> Delivered -> Responder Accepted -> Responder En
  Route -> Resolved.
- On submit, an SOS is transmitted over the mesh through the Phase 5 reliability
  layer (queue, retry, offline resend). The reliability layer now processes its
  queue in priority order, so SOS (high/critical) is always sent before normal
  messages.
- `sos/providers/sos_mesh_provider.dart` — `SosMeshController` receives SOS
  packets from a dedicated transport stream (`incomingSos`), tracks each SOS and
  its status, and lets responders/officials acknowledge: delivery acknowledgement
  is sent automatically on receipt; responders can Accept and mark En Route;
  officials can Acknowledge and Resolve. Each acknowledgement broadcasts a status
  update back across the mesh at emergency priority.
- The Official dashboard shows incoming mesh SOS with resident, emergency, id,
  coordinates, live status, and Acknowledge / Resolve actions. The Volunteer
  (responder) dashboard shows mesh SOS with Accept / En Route actions.

The routing engine itself is unchanged; SOS reception is handled at the transport
delivery point (SOS payloads are routed to their own stream) and everything else
sits in the SOS and reliability layers.

### Volunteer dashboard (Phase 7)

A dedicated responder dashboard (`volunteer/presentation/volunteer_dashboard.dart`)
that volunteers land on after sign-in (routed from the home screen by role).

- Shows the incoming mesh SOS queue, priority-sorted (critical first, then most
  recent), with terminal incidents sunk to the bottom
  (`sortedIncomingSosProvider`).
- Each incident card shows resident information (name, resident id, coordinates,
  a distance placeholder), the emergency type and priority, the live status, a
  dummy map preview, and dummy navigation buttons (the map SDK seam from the SOS
  location work).
- Response actions gated by status: before acceptance, Accept or Reject; after
  acceptance, En Route, Arrived, then Resolved.
- The SOS status lifecycle gained `rejected` and `arrived`
  (Sent -> Relayed -> Delivered -> Responder Accepted -> Responder En Route ->
  Arrived -> Resolved, with Rejected as a terminal branch).
- Every responder action broadcasts a status update across the mesh. On the
  resident's device this updates their own SOS record and raises an in-app
  notification (a snackbar) so the resident automatically sees progress
  (accepted, en route, arrived, resolved).

The map and distance remain placeholders; wiring a real (precached, offline) map
later is a change confined to the existing map preview widget.

### Barangay Official dashboard redesign (Phase 8)

A new, tablet-optimised command dashboard
(`admin/presentation/official_dashboard.dart`) that officials land on after
sign-in. Material 3, adaptive across 8" and 10" Android tablets in both
orientations, and still usable on phones.

- Three layout builders selected from width and orientation: a phone single
  column, a tablet-portrait two-column masonry, and a tablet-landscape main area
  plus a fixed side rail. Each is a separate widget.
- Composed from independent section widgets, all reusing existing providers (no
  new data): Statistics cards, Network status, Current incidents, Recent SOS,
  Mesh health, Connected mesh devices, Online volunteers, Map placeholder,
  Broadcast panel, Recent broadcasts, and Community chat.
- The statistics grid and section placement scale with screen size using the
  existing responsive helpers (`gridColumns`, `pageInset`).

Automatic mesh formation is independent of this screen: it runs app-wide from
startup with no screen-size guards, so a tablet discovers and connects to nearby
SUMPAY devices automatically, exactly like a phone, provided its Bluetooth,
Wi-Fi and Location radios are on and permissions are granted. The dashboard's
Network status, Mesh health, and Connected mesh devices sections surface that
live state. The dashboard only reads mesh state; it never stops or disables the
mesh.

---

## Tech stack

- **State management:** Riverpod (`flutter_riverpod`)
- **Navigation:** GoRouter (`go_router`) with a stateful bottom-nav shell
- **Responsiveness:** Responsive Framework + custom breakpoint helpers
- **Design:** Material 3, Google Fonts (Plus Jakarta Sans + Inter),
  Material Symbols
- **Motion:** `animations` (fade-through), Hero transitions, custom animations,
  Lottie placeholders

## Where to plug in the backend

| Placeholder | File | Replace with |
|---|---|---|
| Auth | `features/authentication/providers/auth_provider.dart` | Real auth repository |
| Network telemetry | `features/iot/providers/network_provider.dart` | BLE / Wi-Fi Direct bridge stream to ESP32 |
| SOS submission | `features/sos/providers/sos_provider.dart` | LoRa packet dispatch + acknowledgement |
| Messaging | `features/messaging/providers/messaging_provider.dart` | Mesh / LoRa transport + local queue |
| Broadcasts | `features/broadcast/providers/broadcast_provider.dart` | Command-node broadcast API |
| Dummy JSON | `features/*/data/dummy_*.dart` | Database / API responses |

Each model already exposes `fromJson`, so swapping dummy data for live payloads
requires no changes to the widget layer.

### Community chat improvements (Phase 9)

The mesh-wide community chat gained richer messaging, all kept compatible with
the routing system:

- Each message shows the sender's name, a role badge (Resident, Volunteer,
  Barangay Official, Administrator) and its delivery status, reusing the existing
  message bubble.
- Reply: long-press a message to reply; the composer shows a reply preview and
  the quoted message renders inside the bubble. The reply target id, sender name
  and a short text preview travel with the message packet (optional JSON fields,
  so older packets still decode) and are persisted.
- Read status is local-only by design: opening the community chat marks messages
  read on this device. No read receipts are transmitted, so read tracking adds
  no mesh traffic. An unread counter appears on the community chat entry card.
- Pinned announcements: long-press to pin a message; a pinned bar shows above the
  thread. Pins are local device state.

Two commonly-expected chat features were deliberately left out because they do
not fit an offline, serverless mesh: a typing indicator (multi-hop typing pings
add traffic for little value) and online presence (there is no server to track
who is online). Leaving them out keeps the system honest about what a mesh can
actually guarantee.

Only reply metadata travels the mesh; read and pinned state are local, so mesh
compatibility and traffic are unaffected. Database schema is at version 5,
adding reply, read and pinned columns to messages; a migration upgrades existing
installs.

### Resident interface refinements (Phase 10)

Focused improvements to the resident-facing screens, all reusing existing
infrastructure:

- SOS: the free-text "describe your situation" field was removed so residents
  only pick a predefined category; the Custom category is hidden from the
  resident SOS grid (kept in the enum for compatibility) via
  `EmergencyType.residentSelectable`. The people-affected control is labelled
  "Number of people affected" and is clamped to a minimum of one.
- Area-specific chat: a barangay + purok group chat
  (`ChatRepository.areaConversationId`) that reuses the community chat controller
  and the existing mesh broadcast + conversation-id filtering, scoped to the
  user's area, so no separate networking is introduced. The community chat
  screen was parameterised so one screen serves both chats; the Messages screen
  shows both a Community and an Area entry, each with an unread badge.
- Profile editing: residents can edit their medical information (blood type,
  allergies, conditions) and add, edit, or delete emergency contacts. Changes are
  persisted locally through `AuthController.persistProfile`, which upserts the
  resident record (the user row already stores medical info and contacts as
  JSON), so edits survive restarts.

Broadcast and Network screens already met the requirements from earlier phases
(severity-sorted broadcasts; live mesh status, connected devices and signal
quality) and were left unchanged.

### Internet-wide connectivity (Sprint 1)

SUMPAY is now a hybrid communication system: it uses the internet when available
and falls back to the offline mesh when it is not. The mesh is unchanged and
remains the resilient core.

A transport abstraction was introduced so the application layer is independent
of the communication method. `SumpayTransport` is the shared contract; the
existing mesh and a new Supabase-backed `InternetTransport` both sit behind a
`TransportManager` that sends over whichever paths are available. Inbound
internet packets are fed into the existing routing engine, so decoding,
duplicate-prevention (by packet uuid) and local delivery reuse the proven mesh
code rather than a parallel path. The same `MeshPacket` travels over both
transports; there is no separate internet message model.

SOS and community chat now send through the manager, so an SOS goes out over the
internet when connected and over the mesh when there are nearby devices, and is
queued and flushed on reconnect otherwise. A `ConnectivityService` exposes the
independent Internet / Wi-Fi / Bluetooth / Mesh / Gateway states without merging
them into one misleading status.

The backend is Supabase (Realtime broadcast for delivery, a `packets` table for
durability and admin oversight). It is configured through `--dart-define`
values; when absent, the app runs mesh-only with no crash. See
`SUPABASE_SETUP.md` for the one-time backend setup.

Known limitations this sprint: authentication and Row Level Security are not yet
wired (a following step), and the cross-network round-trip must be verified on
devices once the team's Supabase project is live.

### Resident network status icon (Sprint 2)

On the Resident Home screen, the large network status card was replaced by a
compact, tappable network icon in the top-right app bar, immediately before the
Notifications icon. The icon reflects the current network state (Internet
connected, mesh active, Wi-Fi active, Bluetooth active, connecting, or offline)
via a single most-meaningful glyph and colour, resolved from the connectivity
snapshot (`network_glyph.dart`), with an accessible tooltip. Tapping it opens the
existing Network screen, where the detailed mesh information still lives. Mesh
connection state is now mirrored into the connectivity snapshot so the icon
reflects the live mesh, and the SOS button remains the dominant action on the
home body. Only the Resident Home screen was changed.

### Responder response workflow (Sprint 3)

When a responder accepts an SOS, the resident now receives a dedicated,
SOS-associated response event over the existing mesh routing (no bypass, no new
chat message). The SOS packet gained responder identity and a dedicated response
id (responder id, responder role, response id), carried as optional fields so
older packets still decode. On the resident's home a prominent GREEN response
card appears showing the responder's name, role, response status and time,
signalling that the emergency has been acknowledged. The green styling is used
only for the SOS responder response, not for ordinary messages. The card updates
as the responder progresses (accepted, en route, arrived, resolved), and is only
shown for the resident's own SOS. The response travels the same routing engine
and transports as everything else, so direct and multi-hop both apply.

### Responder tracking + OpenStreetMap (Sprint 4)

When a responder accepts, the resident's home shows a FoodPanda-style floating
status overlay (replacing the earlier inline card) that hovers above the page
content while the SOS is active. It keeps the green "accepted" styling and shows
the responder's name, role, the SOS type, and a live status line, and it is not
casually dismissible so an active emergency can't be swiped away by accident. A
"Track Responder" action opens a dedicated OpenStreetMap tracking screen built
on flutter_map (no Google Maps, no API key, cacheable OSM tiles). The screen
shows resident, responder and SOS markers, a route/path placeholder polyline,
map controls (center on resident, center on responder, recenter, zoom) and a
bottom status panel with the responder's status and last update time. The
responder's location is captured via GPS when they accept (non-blocking if
permission is denied) and travels inside the existing SOS packet over the mesh.
A MapService abstraction (OsmMapService) isolates the mapping implementation so
it can be swapped later, and the TrackingState supports future periodic location
updates without UI changes. Map tile availability is kept separate from
communication: if tiles fail to load, the mesh and SOS continue working.

### Map integration hardening (Phase 2.15)

The tracking map was hardened against this phase's requirements: marker labels
now read "Your Location", "Responder" and "Emergency Location" with distinct
icons (person pin, responder, SOS); the status panel shows the live responder
status and a straight-line distance (via latlong2, no network) between resident
and responder alongside the last-update time. If OSM tiles fail to load (e.g.
offline), an on-map "tiles unavailable offline" banner appears while the markers,
distance and status panel keep working. The tracking feature reads only from
providers and shares no code with the transport layer, so a map-tile failure
cannot affect mesh or SOS communication. No Google Maps dependency exists.

© SUMPAY — for academic use.
