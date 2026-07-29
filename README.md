# Flutter Chat App (Firebase Auth + Cloud Firestore only)

A WhatsApp-style real-time chat app. Text-only communication — no Firebase
Storage, no Firebase Cloud Messaging, no media/file sharing, as specified.

## Feature coverage

- **Auth**: register/login (email+password), update display name, logout.
- **Chats**: 1:1 chats, group chats, real-time sync via Firestore streams.
- **Messaging**: send/receive, edit, delete-for-me, delete-for-everyone,
  reply, forward, copy, pin, star/favorite, per-chat search, timestamps,
  delivery status (sent/delivered/read), read receipts, typing indicator,
  online/offline + last seen, date separators, swipe-to-reply, long-press
  action sheet, pagination (infinite scroll up), pull-to-refresh.
- **Reactions**: emoji reactions, all reactions shown per message, users can
  change/remove their own reaction.
- **Polls**: create poll messages with options, vote once, live results.
- **Location sharing**: share device coordinates, preview + "Open in Google
  Maps" (no map SDK/image — coordinates + external maps link, since Storage
  is excluded).
- **Chat management**: archive, pin to top, mark unread, clear history,
  delete conversation.
- **Groups**: create, rename, add/remove members, admin roles, leave group,
  member list.
- **Privacy**: toggle read receipts, last-seen visibility, online-status
  visibility, block/unblock users.
- **Search/filter**: global chat search, in-chat search, filter by
  unread/groups/archived/favorites.

## Setup

1. `flutter pub get`
2. Create a Firebase project → enable **Authentication (Email/Password)**
   and **Cloud Firestore**. Do **not** enable Storage or Cloud Messaging.
3. Run `flutterfire configure` (FlutterFire CLI) to generate
   `lib/firebase_options.dart` for your project — this repo ships a
   `firebase_options_template.dart` placeholder to replace.
4. Deploy the Firestore security rules in `firestore.rules` (see below) and
   the composite indexes Firestore will prompt for on first query use.
5. `flutter run`

## Firestore data model

```
users/{uid}
  displayName, email, photoInitial, status ("online"/"offline"),
  lastSeen, showLastSeen, showOnlineStatus, showReadReceipts,
  blockedUsers: [uid...]

chats/{chatId}
  type: "direct" | "group"
  participants: [uid...]
  admins: [uid...]                (groups only)
  groupName, groupCreatedBy       (groups only)
  lastMessage, lastMessageAt, lastMessageSenderId
  pinnedBy: [uid...]  archivedBy: [uid...]  unreadBy: {uid: count}
  typing: {uid: bool}

chats/{chatId}/messages/{messageId}
  senderId, text, type ("text"|"poll"|"location")
  createdAt, editedAt
  replyToId, replyToText, replyToSender
  deletedFor: [uid...]  deletedForEveryone: bool
  status: "sent"|"delivered"|"read"
  readBy: [uid...]  deliveredTo: [uid...]
  reactions: {uid: emoji}
  pinned: bool  starredBy: [uid...]
  poll: { question, options: [{text, votes:[uid...]}], allowMultiple }
  location: { lat, lng }
```

## Notes

- This scaffold focuses on correct architecture, Firestore-backed
  real-time state, and complete UI flows for every feature in the spec.
  Wire up your own Firebase project config before running.
- `geolocator` requires location permission entries in
  `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`
  (see Flutter docs for `geolocator` permission setup).
