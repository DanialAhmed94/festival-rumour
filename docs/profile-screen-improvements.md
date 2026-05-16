# Profile screen — issue tracker & rollout plan

Analysis of `lib/ui/views/Profile/profile_view.dart` and
`lib/ui/views/Profile/profile_viewmodel.dart`.

**Rule:** One step per session. Ask the user for approval before implementing each step.  
**Status key:** 🔴 Not started · 🟡 In progress · ✅ Done

---

## Step 1 — Remove duplicate Firestore listener ✅

**Files:** `profile_viewmodel.dart`

**Problem:**  
`_startUserDataListener` and `_startFavoriteFestivalsListener` both subscribe to the
same `users/{uid}` Firestore document via `.snapshots()`.

- In the **online** path only `_startUserDataListener` is called — it already reads
  `favoriteFestivals` (lines 1034–1044) and updates `_favoriteFestivalsCount`.
- In the **offline** path (line 552–553) **both** are called simultaneously → two
  live listeners on the same document → every Firestore update fires two callbacks
  → two potential `notifyListeners()` calls per change → double UI rebuilds +
  double Firestore quota usage.
- `_favoriteFestivalsSubscription` is a separate subscription field that also needs
  cancelling in `onDispose`, adding lifecycle complexity for zero benefit.

**Fix:**  
Delete `_startFavoriteFestivalsListener` and `_favoriteFestivalsSubscription`
entirely. Remove the call in the offline path. `_startUserDataListener` already
handles the count correctly.

**Impact:** −1 Firestore read listener, −1 `StreamSubscription`, −potential double
rebuild on every user document write.

---

## Step 2 — Replace `shrinkWrap: true` GridViews with `SliverGrid` ✅

**Files:** `profile_view.dart`

**Problem:**  
Both `_profileGridWidget` (images tab) and `_profileReelsWidget` (videos tab) use:

```dart
GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), ...)
```

inside a `SliverToBoxAdapter` inside a `CustomScrollView`. `shrinkWrap: true` forces
Flutter to lay out **every grid cell** eagerly — there is no viewport culling.
For a user with 100 posts this is a full O(N) layout pass on every rebuild that
touches the tab content. Also, `SliverToBoxAdapter` wrapping a `shrinkWrap` grid
blocks the sliver framework from doing incremental layout.

**Fix:**  
Move the grid directly into the `CustomScrollView` as a `SliverGrid` (for cells) +
a `SliverToBoxAdapter` (for the Load More row). Remove `shrinkWrap` and
`NeverScrollableScrollPhysics`. The outer `CustomScrollView` handles all scrolling.

**Impact:** O(visible) layout instead of O(N); measurable jank reduction on large
grids; frame budget freed for animations and transitions.

---

## Step 3 — Auto scroll-prefetch for grid pagination ✅

**Files:** `profile_view.dart`, `profile_viewmodel.dart`

**Problem:**  
Both grids show a manual `ElevatedButton("Load More")`. The user must scroll to the
bottom and then manually tap. Same pattern as the pre-Phase-8 feed.

**Fix (mirrors Phase 8 from the feed):**  
- Add a `ScrollController` to `_ProfileViewContentState`.
- Listen to the controller; fire `loadMoreImages` / `loadMoreVideos` when
  `pixels >= maxScrollExtent - prefetchLead` (1.5 × viewport height).
- Replace the button with an auto-trigger footer: spinner while loading, nothing when
  there is no more data (or a small "all caught up" caption).
- Use `addPostFrameCallback` coalescing (one check per frame, same as the feed).

**Impact:** Zero manual taps required; pages load before the user reaches the end;
consistent UX with the global feed.

---

## Step 4 — Replace deprecated `WillPopScope` with `PopScope` ✅

**Files:** `profile_view.dart`

**Problem:**  
Line 119 uses `WillPopScope(onWillPop: ...)`, deprecated since Flutter 3.12 and
scheduled for removal. Generates an analyzer warning on every build and will break on
a future Flutter upgrade.

**Fix:**  
Replace with `PopScope(canPop: ..., onPopInvokedWithResult: ...)`. The back-button
logic (tab callback, `popUntil`, default pop) maps 1-to-1.

`PopScope` API:
- `canPop: false` → intercept back; `onPopInvokedWithResult` runs for both taps and
  gestures.
- `canPop: true` → allow default pop; callback still fires but shouldn't call
  `Navigator` manually.

**Impact:** Removes deprecation warning; future-proofs back navigation.

---

## Step 5 — Fix `refreshUserProfileInfo` firing on every `didUpdateWidget` ✅

**Files:** `profile_view.dart`

**Problem:**  
`didUpdateWidget` (lines 107–113) schedules `refreshUserProfileInfo()` via a
`PostFrameCallback` every time the widget updates while both `oldWidget.userId` and
`widget.userId` are null (own profile). The method has an internal flag guard
(`_hasRefreshedProfile`), but the scheduling overhead — allocating a
`PostFrameCallback` closure, checking `mounted`, calling the async method — still
runs on **every parent rebuild** of `_ProfileViewContent`, which can be frequent
(e.g. badge counter ticks, provider changes).

**Fix:**  
Add a local flag `_didScheduleProfileRefresh` on `_ProfileViewContentState`. Set it
on the first schedule; clear it when the callback fires. This prevents scheduling the
same `PostFrameCallback` twice in one frame cycle and removes redundant closures
during rapid rebuilds.

**Impact:** Fewer unnecessary `PostFrameCallback` allocations; no async work scheduled
on rebuilds after the first.

---

## Implementation order

| Step | Description | Risk | Effort |
|------|-------------|------|--------|
| 1 | Remove duplicate listener | Low — delete-only | Tiny |
| 2 | SliverGrid refactor | Medium — layout change | Medium |
| 3 | Auto scroll prefetch | Low — mirrors feed code | Small |
| 4 | PopScope migration | Low — API swap | Tiny |
| 5 | didUpdateWidget guard | Low — add one bool | Tiny |

---

## Bug fixes (post-step-5) ✅

The following intermittent "sometimes all posts load, sometimes not" bugs were diagnosed and fixed in one session.

---

### Bug 1 — FestivalProvider race condition ✅

**Root cause:**  
`loadUserProfileData` reads `Provider.of<FestivalProvider>(context, listen: false).allFestivals` at the moment the profile screen initialises. On a cold launch (or whenever the FestivalProvider hasn't finished loading yet), `allFestivals` is `[]`. This causes `festivalCollectionNames` to be empty, so every festival-collection Firestore query is skipped entirely — the profile only queries `festivalrumorglobalfeed`. The user sees only their global-feed posts. On the next visit (festivals already cached), all posts appear. Intermittency is perfectly explained by the timing of `FestivalProvider.setAllFestivals()` vs profile init.

**Fix:**  
- Added `bool _loadedWithEmptyFestivals` and `FestivalProvider? _pendingFestivalProvider` fields to `ProfileViewModel`.  
- In `loadUserProfileData`, when `festivalCollectionNames` is empty, a one-shot `addListener(_onFestivalsReady)` is registered on `FestivalProvider`.  
- `_onFestivalsReady` removes itself immediately (no double-fire), builds the collection names from the now-loaded provider, and calls `_refreshPostsWithCollections(names)` — no `BuildContext` required.  
- `refreshPostsOnly(BuildContext)` is refactored to delegate to `_refreshPostsWithCollections(List<String>)` so both the festival-listener path and the manual refresh path share one implementation.  
- Listener is removed in `onDispose` and in `initialize()` reset to prevent stale callbacks.

**Affected files:** `profile_viewmodel.dart`

**Follow-up fix (FestivalProvider never populated):**  
The listener added above registers correctly, but `FestivalProvider.setAllFestivals()` was only ever called from `FestivalViewModel.navigateToHome()` and `navigateToGlobalFeed()` — both of which require the user to explicitly interact with the festival selection screen. If a user navigates directly to `/profile` (e.g., via the bottom nav bar), `FestivalProvider.allFestivals` is permanently empty and the listener never fires.

Root cause confirmed by log: `[Profile] FestivalProvider empty at init — registered reload listener` appeared, but `[FestivalProvider] _allFestivals now has N festivals` never appeared — meaning `setAllFestivals` was not called despite `FestivalViewModel.allFestivals.length=10` having loaded.

**Follow-up fix:**  
- Registered `FestivalProvider` as a `LazySingleton` in `locator.dart` so it can be accessed without a `BuildContext`.  
- Updated `main.dart` to use `ChangeNotifierProvider.value(value: locator<FestivalProvider>())` — widget tree and ViewModels share the same instance.  
- Added `locator<FestivalProvider>().setAllFestivals(allFestivals)` call at the end of `FestivalViewModel.loadFestivals()` (after `_applyFilter()`). Every successful festival API response now immediately populates `FestivalProvider`, guaranteeing the profile's listener fires (or the next profile load finds a non-empty list).

**Affected files:** `locator.dart`, `main.dart`, `festival_view_model.dart`

---

### Bug 2 — Profile image/video cache hard-codes `hasMore: false` ✅

**Root cause:**  
`getUserImagesPaginated` and `getUserVideosPaginated` always returned `'hasMore': false` from a cache hit, regardless of how many posts the user has. A user with 45 posts would have the first 20 cached on their first session. On the next session (cache still valid), `hasMore: false` was returned from cache, pagination was silently disabled, and only 20 images showed with no load-more trigger.

**Fix:**  
- `hasMore` is now stored alongside `data`, `postInfos`, and `timestamp` in `_profileCache`.  
- On a cache read: if `cachedHasMore == true`, the cache entry is **invalidated** and a fresh Firestore fetch is performed. This ensures that users with more than one page of posts always get a fresh first page (with a valid `_lastDocument` cursor for subsequent pages).  
- If `cachedHasMore == false` (all posts fit in one page), the cache is served as before — zero extra Firestore reads for the common case.

**Affected files:** `firestore_service.dart` (`getUserImagesPaginated`, `getUserVideosPaginated`)

---

### Bug 3 — `hasMore` computed incorrectly in fallback path of `getUserPostsPaginated` ✅

**Root cause:**  
When a composite Firestore index is missing (`userId + createdAt`), `getUserPostsPaginated` falls back to fetching **all** user docs without a `.limit()` clause, then filters and sorts in memory. However, `hasMore` was always computed as `querySnapshot.docs.length == limit`. In the fallback path, `querySnapshot.docs.length` is the **total post count**, not the page size. For a user with 25 posts and `limit = 20`, `25 != 20 → hasMore = false` — the last 5 posts were silently dropped after memory truncation.

**Fix:**  
- Added a `bool _fallback` local variable; set to `true` when the index-error catch triggers.  
- In the fallback path: `hasMore = posts.length > limit` (evaluated **before** truncation). If `hasMore`, posts are truncated to `limit` and `newLastDocument` is re-synced to the actual last post in the sorted+limited list (via `querySnapshot.docs.firstWhere(id == lastPostId)`).  
- In the primary path: original `querySnapshot.docs.length == limit` logic is unchanged.

**Affected files:** `firestore_service.dart` (`getUserPostsPaginated`)
