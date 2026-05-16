# Festival Rumour — Global Feed, Rumours, Chat, and Notifications

This document summarizes how the **Flutter** app implements the **global feed**, **festival rumours**, **chat**, and **push / in-app notifications**, backed by **Firebase** (Firestore, Auth, Cloud Messaging) and **HTTPS Cloud Functions**.

---

## High-level architecture

| Area | Primary UI | State / logic | Backend |
|------|------------|---------------|---------|
| Global feed | `HomeView` + `HomeViewModel` | Pagination + Firestore snapshots | Collection `festivalrumorglobalfeed` |
| Festival rumours | `RumorsView` + `RumorsViewModel` | Same patterns + `shared_posts` merge | `{festivalId}_{name}_rumour` + `shared_posts` |
| Chat | `ChatView` / `DirectChatView` + `ChatViewModel` | Live tail + older pages, room docs | `chatRooms/{id}` + `messages` subcollection |
| Push | `FirebaseNotificationService`, `NotificationService` (local) | FCM + channels + navigation | `sendNotification` (HTTP), `onCommentCreated` (trigger) |

Constants such as **`FirestoreService.defaultPostsCollection`** (`festivalrumorglobalfeed`) and **`appUserIdentifier`** (`festivalrumor`) tie the app to the correct Firestore data and FCM recipient filtering.

---

## Global feed

**Full normative spec (constants, trim, detached buffer, cursors, prefetch, footer):** [`global-feed-performance.md`](./global-feed-performance.md).

### Data model

- Posts live in **`festivalrumorglobalfeed`** (global) unless another collection is passed.
- Each post document stores fields consumed by **`PostModel.fromFirestore`** (e.g. `userId`, `createdAt`, content, media, reaction/comment aggregates). **`sourceCollection`** is set on write so later reads know which collection a post came from.

### `HomeViewModel` behavior

- **Initial load**: `getPostsPaginated` with limit **10** (`_initialLimit`), ordered by **`createdAt` descending**.
- **Load more**: same API with **`lastDocument`** cursor; each page returns **`posts`**, **`lastDocument`**, **`hasMore`**, and **`docSnapshotsByPostId`** for cursor repair without per-trim **`get()`** calls; **`hasMore`** uses a full-page **plus** a one-doc “peek” query when applicable.
- **In-memory window**: **`allPosts`** is capped (**`_maxLoadedFeedPosts`**, default **100**); overflow oldest rows move to **`_detachedOlderTail`** in chunks (**`_feedMemoryTrimChunk`**, default **50**), with a max detached buffer (**`_maxDetachedOlderPosts`**, default **200**). **`posts`** is the **filtered** slice shown in the UI.
- **Prefetch at bottom**: while Firestore reports **`hasMorePosts`**, scroll near bottom triggers **`loadMorePosts`**; **`restoreDetachedOlderPosts`** runs only when **`!hasMorePosts`** and the detached buffer is non-empty (details in the spec doc).
- **Real-time updates**: **`getPostsStream`** uses a **fixed** limit (**`_realtimeStreamPostLimit` = 80**), not `allPosts.length`-scaled. The listener prepends **truly new** posts (newer than the current **`allPosts.first`**, or not yet loaded) and merges updates into existing ids.
- **Filtering**: client-side filter by rumour **status** (live / upcoming / past / all) and **search** (username + content). **`_applyFilterNotifyIfChanged`** may skip `notifyListeners` when the filtered list would be visually unchanged.
- Invalid posts with missing **`userId`** are dropped from loads and from the filtered list.

### Firestore APIs (`FirestoreService`)

- **`getPosts` / `getPostsPaginated` / `getPostsStream`** — all default to **`defaultPostsCollection`** when `collectionName` is omitted.
- **`getGlobalFeedPostSnapshot(postId)`** — rare single-document read to align **`_lastDocument`** when the tail post has no paginated snapshot.
- **`savePost`** — writes to the target collection, sets **`sourceCollection`**, increments user post count when appropriate.

---

## Festival rumours (per-festival feed)

### Collection naming

Festival-specific posts use **`FirestoreService.getFestivalCollectionName(festivalId, festivalName)`** → pattern **`{festivalId}_{sanitizedFestivalName}_rumour`** (aligned with the public chat room naming style for festivals).

### `RumorsViewModel` behavior

- Initialized from **`FestivalProvider.selectedFestival`**; **`reinitializeIfFestivalChanged`** resets state when the user picks another festival (e.g. from discover).
- **Pagination**: same **`getPostsPaginated`** but with **`collectionName: _festivalCollectionName`**.
- **Shared posts**: after loading native festival posts, **`getPostsSharedToFestival`** resolves rows in **`shared_posts`** and fetches the **canonical post documents** from their **`sourceCollection`** (often the global feed). Shared items are merged into **`allPosts`** (deduped by `postId`), with **`sourceCollection`** defaulting to the global collection when missing.
- **Empty collections**: may create a **`_metadata`** document so the collection exists in the console.
- **Streams**: **`getPostsStream`** is scoped to the festival collection; logic mirrors home for new vs updated documents.
- **Filters / search**: same UX as home (**`RumorsView`** reuses **`PostWidget`** patterns from the home feed).

### Sharing to a festival

- **`sharePostToFestival`** writes an index doc under **`shared_posts`** and **`arrayUnion`** on the original post’s **`sharedToFestivals`**.

---

## Comment screen (`CommentView`)

**Normative UX / scroll / highlight / index map:** [`comment-screen-architecture.md`](./comment-screen-architecture.md).

- **`ScrollablePositionedList`** + **`ItemScrollController`** for jump/scroll to a target comment from **`focusCommentId`** (notification deep link).
- **`CommentDeepLinkView`** loads the post then navigates to **`AppRoutes.comments`** with resolved args.
- FCM **`post_comment` / `comment_reply`** data fields are parsed in **`FirebaseNotificationService.parseLaunchTargetFromData`** (see **Deep linking** below).

---

## Chat

### Firestore layout

- **`chatRooms`**: one document per room (`chatRoomId`).
- **`chatRooms/{id}/messages`**: subcollection; messages ordered by **`createdAt`**.
- Room fields used in the app include **`name`**, **`isPublic`**, **`members`**, **`createdBy`**, **`lastMessage`**, **`lastMessageTime`**, **`festivalId`** / **`festivalTitle`** for private festival rooms, **`memberJoinedAt`**, etc.

### Public vs private

- **Public festival room**: ID from **`getFestivalChatRoomId`** → **`{festivalId}_{sanitizedName}_PublicChat`**. Created via **`createPublicChatRoom`**; new signups can be merged into public rooms (see **`addUserToAllPublicChatRooms`** in `FirestoreService`).
- **Private festival-scoped room**: **`createPrivateChatRoom`** with **`festivalId`** (and optional **`festivalTitle`**) set on the document.
- **1:1 DM**: deterministic ID **`dm_{uidLow}::{uidHigh}`** via **`getDeterministicDmRoomId`**. The room document may be **created on first message** (`sendChatMessage` detects missing room + parsable DM id and calls **`createPrivateChatRoom`** with **`fixedChatRoomId`**).

### Message pipeline

- **`sendChatMessage`**: batch write — new doc under **`messages`**, update room **`lastMessage`** / timestamps.
- **Live tail**: **`watchRecentChatMessages`** — newest-first query, **`limit`** default **`chatMessagesPageSize` (40)**, real-time snapshots.
- **Older messages**: **`fetchOlderChatMessagesPage`** uses **`startAfterDocument`** for pagination; **`ChatViewModel`** merges “older pages” + live tail and tracks deleted / hidden visibility (**`memberJoined`**, hide timestamps, soft-delete).

### `ChatViewModel` (selected behaviors)

- **Tabs**: public vs private lists; private list is backed by Firestore subscriptions (**`_privateChats`**) plus mock entries for the public tab UI in code (placeholder titles).
- **Hidden rooms**: **`hiddenChatRooms`** on the user document — list filtering and per-room message visibility cutoffs; sending a message can **`removeHiddenChatRoom`**.
- **Profile display**: **`UserPhotoCacheService`** batch-fetches avatars/names for message senders.
- **Location messages**: special message **`type: location`** with **`lat` / `lng` / `festivalName`** (see **`ChatMessageModel`**).

### Push when sending chat

After a successful **`sendChatMessage`**, the view model reloads **`members`** from Firestore, excludes the sender, and calls **`NotificationServiceApi.sendPushNotification`** with **`chatRoomId`**, resolved **`chatRoomName`**, and **`festivalId`** when present — so recipients get the correct **deep link** behavior (festival private room vs DM).

---

## Notifications

### Device: FCM + local notifications

- **`FirebaseNotificationService.init`**: token fetch, **`onTokenRefresh`**, **`Firestore`** merge of **`fcmToken`** + **`appIdentifier: festivalrumor`** on **`users/{uid}`**, **`onMessage`** (foreground), **`onMessageOpenedApp`**, **`getInitialMessage`** (cold start), auth listener to re-sync token.
- **`NotificationService.init`**: **`flutter_local_notifications`** with Android channels **`default_channel`** and **`chat_messages`** (must match Cloud Function **`channelId`**).
- **Foreground**: if notification payload exists, optionally **suppress** when **`CurrentChatRoomService.currentChatRoomId`** matches **`data.chatRoomId`**. **Public** rooms (`*_PublicChat`): no local tray banner (still may update badge / list — see code). **Non-public**: **`NotificationService.show`** with JSON **`payload`** for tap handling.
- **Background isolate** (`main.dart` — **`firebaseMessagingBackgroundHandler`**): updates **SharedPreferences** for **chat badges** and **notification inbox** without full app services.

### In-app notification list

- **`NotificationStorageService`**: persists up to **30** items in **SharedPreferences**; types include **chat** vs **comment** vs **general** based on FCM **`data`**.

### Badges

- **`ChatBadgeService`**: per-**`chatRoomId`** unread counts in prefs; incremented on relevant FCM; cleared when opening a room (elsewhere in app).

### Deep linking (`FirebaseNotificationService`)

- **`parseLaunchTargetFromData`**:
  - **`post_comment` / `comment_reply`**: navigate to **`AppRoutes.commentDeepLink`** with **`postId`**, **`collectionName`**, optional **`focusCommentId`** (**`parentCommentId`**).
  - **`chatRoomId`** present: if **`festivalId`** in data → **`AppRoutes.chatRoom`** with room id string; else → **`AppRoutes.directChat`** with map **`{ chatRoomId }`** (DM / non-festival path).
- **`main.dart`** handles **terminated-state** launch: peeks pending data, and if user is logged in, may set **`AppLaunchInitialRouteArgs`** for **`AppRoutes.notificationLaunch`** then consumes pending data after navigation is ready.

### Server: Cloud Functions

1. **`functions/index.js` — `sendNotification`** (HTTPS, **Bearer** ID token on client):
   - Body: **`userIds`**, **`title`**, **`message`**, optional **`chatRoomId`**, **`chatRoomName`**, **`festivalId`**.
   - Loads **`users/{uid}`**, filters **`appIdentifier === "festivalrumor"`**, reads **`fcmToken`** or first **`fcmTokens[]`**.
   - Dedupes user IDs and tokens; **`sendEachForMulticast`** with notification + **data** (`type`, **`chatRoomId`**, **`festivalId`**).
   - Title can be prefixed with **`chatRoomName`** for context.

2. **`functions_comment/index.js` — `onCommentCreated`** (Firestore **`{collectionId}/{postId}/comments/{commentId}`** onCreate):
   - **Top-level comment** (no `parentCommentId`): notify **post owner only** — like Facebook (`post_comment`). The post owner does **not** get a separate push for *replies* to other people’s comments.
   - **Reply** (non-empty `parentCommentId`): notify **the author of that parent comment document only** — like Instagram (`comment_reply`).
   - Client today sets **`parentCommentId`** to the comment being replied to; the comment UI only starts a reply from **top-level** rows, so all replies in a thread share that top-level comment as parent (the notified user is that comment’s author). Self-comments are skipped.
   - FCM **data** includes **`postId`**, **`collectionName`**, and **`parentCommentId`** (for reply taps) for the client router.

### Client API wrapper

- **`NotificationServiceApi`** (`lib/services/notification_service.dart`): **`POST`** to **`…/sendNotification`** with Firebase Auth **ID token**.

---

## Key files (quick reference)

| Topic | Files |
|-------|--------|
| Global feed VM | `lib/ui/views/homeview/home_viewmodel.dart` |
| Rumours VM | `lib/ui/views/rumors/rumors_viewmodel.dart` |
| Firestore posts & chat | `lib/core/services/firestore_service.dart` |
| Chat VM | `lib/ui/views/chat/chat_view_model.dart` |
| FCM / navigation | `lib/util/firebase_notification_service.dart` |
| Comments UI / VM | `lib/ui/views/comment/comment_view.dart`, `comment_viewmodel.dart`, `comment_deep_link_view.dart`; spec [`comment-screen-architecture.md`](./comment-screen-architecture.md) |
| Local notifications | `lib/util/notification_service.dart` |
| Push HTTP API | `lib/services/notification_service.dart` |
| Badge / current room | `lib/core/services/chat_badge_service.dart`, `current_chat_room_service.dart` |
| Notification inbox | `lib/core/services/notification_storage_service.dart` |
| Background FCM | `lib/main.dart` (`firebaseMessagingBackgroundHandler`) |
| Chat push CF | `functions/index.js` |
| Comment push CF | `functions_comment/index.js` |

---

## Operational notes

- **Two function entry points**: main **`functions/`** (HTTP) vs **`functions_comment/`** (Firestore trigger) — split so deploy tooling does not mix Gen1 HTTP with Gen2-style metadata (see comments in `functions/index.js`).
- **Production URL**: `NotificationServiceApi` targets **`us-central1-crapapps-65472.cloudfunctions.net`**; ensure this matches your deployed project.
- **iOS / Android**: FCM payloads use **`chat_messages`** channel on Android; APNS sound/badge in Cloud Functions.

---

*Generated from codebase review; adjust if collection names or routes change in later versions.*
