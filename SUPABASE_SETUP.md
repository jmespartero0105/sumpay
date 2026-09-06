# SUMPAY — Supabase backend setup (Internet transport)

This guide sets up the backend that powers SUMPAY's internet-wide communication.
Until this is done, the app runs in **mesh-only mode** (offline BLE / Wi-Fi
Direct), which is the intended fallback. Nothing here changes or weakens the
mesh; the internet path is strictly additive.

Do this once. It takes about 15 minutes.

---

## 1. Create the Supabase project

1. Go to https://supabase.com and sign in (free tier is enough).
2. Create a new project. Choose a region close to your users (e.g. Southeast
   Asia / Singapore for the Philippines).
3. Wait for it to finish provisioning.
4. Open **Project Settings -> API** and copy two values:
   - **Project URL** (looks like `https://abcdefgh.supabase.co`)
   - **anon public** key (a long JWT string)

Keep these for step 4.

---

## 2. Create the database tables

Open **SQL Editor** in the Supabase dashboard, paste the following, and run it.

```sql
-- Packets relayed through the backend (durability + admin oversight).
create table if not exists public.packets (
  uuid            text primary key,
  sender_id       text not null,
  destination_id  text not null,
  priority        text not null,
  ttl             int  not null,
  hop_count       int  not null,
  payload         jsonb not null,
  created_at      timestamptz not null default now()
);

create index if not exists packets_created_at_idx
  on public.packets (created_at desc);

create index if not exists packets_destination_idx
  on public.packets (destination_id);
```

The app sends real-time messages over a **broadcast channel** (fast path) and
also inserts each packet into this `packets` table (durability path), so a
device that was offline can catch up and the admin has an authoritative record.

---

## 3. Enable Realtime

The internet transport uses a Realtime **broadcast** channel named
`sumpay-mesh`. Broadcast channels do not require table replication, so there is
nothing else to toggle for messaging.

If you later want the `packets` table itself to stream changes (optional, for an
admin live feed):

```sql
alter publication supabase_realtime add table public.packets;
```

---

## 4. Point the app at your project

The app reads the URL and key from Dart compile-time environment variables, so
no secrets are committed to the repo. Build or run with:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

For a release APK:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

If you omit these, the app simply runs mesh-only (no crash). That is expected
and is a valid SUMPAY state.

Tip: to avoid typing the defines every time, put them in a file such as
`env.json`:

```json
{
  "SUPABASE_URL": "https://YOUR-PROJECT.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR-ANON-KEY"
}
```

and run `flutter run --dart-define-from-file=env.json`.

---

## 5. Security notes (important for the capstone)

The steps above get communication working quickly. Before any real deployment,
tighten access:

- **Row Level Security (RLS).** Enable RLS on `packets` and add policies so only
  authenticated SUMPAY users can insert/select. With the anon key and no RLS,
  the table is world-writable — fine for a controlled demo, not for production.
- **Auth.** This phase ships the transport. Wiring Supabase Auth (so only
  registered officials/volunteers, and synced residents, can use the backend)
  is a following step and pairs with the admin-oversight work.
- The broadcast channel is currently open to anyone with the anon key. For a
  graded demo this is acceptable; note it as a known limitation.

---

## 6. Testing the internet path

1. Build the app on **two phones** with the `--dart-define` values set.
2. Put them on **different networks** (e.g. one on Wi-Fi, one on mobile data).
3. Send a community chat message or an SOS on phone A.
4. Phone B should receive it through the backend, even though they share no
   local network and are out of Bluetooth range.
5. Now turn **off** internet on both and confirm the **mesh** still delivers
   between nearby devices — the fallback must keep working.

---

## What the app does with this

- Sends each SUMPAY packet as a Realtime broadcast on channel `sumpay-mesh`
  (event `packet`) for low-latency delivery, and inserts it into `packets` for
  durability/oversight.
- Receives broadcasts and feeds them into the existing routing engine, which
  de-duplicates by packet uuid — so a packet heard on both the internet and the
  mesh is shown only once.
- Falls back to mesh automatically when the internet is unavailable, and flushes
  queued packets when it returns.
