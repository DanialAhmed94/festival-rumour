# Festival tap navigation — production flow

This document defines the intended production behavior when a user taps a festival (slider, search, or similar). **Implementation status:** Layers **1–F**, **A–E**, **H** and the shared gate/outcome helpers are **shipped** in the codebase (see [Implementation file map](#implementation-file-map)). **Layer G** remains **partial**: today you only get **debug logging**; a full **[Layer G roadmap](#layer-g--observability-partial)** defines suggested **`festival_gate_*`** events, **failure buckets**, and **retry metrics** for production monitoring. Table and priority sections mix **live spec** with **historical tracking** notes.

---

## Implementation status (update after each merged step)

| Step | Scope | Status |
|------|--------|--------|
| **LAYER 1** | Wait for auth stabilization + null `currentUser` retry (once, 100–300 ms) before phone/profile checks | Done — [`ProfileReadinessService._resolveAuthUserStable`] |
| **LAYER 2** | Firestore profile fetch + `doc == null` retry (once, short delay) on festival tap — document creation race | Done — sequential reads + `_docRaceDelay` in gate |
| **LAYER 3** | OTP / `savePhoneToFirestore`: **never** silently ignore failure; Option A UX (block + retry) | Done — [`OtpViewModel.verifyCode`] from-festival path |
| **LAYER 4** | Lightweight local cache (`hasPhoneVerified` / profile-complete flag via SharedPreferences / existing storage) | Done — [`StorageService`] gate keys + parity |
| Follow-up | `navigateToHome` reads cache first → Firestore only when invalid / missing cache; separate **Firestore error** vs **missing phone** UX | Done — gate fast path vs outcomes |
| **LAYER A** | **Centralized gate** — single `ProfileReadinessService` / `FestivalNavigationGuard` used by festival + View All + Discover + profile→NavBar | Done — Discover in-Nav stays selection-only; slider / View All / profile list use gate |
| **LAYER B** | **Typed outcomes** (`authenticatedPhoneReady`, `firestoreUnavailable`, `needsPhoneEnrollment`, `authTransientlyNull`) — no OTP on transient failure | Done — [`lib/core/models/festival_navigation_gate_outcome.dart`] + [`lib/core/navigation/apply_festival_navbar_gate_outcome.dart`] |
| **LAYER C** | Auth wait: **`authStateChanges()`** one-shot + timeout; still **bounded delays** if user still null | Done — `authStateChanges().first.timeout` + short delay retries in [`ProfileReadinessService`] (no `idTokenChanges` yet) |
| **LAYER D** | Firestore **`GetOptions`** — intentional first vs retry read (`serverAndCache` then `server` on retry when doc suspicious) | Done — [`ProfileReadinessService`] + [`FirestoreService.getUserData`] |
| **LAYER E** | Post-OTP: **read-back** `users/{uid}` after write; assert `phoneNumber` before local flag + `navigateTo(festivals)` | Done — [`OtpViewModel`] server read-back + `persistPhoneVerificationForUser` |
| **LAYER F** | Cache hygiene: schema version + timestamp keys; **clear gate cache on sign-out** | Done — [`StorageService`] gate keys (`gate_phone_*`, schema `1`); [`AuthService.signOut`] calls `clearPhoneVerificationGateCache` after auth sign-out succeeds |
| **LAYER G** | **Observability** — analytics / failure buckets / retry metrics (no PII) | Partial — see [Layer G — Observability](#layer-g--observability-partial); debug logging today; Firebase Analytics–style names below |
| **LAYER H** | **Tap UX** — disable / loading on card while gate runs | Done — [`navbarGateBusy`] + `AbsorbPointer` on festival sliders / View All list |
| **Infra (optional)** | Backend / Rules: discourage partial `users/` docs without required verification fields | 🔲 Deferred / product |

---

## Correct production flow (when user taps a festival)

### Step 1 — Auth stabilization

- **Baseline (Layer 1):** Wait briefly, e.g. **100–300 ms**, before treating auth as finalized for this tap.
- **Only if** `currentUser == null` **after that wait**, **retry once** (same minimal delay is acceptable).
- Rationale: avoid racing Firebase Auth restoration (notably iOS lifecycle).

**Refinement (Layer C — preferred over blind sleep alone)**

- Implemented path uses **`authStateChanges().first`** with **timeout (~430 ms)** plus short baseline/retry delays (see **`ProfileReadinessService._resolveAuthUserStable`**). Optionally add **`idTokenChanges()`** the same way for parity with older doc text.

Constraints:

- One retry max for null user after the stabilization attempt.
- Only on navigation tap — not global polling.
- **Do not attach long-lived** `listen`; **one-shot/firstWhere + timeout** only (see **[Layers A–H](#enhanced-practices-layers-ah--infra)** — Layer C).

### Step 2 — Firestore profile

- Fetch Firestore profile (`users/{uid}`).
- If **`doc` is null / does not exist**:
  - **Retry once** after a short delay (**Layer 2**).
  - Reason: common **document creation race** after sign-in/onboarding merges.
- **Layer D:** Optionally second `get(Source.server)` on that retry path when the first snapshot is **`!exists`** or suspicious — reduces reliance on stale cache edges (SDK-default semantics apply to first read).
- **Why one retry is production-safe:** single retry, tiny delay, only at tap-time, no perpetual listeners — common in large apps.

---

## Layer 3 — Never silently ignore Firestore save failure (fixed in app)

### Current dangerous pattern

```text
try {
  await savePhoneToFirestore(...)
} catch (_) {}

navigateTo(festivals);
```

This corrupts apparent app state: user looks fully onboarded while **`phoneNumber` was never persisted**.

### Correct production behavior

If save **fails**:

- **Do not** continue silently.

**Option A (recommended — BEST)**

- Block navigation with a clear message, e.g.  
  `"Could not complete verification. Please try again."`
- Offer **retry**.

**Option B**

- Queue local retry before entering app — more complex.

**Recommendation:** Option A — simple and reliable.

---

## Layer 4 — Lightweight local profile cache (HIGHLY RECOMMENDED)

### Current issue

Every festival tap depends on a **live Firestore read**:

- Higher latency  
- Race conditions  
- Offline  
- iOS lifecycle timing quirks  

### Target architecture

After **successful onboarding** (OTP path where phone is persisted):

1. Firestore save **succeeds**  
2. **Local cache updated** (`hasPhoneNumber` / `profileCompleteVerified` — exact key TBD during implementation; use **SharedPreferences**, **Hive**, or **secure storage** consistent with codebase)  
3. **Then** navigate to festivals  

### On festival tap (fast path)

1. Check **local cache first**  
2. If cache says profile/phone verified → navigate to app (**NavBar**) **immediately**  
3. Optional: refresh Firestore in background for sync  

If **local cache is missing or invalid**:

1. Fetch Firestore profile (with Layer 2 retry behavior)  
2. If Firestore **temporarily fails** → loading / retry UI — **not** automatic OTP unless we genuinely know phone is absent after successful read  

### Why this matters

Firestore remains **source of truth**, but ceases being the **only critical navigation blocker** on every tap.

Benefits:

- Fewer random OTP redirects  
- Safer iOS timing  
- Fewer Firestore reads  
- Better offline UX  
- Faster navigation  

Constraints:

- No **long-lived** stream subscriptions for this gate (one-shot + timeout OK — see Layer C).  
- No massive state-management rewrite  

---

## Enhanced practices (Layers A–H + infra)

Most of this is **implemented**; see the [status table](#implementation-status-update-after-each-merged-step) and [file map](#implementation-file-map). **Layer G**: debug logs today — see [Layer G — Observability](#layer-g--observability-partial) for **`festival_gate_firestore_unavailable`**, **`festival_gate_needs_phone`**, **`festival_gate_auth_retry_success`**, buckets, and retry parameters.

### Layer A — Centralized gate API (implemented)

- **`ProfileReadinessService.evaluateFestivalNavbarGate()`** — `lib/core/services/profile_readiness_service.dart`.
- **Entry points:** `FestivalViewModel.navigateToHome`, `ViewAllFestivalsViewModel.navigateToHome`, `AppRouter` **profile list** (`ProfileListView` festival taps), `NavBaar` **Festivals / Attended** profile sub-tabs (`ProfileListView` + `applyFestivalNavbarGateOutcome`).
- **Out of scope for gate-on-tap:** `DiscoverViewModel.selectFestival` — only updates `FestivalProvider` while already inside NavBar (no duplicate NavBar push).

### Layer B — Typed outcomes (implemented)

Enum **`FestivalNavigationGateOutcome`** — `lib/core/models/festival_navigation_gate_outcome.dart`. Shared UI handling — `lib/core/navigation/apply_festival_navbar_gate_outcome.dart` (uses route `'/signup'`, aligned with `AppRoutes.signup`).

| Outcome | User-facing |
|--------|-------------|
| `authenticatedPhoneReady` | Navigate to **`navbaar`** |
| `firestoreUnavailable` | Error snackbar — **never** OTP from this outcome |
| `authTransientlyNull` | Warning snackbar — **never** OTP from this outcome |
| `needsPhoneEnrollment` | Push **`signup`** with phone flow (`arguments: true`) |

Only **`needsPhoneEnrollment`** routes to signup/verify from the gate.

### Layer C — Auth stream wait (implemented)

- **`authStateChanges().first`** with **timeout**, then short **delay retries** + `currentUser` checks — see `ProfileReadinessService._resolveAuthUserStable`. **`idTokenChanges`** is **not** wired yet (optional future supplement).


### Layer D — Firestore `GetOptions` (implemented)

- **`FirestoreService.getUserData(userId, {Source? source})`** passes through `GetOptions` when `source` is set.
- Gate uses default read first, then **`Source.serverAndCache`** and **`Source.server`** after delays when `phoneNumber` still missing (`ProfileReadinessService`).

### Layer E — OTP path: transactional read-back (implemented)

After **`savePhoneToFirestore`** succeeds (no silent swallow) in **`OtpViewModel.verifyCode`** (`fromFestival == true`):

1. **`getUserData(uid, source: Source.server)`** on `users/{uid}`.  
2. **Require** non-empty **`phoneNumber`** before **`persistPhoneVerificationForUser`** and **`navigateTo(festivals)`**.  
3. On save failure or read-back failure → **`NavigationService.showSnackbar`** (Option A — **Layer 3**); do not navigate into app with a phantom verified state.

Costs one cheap read once per verification; catches partial writes / rules bugs early.

### Layer F — Cache hygiene (implemented)

- **`StorageService`**: `gate_phone_profile_schema_version`, `gate_phone_verified_uid`, `gate_phone_verified_at_iso` (schema version **1**). Methods: `setPhoneVerificationGateCache`, `clearPhoneVerificationGateCache`, parity check `isPhoneVerificationCachedForUser`.
- **`AuthService.signOut`**: after successful Firebase + Google sign-out, calls **`clearPhoneVerificationGateCache`**.
- **`StorageService.clearAll`** also removes gate keys (see implementation).

### Layer G — Observability (partial)

**Today:** debug **`print`** / **`ProfileReadinessService._gateLog`** (`🎯 [festival_gate_outcome] …`) — mirrors outcome paths but does not populate dashboards.

**Production goal:** measure **real-world failure rates**, **retry effectiveness**, and **which branch** users hit — without raw phone/email/UID (optional: hashed UID only if policy allows).

---

#### Event naming convention

Use a stable prefix **`festival_gate_`** (+ outcome or phase). Prefer **Firebase Analytics–safe** names: lowercase **`snake_case`**, ≤40 chars each segment, avoid dynamic user strings in the event **name**.

**Examples (recommended):**

| Event name | When to fire | Notes |
|-------------|---------------|-------|
| `festival_gate_evaluate_start` | Each tap invokes the gate (`evaluateFestivalNavbarGate` entry) | Optional `source` param: `festival_slider`, `view_all`, `profile_list`, `navbar_profile_festivals` |
| `festival_gate_cached_hit` | Fast path — local parity cache says phone verified | High volume when healthy |
| `festival_gate_firestore_miss_after_retry` | Phone field still missing after delayed + `serverAndCache`/`server` reads | Surrogate for doc race vs truly missing profile |
| `festival_gate_firestore_unavailable` | Gate returns **`firestoreUnavailable`** (exception / unreachable read) | **Failure bucket**: infra / connectivity |
| `festival_gate_needs_phone` | Gate returns **`needsPhoneEnrollment`** | **Failure bucket**: product / onboarding gap (not transient) |
| `festival_gate_auth_null_after_stabilization` | Gate returns **`authTransientlyNull`** after stream wait + delays | **Failure bucket**: auth lifecycle / timing |
| `festival_gate_navbar_allowed` | Outcome **`authenticatedPhoneReady`** → NavBar navigation runs | Success funnel anchor |
| `festival_gate_signup_redirect` | Outcome **`needsPhoneEnrollment`** → signup route pushed | Count “forced enrollment” taps |
| `festival_gate_auth_retry_success` | Optional: **`currentUser`** became non-null only after delayed retry path (not on first peek) | Proves stabilization retries help |

You can consolidate some of the above into **one** event `festival_gate_outcome` with parameter **`result`** = enum string (`cached_hit`, `firestore_unavailable`, `needs_phone`, `auth_null`, `navbar_allowed`, …) if your analytics UX prefers fewer event types — the **names above** map 1:1 to those **`result`** values for dashboards.

---

#### Failure buckets (for dashboards)

Group parameters or derived charts so teams can separate **whose problem** it is:

| Bucket | Typical `result` / events | Interpretation |
|--------|---------------------------|----------------|
| **Transient / infra** | `festival_gate_firestore_unavailable`, flaky `evaluate_start` → error | Retry UX, quotas, offline — not “missing phone”. |
| **Auth timing** | `festival_gate_auth_null_after_stabilization` | iOS resume, cold start — tune timeouts or retries. |
| **Product / data** | `festival_gate_needs_phone`, `festival_gate_signup_redirect` | True enrollment gap vs Firestore content. |
| **Success** | `festival_gate_cached_hit`, `festival_gate_navbar_allowed` | Healthy path share and latency proxies. |

---

#### Retry metrics (recommended parameters)

Instrument **counts and stages**, not stack traces:

- **Auth phase:** integer **`auth_attempt_index`** — `1` first `currentUser` / stream result, `2` after first delay, `3` after second (match `ProfileReadinessService` semantics). Tracks **`festival_gate_auth_retry_success`** vs **`auth_null_after_stabilization`** ratio.
- **Firestore phase:** integer **`profile_read_generation`** — `1` default `get`, `2` post–`_docRaceDelay` retry, `3` subsequent `serverAndCache`, `4` `server`-only retry (align names to implementation when wiring). Helps answer “do retries recover users?” without logging doc paths.
- **Optional:** **`gate_duration_ms`** (timer from `evaluate_start` to outcome) — p50/p95 for “tap feels stuck” regressions.

**Do not send:** raw `phoneNumber`, email, display name, or full **`uid`** unless hashed and approved.

---

#### Implementation hint

Single choke point **`ProfileReadinessService.evaluateFestivalNavbarGate`** (plus optional **`applyFestivalNavbarGateOutcome`** for UI-only redirects) keeps one place to attach **`FirebaseAnalytics.instance.logEvent(...)`** (or your wrapper) when ready.

### Layer H — Tap UX (implemented)

- **`navbarGateBusy`** on `FestivalViewModel` / `ViewAllFestivalsViewModel` with **`AbsorbPointer`** on the festival slider and View All list while the gate runs. Taps use async navigation without blocking the UI thread.

### Infra (optional, product/backend)

- Strengthen **`users`** creation contracts: Cloud Function or rules so “complete signup” docs **cannot** omit verification fields unintentionally — reduces malformed profiles at source.

---

## Recommended final architecture (summary)

```text
On successful OTP save
  Firestore write succeeds (Layer 3 — no swallow)
    → READ-BACK confirms phone on doc (Layer E)
    → local cache updated (Layer 4 / F)
    → enter festivals

On festival tap
  check local cache
    → if valid → enter app instantly
    → optionally background-sync Firestore later

If local cache missing / stale
    → fetch Firestore (with one retry if doc missing)
    → if transient Firestore failure → retry / loading (NOT assume OTP)

If authoritative read confirms no phone → then signup/verify flow
```

### Production-grade checklist (why)

- Eliminates random OTP redirects when state is consistent  
- Handles iOS auth timing safely  
- Reduces Firestore dependency on hot path  
- Better offline behavior  
- Lower read cost  
- Faster festival navigation  
- No leak-prone **long-lived** listeners for this (**one-shot** timeout streams OK)

---

## What NOT to do

| Don’t | Do instead |
|-------|-------------|
| Retry forever | **One retry** only (per concern: auth null, missing doc) |
| Long-lived **`listen`** subscriptions for readiness | **`get`** + optional second `get`; or **one-shot** `first`/`firstWhere` + **timeout**, then dispose |
| Full app state rewrite | Central **service/guard** (Layer A); keep UI thin |

---

## Priority (execution order)

Items **1–8** below are addressed in code except **analytics (item 7 / Layer G)**, which is still partial. Item **9** remains product/backend.

### MUST DO

1. Stop silent Firestore failure after OTP (**Layer 3 / Option A**).  
2. Separate **transient Firestore/network failure** vs **confirmed missing phone** — ideally via **typed outcomes** (**Layer B**).  
3. Add bounded auth stabilization (**Layers 1 + C**) and **`doc == null`** retry (**Layers 2 + D**).

### HIGHLY RECOMMENDED

4. Local **profile-complete / phone-verified flag** + sign-out clears (**Layers 4 + F**).  
5. Central **`ProfileReadinessService` / gate** (**Layer A**).  
6. OTP **read-back** after successful write (**Layer E**).

### SHOULD DO

7. **Layer G** analytics: **`festival_gate_*`** events, **failure buckets**, **retry parameters** (`auth_attempt_index`, `profile_read_generation`, optional `gate_duration_ms`) — see [Layer G](#layer-g--observability-partial).
8. **Loading/disable tap** while gate runs (**Layer H**).

### INFRA / PRODUCT (optional)

9. Tighten **`users`** schema / Functions / Rules so incomplete profiles cannot ship (**Infra row**).

---

## Implementation file map

| Area | Path(s) |
|------|---------|
| Gate + cache write | `lib/core/services/profile_readiness_service.dart` |
| Outcome enum | `lib/core/models/festival_navigation_gate_outcome.dart` |
| Snackbar + navigate from outcome | `lib/core/navigation/apply_festival_navbar_gate_outcome.dart` |
| DI | `lib/core/di/locator.dart` — `ProfileReadinessService` |
| Firestore `GetOptions` | `lib/core/services/firestore_service.dart` — `getUserData(..., source:)` |
| Prefs / gate keys | `lib/core/services/storage_service.dart` |
| Profile list → NavBar | `lib/core/router/app_router.dart` — `ProfileListView` + `onFestivalSelected` |
| NavBar profile festivals | `lib/ui/views/navbar/navbaar.dart` — `ProfileListView` festivals/attended |
| Festival / View All | `lib/ui/views/festival/festival_view_model.dart`, `festival_view.dart`, `view_all_festivals_view_model.dart`, `view_all_festivals_view.dart` |
| OTP festival link | `lib/ui/views/otp/opt_view_model.dart` — `fromFestival` path |
| Post–interests signup | `lib/ui/views/interest/interests_view_model.dart` — `persistPhoneVerificationForUser` when phone saved |
| Sign-out cache clear | `lib/core/services/auth_service.dart` — `signOut` |
| Strings | `lib/core/constants/app_strings.dart` — gate/OTP related messages |
| Analytics (**Layer G**, not wired) | Recommended choke point: `lib/core/services/profile_readiness_service.dart` |

**Discover:** `lib/ui/views/discover/discover_viewmodel.dart` — festival **selection** only (no gate); user is already on NavBar.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-05-08 (initial) | Doc created — implementation not started |
| 2026-05-08 (follow-up) | Added Layers **A–H**, infra notes, **[Step 1](#step-1--auth-stabilization)** Layer C refinement, **[Step 2](#step-2--firestore-profile)** Layer D `GetOptions`, **[Enhanced practices](#enhanced-practices-layers-ah--infra)** full section, OTP **read-back** in architecture diagram, tightened “What NOT to do”, rebuilt priorities (**MUST / HIGHLY / SHOULD / INFRA**), tracker rows, expanded files list |
| 2026-05-11 | **Layer G** expanded: `festival_gate_*` example events (**`firestore_unavailable`**, **`needs_phone`**, **`auth_retry_success`**, …), **failure buckets** for dashboards, **retry metrics** (auth attempts, Firestore read generation, duration). |
