# ORBE Phase 11 — Community Domain and Firestore Contract

Status: domain contract and design only. No Firestore, rules, indexes, Cloud Functions, data, providers, or production code were changed.

Date: 2026-09-03

## 1. Source of Truth and Scope

The primary source for this contract is [ORBE_PHASE_10_FIRESTORE_DOMAIN_AUDIT.md](ORBE_PHASE_10_FIRESTORE_DOMAIN_AUDIT.md), checked against the current Dart models and services.

This document defines the domain boundary and a future persistence contract. It does not create collections, documents, indexes, repositories, migrations, or live queries.

No live Firestore inventory was performed. The Firestore map below describes paths observed in repository code and rules.

## 2. Current State

The repository currently has persistence for:

- `users/{userId}` and user relationship subcollections;
- `posts/{postId}` and post interaction subcollections;
- `users/{userId}/stories/{storyId}` and story interaction subcollections;
- `chats/{chatId}/messages/{messageId}`;
- `groups/{groupId}/messages/{messageId}`;
- `memories` references and interaction paths;
- administrative, reports, configuration, notification, and system collections.

There is no canonical Firestore collection for `communities`, `topics`, `interests`, or Community membership.

Current local domain models:

- `SocialCommunity`: `id`, `name`, optional `description`, optional `SocialTopic`.
- `SocialTopic`: `id`, `title`, optional `description`, optional `parentTopicId`.
- `OrbMembership`: contextual explanation with `orbId`, `contextId`, `kind`, optional label, and relevance.
- `OrbUniverse`: transient context/projection containing a center, Orbs, context identifiers, and navigation-oriented state.

No current Dart service persists or loads `SocialCommunity` or `SocialTopic`.

## 3. Domain Model

The conceptual direction is:

```text
Topic       = subject or concept
Community   = social space organized around an interest/context
Membership  = persisted relationship between a user and a Community
OrbMembership = explanation for an Orb's presence in one context
Universe    = runtime projection of a domain context
```

These concepts must not be collapsed:

- `Community` is not a `Topic`.
- `Topic` is not a `Universe`.
- `OrbMembership` is not persisted Community membership.
- `InteractionScore` is not membership.
- `OrbUniverse` is not a Firestore aggregate by default.

### 3.1 Core domain versus persistence versus UI

| Concern | Owns | Must not own |
|---|---|---|
| Core domain | identity, name/title, relationships, lifecycle concepts, visibility concepts | `DocumentReference`, Firestore `Timestamp`, widgets, navigation controllers |
| Persistence adapter | Firestore field names, timestamps, document IDs, query mapping, serialization | presentation state, physics, selection, route transitions |
| UI/projection | `OrbUniverse`, center presentation, `OrbPosition`, renderer state, breadcrumbs | authoritative membership, authorization decisions, Firestore writes |

## 4. SocialCommunity Contract

`SocialCommunity` is currently intentionally minimal. The future core domain should add only fields required by product behavior:

| Field | Domain status | Justification |
|---|---|---|
| `id` | Required | Stable identity and route/context key |
| `name` | Required | User-visible identity |
| `description` | Optional | Context explanation; not required for a valid Community |
| `ownerId` | Required in persisted contract | Ownership and initial administration boundary |
| `topicIds` | Optional list | Supports one or more curated subject references without embedding a full Topic aggregate |
| `visibility` | Required in persisted contract | Needed to define discovery and read authorization |
| `status` | Required in persisted contract | Supports active/archived/suspended lifecycle without deleting history |
| `createdAt` / `updatedAt` | Required in persisted contract | Ordering, auditability, and cache invalidation |
| `imageUrl` or `iconKey` | Optional | Community identity; image storage remains a separate concern |
| `memberCount` | Optional derived field | Useful for discovery only if server-maintained and treated as non-authoritative |
| `metadata` | Restricted optional map | Extension point only for bounded, documented values; not a generic data dump |

`ownerId`, visibility, lifecycle, timestamps, and image identity are persistence/product contract concerns that are not present in the current local `SocialCommunity`. They must be added only when the persistence phase is approved.

No `DocumentReference` or Firebase-specific timestamp belongs in the domain object.

## 5. SocialTopic Contract

`SocialTopic` should be an independent, reusable subject identity. It can be referenced by a Community and can later be the center of a Topic Universe.

Current fields are sufficient for the local concept:

- `id`: stable topic identity;
- `title`: user-visible subject;
- `description`: optional explanation;
- `parentTopicId`: optional taxonomy relationship.

Future persisted fields may include a normalized key and lifecycle metadata, but no recommendation or ranking fields should be added to the Topic entity. Relevance remains a query/projection concern.

Recommended interpretation:

```text
Topic: Relatividade
  referenced by
Community: Física
  projected as
Topic Universe / Community Universe
```

A Topic may exist independently of a Community, but a Topic Universe should only be opened when the Topic record or an explicitly authorized local projection exists. Do not manufacture topics from arbitrary UI labels.

## 6. CommunityMembership Contract

`CommunityMembership` is a future persisted domain entity, distinct from `OrbMembership`.

### Required conceptual fields

| Field | Decision | Reason |
|---|---|---|
| `communityId` | Required | Identifies the context being joined |
| `userId` | Required | Identifies the member |
| `role` | Required with default `member` | Separates owner/moderation authority from ordinary membership |
| `status` | Required | Makes active, pending, blocked, and left states explicit |
| `joinedAt` | Required when active | Supports ordering and audit history |
| `updatedAt` | Required | Supports moderation/state changes and cache invalidation |

### Roles

Use only roles needed by current product policy:

- `owner`: owns and administers the Community;
- `moderator`: moderates according to future policy;
- `member`: ordinary active participant.

No additional role is justified by the current backend audit.

### States

- `active`: membership grants the documented Community access;
- `pending`: awaiting approval, if private/approval communities are supported;
- `blocked`: membership is denied or suspended by moderation;
- `left`: historical relationship retained without active access.

The current code does not establish whether private communities or approval flows are required. Therefore `pending` and `blocked` are contract capabilities, not implemented behavior.

## 7. OrbMembership Contract

`OrbMembership` answers: “Why is this Orb shown in this Universe?”

It is a local contextual projection and currently contains:

- `orbId`;
- `contextId`;
- `OrbMembershipKind`;
- optional display label;
- optional relevance value.

`OrbMembershipKind` currently includes relationship, membership, relevance, topic, participation, context, and unknown.

It must not become the authoritative source of Community access. A future adapter may derive it from `CommunityMembership`, Topic relations, Group membership, event participation, or authorized content context.

```text
CommunityMembership -> persisted authorization relationship
OrbMembership       -> runtime explanation for visual inclusion
InteractionScore    -> relevance/priority at display time
```

## 8. OrbUniverse Contract

`OrbUniverse` remains a transient projection/context object.

A persisted Community record may be projected as:

```text
CommunityRepository
  -> SocialCommunity
  -> bounded CommunityMembership/member projections
  -> OrbMembership explanations
  -> OrbUniverse.community()
  -> OrbRenderer / OrbPhysicsEngine
```

Do not persist:

- `OrbPosition` frame coordinates;
- physics velocity/targets;
- selected Orb;
- breadcrumb state;
- route state;
- renderer state.

The Universe may carry `contextId`, `parentId`, title/subtitle, center, and bounded Orbs at runtime. It should not duplicate the authoritative Community aggregate.

## 9. Firestore Contract — Proposed, Not Implemented

### 9.1 Recommended collection shape

```text
communities/{communityId}
  name
  description
  ownerId
  topicIds[]
  visibility
  status
  imageUrl or iconKey
  memberCount (derived/server-maintained, optional)
  createdAt
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
  parentTopicId (optional)
  createdAt
  updatedAt

community_topics/{relationId}
  communityId
  topicId
  createdAt
```

`membershipId` must have an explicitly documented uniqueness/idempotency strategy. A deterministic key derived from `communityId` and `userId` is a candidate, but must be validated against the selected query and security design before implementation.

Existing posts, stories, groups, chats, and memories should not be copied into new contextual collections by default. Contextual references should be designed separately only when product requirements demonstrate the need.

### 9.2 Why this schema

The recommended shape keeps community documents bounded, supports listing a user's Communities, supports membership checks, and enables reverse lookups without embedding thousands of members in a single document.

It requires:

- explicit rules for each operation;
- indexes based on actual queries;
- idempotent join/leave behavior;
- a decision on public metadata versus member-only metadata;
- server ownership of counts and moderation-sensitive fields.

None of these were implemented in Phase 11.

## 10. Alternatives Considered

### Option A — Members inside the Community document

```text
communities/{communityId}.members = [userId, ...]
```

Advantages:

- simplest read for very small groups;
- one document lookup for membership.

Disadvantages:

- unbounded document growth and write contention;
- poor pagination and member listing;
- difficult per-member role/status/audit data;
- array updates become expensive and harder to moderate;
- listing Communities for a user requires scanning Communities.

Decision: not recommended for real Communities.

### Option B — Community member subcollection

```text
communities/{communityId}/members/{userId}
```

Advantages:

- natural ownership boundary;
- straightforward list-members pagination;
- small Community document;
- intuitive security rules for a Community and its members.

Disadvantages:

- listing all Communities for a user requires collection-group querying or a reverse index;
- reverse topic/member discovery needs additional design;
- membership role and state queries require indexes and careful rules.

Decision: viable minimum schema for a small initial product, especially if the first query is “members of this Community.”

### Option C — Independent membership collection

```text
community_memberships/{membershipId}
```

Advantages:

- direct query for a user's Communities;
- direct query for a Community's members;
- flexible role/status lifecycle;
- easier future moderation, audit, and reverse relations;
- Community documents remain bounded.

Disadvantages:

- more indexes and rules;
- uniqueness/idempotency must be guaranteed;
- every query needs explicit authorization conditions;
- a Community read and membership read may require multiple reads or a repository-level composition.

Decision: recommended for the ORBE target because the product needs both Community Universe member listing and a future “my Communities” query. It should be introduced only with rules tests, pagination, and an idempotent membership key.

## 11. Query Contract

These operations are future repository/service contracts, not current APIs.

| Operation | Input | Output | Source | Authorization | Pagination/index notes |
|---|---|---|---|---|---|
| `getCommunity(id)` | `communityId` | nullable `SocialCommunity` | `communities/{id}` | public metadata or authenticated policy, to be decided | single document; no index |
| `listCommunities()` | caller, page size/cursor | page of discoverable Communities | `communities` | only discoverable/allowed status | order/filter index required after policy is fixed |
| `listUserCommunities(userId)` | `userId`, page size/cursor | page of active memberships plus Community summaries | `community_memberships` + community reads | self or authorized administrative access | filter `userId,status`; composite index likely |
| `isMember(userId, communityId)` | both IDs | membership status/role or null | membership document/query | self, Community moderator, or server policy | deterministic membership ID preferred; otherwise compound query |
| `listMembers(communityId)` | `communityId`, page size/cursor | bounded member projections | `community_memberships` + users | member/moderator policy | filter `communityId,status`; paginate; composite index likely |
| `listCommunitiesByTopic(topicId)` | `topicId`, page size/cursor | page of Community summaries | `community_topics` + communities | discoverability policy | filter `topicId`; index likely |
| `joinCommunity()` | `userId`, `communityId` | created/updated membership | membership collection | authenticated user; public/private policy | idempotent write; no client-controlled role |
| `leaveCommunity()` | `userId`, `communityId` | updated `left` state or deletion policy | membership collection | authenticated member; owner transfer policy required | idempotent state transition; preserve audit if required |
| `openCommunityUniverse()` | `communityId`, caller | transient `OrbUniverse` projection | community + bounded memberships/users | same as metadata/member reads | never load all members; cap visual Orbs |
| `openTopicUniverse()` | `topicId`, caller | transient Topic `OrbUniverse` | topic + approved relations | topic visibility policy | requires topic relation contract |
| `openGroupUniverse()` | `groupId`, caller | transient Group `OrbUniverse` | existing `groups/{id}` + authorized members | reuse existing group rules | do not duplicate chat/group membership |

No query contract above is implemented in this phase.

## 12. Security Contract

Current rules provide no path for `communities`, `topics`, `community_topics`, or `community_memberships`. New rules must be designed and tested before any collection is deployed.

Future policy questions and provisional boundaries:

| Operation | Provisional future boundary |
|---|---|
| Read Community | authenticated users for public metadata; private metadata requires explicit policy |
| Create Community | authenticated user; creator becomes owner; validation and rate limits required |
| Update Community | owner/moderator for allowed fields; immutable owner/audit fields |
| Delete Community | owner/admin policy; soft archive likely safer than destructive delete |
| Join Community | authenticated user; public join or pending approval according to visibility |
| Leave Community | active member; owner must transfer ownership or archive |
| Read members | member/moderator policy; public member visibility must be an explicit decision |
| Moderate Community | moderator/owner/admin only; action audit required |

Security risks that must block implementation until resolved:

1. Client-controlled `role`, `status`, `ownerId`, and `memberCount` writes.
2. Public metadata accidentally exposing private Community existence.
3. Membership enumeration through overly broad queries.
4. Join/leave races creating duplicate or resurrected membership records.
5. Group-like message access being inferred from Community membership without a documented rule.
6. Contextual content inheriting visibility incorrectly from a Community.
7. Collection-group queries that cannot express the intended privacy predicate safely.

## 13. Performance Contract

- Community documents must remain bounded; no unbounded `members` array.
- Member lists must be paginated and never loaded wholesale into the visual universe.
- `OrbUniverse` should receive a capped visual projection, approximately the existing 40–50 Orb scale, while search/repository results remain independent of rendering limits.
- Use one metadata read plus bounded member/content pages rather than a listener over all Community data.
- Realtime listeners should be scoped to a specific Community or group only when the product requires live behavior.
- Existing patterns to reuse: paginated posts with `startAfterDocument`, bounded story collection-group reads, and parent-scoped chat/group message streams.
- `InteractionScore` should operate on already-authorized bounded fields and must not cause one network read per Orb.
- `OrbMembership` is computed locally from returned relations; it does not justify a write per frame or per render.
- Derived `memberCount` is optional and must not be treated as an authorization source.
- Indexes should be added only after query shapes and cardinality are measured.

## 14. Repository Boundary

The recommended future dependency direction is:

```text
Firestore adapter
      ↓
CommunityRepository
      ↓
CommunityService
      ↓
SocialCommunity / SocialTopic / CommunityMembership
      ↓
OrbMembership projection
      ↓
OrbUniverse
      ↓
OrbRenderer / OrbPhysicsEngine
```

Responsibilities:

- `CommunityRepository`: Firestore paths, DTO mapping, cursors, authorization-aware reads/writes.
- `CommunityService`: domain operations and membership state transitions.
- Domain models: framework-independent values and invariants.
- Universe builder/projection: compose bounded domain data into transient `OrbUniverse`.
- UI/renderer: display and interaction callbacks only.

The Community page must not become the Firestore repository. Existing Personal Universe behavior should remain on its current `users` flow until an approved adapter is introduced.

## 15. Serialization Contract

Do not add `fromMap()`/`toMap()` to every class by convenience.

Recommended boundary:

- Persistence DTOs/adapters should own Firestore `fromMap`/`toMap` because field names and timestamp conversion are storage concerns.
- `SocialCommunity` and `SocialTopic` may receive serialization only when a repository is actually implemented and the field contract is stable.
- `CommunityMembership` should be serializable at the repository boundary because it is a persisted entity.
- `OrbMembership` currently needs only local construction; its existing `toMap()` is useful for diagnostics/tests but is not a Firestore contract.
- `OrbUniverse`, `OrbPosition`, physics state, selection, and breadcrumbs must remain non-persistent runtime state.

## 16. UserProfile Duplication Risk

Two overlapping models remain intentionally unchanged:

- `lib/models/user_profile.dart`: `id`, display name, bio, avatar, creation date, integer stats, Firestore `Timestamp` mapping. Used by profile services and broader app/domain paths.
- `lib/features/social/models/user_profile_model.dart`: `uid`, optional social fields, close-friend state, friends, pending requests, JSON/local-cache mapping. Used by `SocialProvider`.

Risks:

- `id` versus `uid` identity ambiguity;
- `name`/`displayName` and `photoUrl`/`avatarUrl`/`photoURL` drift;
- different serialization formats and timestamp handling;
- social relationship state diverging from profile state;
- future Community membership adapters selecting the wrong model.

Recommendation: converge only during a dedicated compatibility migration after import usage, caches, tests, and persisted field names are inventoried. Do not fix this as part of Community schema creation.

## 17. Migration Prerequisites

Before any backend change is authorized:

1. Confirm the live Firestore inventory against the repository audit.
2. Decide public/private Community discovery policy.
3. Decide whether Topic is globally reusable and who may create/rename it.
4. Approve the canonical membership key and idempotent join/leave semantics.
5. Approve the recommended independent membership collection or explicitly select another option.
6. Define field ownership for owner, role, status, counters, timestamps, and visibility.
7. Write and emulator-test Firestore rules before deployment.
8. Define required indexes from finalized query shapes.
9. Define bounded pagination and visual Orb caps.
10. Decide whether contextual content uses references to existing `posts`, `stories`, `memories`, `groups`, and `chats`, rather than copied documents.
11. Add repository contract tests with fake/emulator data explicitly marked as fixtures.
12. Define reversible backfill and rollback procedures.
13. Add observability for read counts, latency, denied reads, join/leave conflicts, and empty projections.

## 18. Phase 11 Decision Log

- Documentation only: approved.
- No collections created: confirmed.
- No documents or scripts executed: confirmed.
- No rules or indexes changed: confirmed.
- No Cloud Functions changed: confirmed.
- `OrbUniverse` remains transient: confirmed.
- `CommunityMembership` is distinct from `OrbMembership`: confirmed.
- `InteractionScore` remains distinct from membership: confirmed.
- `SocialTopic` is modeled as an independent reusable subject: recommended.
- Independent membership collection (Option C) is recommended, subject to security and query review.
- Personal Universe remains on the existing real `users` flow.
- UserProfile duplication remains documented and intentionally unresolved.

## 19. Explicit Non-Goals

This contract does not implement:

- Firestore collections or documents;
- membership writes or reads;
- Community/Topic repositories;
- Firestore rules or indexes;
- Cloud Functions;
- migration/backfill;
- recommendation algorithms;
- contextual feed/chat/media systems;
- changes to Personal Universe, CommunityPage, OrbRenderer, or OrbPhysicsEngine.
