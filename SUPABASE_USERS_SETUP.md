# SUMPAY — Supabase `users` Table Setup (for the auth/account system)

This adds the **user accounts** part of the backend, on top of the existing
`packets` table you already set up for messaging. It lets SUMPAY store accounts
(admin, officials, responders, residents), authenticate logins, and handle the
admin approval of residents.

You only need to do this **once**, on the **same Supabase project** the app
already uses for the internet transport. No coding — you paste SQL and run it.

Estimated time: ~10 minutes.

> Do this on the SAME project whose URL + anon key are already in the app's
> build (`--dart-define`). Do NOT make a new project.

---

## Part 1 — Create the `users` table

1. Open your project at https://supabase.com → your SUMPAY project.
2. Left sidebar → **SQL Editor** → **New query**.
3. Paste this exactly and click **Run**:

```sql
create table if not exists public.users (
  id              text primary key,
  surname         text not null,
  first_name      text not null,
  middle_name     text,
  role            text not null,           -- resident | volunteer | official | admin
  phone           text not null unique,    -- login identifier
  email           text not null,
  barangay        text not null default '',
  purok           text not null default '',
  municipality    text not null default '',
  household_size  int  not null default 1,
  language        text not null default 'English',
  device_id       text not null default '',
  emergency_contacts jsonb not null default '[]',
  medical         jsonb not null default '{}',
  status          text not null default 'pending',  -- pending | active | rejected | inactive
  password_hash   text not null,
  created_at      timestamptz not null default now()
);

create index if not exists users_phone_idx  on public.users (phone);
create index if not exists users_status_idx on public.users (status);
```

You should see **Success. No rows returned.**

To confirm: left sidebar → **Table Editor** → you should now see a **users**
table with those columns (alongside the existing **packets** table).

---

## Part 2 — Allow the app to use the table (demo access policy)

By default the table is locked. For the demo we open read/write/update access.
(This is the same posture as the `packets` table — fine for a controlled demo,
to be tightened later.)

In **SQL Editor** → **New query**, paste and **Run**:

```sql
alter table public.users enable row level security;

create policy "sumpay users read"
  on public.users for select using (true);

create policy "sumpay users write"
  on public.users for insert with check (true);

create policy "sumpay users update"
  on public.users for update using (true) with check (true);
```

Expected result: **Success. No rows returned.**

(If it says a policy already exists, someone already ran it — that's fine.)

---

## Part 3 — Seed the demo accounts

These are the pre-made accounts for the presentation. The passwords are stored
as **SHA-256 hashes** (never plaintext). The people running the demo will log in
with the plain passwords listed at the bottom; the database only stores the
hash.

> IMPORTANT: The exact `INSERT` statements with the hashed password values will
> be provided by the developer (they are generated to match the app's hashing).
> Paste those in the SQL Editor and Run. This section explains what they do and
> lets you verify the result.

After running the provided seed INSERTs, you should have **7 accounts** in the
`users` table:

| Role       | Name (Surname, First)   | Phone (login) | Status |
|------------|-------------------------|---------------|--------|
| admin      | Admin, Barangay         | 09000000001   | active |
| official   | Rubio, Elena            | 09000000002   | active |
| official   | Santos, Mario           | 09000000003   | active |
| volunteer  | Cruz, Jose              | 09000000004   | active |
| volunteer  | Lim, Ana                | 09000000005   | active |
| resident   | Fernandez, Maria Liza   | 09000000006   | active |
| resident   | Reyes, Pedro            | 09000000007   | active |

To verify: **Table Editor → users** → you should see all 7 rows, each with a
`role`, a `phone`, a `status` of `active`, and a non-empty `password_hash`.

("volunteer" is the responder role in the app.)

---

## Part 4 — Confirm the app points at this project

Nothing new to configure in the app itself — it reads/writes `users` using the
**same URL + anon key** already set for messaging. Just make sure the build uses
those same values:

```
--dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co
--dart-define=SUPABASE_ANON_KEY=THE-ANON-PUBLIC-KEY
```

(Use the **anon / public** key — NOT service_role. Same one that already makes
the internet transport work.)

---

## Part 5 — Quick verification checklist

- [ ] `users` table exists with the columns above (Table Editor).
- [ ] The 3 policies exist (Authentication → Policies, or re-running Part 2 says
      "already exists").
- [ ] 7 seeded accounts present, all `status = active`, all with a
      `password_hash`.
- [ ] The project is the SAME one as the working `packets`/messaging setup.

Once these are checked, the app will be able to authenticate logins and run the
admin create/approve flows against this table.

---

## What the developer still needs to provide you
- The **exact `INSERT` statements** for Part 3 (with the correct SHA-256 hashes).

## Security note (for after the demo)
The Part 2 policies allow anyone with the anon key to read/write the table —
acceptable for a controlled demo, but before any real deployment this must be
tightened (proper Supabase Auth + row-level rules so only the admin can create
staff and approve residents, and so password hashes aren't world-readable).
