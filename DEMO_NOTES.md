# Carp – Demo notes

Carp is a university carpooling app. This is a **demo** built with Flutter and runs in Chrome.
All data is fake and lives in memory: **reloading the page resets everything** to the sample data.

---

## 1. How to start the app tomorrow

Open **PowerShell** (or the VS Code terminal) and run:

```powershell
cd D:\carp\carp_app        # go to the app folder
flutter run -d chrome      # build the app and open it in Chrome (takes ~30-60 s the first time)
```

- While it runs: press `r` for hot reload, `R` to restart (also resets the data), `q` to quit.
- If you get `flutter is not recognized`: close and reopen the terminal (the PATH was updated tonight).
  If it still fails, run this first: `$env:Path = "D:\dev\flutter\bin;C:\Program Files\Git\cmd;$env:Path"`
- To run the tests: `flutter test` (in `D:\carp\carp_app`).

---

## 2. Two-minute demo script for the teacher

Sample users (any password works, e.g. `demo1234`):

| User | Role | Why |
|---|---|---|
| **Ayesha Khan** | Driver (car, LEA-1234) | Has open trips, a trip to confirm, a pending payment |
| **Bilal Ahmed** | Driver (bike, ICT-21-555) | Bike = max 1 seat, has a FULL trip |
| **Sara Malik** | Rider | Owes Ayesha Rs 600, has Rs 25 credit from Bilal |
| **Usman Tariq** | Rider | Joined 4 min ago (free cancel), has a pending JazzCash payment |

**Driver side (about 1 minute)**
1. Login screen → explain "real login only allows @isbstudent.comsats.edu.pk". Tap chip **Ayesha Khan** → **Log in**.
2. You are in **Driver** mode (switch at the top right). Show the bottom bar: My trips, Map (coming soon), Riders, Profile.
3. Tap **Post a trip** → press **Post trip** empty to show the validation messages. Fill in: From `F-7 Markaz`, To `COMSATS`,
   date tomorrow, time 8:00, Car, 3 seats, plate `LEA-1234`, Total split, `1500`. The box shows
   "1 rider → Rs 750, 2 riders → Rs 500, 3 riders → Rs 375". Post it. ✅
4. Tap **Post a trip** again and fill it in again → the **"Free plan allows 2 trips per day. Pro coming soon."** message appears.
5. Open the trip **G-11 Markaz → COMSATS Park Road** (Sara + Usman joined). Turn **Usman → Absent**. The text shows
   "1 present × Rs 750". Press **Confirm trip**. Only Sara is charged.
6. Go to **Riders** tab → Usman's pending JazzCash Rs 350 → press ✓ **Confirm**. His balance becomes settled.

**Rider side (about 1 minute)**
7. **Profile → Demo: switch user → Sara Malik**. App switches to **Rider** mode.
8. **Find rides** → open **Bahria Town Phase 7** (bike) → it shows **"This trip is full"**.
9. Open **F-10 Markaz** → **Join trip**. Explain: free cancel within 10 min, then 10% penalty.
10. **Wallet** → total balance, per-driver balance, full history (charges, payments, the Rs 25 driver-cancel credit).
    Tap **I paid** next to Ayesha → type `2000` (more than owed: the dialog says "Rs X extra will become credit")
    → Easypaisa → **Save**. It shows as **Pending** until Ayesha confirms it.
    Try saving the exact same payment again right away → **"This payment was already added."**
11. In the history, tap the **Dispute** button on a recent charge (within 24 h) → it is listed on the trip.

Optional extras: as Ayesha, open the **COMSATS Park Road → G-11 Markaz** trip (confirmed 3 h ago) → switch Usman to Present →
**Save attendance edit** → reversal + new charges appear and the trip shows **"Confirmed · Edited"** with an edit history.
Before step 5 (or after pressing `R` to reset): as Usman, open **G-11 Markaz** in My rides → cancel → free
(he joined less than 10 min before the app started). As Sara the same cancel costs Rs 50 (10% of Rs 500).

---

## Theme

- **Sun/moon button** at the top right of the login screen and every main tab: one tap switches light ↔ dark.
- **Profile → Appearance → "Dark mode"** switch does the same thing and stays in sync with the button.
- The choice is remembered after closing the browser. On first launch the app follows the browser/device setting.
- All colors live in `carp_app/lib/theme/app_theme.dart` (bright blue, orange, green, amber and red, with a navy dark mode).

---

## 3. What is real vs fake

| Real (working logic) | Fake / demo only |
|---|---|
| Cost split, rounding up, per-seat pricing | Login: any email/password works, no verification |
| 2-trips-per-day limit | Data is in memory only, resets on reload |
| Seat check, "trip full" | No server, no database (sample users and trips are seeded) |
| 10-minute free cancel, 10% penalties, driver-cancel credits | Map tab ("Coming soon") |
| Attendance, confirm, 24 h edit with reversal entries + edit history | Disputes are only listed, nobody reviews them |
| Ledger: balances, credits, overpayment → credit | Payments are not real money; Cash/JazzCash/etc. are just labels |
| Pending payments + driver confirm/reject, duplicate (double tap) guard | Urdu language, Carp Pro ("Coming soon") |
| Form validation with clear messages | Users can switch accounts freely ("Demo: switch user") |

All money rules are in plain Dart files with no UI code: `carp_app/lib/domain/money_rules.dart` and
`carp_app/lib/domain/trip_draft.dart`. The app talks to data only through `CarpRepository`
(`carp_app/lib/data/carp_repository.dart`). Tonight that is `InMemoryCarpRepository`; later it becomes an HTTP version
that calls the Node.js backend.

---

## 4. Actual test results (run on 2026-10-29)

`flutter analyze` → **No issues found!**

`flutter test` → **56 tests, All tests passed!**

- `test/money_rules_test.dart` (42 tests): total split with 1/2/3 riders (750/500/375), Rs 1000 / 3 people = Rs 334,
  per-seat pricing, zero attendees = no charges, 3rd trip same day rejected, full trip rejected, cancel at 9 min free /
  10 min free / 11 min penalty, driver cancel credits (rounded up), attendance edit at 23 h allowed / 25 h rejected,
  reversal + new charge planning, disputes within / after 24 h, duplicate payment rejected (and different amount / method /
  later time allowed), overpayment becomes credit.
- `test/repository_test.dart` (12 tests): the same rules end to end through the in-memory repository with a fake clock
  (post → join → confirm → edit, penalties, credits, pending → confirmed payments, double tap, disputes).
- `test/app_smoke_test.dart` (2 tests): logs in, opens every tab as driver and rider, trip details and the post form,
  at phone width (390 px) and laptop width (1280 px), and fails on any crash or layout overflow.
  (This test found a price label overflow on phones, which was then fixed.)

`flutter run -d chrome` → app built and opened in Chrome with no errors in the console log.

---

## 5. Next steps for the semester

Not done tonight (on purpose):
- **Backend**: Node.js + Express + PostgreSQL with Prisma. Write `ApiCarpRepository` with the same methods as
  `CarpRepository`, and move the money rules to the server (the server must be the one that decides charges).
- **Real login**: only `@isbstudent.comsats.edu.pk` emails, **email verification**, password hashing, sessions/JWT.
- **Real maps**: routes and pickup points (Map tab).
- **WhatsApp** contact/sharing with the driver.
- **Real billing** for Carp Pro (and lifting the 2-trips-per-day limit for Pro).
- **Offline mode** (cache trips and balances on the phone).
- **Android APK** (needs Android Studio + Android SDK) and **iOS build** (needs a Mac with Xcode).
- Urdu translation (Flutter `intl` / ARB files).
- Dispute review screen for admins; notifications (trip confirmed, payment pending, trip cancelled).
- Repeating trips: create one trip per day automatically instead of one trip with a repeat label.

---

## Setup notes from tonight

- Flutter 3.47.8 (stable) cloned to `D:\dev\flutter`; `D:\dev\flutter\bin` added to the **user** PATH (no admin needed).
- Git was installed but not on the PATH, so `C:\Program Files\Git\cmd` was added to the user PATH too (Flutter needs git).
- `flutter config --enable-web` done. `flutter doctor`: Flutter ✓, Chrome ✓. Android toolchain ✗ and Visual Studio ✗
  are **expected** (not needed for the Chrome demo).
- Nothing failed to install.
