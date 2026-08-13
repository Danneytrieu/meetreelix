# meetReelix

A group scheduler that tells you the answer instead of making you squint for it.

Everyone marks when they're free on a shared grid. The times that work for
**everyone** show up in a different colour — not a slightly darker one — and the
strongest overlaps are ranked for you, longest first. Lock one in and each
person gets a one-click **Add to Google Calendar** in their own timezone.

No accounts. No sign-in. One link.

## Why it exists

when2meet works, but it makes you do the last mile yourself: 8-of-9 and 9-of-9
are nearly the same green, so the answer hides in the gradient, and once you've
found it you're still copying times into Slack by hand.

- **A full house is a different hue.** The density ramp is quiet olive; only
  "everyone" glows volt.
- **Overlaps are ranked**, and you can ask for a minimum length — "I need 90
  minutes" re-ranks around blocks that actually fit.
- **Timezones are per-reader.** The event stores the organiser's zone; every
  slot is an absolute instant re-expressed in *your* clock. Hours that don't
  exist on your side of the date line are hatched out.
- **You can only edit your own row.** Your name locks to your browser. Filling
  in for someone else takes a deliberate action and announces itself the whole
  time it's on.

## Setup

**1. Create a Supabase project** — <https://supabase.com>, free tier is plenty.

**2. Create the tables.** Open the project → SQL Editor → New query, paste all
of [`schema.sql`](schema.sql), Run.

**3. Point the app at it.** In `config.js`, replace the two placeholders with
the values from Settings → API:

```js
window.MEETREELIX_CONFIG = {
  url:     "https://YOUR-PROJECT.supabase.co",
  anonKey: "eyJhbGci..."
};
```

Use the **anon / public** key. Never the `service_role` key — that one bypasses
every row-level policy.

**4. Serve it.** Any static host works; it's one HTML file plus a config. For
GitHub Pages: Settings → Pages → Deploy from branch → `main` / root.

Without config, the app still runs — it just keeps everything on your own
device and falls back to passing a link around.

## Security model

Holding an event id is the permission, exactly like an "anyone with the link"
doc. Ids are 128-bit random, so they can't be guessed or walked. No policy
permits listing events, so nobody can enumerate schedules they weren't sent.

What this deliberately does **not** do is authenticate people. Anyone with the
link can add a name or edit an answer — the identity lock prevents *accidents*,
not a determined person. That's the right trade for scheduling a meeting; it
would be the wrong trade for anything private.

## Keyboard

| | |
|---|---|
| drag | mark when you're free |
| drag from a filled cell | clear |
| click a day header | fill / clear the whole column |
| arrows | move · space toggles · shift+arrow drags |
| ⌘Z / ⌘⇧Z | undo / redo, one step per gesture |

## The War Room

The same rail that holds the scheduler also holds five read-and-write rooms for
the Higgsfield Global Film Festival. The calendar is now one icon; the rest are
its neighbours.

| Room | What it is |
|---|---|
| **Schedule** | the original availability grid, unchanged — its four panels moved into sub-tabs |
| **The clock** | the festival timeline, computed live against the real dates. It advances on its own |
| **The judges** | dossiers on all four — Catmull, Papamichael, Anderson, Proyas: quotes, filmographies, what lands and what dies |
| **The rules** | the nine ways to be ruled non-eligible before a judge sees your film |
| **The slate** | six concepts built for this specific jury, with key art |
| **The room** | anonymous idea posting and voting |

Everything except **The room** is static — edit the `JUDGES`, `GATES`, `SLATE`
and `FEST` arrays near the bottom of `index.html` and the pages rebuild
themselves. Key art lives in `art/`, one file per concept `key`.

### The room's trust model is not the scheduler's

The scheduler treats the link as the permission, and any holder can edit any
row. That is the right trade for availability and the wrong one for competitive
ideas, so `festival_ideas` and `festival_votes` authenticate every write against
a token the browser holds and the server never returns: `owner_token` is
excluded from all read grants, deletes must present it, and one voter gets one
vote per idea by primary key.

It is still not a ballot box. Clearing site data yields a new identity and a
second vote. That is acceptable for a closed room of collaborators and would not
be for anything public — the UI says so on the page.

Run the whole of `schema.sql` again after upgrading; the festival section is
additive and every statement is idempotent.
