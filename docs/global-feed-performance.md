# Global feed — full specification & rollout tracker

This document is the **source of truth** for `HomeView` / `HomeViewModel` global feed behavior: Firestore usage, in-memory windowing, pagination cursors, scroll prefetch, UI list vs stored posts, and phased refactors.

**Rule for changes:** Update this file whenever feed constants or behavior change so agents and developers share the same context.

Companion doc: [`ARCHITECTURE_FEED_CHAT_NOTIFICATIONS.md`](./ARCHITECTURE_FEED_CHAT_NOTIFICATIONS.md) (high-level product + other subsystems).

---

## 1. Normative specification (current implementation)

### 1.1 File map

| Area | File(s) |
|------|---------|
| UI, scroll, footer, list | `lib/ui/views/homeview/home_view.dart` |
| State, pagination, filter, memory window, stream | `lib/ui/views/homeview/home_viewmodel.dart` |
| Firestore queries | `lib/core/services/firestore_service.dart` (`defaultPostsCollection`, `getPostsPaginated`, `getPostsStream`, `getGlobalFeedPostSnapshot`) |
| Post row / video budget | `lib/ui/views/homeview/widgets/post_widget.dart`, `feed_video_init_budget.dart`, `post_widget_list_header.dart` |

---

### 1.2 Collections & query shape

| Item | Value |
|------|--------|
| Default posts collection | `FirestoreService.defaultPostsCollection` → **`festivalrumorglobalfeed`** |
| Order | **`createdAt` descending** (newest first in `allPosts[0]` … oldest loaded at `allPosts.last`) |
| Pagination | `getPostsPaginated`: `limit`, optional `lastDocument` → `startAfterDocument(lastDocument)` when not null |
| `getPostsPaginated` return map keys | **`posts`** (`List<Map>`), **`lastDocument`** (last row of page), **`hasMore`** (`bool`), **`docSnapshotsByPostId`** (`Map<postId, DocumentSnapshot<Map<String,dynamic>>>`) |
| `hasMore` computation | If page size **== limit** and last doc non-null: extra query **`limit(1)`** after that document; `hasMore = nextSnapshot.docs.isNotEmpty`. If that peek fails: fallback **`hasMore = (fetched == limit)`**. If fetched **< limit**: **`hasMore = false`**. |

---

### 1.3 HomeViewModel constants (exact values in code)

| Constant | Value | Role |
|----------|--------|------|
| `_initialLimit` | **10** | First `getPostsPaginated` batch after reset |
| `_loadMoreLimit` | **10** | Each `loadMorePosts()` batch |
| `_maxLoadedFeedPosts` | **100** | Max length of **`allPosts`** before **trim** moves tail into detached buffer |
| `_feedMemoryTrimChunk` | **50** | Each trim removes this many **oldest** rows from the end of `allPosts` and prepends them into the detached buffer (same order: chunk oldest-at-end of list → buffer order preserved for restore) |
| `_maxDetachedOlderPosts` | **200** | Max rows in **`_detachedOlderTail`**; excess **oldest** detached rows are dropped; matching ids removed from cursor snapshot map |
| `_realtimeStreamPostLimit` | **80** | `getPostsStream(limit: …)` — fixed cap; **does not** grow with `allPosts.length` |

**Critical invariant:** If **`_maxLoadedFeedPosts` ≤ `_initialLimit`**, the first successful **load more** still overfills the cap; **trim** removes the newly loaded **tail** until length ≤ cap, so the **visible** window can stay at the **same** newest N ids as initial load (`posts` unchanged). For paging to visibly grow,\ **`_maxLoadedFeedPosts` must be large enough** relative to `_initialLimit + _loadMoreLimit` (and trim chunk math) or trims will hide every new page.

---

### 1.4 Lists: `allPosts` vs `posts` vs buffers

| Structure | Meaning |
|-----------|---------|
| **`allPosts`** | Full in-memory vertical slice of the feed (newest → oldest), subject to cap + trim |
| **`posts`** | **Filtered** view of `allPosts` for the ListView (`selectedFilter` + `searchQuery`); missing `userId` excluded |
| **`_detachedOlderTail`** | **Oldest** posts **removed from `allPosts`** by trim; kept to re-attach via **`restoreDetachedOlderPosts()`**; FIFO cap at **`_maxDetachedOlderPosts`** |
| **`_feedCursorDocByPostId`** | `DocumentSnapshot` per `postId` from paginated queries (and rare single-doc fetch); used to set **`_lastDocument`** without re-querying after trim |

**`loadInitialPosts`** reset: clears **`allPosts`**, **`_detachedOlderTail`**, **`_feedCursorDocByPostId`**; sets **`_lastDocument = null`**, **`_hasMorePosts = true`**; loads first page + starts realtime listener after enrich/reactions/filter.

The ListView uses **`viewModel.posts`**, not `allPosts`.

---

### 1.5 Filtering

- **`selectedFilter`**: compared to `AppStrings` — **live** / **upcoming** / **past** require `post.status` match; **all** passes status |
- **`searchQuery`**: case-insensitive match on `username` **or** `content` |
- **`_computeFilteredPosts()`** builds the visible list |
- **`_applyFilterNotifyIfChanged()`** assigns **`posts = next`** only if **`_filteredSnapshotsEqual(posts, next)`** is false — skips `notifyListeners` when the **visible** list would be identical (per-row **`_feedRowsVisuallyEqual`**: postId, counts, reactions, text, media, link preview fields, etc.) |

**Implication:** If `allPosts` gains then loses rows (trim) such that the **filtered** slice is **unchanged**, listeners may **not** fire from the filter helper — **`loadMorePosts`** still ends with **`finally { notifyListeners() }`**.

---

### 1.6 Pagination pipeline (`loadMorePosts`)

1. Early exit if disposed, `_isLoadingMore`, or **`!_hasMorePosts`**
2. **`await _syncPaginationCursorFromCachedDoc()`**
3. **`getPostsPaginated(limit: _loadMoreLimit, lastDocument: _lastDocument)`**
4. **`_mergeDocSnapshotsFromPaginatedResult`** — fills **`_feedCursorDocByPostId`**
5. Assign **`_lastDocument`** and **`_hasMorePosts`** from result
6. Parse maps → **`newPosts`**; drop rows with null/empty **`userId`**
7. **`uniqueNewPosts`**: skip any `postId` already in **`allPosts`**
8. If **`newPosts` empty** → **`_hasMorePosts = false`**
9. Else if **`uniqueNewPosts` empty** (duplicate page vs list) → **do not append**; **`_pruneFeedCursorDocsToStoredPosts()`**; cursor already advanced via API **`lastDocument`**
10. Else append to **`allPosts`**, enrich photos + reactions for new indices only, **`_trimAllPostsIfOverMemoryCap()`**; if trim ran, **`await _syncPaginationCursorFromCachedDoc()`**; prune cursor map
11. **`_applyFilterNotifyIfChanged()`**
12. **`finally`**: clear **`_isLoadingMore`**, **`notifyListeners()`**

---

### 1.7 Cursor sync (`_syncPaginationCursorFromCachedDoc`)

- Uses **`allPosts.last.postId`**
- If **`_feedCursorDocByPostId[id]`** present → set **`_lastDocument = snap`** (no network)
- Else **`getGlobalFeedPostSnapshot(postId)`** — **one document `get()`**; on success store in map and set **`_lastDocument`**
- **Rare** edge: tail post only ever from realtime path may need fallback

**Trim:** Does **not** use `doc(postId).get()` for every trim; snapshots come from pagination / fallback cache.

---

### 1.8 Memory trim & detached buffer

- While **`allPosts.length > _maxLoadedFeedPosts`** and **`allPosts.length >= _feedMemoryTrimChunk`**: remove **`sublist(length - chunk, length)`** from **`allPosts`**, **`insertAll(0, removed)`** into **`_detachedOlderTail`**, then **`_capDetachedOlderTail()`**
- **`_capDetachedOlderTail`**: if length **`> _maxDetachedOlderPosts`**, drop from index **`_maxDetachedOlderPosts`** onward (evicted ids removed from **`_feedCursorDocByPostId`**)

---

### 1.9 Restore (`restoreDetachedOlderPosts`)

- Copy buffer → **`chunk`**, clear buffer
- **`room = _maxLoadedFeedPosts - allPosts.length`**
- If **`room <= 0`**: re-queue **`chunk`**, return (no attach)
- **`deduped`**: skip ids already in **`allPosts`**
- Take up to **`room`** into **`attach`**, rest as **`remainder`** back into buffer; cap after remainder
- If **`attach` empty** (e.g. all duplicates): re-queue full **`chunk`**
- Else **`allPosts.addAll(attach)`**, enrich + reactions, prune + **`await _syncPaginationCursorFromCachedDoc()`**

---

### 1.10 Prefetch policy (scroll) — **`HomeView`**

**Priority:** **`hasMorePosts`** → **`loadMorePosts()`** first. **Only if `!hasMorePosts`** and **`hasDetachedOlderChunk`** → **`restoreDetachedOlderPosts()`**.

Reason: If detached ran first while **`hasMorePosts`** and list at cap, **restore** could return with **no room** and **block** Firestore paging.

**Triggers:**

| Trigger | Condition |
|---------|-----------|
| **`_maybePrefetchMoreFeed`** | Not loading; and (**`hasMorePosts` OR `hasDetachedOlderChunk`**); scroll: **`maxScrollExtent <= 0`** **OR** **`pixels >= maxScrollExtent - prefetchLead`** where **`prefetchLead = viewportH * 1.5`** |
| **`_topUpShortFeedIfNeeded`** | After build when **`posts.length`** changed; **`maxScrollExtent == 0`** (short list); same **`_prefetchOlderFeedContent`** |

Scroll uses **`addPostFrameCallback`** once per frame (`_prefetchFrameScheduled`).

---

### 1.11 Footer row (`_buildFeedFooter`)

Footer is an **extra** ListView item when **`showFooter`**:

`isLoadingMore || !hasMorePosts || hasDetachedOlderChunk`

| State | UI |
|--------|-----|
| **`isLoadingMore`** | CircularProgressIndicator |
| **`hasDetachedOlderChunk && !hasMorePosts`** | Text: **“Scroll down for earlier posts”** |
| **`!hasMorePosts`** (and not loading) | **“No more posts available”** |
| Else | `SizedBox.shrink()` |

When **`hasMorePosts`** and detached backlog exists, footer is still “active” slot but may shrink — **prefetch still prefers `loadMore`**.

---

### 1.12 Realtime listener (global newest window)

- **`getPostsStream(limit: _realtimeStreamPostLimit)`** — **fixed 80**
- New docs **not** in loaded set: prepend only if **newer than** current **`allPosts.first.createdAt`** (or empty list)
- Existing ids: merge updates (reactions, counts, etc.)
- **Does not** re-subscribe on load more (Phase 2)

**Product:** Rows **older than the 80-doc stream window** may not get live metadata updates until refresh / re-entry.

---

### 1.13 Delete post (local)

On successful delete: remove from **`posts`/`allPosts`**, **`_feedCursorDocByPostId.remove(postId)`**, notify.

---

### 1.14 Debug logging (debug mode only)

Console prefix **`[GlobalFeed]`** for: initial load stats, cursor cache merge/prune, cursor sync miss + fallback, buffer cap, trim, restore steps, load more steps, prefetch branch, delete cleanup. Optional: **`flutter/foundation.dart`** `kDebugMode` in `home_view` for prefetch prints.

---

### 1.15 Related constants elsewhere (feed cards)

| Item | Location | Value |
|------|----------|--------|
| Feed video init budget | `feed_video_init_budget.dart` | **`maxConcurrent = 2`** network inits |
| Visibility pause threshold | `home_view.dart` | **`visibleFraction < 0.12`** → pause videos |

---

## 2. Rollout phases (historical refactors)

**Rule:** One phase per PR or commit series; test the feed (scroll, reactions, new post, load more) after each phase.

---

### Phase 1 — Scoped reactions + targeted avatar enrich ✅

**Goal:** Stop scanning **all** loaded posts for every enrichment and every reaction refresh when only a subset changed.

**Changes:** `_enrichPostsWithUserPhotos({List<int>? indices})`, `_loadUserReactions({List<String>? postIds})`; stream prepend / reaction-diff narrow sets; load more narrows to appended indices.

**Files:** `lib/ui/views/homeview/home_viewmodel.dart`

---

### Phase 2 — Realtime window + fewer listener restarts ✅

**Goal:** Bounded stream (`_realtimeStreamPostLimit = 80`); no **`_startPostsListener()`** from **`loadMorePosts()`**.

**Files:** `lib/ui/views/homeview/home_viewmodel.dart`

---

### Phase 3 — Viewport-aware video / visibility ✅

**Goal:** Replace O(N) scroll scan with **`VisibilityDetector`** (`visibleFraction < 0.12`).

**Files:** `pubspec.yaml`, `lib/ui/views/homeview/home_view.dart`

---

### Phase 4 — Narrow rebuilds / filter shortcuts ✅

**Goal:** **`_applyFilterNotifyIfChanged`** + **`_filteredSnapshotsEqual`** reduce redundant **`notifyListeners`**.

**Files:** `lib/ui/views/homeview/home_viewmodel.dart`

---

### Phase 5 — PostWidget split + video caps ✅

**Goal:** **`FeedVideoInitBudget`**, **`PostWidgetListHeader`**.

**Files:** `feed_video_init_budget.dart`, `post_widget_list_header.dart`, `post_widget.dart`

---

### Phase 6 — List / keep-alive tuning ✅

**Goal:** Adaptive **`cacheExtent`**, lifecycle + route pause for feed video.

**Files:** `navigation_service.dart`, `main.dart`, `home_view.dart`

---

### Phase 7 — Paginated document snapshots + cursor cache + single-doc fallback ✅

**Goal:** Avoid extra **`get()`** on every trim; carry **`DocumentSnapshot`** per id from **`getPostsPaginated`** (`docSnapshotsByPostId`); **`getGlobalFeedPostSnapshot(postId)`** only when tail id missing from cache; merge/prune map with **`allPosts` ∪ detached buffer**; **`_syncPaginationCursorFromCachedDoc`** before/after load/trim/restore as implemented.

**Files:** `firestore_service.dart`, `home_viewmodel.dart`

---

### Phase 8 — Prefetch: load more before restore ✅

**Goal:** When **`hasMorePosts`** and detached buffer non-empty, always **Firestore load more** first so paging is not blocked by **restore** with no room at memory cap.

**Files:** `home_view.dart` ( **`_prefetchOlderFeedContent`** ); footer text: **“Scroll down for earlier posts”** only when **`hasDetachedOlderChunk && !hasMorePosts`**.

---

## 3. Out of scope (by product choice)

- Thumbnail URLs / CDN resize / LQIP (excluded from feed perf plan).

---

## 4. References

- Run **`dart analyze`** after feed changes.
- Firestore: `getUserReactions` uses collection-group when available; scales with requested post ids.
