# 📋 Festival Rumour — Project Progress Log

> **This file is the heart of the project.** Every meaningful change, fix, decision, and milestone gets recorded here so the full journey stays traceable. Newest entries go at the top of the Journal.

---

## 🧭 Project Snapshot

| | |
|---|---|
| **App name** | Festival Rumour (display name "Festival App") |
| **Type** | Flutter festival social network |
| **Version** | 1.0.2+6 |
| **Real project path** | `/Users/faisaliqbal/Desktop/AndroidStudioProjects/Client James/fASourceCode` |
| **iOS bundle id** | `com.festival.rumour` |
| **Android applicationId** | `com.festival_rumour` |
| **App Store Connect app** | 6753773348 |
| **Backend** | Firebase (Auth, Firestore, Storage, Messaging, App Check) + REST festival catalog |
| **Flutter SDK** | 3.35.7 stable @ `~/development/flutter/bin` (not in PATH) |

---

## ✅ Current Status

- [x] Project cloned and build environment set up
- [x] Runs on Android emulator
- [x] Runs on iOS simulator
- [x] Full codebase + docs understood and mapped
- [x] **Referral Reward System — code complete** (compiles; backend/rules/hosting NOT yet deployed)

---

## ⚠️ Open Items / Known Blockers

These are tracked but NOT yet fixed (see release notes):

- **iOS push entitlement** — `ios/Runner/Runner.entitlements` is `aps-environment = development`; must be `production` for App Store/TestFlight push.
- **Staging REST URLs** — `ApiConfig.baseUrl`/`imageBaseUrl` point at `stagingcrapadvisor.semicolonstech.com`; swap to prod before release.
- **Cloud Function URLs** — hardcoded to Firebase project `crapapps-65472`; confirm they match the intended live project.
- **Security debt** — wide-open Firestore rules; unsalted SHA-256 passwords in Firestore; `sendNotification` doesn't verify its Bearer token; committed secrets (Maps API key, `key.properties`).
- **Subscription** — non-functional stub (no billing SDK).

### Referral system — deploy status
- **Backend functions — DEPLOYED** ✅ (2026-06-14) to `crapapps-65472`: `getOrCreateReferralCode`, `redeemReferral`, `expirePioneerBadges` live (Cloud Scheduler API auto-enabled).
- **Hosting — DEPLOYED** ✅ invite page live at `https://crapapps-65472.web.app/invite/<CODE>`.
- **Rules + indexes — NOT deployed yet** — `firebase deploy --only firestore:rules,firestore:indexes`. ⚠️ The new `firestore.rules` tightens reward fields by narrowing the wildcard to per-collection — **test in the Firestore emulator first** (production is shared by multiple apps; a rules mistake breaks live users). The new index powers the badge-expiry sweep. Until deployed, reward fields are client-writable (no worse than today's wide-open rules).
- **Invite domain — DONE** ✅ now `https://thefestivalapps.com/invite/` (hosted on **Hostinger**, files in repo `hostinger_invite/` → uploaded to `public_html/invite/` with an `.htaccess` rewrite). Kept in sync across 3 places: `functions/index.js` `INVITE_BASE_URL`, `lib/core/constants/app_strings.dart` `inviteDomainBaseUrl`, `ReferralService.inviteBaseUrl`. (The Firebase `crapapps-65472.web.app/invite/` page still works as a fallback.)
- **Debug Google Sign-In** — registered this Mac's debug keystore SHA-1/SHA-256 with the Firebase Android app so debug builds can use Google Sign-In on devices (production release SHA was already registered).
- **iOS auto-attribution (future)** — manual code entry is the live path; Universal Links (via `appAssociation:AUTO` in firebase.json) is the recommended fast-follow to skip manual entry on iOS.

---

## 📓 Journal

### 2026-06-25 — Festival listing invite reworked to a full screen + richer email subject
The bottom-sheet/dialog for "festival not found → invite the organiser" never reliably appeared on the user's device (overlay/modal layer issue we couldn't pin down; the Samsung device filters Flutter logcat so we couldn't trace it). Per the user's decision, replaced it with a **dedicated full-screen route** — bulletproof, always renders.
- New screen [festival_listing_invite_view.dart](lib/ui/views/festival/festival_listing_invite_view.dart): pink AppBar, message (with the searched festival name), required email field, Send Invite button (loading + validation). Pushed via `Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(...))` from BOTH search empty states ([festival_view.dart](lib/ui/views/festival/festival_view.dart), [view_all_festivals_view.dart](lib/ui/views/festival/view_all_festivals_view.dart)). Deleted the old `festival_not_found_invite_dialog.dart`.
- **Email now carries the searched festival name + the requesting user's name in the SUBJECT** (and body). Backend `buildListingInviteEmail` takes `inviterName`; `sendOrganiserInvite` listing subject = `"{inviter} wants to list \"{festival}\" on The Festival App"`. Client `OrganiserInviteService.sendFestivalListingInvite` gains `inviterName` (from `FirebaseAuth.currentUser.displayName`). Backend **deployed** (2026-06-25).
- 0 analyzer errors. Built + installed fresh debug APK on the device for testing.

### 2026-06-25 — Invite-organiser sheet not opening on All Festivals (hardening)
Reported: tapping "Invite the organiser" in the All-Festivals (`view_all_festivals_view`) not-found state did nothing — the bottom sheet didn't appear. Code was already correct (inline panel, valid context, identical to the home screen), so the prime suspect is a **stale incremental Android build** (known issue in this project). Hardened the trigger in [festival_not_found_invite_dialog.dart](lib/ui/views/festival/festival_not_found_invite_dialog.dart) regardless: removed the pre-`unfocus()` (potential rebuild race that could drop the button's context before the sheet mounts), added `useRootNavigator: true` (sheet always sits above the whole screen), and a `debugPrint('[INVITE] …tapped')` so a fresh build + `adb logcat | grep INVITE` confirms whether the tap fires. Needs a **fully fresh** Android build to test.

### 2026-06-25 — ✅ Uploaded to TestFlight: 1.0.3 (8)
**The Festival App 1.0.3 (8) successfully uploaded to App Store Connect** (Organizer → Distribute → App Store Connect). Now processing on Apple's side (~5–30 min) → then appears under the app's TestFlight tab to assign to testers. Two blockers were resolved along the way:
1. **Apple PLA** — the account holder (Peter James Hughes) accepted the updated Program License Agreement, which unfroze the iOS Distribution certificate (automatic signing then created it).
2. **Version train closed** — Apple rejected `1.0.2 (7)` with *"train version 1.0.2 is closed for new build submissions; CFBundleShortVersionString must be higher than the approved 1.0.2."* So bumped the **marketing version to `1.0.3`** (`pubspec` → `1.0.3+8`), re-archived, and uploaded. Lesson: once a marketing version is approved on the store, the next upload needs a higher version, not just a higher build number.

### 2026-06-25 — TestFlight prep: version 1.0.2+7
Prepping an iOS TestFlight upload (App Store Connect app 6753773348, team TM5435KU6D, bundle `com.festival.rumour`):
- **Version bumped** `1.0.2+6` → **`1.0.2+7`** in [pubspec.yaml](pubspec.yaml); regenerated `ios/Flutter/Generated.xcconfig` (`FLUTTER_BUILD_NUMBER=7`) via `flutter build ios --config-only`. Info.plist already uses `$(FLUTTER_BUILD_NAME)`/`$(FLUTTER_BUILD_NUMBER)`.
- **CocoaPods:** `pod` is broken (Homebrew Ruby 4.0.3 can't find the cocoapods gem) and `ios/Pods/Manifest.lock` was missing → Xcode's "Check Pods Manifest.lock" would fail the archive. Restored it with `cp ios/Podfile.lock ios/Pods/Manifest.lock` (valid: Pods already installed, no iOS deps changed this session). Sync check now passes without needing `pod install`.
- **Push entitlement:** `ios/Runner/Runner.entitlements` `aps-environment` `development` → **`production`** (correct for TestFlight/App Store; avoids the known upload-validation rejection). Note: debug-build push now uses production APNs; revert to `development` for local push debugging if needed.
- Upload itself is done by the user in Xcode (Archive → Distribute → App Store Connect) — needs their Apple ID auth.

### 2026-06-25 — Interests screen: referral-code field made prominent
The "Have a referral code? (optional)" field on the Interests/onboarding screen was muted grey text at the bottom and easy to miss. Restyled `_buildReferralField` in [interests_view.dart](lib/ui/views/interest/interests_view.dart) as a **brand-pink card** (`#FC2E95`, matching the screen title): pink-tinted background, pink border, a gift icon, a bold pink label (`TextType.subtitle`), and a white input with pink focus border. Flutter-only, 0 analyzer errors.

### 2026-06-21 — Fix: "Invite the organiser" opened a blank dimmed screen
**Bug:** tapping **Invite the organiser** in the festival search not-found state dimmed the screen (barrier) but showed no form. **Cause:** it opened an `AlertDialog`/`Dialog` while the **search keyboard was still up** (the button never unfocused, unlike the result-item taps). A `Dialog` containing a `TextField`, opened over the keyboard, collapsed to an empty box. (The app's other working dialogs have no text field / open with the keyboard down.)
**Fix:** rewrote [festival_not_found_invite_dialog.dart](lib/ui/views/festival/festival_not_found_invite_dialog.dart) — `showFestivalNotFoundInviteDialog()` now drops the keyboard first (`FocusManager…unfocus()`) and presents a **`showModalBottomSheet`** (the app's standard form pattern): `isScrollControlled`, bottom padding = `MediaQuery.viewInsetsOf().bottom` (sits above the keyboard), `SingleChildScrollView` (can't collapse/overflow), drag handle, autofocused email field. Same content/logic (empty → close, filled → send listing invite, success/fail snackbar). Callers unchanged (same function name). Flutter-only, 0 analyzer errors.

### 2026-06-21 — Create Post: "Send invite" button (invite without posting)
Added a **Send Invite** button inside the Tag Festival Organiser card so the user can email the organiser the join invite **without creating a post**. Reuses the existing (already-deployed) `sendOrganiserInvite` flow — no backend change.
- [create_post_view_model.dart](lib/ui/views/create_post/create_post_view_model.dart): new `sendOrganiserInviteNow()` (reads `festivalOrganiserEmailController`; empty → no-op; sends via `OrganiserInviteService.sendOrganiserInvite` with the inviter's name; clears the field on success) + `sendingInvite` loading flag. The existing on-upload invite behaviour is unchanged.
- [create_post_view.dart](lib/ui/views/create_post/create_post_view.dart): right-aligned `TextButton.icon` ("Send Invite", send icon, spinner while sending) in `_buildOrganiserEmailCard`; empty email → snackbar prompt; result → success/failure snackbar.
- Flutter-only, 0 analyzer errors.

### 2026-06-21 — Fix: tapping a festival opened the "verify contact" form
**Bug:** tapping a festival (search result or card/list item) sometimes opened the phone-verification form (`/signup` with `fromFestival:true`, shown as "Verify Contact") instead of the festival detail/home. **Cause:** `navigateToHome()` ran `ProfileReadinessService.evaluateFestivalNavbarGate()`; for accounts without a `phoneNumber` (e.g. Gmail logins) it returned `needsPhoneEnrollment` → routed to signup.
**Fix:** removed the phone-verification gate from festival selection in both [festival_view_model.dart](lib/ui/views/festival/festival_view_model.dart) and [view_all_festivals_view_model.dart](lib/ui/views/festival/view_all_festivals_view_model.dart) — `navigateToHome()` now sets the selected festival and navigates **directly to `AppRoutes.navbaar`** (NavBaar → DiscoverView: Location & map, Stage Times, Inner Map, Chat Rooms). Removed the now-unused `ProfileReadinessService` / `applyFestivalNavbarGateOutcome` imports. `navbarGateBusy` getter kept (still read by an `AbsorbPointer`; now always false). Flutter-only, 0 analyzer errors, no backend/deploy change.
- ⚠️ Note: this means browsing a festival no longer forces phone enrollment. The normal signup OTP flow still verifies phone. If phone verification should be enforced elsewhere, say so and I'll scope it.

### 2026-06-21 — Festival search "not found" → invite organiser to list it
When a festival search returns no results, the empty state now offers an **"Invite the organiser"** button that opens a form (optional email field). If an email is entered, we email that organiser asking them to list the festival. Backend reuses the `sendOrganiserInvite` SMTP function with a new `listing` variant.
- Backend ([functions/index.js](functions/index.js)): added `buildListingInviteEmail({festivalName})` (leads with **Festival Organiser** app links, then The Festival App / Toilet / Foodie) and a `body.inviteType === "listing"` branch in `sendOrganiserInvite` (subject "A festival listing request via The Festival App"). Default path unchanged → Create Post "Tag" invite still works. **Deployed.**
- Client service ([organiser_invite_service.dart](lib/core/services/organiser_invite_service.dart)): added `sendFestivalListingInvite({organiserEmail, festivalName})` (posts `inviteType:"listing"`); refactored to a shared private `_send`.
- UI: new reusable [festival_not_found_invite_dialog.dart](lib/ui/views/festival/festival_not_found_invite_dialog.dart) (`showFestivalNotFoundInviteDialog(context, festivalName:)`) — message + optional email field (Tag-Organiser style) + Send Invite. Wired into the empty state of **both** search screens ([festival_view.dart](lib/ui/views/festival/festival_view.dart) home + [view_all_festivals_view.dart](lib/ui/views/festival/view_all_festivals_view.dart)). Search itself is unchanged (REST `/getfestival?search=`; not-found = empty `searchResults`).
- **Rule:** email empty → dialog just closes, no email; email filled → invite sent with the searched festival name.

### 2026-06-21 — Welcome email reworked: every Gmail/Apple login (client-driven)
**Revised** the welcome email (see prior entry): the requirement is a greeting on **every** Google/Apple login (not only first signup), which a Firestore `onCreate` trigger can't detect. Switched to **client-driven**:
- Backend: replaced the `onDocumentCreated` trigger with an authenticated HTTP **`sendWelcomeEmail`** function (derives recipient from the verified uid via `admin.auth().getUser`; optional `displayName` in body). Old trigger **deleted**. **Deployed & smoke-tested** (unauth → 401).
- Client ([welcome_view_model.dart](lib/ui/views/welcome/welcome_view_model.dart)): fire `WelcomeEmailService.sendWelcomeEmail()` after `signInWithCredential` in **both** `loginWithGoogle` and `loginWithApple` → covers every Gmail/Apple login (new + returning). New-email signup greeted once in [interests_view_model.dart](lib/ui/views/interest/interests_view_model.dart) (`!isOAuthFlow` guard, so OAuth users aren't double-emailed). Returning email login → no email. New service [welcome_email_service.dart](lib/core/services/welcome_email_service.dart).
- ⚠️ Needs a fresh APK to test (client changes).

### 2026-06-21 — Welcome email for new users (deployed & live)
New users get a one-time welcome email (from `info@thefestivalapps.com`) on their first signup — covers **email, Google, and Apple** uniformly. **Backend-only, zero Flutter changes.**

**Mechanism (chosen after exploring the auth flow):** a Firestore **`onDocumentCreated('users/{uid}')`** trigger — `exports.sendWelcomeEmailOnSignup` in [functions/index.js](functions/index.js). The user doc is created exactly once per new user via `FirestoreService.saveUserData()` (`merge:false`), and all three signup methods funnel through `interests_view_model.dart._createUserWithAllData()`. Returning logins only do `merge:true` FCM updates on an existing doc → no `onCreate` → **the email never re-sends** (satisfies "only on first signup/login"). Recipient = the doc's `email` field; personalised with `displayName`. Idempotency guard: sets `welcomeEmailSent`/`welcomeEmailSentAt` after sending; best-effort (errors logged, not thrown → no retry duplicates).
- Reuses the existing SMTP setup (nodemailer + `SMTP_*` secrets) and `FESTIVAL_APPS` links from the organiser-invite work. New `buildWelcomeEmail()` produces a short, emoji-led HTML+text body: greeting → welcome → pioneer/early-starter → help-shape-the-app → invite 25 festie besties → all 4 apps with Android+iOS links.
- **Deployed & live (2026-06-21):** `sendWelcomeEmailOnSignup` (us-central1, v2, trigger `…firestore.document.v1.created`). Note: Firestore DB is in **europe-west2**; function in us-central1 → supported cross-region trigger (deploy warns about the hop only; fires correctly).

**🧪 To verify:** sign up a brand-new account (email/Google/Apple) → the welcome email should arrive at that account's address (check spam). Existing users get nothing (correct). Logs: `firebase functions:log --only sendWelcomeEmailOnSignup`.

### 2026-06-20 — "Tag Festival Organiser" invite email on Create Post
New feature: a user can tag a festival organiser's email on the Create Post form; on submit we email that organiser an invite (from `info@thefestivalapps.com`). Code complete, `flutter analyze` clean (0 errors), Cloud Function syntax-checked (`node --check`), nodemailer installed. Reviewed by a 3-dimension adversarial workflow (Flutter / backend / deploy) — 18 findings raised, **0 confirmed** after skeptic verification. **Not built/installed**, and **functions NOT deployed** — see deploy + SMTP steps below.

**Part 1 — Flutter (Create Post):**
- New OPTIONAL email field "Tag Festival Organiser" with a headline ("Know a festival organiser? Add their email and we'll send them an invite…"), inserted after the URL card in [create_post_view.dart](lib/ui/views/create_post/create_post_view.dart) (`_buildOrganiserEmailCard`). Strings in [app_strings.dart](lib/core/constants/app_strings.dart) (`tagFestivalOrganiser*`).
- [create_post_view_model.dart](lib/ui/views/create_post/create_post_view_model.dart): added `festivalOrganiserEmailController` (disposed + cleared on reset). After `savePost()` succeeds, if the email is non-empty it fires `OrganiserInviteService.sendOrganiserInvite(...)` **fire-and-forget** (locals captured, no VM-state in callback) so a slow/failed email never blocks the post or the screen pop. **Rule:** empty → post only; filled → post + email.
- New client service [organiser_invite_service.dart](lib/core/services/organiser_invite_service.dart) — static, best-effort (returns false / never throws), POSTs `{organiserEmail, inviterName?}` with `Authorization: Bearer <idToken>` to `…cloudfunctions.net/sendOrganiserInvite` (mirrors `notification_service.dart`).

**Part 2 — Cloud Function + SMTP (`functions/`, codebase `default`):**
- Added `exports.sendOrganiserInvite` (v2 `onRequest`) in [functions/index.js](functions/index.js): CORS, POST-only, `verifyBearer` (auth required), email-format validation, sends via **nodemailer** SMTP from `info@thefestivalapps.com`.
- SMTP creds via v2 secrets `SMTP_HOST/PORT/USER/PASS` (`defineSecret` from `firebase-functions/params`, bound only to this function, read from `process.env`). Transport auto-selects SSL(465)/STARTTLS(587).
- Email body (HTML + plain-text) follows the exact spec order: greeting → company info → "a user asked you to register" → **The Festival App** links → **Festival Organiser** links → "suite of apps" line → **Festival Toilet** + **Festival Foodie** links (all 4 apps × Android+iOS, exact URLs).
- `nodemailer ^6.10.1` added to [functions/package.json](functions/package.json) + installed.

**✅ DEPLOYED & LIVE (2026-06-21):**
- Mailbox `info@thefestivalapps.com` confirmed working on Hostinger.
- Firebase secrets set: `SMTP_HOST=smtp.hostinger.com`, `SMTP_PORT=465`, `SMTP_USER=info@thefestivalapps.com`, `SMTP_PASS` (mailbox pw — set to `infoFestival@1234`; see caveat).
- Deployed: `sendOrganiserInvite` (us-central1) → `https://us-central1-crapapps-65472.cloudfunctions.net/sendOrganiserInvite`.
- Smoke test: unauthenticated POST → HTTP 401 `{"success":false,"error":"Missing or invalid Authorization header"}` (function live, auth works, no email sent).

**⚠️ Only check left — real end-to-end test:** submit a post with an organiser email from the app → confirm the invite arrives (check spam). This is the only step that validates the SMTP password. **Password caveat:** given as `infoFestival@1234` (deliberate) vs `nfoFestival@1234` (pasted, likely a dropped "i"); used `infoFestival@1234`. If the email doesn't arrive, re-set `SMTP_PASS` and redeploy. Logs: `firebase functions:log --only sendOrganiserInvite`.

### 2026-06-20 — Section renames + device-aware store links
Two-part change requested by the client. Code complete, `flutter analyze` clean (0 new errors), `flutter clean` + `pub get` done. **Not built/installed** — handed off for a fresh APK from Android Studio.

**A. Section renames (the "Detail" screen + Discover grid):**
- **"Detail" → "Stage Times & Running Orders"** — `DetailView` app-bar title (`detail_view.dart`) and the Discover grid tile (`AppStrings.detail`). To keep navigation working after the rename, the grid tile's nav was decoupled from its display text: `discover_view.dart` now calls `onNavigateToSub('detail')` via `onTap` instead of routing through `GridOption._handleNavigation`'s `case 'DETAIL'` title switch (which would otherwise have broken).
- **"WHERE THE BEATS DROP" → "What's On"** — `DetailView` card (was the "Where's The Beat" section).
- **"TOILET" → "Got To Go"** — `DetailView` card now shows a `Icons.wc` icon + "Got To Go" text (added an optional `icon` param to `_buildCard`). Also `AppStrings.toilets` "Toilets" → "Got To Go", which cascades to the toilet screen app-bar/section-header/card and the View-All tab.

**B. Device-aware store links (Android device → Google Play; iOS device → App Store):**
- Added `AppStrings.festivalRumourAppStoreUrl` (`https://apps.apple.com/us/app/the-festival-app/id6753773348`) + helper `festivalAppStoreUrl({required bool isIOS})`.
- `AppStrings.shareMessage` and `shareDiscoverInviteMessage` are now functions taking `{required bool isIOS}` so the embedded download link matches the sharer's OS. Callers updated: Settings `shareApp` (`settings_view_model.dart`, uses `Platform.isIOS`), Discover "Invite your festie bestie" (`discover_view.dart`, added `dart:io` import).
- Settings **Rate Us** (`rateApp`) iOS branch now opens the App Store URL instead of the Play Store URL (was a placeholder).
- Partner-app tiles (Festival Toilet / Organiser / Foodie) already selected store by OS via `openPartnerAppStore`/`_selectStoreUrl` — synced the three iOS URLs to the client's exact slugs (`festival-toilet-app/id6738211790`, `festival-organiser/id6686404949`, `festival-foodie/id6744639737`); Play Store IDs already matched.
- Referral invite link (`thefestivalapps.com/invite/...`) left as-is — it's a branded landing page that already redirects by device.

### 2026-06-14 — Chat keyboard smoothness: bottom-anchored reverse list
Root cause of the "UI hangs when keyboard opens": the message list was a FORWARD `ListView`, so the keyboard resize fought the scroll (and a forward list re-scrolls/jumps). Converted both chat lists to **`reverse: true`** (bottom-anchored, like WhatsApp/Telegram) — when the keyboard pushes up, the bottom stays pinned, nothing re-scrolls. Plan was produced + adversarially reviewed by a workflow before editing.
- `chat_view.dart` + `direct_chat_view.dart`: `reverse: true`, itemBuilder index inverted (`count-1-index`), older-page spinner moved to the visual top (`index == count`).
- `chat_view_model.dart`: `_handleScroll` thresholds flipped (load-older near `maxScrollExtent`, stick-to-bottom near `0`); removed the now-unneeded scroll-position-preservation snapshot + `jumpTo` in `loadOlderChatMessages` (reverse keeps the bottom anchored on prepend); stick-to-bottom `animateTo(0)`.
- Also wrapped `ChatComposer` in a `RepaintBoundary` so its shadow-heavy bar is cached + translated (not repainted) as the keyboard slides.
- 0 analyzer errors; `flutter clean` + `pub get` done.
- **⚠️ MUST device-test:** (1) scroll up to load older in BOTH a group room and a DM (no jump/refetch loop); (2) prepended older messages appear above, no jolt; (3) at bottom a new message scrolls into view, but when scrolled up reading history a new message does NOT yank you down. (Note: debug builds still animate the keyboard slower than release — but the list no longer fights it.)

### 2026-06-14 — Chat composer redesigned (shared widget) to match the design
Rebuilt the chat input bar to the provided design: one **cream pill** containing 📎 attach · **white rounded field with the 📷 camera inside on the right** · thin divider · 🎤 mic · divider · **pink-gradient send circle** (with glow). All icons brand pink; "Type something…" hint.
- **Extracted to a single shared widget** `lib/ui/views/chat/widgets/chat_composer.dart` (`ChatComposer(viewModel:)`), used by BOTH `chat_view.dart` (group/public) and `direct_chat_view.dart` (DMs). Deleted the duplicated per-view composer methods (`_buildInputSection/_buildComposerRow/_buildRecordingRow/_sendCircle/_on*Pressed/_handleSendMessage`) so the two screens can never drift again.
- Recording bar restyled to match (same cream pill). Upload progress bar kept above.
- 0 analyzer errors; `flutter clean` + `pub get` done.

### 2026-06-14 — Smooth app-startup cross-fade (no white flash)
`_AppRoot.build()` now wraps the boot → splash → app states in an `AnimatedSwitcher` (350ms cross-fade, wrapped in `Directionality` since it's above any MaterialApp). The pre-bootstrap placeholder is now a **branded cream screen with the app logo** (`_BrandedLoading`, `AppAssets.splashLogo`) instead of plain white — so returning users who skip the video fade smoothly into content with no white flash. Each state keyed via `KeyedSubtree`.

### 2026-06-14 — Intro splash video now first-launch only
The splash video (`assets/videos/Festival_Rumour.mp4`, with Skip button) used to play on EVERY launch. Now it plays **only on the very first launch**; returning users skip straight to their route.
- `StorageService.hasShownIntroVideo()/setIntroVideoShown()` (key `intro_video_shown`).
- `main.dart` `_AppRoot._bootstrap()`: if intro already shown → skip the video, compute route, finish; else mark shown + play it once. Refactored the pending-notification handling into `_handlePendingNotification()` shared by both paths. Notification cold-start path (main → `notificationLaunchRoute`) unchanged.
- Ran `flutter clean` + `pub get`.

### 2026-06-14 — One-time "Invite Friends" promo popup (code complete; ⚠️ assets needed)
Built the welcome reward popup (matches the provided design): gift hero, "Invite Friends, Earn Your Pioneer Badge!" headline, subtitle, gold 1-Year-Pioneer badge tile (star + lock), "x / 25 Friends Invited" progress, "SHARE YOUR CODE" button (shares the referral link), close X, footer.
- **File:** `lib/ui/views/invite/invite_promo_dialog.dart` (`showInvitePromoDialog`). Pulls code/count via `ReferralService`; shares via `Share.share`.
- **Shows once:** `StorageService.hasShownInvitePromo()/setInvitePromoShown()` (key `invite_promo_shown`). Triggered from `FestivalView.buildView` (the post-login landing / "home") via `_maybeShowInvitePromo` (static guard + postFrame). Never reappears after first show.
- **⚠️ Assets MISSING in this checkout:** `assets/images/gift.png` and `assets/svgs/friends_invited.svg` are NOT present (likely pasted into the wrong folder — project moved to `Client James/fASourceCode`). Code references those exact paths with safe fallbacks (🎁 emoji / `Icons.group`) so it won't crash, but drop the real files in for the intended look. `assets/images/` + `assets/svgs/` are already registered in pubspec, so no pubspec change needed.
- Ran `flutter clean` + `pub get` for a fresh Android Studio build.

### 2026-06-14 — Keyboard-open jank: diagnosed as debug-build artifact (structure is sound)
User reported the chat UI "slowly/laggily moves up" when the keyboard opens. Investigated the structure: both message lists are lazy `ListView.builder` (per-item `RepaintBoundary` + `ValueKey` + `cacheExtent`), the scroll handler is throttled and does NOT call `notifyListeners`, there's no keyboard observer/scroll-to-bottom animation fighting the resize, and opening the keyboard fires no `notifyListeners` (so `buildView`/the Consumer does not rebuild during the animation). Conclusion: **the structure is fine; the jank is debug-mode (JIT) overhead.** Built a **profile (AOT) APK** (`flutter build apk --profile` → `app-profile.apk`) and installed it to demonstrate true performance — keyboard/scroll are smooth in profile/release. (For shipping, release build behaves the same. `resizeToAvoidBottomInset` left at default true so the composer stays above the keyboard.)

### 2026-06-14 — Chat camera capture + performance pass (built, verified, installed ✅)
- **Camera (WhatsApp-style):** added a 📷 camera icon to the chat input in BOTH `chat_view.dart` + `direct_chat_view.dart`. Tap → bottom-sheet chooser (`widgets/camera_source_sheet.dart`, `CameraChoice.photo|video`) → `ChatViewModel.capturePhoto()` / `recordVideo()` (image_picker camera source) → reuses the preview → `sendMediaFiles` flow. Input icons made compact (40px) to fit camera + attach + mic + send.
- **Performance pass** (from a 3-agent chat audit workflow — applied the high-confidence/low-risk fixes; deferred the risky Consumer-scope refactor):
  - Audio: `stop()` before `dispose()` in `chat_audio_bubble.dart` (no background audio after leaving chat).
  - **Throttled upload-progress `notifyListeners` to ~10fps** (`chat_view_model.dart`) — was rebuilding the whole screen per Storage byte (main lag source during upload).
  - `memCacheWidth: 480` on chat grid thumbnails (`chat_media_grid.dart`) — avoids decoding full-res images.
  - DM list: added `RepaintBoundary` + `ValueKey` + `cacheExtent: 320` (matches `chat_view.dart`).
  - Share temp files now deleted after `Share.shareXFiles` (disk-leak fix).
  - Audit dropped 2 false-positive "bugs"; `notifyListeners`-after-dispose is already safe (BaseViewModel guards `_isDisposed`).

### 2026-06-14 — Chat media UI polish (built + installed on device ✅)
Fixed two issues found via on-device screenshot, in BOTH `chat_view.dart` and `direct_chat_view.dart`:
- Attach 📎 + mic 🎤 icons were `AppColors.white` → invisible on the cream chat background. Recolored to brand pink `0xFFFC2E95`.
- Recording row overflowed ("OVERFLOWED BY 25 PIXELS"): the "Recording… tap send to finish" label was too long for the pill. Shortened to "Recording…" and wrapped in `Expanded` + `TextOverflow.ellipsis`.
Clean rebuild (`BUILD_OK`) installed and launched on the device. (adb wireless pairing kept hitting a protocol-fault bug — retrying `adb pair` a few times succeeds; then `adb connect <ip>:<connect-port>` found via `adb mdns services`.)

### 2026-06-14 — Chat media messaging (WhatsApp-style) — built, verified, installed on device
Added multi-image/video + voice-note messaging to user chat. Build verified (APK kernel_blob actually contains the new code) and installed on the physical device for testing.
- **Decisions:** in-app voice recording (`record`), preview screen before sending, Post-to-Feed = own media only, one album bubble per multi-select.
- **Deps added:** `just_audio ^0.9.40` (playback), `record ^6.0.0` (voice notes — bumped from 5.x because `record 5.2.1` resolved an incompatible `record_linux 0.7.2`/`record_platform_interface 1.6.0` pair that failed the Dart kernel compile; 6.2.1 pulls `record_linux 1.3.1` and compiles clean). Skipped `video_thumbnail` (flaky native plugin) — video bubbles use a dark poster + play icon, full-screen via Chewie on tap.
- **⚠️ Build gotcha learned:** incremental `flutter build apk --debug` silently shipped a STALE kernel (old code) even after edits — every "successful" build until a `flutter clean` was old. After any dependency change OR if new code doesn't appear, run `flutter clean` and verify the APK with `unzip -p .../app-debug.apk assets/flutter_assets/kernel_blob.bin | strings | grep <new-string>`.
- **Model** (`chat_message_model.dart`): new `mediaUrls`/`isVideoList`/`audioDurationMs`/`thumbnailUrl`; types `media` + `audio`; getters `isMediaMessage`/`isAudioMessage`/`isVideoAtIndex`. Parser updated in `chat_view_model._mapRawToChatMessage`.
- **Backend**: `FirestoreService.sendChatMediaMessage(...)` (mirrors `sendChatMessage` + media fields). New shared `lib/core/services/media_upload_service.dart` (Storage upload, registered in locator). Storage path `chat_media/{roomId}/{images|videos|audio}/...`.
- **ViewModel**: `pickMedia()` (image_picker `pickMultipleMedia`), `sendMediaFiles()`, `startRecording/cancelRecording/stopAndSendRecording` (record), `postChatMediaToGlobalFeed()` (reuses `savePost` with existing URLs, own media only), `shareChatMedia()` (dio download → `Share.shareXFiles`).
- **UI**: input attach 📎 + mic buttons + recording row + upload progress bar; bubble renders `ChatMediaGrid` (album → full-screen via reused `PostMediaFullscreenPage`) / `ChatAudioBubble` (just_audio play/seek/duration); long-press sheet gains Share + Post to Global Feed alongside Delete. New widgets in `lib/ui/views/chat/widgets/`. **Applied to BOTH chat screens:** `chat_view.dart` (group/public rooms) AND `direct_chat_view.dart` (1:1 DMs) — they're separate views with duplicated UI but share `ChatViewModel`. (Easy to miss the DM view.)
- **Native perms**: Android `RECORD_AUDIO` + `READ_MEDIA_IMAGES/VIDEO/AUDIO`; iOS `NSMicrophoneUsageDescription`.
- **⚠️ Runtime to verify:** Firebase **Storage** rules are console-managed (no `storage.rules` in repo). `posts/**` uploads work, so `chat_media/**` should too — but if chat uploads fail with permission-denied, add a `chat_media/**` rule in the console. iOS needs `pod install` for the new plugins before an iOS build.

### 2026-06-14 — Invite Friends entry points added across the app
Added "Invite Friends" entry points (all route to `/invite`):
- **Chat list** (`chat_list_view.dart`) — gift icon in the app bar.
- **Chat room info** (`chat_room_detail_view.dart`) — full-width "Invite Friends" button.
- **Profile** (`profile_view.dart`) — clear labeled "Invite Friends ›" row above the referral progress (own profile), in addition to the existing 🎁 topbar icon.
- (Settings row + Profile topbar icon were already present.)

### 2026-06-14 — Pioneer badge visual + premium messaging
- Designed a real gold-medallion **Pioneer badge** SVG (`assets/svgs/pioneer_badge.svg`) — notched gold coin + star + shine — replacing the plain Material icon. `PioneerBadge` now renders it (small, `ClipOval`-rounded) on chat names + Profile; new `PioneerBadgeCard` (compact, rounded) shows on the Invite screen.
- Added **premium-access messaging** (generic, no time period): card shows "Premium features unlocked" (earned) / "Refer 25 friends to unlock premium features" (locked teaser); tooltip + badge-earned push updated. Tested on device.
- **Note:** messaging only — no actual feature is gated behind the badge yet (subscription/premium is still a stub). Real premium gating is a separate TODO.

### 2026-06-14 — Referral Reward System (code complete)
Built the full referral system per the approved plan (manual code entry, branded invite links, 1-year-expiring Pioneer badge at 25 referrals, dedicated Invite screen). Verified with `flutter analyze` (0 errors) and a successful `flutter build apk --debug`. **Backend, rules, and Hosting are written but NOT deployed** (see Open Items).

- **Backend** (`functions/index.js`): added `getOrCreateReferralCode` (idempotent, unique-code generation), `redeemReferral` (verifies ID token; anti-fraud: self-referral block, one-per-account via `referrals/{uid}` doc id, device dedupe; atomic server-side count + Pioneer badge grant at 25), and `expirePioneerBadges` (daily `onSchedule` sweep). Reuses the existing `verifyIdToken`/CORS/FCM patterns; sends `referral_joined` + `badge_earned` pushes.
- **Data model**: new `users` fields `referralCode/referralCount/referredBy/pioneerBadge` (server-written only) + collections `referralCodes/{CODE}`, `referrals/{referredUid}`, `referralDevices/{deviceId}`.
- **Rules/indexes**: rewrote `firestore.rules` to make reward fields server-only (narrowed the wildcard, excluded `users`/referral collections by name); added `users (pioneerBadge.active + expiresAt)` index.
- **Hosting**: `firebase.json` hosting block + `public/invite.html` (shows code, copies it, redirects to the right store).
- **Client**: `ReferralService` + `UserBadgeCacheService` (locator-registered); dedicated **Invite screen** (`lib/ui/views/invite/`, route `/invite`) with code/link, `x/25` progress bar, and WhatsApp/Messenger/Copy/More share; signup attribution in `interests_view_model.dart` (after `saveUserData`, errors swallowed) fed by a new "Have a referral code?" field; entry points from Settings + Profile; Pioneer badge on Profile header and chat sender names (via the live badge cache, not denormalized — badge expires); notification inbox + deep-link routing for `referral_joined`/`badge_earned`. Reusable `PioneerBadge` + `ReferralProgressBar` widgets. No new pub dependencies.

### 2026-06-14 — Onboarding, build setup & full project understanding
- **Build environment:** located Flutter at `~/development/flutter/bin` (not in PATH); ran `flutter pub get`.
- **Android:** fixed `android/app/build.gradle.kts` signing config — release signing now only applies when `key.properties` exists, else falls back to debug (a fresh clone was failing with "null cannot be cast to non-null type kotlin.String"). Auto-installed NDK 27.0.12077973. App launched on emulator `Medium_Phone_API_36.0`.
- **iOS:** installed CocoaPods (1.16.2 via Homebrew); removed a corrupted `gRPC-Core` spec and ran `pod install --repo-update` (59 pods); app built and launched on iPhone 17 simulator.
- **Project location correction:** discovered the original `FA James/sourceCode` is now empty; the live project is at `Client James/fASourceCode`. All work happens there.
- **Understanding:** read all 9 project docs and mapped the full `lib/` tree (203 Dart files) + Firebase backend. Captured architecture, feature map, backend structure, perf decisions, and risks. Saved durable context to Claude memory.
- **Created this PROGRESS.md** as the project's central progress log.
