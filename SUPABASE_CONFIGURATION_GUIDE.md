# SUMPAY — How to Configure the Supabase Backend

This guide sets up the online backend that lets SUMPAY communicate over the
internet (across different Wi-Fi networks and mobile data). You only need to do
this **once** for the whole team — one shared Supabase project.

**No coding is required.** You will click through the Supabase website, paste in
one block of SQL, copy two values, and hand those two values to whoever builds
the app.

Estimated time: about 15–20 minutes.

> Important: SUMPAY still works **without** this. If the backend is not set up,
> the app runs in offline mesh mode (Bluetooth / Wi-Fi Direct) and does not
> crash. This backend only **adds** the internet path. So there is no risk in
> doing this — you cannot break the existing app by setting it up.

---

## Part 1 — Create the Supabase account and project

1. Go to **https://supabase.com**
2. Click **Start your project** (top right) and sign in. The easiest option is
   **Sign in with GitHub**; email sign-up also works. The **free plan** is
   enough for our capstone — do not pay for anything.
3. Once signed in you land on the **Dashboard**. Click **New project**.
4. Fill in the form:
   - **Organization:** if asked to create one, name it anything (e.g. `SUMPAY`).
   - **Project name:** `sumpay`
   - **Database Password:** click **Generate a password**, then **copy it and
     save it somewhere** (a group chat pinned message or a shared doc). You may
     need it later. This is NOT the value the app uses, but don't lose it.
   - **Region:** choose the closest one to the Philippines. Pick
     **Southeast Asia (Singapore)**. Closer region = faster.
   - Leave everything else default.
5. Click **Create new project**.
6. Wait about 1–2 minutes while it says "Setting up project…". When it finishes,
   the project dashboard opens. Continue to Part 2.

---

## Part 2 — Create the database table

The app relays messages in real time, and also saves a copy of every packet in
a table (so devices that were offline can catch up, and so the admin can later
see records). We need to create that one table.

1. In the left sidebar of your project, click the **SQL Editor** icon (looks
   like a terminal / `>_`).
2. Click **+ New query** (or **New snippet**).
3. **Delete anything** in the editor, then **paste this exactly**:

```sql
-- Table of SUMPAY packets relayed through the backend.
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

-- Helpful indexes for fetching recent packets and by destination.
create index if not exists packets_created_at_idx
  on public.packets (created_at desc);

create index if not exists packets_destination_idx
  on public.packets (destination_id);
```

4. Click **Run** (bottom right, or press Ctrl/Cmd + Enter).
5. You should see **Success. No rows returned.** That means the table was
   created. (If you run it again later it is safe — `if not exists` prevents
   errors.)

To confirm: click the **Table Editor** icon in the sidebar. You should see a
table named **packets** with the columns listed above.

---

## Part 3 — Allow the app to use the table (temporary demo policy)

By default Supabase blocks all access to the table for safety. For our testing
we will open it up with a simple policy. **Read the security note at the end
before any real/public deployment**, but for capstone testing this is fine.

1. Go back to the **SQL Editor**, **New query**, paste this, and **Run**:

```sql
-- Turn on row-level security for the table.
alter table public.packets enable row level security;

-- DEMO POLICY: allow anyone with the app to read and insert packets.
-- This is intended for controlled capstone testing only.
create policy "sumpay demo read"
  on public.packets for select
  using (true);

create policy "sumpay demo insert"
  on public.packets for insert
  with check (true);
```

2. You should again see **Success. No rows returned.**

(If it says a policy already exists, that's fine — it means someone already ran
it.)

---

## Part 4 — Copy the two values the app needs

The person who builds the app needs exactly **two values** from your project.

1. In the left sidebar, click the **gear / Project Settings** icon (bottom).
2. Click **API** (or **Data API**, depending on the dashboard version).
3. Find and copy these two:

   - **Project URL** — looks like:
     `https://abcdefghijklmnop.supabase.co`
   - **anon public** key (under "Project API keys") — a very long string that
     starts with something like `eyJhbGciOi...`. Make sure you copy the one
     labeled **anon** / **public**, NOT the one labeled **service_role**.

> ⚠️ **Do NOT share the `service_role` key** and do not put it in the app. Only
> the **anon / public** key goes to the app. The service_role key is a master
> key — keep it secret.

4. Paste both values into your group's shared note / pinned chat message, clearly
   labeled:

```
SUPABASE_URL = https://YOUR-PROJECT.supabase.co
SUPABASE_ANON_KEY = eyJhbGciOi...(the long anon key)...
```

That's everything the backend needs. The person doing the build/testing takes it
from here.

---

## Part 5 — (For whoever builds/tests the app) Plugging the values in

The app reads these two values at build time, so they are never committed to the
code. Run the app like this (replace with the real values from Part 4):

```bash
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

For a release APK to install on phones for testing:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

Optional, to avoid retyping every time: create a file named `env.json` in the
project root:

```json
{
  "SUPABASE_URL": "https://YOUR-PROJECT.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOi..."
}
```

then run:

```bash
flutter run --dart-define-from-file=env.json
```

(Do not commit `env.json` to a public repo.)

If you build **without** these values, the app still runs — just in offline mesh
mode only. That is expected.

---

## Part 6 — How to check it's working

1. Build the app **with** the values on **two phones**.
2. Put the phones on **different internet connections** — e.g. one on home
   Wi-Fi, one on mobile data. They do NOT need to be near each other.
3. On phone A, send a **community chat** message (or an SOS).
4. Phone B should receive it through the internet, even far apart.
5. To confirm the backend is storing packets: in Supabase, open
   **Table Editor → packets**. You should see new rows appear as messages are
   sent.

To confirm the offline mesh still works: turn **off** internet on both phones,
keep them near each other, and send a message — it should still go through over
Bluetooth / Wi-Fi Direct.

---

## Troubleshooting

- **"I set the values but nothing arrives over the internet."**
  - Double-check the URL and anon key have no extra spaces or line breaks.
  - Make sure you used the **anon/public** key, not service_role.
  - Make sure Part 3 (the policies) was run — without it, inserts are blocked.
  - Confirm both phones actually have working internet.

- **"Success. No rows returned" — is that an error?**
  No. For `create table` / `create policy`, that message means it worked.

- **"Policy already exists" error when running Part 3.**
  Someone already ran it. Safe to ignore.

- **The app crashes on launch after adding Supabase.**
  Run `flutter pub get` first (two new packages were added). If it still
  happens, capture the red `E/flutter` line from the logs and send it — that
  line pinpoints the cause.

- **Nothing shows in Table Editor → packets.**
  The real-time message may still have delivered (that path doesn't need the
  table). The table only fills when inserts are allowed (Part 3) and the app is
  built with valid values.

---

## Security note (read before any real deployment)

The demo policies in Part 3 let **anyone with the anon key** read and write the
`packets` table. For a controlled capstone demo this is acceptable and simplest.
Before any real public use, we should:

- Add Supabase **Authentication** so only registered SUMPAY users (officials,
  volunteers, and synced residents) can use the backend.
- Replace the "allow everyone" demo policies with policies tied to authenticated
  users.

This is planned for a later development step and does not affect testing now.

---

## Summary — what each person does

- **Whoever owns the backend:** Parts 1–4, then post the two values to the group.
- **Whoever builds/tests:** Parts 5–6 using those two values.
- **Everyone else:** nothing — just install the test APK you're given.
