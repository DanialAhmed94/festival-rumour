# Comment screen — specification & rollout

Normative behaviour for **`CommentView`** / **`CommentViewModel`**, notification deep-links, scroll-to-comment, and list performance.

Companion doc: [`ARCHITECTURE_FEED_CHAT_NOTIFICATIONS.md`](./ARCHITECTURE_FEED_CHAT_NOTIFICATIONS.md) (FCM payloads, **`onCommentCreated`**, **`parseLaunchTargetFromData`**).

---

## File map

| Area | File(s) |
|------|---------|
| Comments UI | `lib/ui/views/comment/comment_view.dart` |
| Comments state | `lib/ui/views/comment/comment_viewmodel.dart` |
| Notification → resolved post → `CommentView` | `lib/ui/views/comment/comment_deep_link_view.dart` |
| Route | `AppRoutes.comments`, `AppRoutes.commentDeepLink` in `lib/core/router/app_router.dart` |
| Indexed list | **`scrollable_positioned_list`** (pubspec dependency) |

---

## Deep-link flow (`focusCommentId`)

1. FCM **`type: post_comment`** or **`comment_reply`** includes **`postId`**, **`collectionName`**, and for replies optional **`parentCommentId`** mapped to **`focusCommentId`** in routing args.
2. **`CommentDeepLinkView`** fetches the post via **`FirestoreService.getPostById`**, then **`pushReplacementNamed(AppRoutes.comments, arguments: …)`**.
3. **`CommentView`** passes **`focusCommentId`** into **`CommentViewModel.initialize(..., focusParentCommentId: focusCommentId)`** (top-level comment id for threading / replies).

No separate field is persisted for scroll targets after init — scrolling is triggered **once** from **`loadInitialComments`** when **`focus`** is non-empty.

---

## List implementation: `ScrollablePositionedList`

Replaces **`ListView.builder`** on the comments screen only.

| Component | Role |
|-----------|------|
| **`ItemScrollController`** | **`scrollTo`** / **`jumpTo`** by **index** (O(1) logical scroll; lazy build preserved) |
| **`ItemPositionsListener`** | Detect whether the user scrolled away from the bottom (gates auto-scroll on stream updates) |
| Footer row | Index **`comments.length`** — load-more / “no more comments” |

---

## Index map (`Map<String, int>`)

Built by **`_rebuildIndexMap()`**: for each **`CommentModel`** with non-null **`commentId`**, **`commentId → list index`**.

Rebuild after:

- Initial paginated load
- Incremental stream updates (**`_updateCommentsIncrementally`** path)
- **`loadMoreComments`**
- Optimistic **`addComment`** (local insert)

Purpose: **`_scrollToFocusComment(commentId)`** resolves index in **O(1)** without **`GlobalKey`** per row or **`ensureVisible`** scans.

---

## One-shot scroll + highlight

After **`loadInitialComments`** succeeds:

1. If **`focusParentCommentId`** was set → **`WidgetsBinding.instance.addPostFrameCallback`**: **`ensureRepliesExpanded(focus)`** then **`_scrollToFocusComment(focus)`**.
2. Else → **`_scrollToBottom()`** (normal open: newest at bottom).

**Scroll:** **`itemScrollController.scrollTo(index, alignment: ~0.1, duration …)`** so the target sits near the top of the viewport.

**Highlight:** set **`_highlightedCommentId`**, **`notifyListeners()`**; **`Timer(1.5s)`** clears highlight. UI: **`AnimatedContainer`** + **`Consumer`** per row keyed on **`vm.isHighlighted(comment.commentId)`** (yellow tinted background fade).

Repeated scroll on every rebuild/stream is **avoided**: focus is consumed through the single post-frame chain (not stored as long-lived pending scroll field).

---

## Critical implementation details

### `_scrollToBottom()` and loading state

`loadInitialComments` runs while **`isLoading`** shows **`LoadingWidget`** — the list is **not** mounted yet, so **`itemScrollController.isAttached`** may be **false** at call time.

**Do not** return early before scheduling the delayed **`jumpTo`**. Use a short **`Future.delayed`** (e.g. **200 ms**) so the scaffold switches to **`ScrollablePositionedList`** and the controller attaches, then **`jumpTo(index: comments.length)`** (footer).

### **`_userScrolledUp`** with `ItemPositionsListener`

Footers live at index **`comments.length`**. Visible max index **below** footer when all comments fit is **`comments.length - 1`**, not **`comments.length`**.

Wrong check **`lastVisible < comments.length`** would always treat the user as “scrolled up” on first layout and **suppress** **`_scrollToBottomSmoothly`** after stream merges.

Correct: **`_userScrolledUp = lastVisible < max(comments.length - 1, 0)`**.

### Auto-scroll after stream updates

`**_scrollToBottomSmoothly`** only runs when the list is effectively the first page and **`!_userScrolledUp`**, mirroring prior **`ScrollController`** behaviour.

---

## Dependency

```yaml
scrollable_positioned_list: ^0.3.8
```

(update version in **`pubspec.yaml`** if bumped)

---

## Rule for changes

When comment list scrolling, indexing, notification **`focusCommentId`** handling, or highlight behaviour changes, **update this file** so agents and reviewers share the same source of truth.
