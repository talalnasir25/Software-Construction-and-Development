# Carp – university carpooling app (DEMO)

## Naming rule
- **"Claude Code"** = Claude inside VS Code (the coding agent working in this folder).
- **"Claude"** = the Claude chat on claude.ai in Chrome.

## Project
- Owner: beginner student, working solo. Demo for a university lab.
- Project root: `D:\carp` (the folder open in VS Code). Flutter app: `D:\carp\carp_app`.
- Flutter SDK: `D:\dev\flutter` (stable, git clone, no admin), `D:\dev\flutter\bin` on the USER PATH.
- Target: Chrome (web) now; Android/iOS later.
- Explain every command in one short line.

## Requirements / decisions (from the owner)
- Material 3, one consistent theme, reusable widgets, loading/empty/error states.
- NO real backend yet. All data in memory with seeded sample data, behind a repository class
  (`CarpRepository`) so a Node.js + Express + PostgreSQL (Prisma) backend can be swapped in later.
- Not installed tonight: Android Studio, Node.js, PostgreSQL.
- Login (demo): any email/password works. Real login will only allow `@isbstudent.comsats.edu.pk`
  (students and faculty), verified server-side later.
- Profile has "Demo: switch user" with sample users.
- One account, Driver/Rider mode switch. Bottom nav changes per mode. "Map" tab = "Coming soon".
- Driver posts trips: from, to, date, time, repeat (one-time/daily/weekdays), vehicle (car max 4 seats,
  bike max 1), seats, number plate, pricing mode:
  - TOTAL SPLIT: total shared equally by attending riders + driver. Share = ceil(total / (riders + 1)).
  - PER SEAT: fixed price per rider.
- Free limit: max 2 trips per driver per calendar day. 3rd → "Free plan allows 2 trips per day. Pro coming soon."
- Rider: browse, details, join if seats left, "My rides", clear "trip full" message.
- Cancellations: rider within 10 min of joining = free; after = 10% of share penalty (rider → driver).
  Driver cancels = each joined rider gets 10% of their share as credit from the driver.
  "Share" = per-rider cost at that moment. Round every rupee amount UP.
- Attendance: riders default PRESENT; driver toggles, then "Confirm trip" → charges for present riders only.
  Zero attendees = no charges. Edit allowed for 24h after confirming: never overwrite, add reversal
  entries + new charges, mark trip "Edited", edit history visible to riders.
- Disputes (demo): rider can dispute a charge within 24h; disputes listed on the trip.
- Balances: ledger-based. Positive = owes, negative = credit. Full history visible.
- Payments outside app (Cash, JazzCash, Easypaisa, NayaPay). Rider marks "I paid" → PENDING until the driver
  confirms. Driver can record a payment directly. Overpayment = credit. Block duplicate double-tap payments.
- Settings: profile, vehicle info, language (English; Urdu coming soon), "Carp Pro – Coming soon", logout.
- All money rules in plain Dart (no UI) under `lib/domain/`, with unit tests.
- Commit with clear messages after each major step.

## Decisions made by Claude Code
- Git exists at `C:\Program Files\Git\cmd` but was not on PATH; added it to the USER PATH (Flutter needs git).
- State management: plain `ChangeNotifier` + `ListenableBuilder` (no extra packages) to keep it simple for a beginner.
- Money stored as whole rupees (`int`), never doubles. Rounding up uses integer math.
- Ledger amounts are per rider-driver pair: positive = rider owes driver, negative = driver owes rider (credit).
- Duplicate payment = same rider, driver, amount, method within 10 seconds → rejected.
- A trip's "calendar day" for the 2-per-day limit = the trip's departure date (not the posting date).
- Repeating trips are stored as one trip with a repeat rule (not expanded into many trips) for the demo.
- Rider share for TOTAL SPLIT shown on browse = share if this rider joins (ceil(total / (joined + 1 + 1))).
- Disputes do not change money; they are only listed on the trip for the driver/admin to review.
