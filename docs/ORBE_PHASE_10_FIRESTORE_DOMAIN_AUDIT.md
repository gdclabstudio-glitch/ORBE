# ORBE Phase 10 — Firestore and Domain Audit

Status: audit and design only. No Firestore, rules, indexes, Functions, data, or production code were changed.

Audit date: 2026-09-03

## Scope and Evidence

This audit covers the repository configuration, Dart services/models, Cloud Functions source, `firestore.rules`, and `firestore.indexes.json`. It describes the schema referenced by the repository. It does not claim to be a live-project inventory because no remote Firestore inspection was executed in this phase.

## Executive Summary

The current backend has real persistence for users, posts, chats, groups, stories, follows, notifications, memories, reports, and administrative/system data. It has no implemented `communities`, `topics`, `interests`, or community-membership collection.

`OrbUniverse`, `SocialCommunity`, `SocialTopic`, and `OrbMembership` are local domain/presentation models. They are not currently persisted and should remain projections/context objects until a product contract and security model exist.

The current Personal Universe can be backed by existing `users` data and existing relationship fields. A real Community Universe cannot yet be loaded from Firestore without introducing a new schema and rules. That work is intentionally deferred.

## Current Firestore Map

| Domain entity | Dart model/service | Firestore location | Observed fields/relations |
|---|---|---|---|
| User profile | `lib/models/user_profile.dart`, `lib/features/social/models/user_profile_model.dart`, `UserProfileService` | `users/{userId}` | `displayName`, `name`, `bio`, `avatarUrl`/`photoURL`, `stats`, `private`, `followers`, `following`, relationship request fields, presence-related fields used by Community |
| User stories | Story views/services | `users/{userId}/stories/{storyId}`; collection-group reads | `userId`, `authorName`, `authorPhoto`, `displayName`, `photoURL`, `createdAt`; 24-hour read window |
| Story reactions | `ReactionService`, story viewer | `users/{userId}/stories/{storyId}/reactions/{reactionId}` | Reaction owner and reaction id constraints in rules |
| Story views | Story viewer | `users/{userId}/stories/{storyId}/views/{viewerId}` | `viewerId`; owner/viewer access |
| Followers | Profile pages/outbox | `users/{userId}/followers/{followerId}` | `followerId`, `createdAt` |
| Following | Profile pages/outbox | `users/{userId}/following/{followedId}` | `userId`, `followingId`, `createdAt` |
| Follow requests | Profile pages/outbox | `users/{userId}/outgoingFollowRequests/{targetId}` and `incomingFollowRequests/{requesterId}` | requester/target IDs, `createdAt` |
| Notifications | Notification service/Functions | `users/{userId}/notifications/{noteId}` | server-created notifications; user read/update access |
| Post | `lib/models/post.dart`, `PostService`, SocialFeed | `posts/{postId}` | `userId`/`authorId` variants, author display fields, `content`, `avatarUrl`, `createdAt`, `isPinned` |
| Post comments | Post interaction/feed services | `posts/{postId}/comments/{commentId}` | `authorId`, text/content fields, `createdAt`; reactions below comments |
| Post reactions/likes | Reaction/feed services | `posts/{postId}/reactions/{reactionId}` and `posts/{postId}/likes/{userId}` | user-owned reaction/like records |
| Private chat | `ChatService` | `chats/{chatId}/messages/{messageId}` | chat parent has `participants` or legacy `members`; message has `senderId`, `createdAt`, delivery/read fields |
| Group | `GroupService`, `GroupChannelPage` | `groups/{groupId}` | `name`, `description`, `admins`, `members`; group messages below |
| Group messages | `GroupService` | `groups/{groupId}/messages/{messageId}` | `senderId`, `text`, `createdAt`; read/write membership checks |
| Memory | `Memory`, memory services/admin service | `memories/{memoryId}` is referenced by admin/outbox paths; some app memory implementations are local/abstract | `id`, `title`, description, dates, `imageUrls`, `ownerId` in Dart model; exact deployed document shape needs live confirmation |
| Memory interactions | Memory social service/outbox | `memories/{memoryId}/likes` and `memories/{memoryId}/comments` | referenced by services; rules for these paths are not present in the inspected `firestore.rules` excerpt |
| Friend requests | `SocialProvider` | top-level `friend_requests` | `from`, `to`, `status`, `createdAt` |
| Reports | moderation service/Functions | `reports/{reportId}` and legacy/client `moderation_reports` references | reporter/resource/category/status/reason metadata |
| Admin/system | admin services/Functions | `admin_profiles`, `admin_requests`, `admin_audit_logs`, `system_events`, `system_metrics`, `admin_config` | privileged operational data |
| Site/event configuration | `ContentService`, `EventConfig` | `site_config/{documentId}`, `gallery/{year}` | event/site configuration and gallery; `EventConfig` is also local configuration |
| Broadcast/announcements | notification/admin services | `broadcasts`, `official_announcements` | administrative communication |
| Rankings/metrics | ranking/admin services | `userStats`, `system_metrics` | derived/statistical data |

## Models and Duplication Risks

### User profiles

There are two separate `UserProfile` classes:

- `lib/models/user_profile.dart`: `id`, `displayName`, `bio`, `avatarUrl`, `createdAt`, integer `stats`; Firestore `Timestamp` mapping.
- `lib/features/social/models/user_profile_model.dart`: `uid`, optional `name/email/photoUrl/status`, close-friend flag, friends and pending requests; JSON/local-cache mapping.

They serve different callers today, but they represent overlapping profile concepts. This is a future consolidation risk. No consolidation is recommended during this audit because it could affect cached data, imports, and profile flows.

### Existing content models

- `Post` exists at `lib/models/post.dart` and is persisted under top-level `posts`.
- Story data is currently map-shaped at the feature boundary rather than represented by a single shared Story model.
- `Memory` exists at `lib/features/memories/models/memory.dart`; its service abstraction supports local/in-memory implementations, while Firestore usage is spread across admin/outbox/social services.
- There is no canonical Dart `Community`, `Topic`, `Interest`, or `Conversation` domain model.
- `GroupService` accesses real `groups`, but there is no dedicated immutable Group model in the inspected feature layer.
- Chat is represented by service payload maps and Firestore documents rather than one shared Conversation model.
- `EventConfig` is application/event configuration, not a persisted Community/Event aggregate.

## Existing ORBE Domain Mapping

```text
Existing users and relationship fields
        -> CommunityNode
        -> SocialOrb(type: person)
        -> Personal OrbUniverse projection
        -> OrbPhysicsEngine / OrbRenderer
```

```text
Future contextual domain (not persisted today)
SocialTopic       -> topic identity/context
SocialCommunity   -> shared interest/context
OrbMembership     -> why an Orb belongs to a context
OrbUniverse       -> presentation/navigation projection of that context
```

`OrbMembership` and `InteractionScore` must remain separate. Membership answers why an entity is in a context; score answers how relevant it is at a moment in time.

## Membership Findings

No existing community membership representation was found. In particular, the repository does not use:

- `communities/{id}/members/{uid}`;
- `community_memberships`;
- `users/{uid}/communities`;
- `community.members` in an implemented Community collection.

Existing membership-like structures are limited to:

- `groups/{groupId}.members` for group message authorization;
- `chats/{chatId}.participants` or legacy `.members` for chat authorization;
- user follow/friend arrays and subcollections;
- story ownership through the user document path.

No membership schema should be selected until the product decides whether community membership is public, private, approval-based, role-bearing, or discoverable.

## Security Audit

No rules were changed. Current observed rules imply:

- `users`: authenticated reads subject to owner/follower/public-profile privacy; users create their own profile and update only an allow-listed set of fields.
- User stories: owner/server writes; reads require authentication, non-expired `createdAt`, and public/follower/owner access.
- Followers/following/request subcollections: access is restricted to the relevant user, target, server, or admin according to operation.
- `posts`: authenticated reads; creation is author-owned or server; updates/deletes are author/admin/server controlled.
- `chats`: reads and messages require membership in `participants` or legacy `members`.
- `groups`: group documents are readable by any authenticated user; group updates/deletes are admin or group-admin controlled; group messages require the caller to be in the group's `members` array.
- `reports` and administrative/system collections: privileged reads and server/admin-controlled updates.
- Default rule: unmatched paths deny read and write.

There is currently no rule path for `communities`, `topics`, `interests`, or community membership. Adding any of those collections would require an explicit security design and rules review before deployment.

Open security questions for a future schema:

1. Can unauthenticated users discover community metadata?
2. Can any authenticated user list members, or only members/moderators?
3. Who can join/leave and who can approve membership?
4. Which roles can edit community identity and moderate contextual content?
5. Are private communities and blocked users supported?
6. Should content visibility be inherited from community membership or evaluated per content item?

## Query Inventory for a Future ORBE Universe

| Query | Current feasibility | Future concern |
|---|---|---|
| List communities | Not available | Needs a real collection and visibility predicate |
| Get community by ID | Not available | Needs identity/read rules |
| Check membership | Not available | Needs canonical membership source |
| List members | Not available | Must be paginated; privacy and moderation rules required |
| List topics | Not available | Requires independent Topic collection or a documented denormalized field |
| Communities by topic | Not available | Likely needs an index or a reverse relation |
| Contextual content | Not available | Requires explicit context fields on existing content or a relation collection |
| Open Community Universe | Local-only today | Can project a fetched community plus bounded related entities |
| Open Topic Universe | Local-only today | Requires topic identity and relation query |
| Open Group Universe | Partially available | Existing group documents/messages exist; member listing and group identity model need normalization |
| Personal Universe people | Available | Existing Community query currently streams `users` ordered by `displayName`; no community filter |
| Recent stories | Available | Collection-group query is bounded to 60 active stories and indexed by `createdAt` |
| Posts | Available | Paginated by pinned status and `createdAt`, with an existing composite index |

No new query, index, listener, or collection was added in this phase.

## Performance Findings

- The current Community reads the `users` collection ordered by `displayName` and filters locally. This is acceptable only for the current bounded product scope; it is not a scalable community-member query for thousands of users.
- Stories already use a bounded collection-group query (`limit(60)`) and a 24-hour window.
- Posts use pagination and `startAfterDocument`, which is the correct pattern to reuse for contextual feeds later.
- Group and chat messages are streamed per parent context, which is preferable to a global message listener.
- A future Community Universe should never stream all members/content. It should fetch community metadata once, page members/content, and cap the visual projection to the most relevant Orbs.
- `InteractionScore` should be computed from bounded, authorized data or server-derived fields; it should not require per-orb network calls.
- `OrbUniverse` and orbital positions should remain transient. Positions must not be written per frame.

## Schema Proposals

These are proposals only and were not applied.

### A. Minimum schema

Use when the first real community feature is ready:

```text
communities/{communityId}
  name
  description
  imageUrl or iconKey
  topicId (optional)
  visibility
  createdAt
  createdBy
  updatedAt

communities/{communityId}/members/{userId}
  role
  status
  joinedAt
  updatedAt
```

The client would build an `OrbUniverse` projection from community metadata plus a bounded member page. `OrbMembership` would remain a client/domain representation of the fetched membership record, not a UI-only guess.

### B. Recommended schema

Prefer a canonical membership relation for querying, moderation, and role changes, while keeping community documents small:

```text
communities/{communityId}
  name
  description
  imageUrl or iconKey
  visibility
  topicIds[] (small, curated set only)
  memberCount (server-maintained)
  createdAt
  createdBy
  updatedAt

community_memberships/{membershipId}
  communityId
  userId
  role
  status
  joinedAt
  updatedAt

 topics/{topicId}
  title
  description
  normalizedKey
  createdAt
  createdBy

community_topics/{relationId}
  communityId
  topicId
  createdAt

contextual_content/{relationId}
  contextType
  contextId
  contentType
  contentId
  createdAt
  relevanceSource
```

This supports membership checks and reverse lookups without putting an unbounded member list in a community document. It requires carefully designed rules, query indexes, uniqueness/idempotency handling, and probably server-maintained counts. It must not be implemented without approval.

### C. Future evolution

Only after real usage and authorization requirements are known:

- role/permission documents for moderators;
- approval requests and bans;
- denormalized discovery summaries;
- materialized contextual feeds;
- server-computed relevance/search projections;
- group/community relationship documents;
- content visibility and moderation state per context.

These are intentionally outside Phase 10.

## Universe Persistence Decision

`OrbUniverse` should remain a transient projection/context object, not a Firestore entity, for the foreseeable next phase.

Reasons:

- It combines navigation state, visual center, bounded Orbs, and presentation context.
- Its positions, physics state, selection, depth, and breadcrumbs are UI/runtime state.
- Persisting it would duplicate Community/Topic/Group domain data and create synchronization problems.
- Existing Firestore entities can be projected into it when the underlying schema is approved.

Persist only domain entities and relations that must exist independently of the UI. Do not persist physics state or frame positions.

## Safe Migration Plan

### Phase A — Read-only compatibility

- Confirm the live schema against the repository audit.
- Define canonical `Community`, `Topic`, membership, and visibility contracts.
- Add read-only adapters/models only after the contract is approved.
- Keep Personal Universe on existing `users` and relationship data.

### Phase B — New entities

- Create the approved collections and rules in a separate reviewed change.
- Add indexes only from measured query requirements.
- Add emulator/rules tests for membership, privacy, moderation, and pagination.
- Backfill only with an explicit, reversible migration plan.

### Phase C — Service integration

- Add repositories/services with bounded reads and pagination.
- Map fetched records to `SocialCommunity`, `SocialTopic`, `OrbMembership`, and `OrbUniverse` projections.
- Keep `InteractionScore` separate from membership and preserve existing fallbacks.

### Phase D — Real Community Universe

- Load community metadata and a bounded member page.
- Render only a capped set of relevant Orbs.
- Keep profile/chat/feed routes unchanged.
- Add observability for read counts, latency, empty results, and authorization failures.

### Phase E — Real Topic Universe

- Resolve topic identity and community/topic relations.
- Add contextual content only when an authorized relation exists.
- Preserve breadcrumb and UniverseStack behavior.

### Phase F — Real Group Universe

- Reuse existing `groups/{groupId}` and message authorization.
- Introduce a typed Group adapter only after field conventions are documented.
- Do not create a parallel chat or membership system.

## Gaps and Risks

1. No persisted Community or Topic schema exists.
2. No community membership authorization exists in rules.
3. User profile fields have naming/ownership variations (`id` vs `uid`, `name` vs `displayName`, `avatarUrl` vs `photoURL`).
4. There are two overlapping UserProfile models.
5. Story and chat payloads are partly map-based rather than canonical shared models.
6. Memory Firestore usage is distributed and its exact deployed schema needs confirmation.
7. Current Community local filtering over `users` will not scale to large communities.
8. Existing `groups` document reads are broad, while message reads are membership-gated; a future Group Universe must preserve that distinction.
9. No live Firestore inventory was performed in this repository-only audit.

## Phase 10 Decision Log

- No Firestore changes: approved.
- No rules changes: approved.
- No indexes: approved.
- No Cloud Functions: approved.
- No data migration: approved.
- No new collections: approved.
- `OrbUniverse` persistence: defer; keep it as a transient projection.
- Community membership schema: defer until product/security contract approval.
- Topic persistence shape: defer; current code does not establish whether Topic is independent or a relation attribute.
- Personal Universe: preserve existing real-user path and InteractionScore behavior.
