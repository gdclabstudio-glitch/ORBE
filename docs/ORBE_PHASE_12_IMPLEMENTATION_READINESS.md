# ORBE Phase 12 — Community Implementation Readiness and Migration Design

Status: technical specification only. No production implementation was performed.

Date: 2026-09-03

> Nenhuma decisão deste documento constitui alteração de produção. A implementação somente poderá começar após aprovação explícita da Fase 12.

## 1. Objective of the Future Implementation

The first real Community implementation should allow ORBE to represent a persisted shared context and project it into a bounded `OrbUniverse` without replacing the existing Personal Universe.

### MVP

- Read a Community by stable ID.
- Read its public identity and lifecycle state.
- Determine the authenticated user's membership and role.
- List members through bounded, paginated reads.
- Create and update Communities under explicit ownership rules.
- Join and leave according to visibility and lifecycle policy.
- Project a Community and a bounded member set into `OrbUniverse.community()`.
- Preserve `OrbMembership` as the explanation for visual inclusion and `InteractionScore` as relevance.
- Reuse existing `users` profiles without duplicating user documents.

### Post-MVP

- Approval-based membership using `pending`.
- Moderator roles and moderation actions.
- Reusable Topic references and Community/Topic discovery.
- References to existing posts, stories, memories, groups, or chats where authorized.
- Server-maintained member counters and discovery projections.
- Offline cache and observability for contextual reads.

### Future

- Contextual feeds and recommendations.
- Community-specific moderation policy and permissions.
- Topic and Group Universe composition with real relations.
- Search projections and materialized relevance.
- Community analytics and advanced lifecycle states.

None of these operations are implemented by this document.

## 2. Final Domain Model

The domain/persistence boundary is:

```text
Firestore adapter
    -> repository DTOs
    -> SocialCommunity / SocialTopic / CommunityMembership
    -> OrbMembership projection
    -> OrbUniverse projection
    -> UI
```

Domain models must not import Firebase types, widgets, navigation, or physics code.

### 2.1 SocialCommunity

**Responsibility:** represent the identity and lifecycle of a shared social context.

**Identity:** stable `communityId`.

**Required domain fields:**

- `id`;
- `name`.

**Optional domain fields:**

- `description`;
- owner identity;
- topic references;
- visibility;
- lifecycle status;
- created/updated instants;
- image identity;
- bounded metadata.

**Invariants:**

- `id` and `name` are non-empty;
- owner, visibility, and lifecycle values come from controlled enums/values;
- topic references identify Topics and do not embed arbitrary Topic documents;
- member counts, if present, are derived and never authorization sources;
- metadata is bounded and documented.

**Must not contain:** `DocumentReference`, `Timestamp`, Firestore paths, membership lists of unbounded size, UI state, Orb positions, physics state, or route state.

Current implementation note: [social_community.dart](../lib/features/social/models/social_community.dart) currently contains only `id`, `name`, optional `description`, and optional `SocialTopic`. The future persistence fields above are contract fields, not current code changes.

### 2.2 SocialTopic

**Responsibility:** represent a reusable subject, concept, or taxonomy node.

**Identity:** stable `topicId`.

**Required:** `id`, `title`.

**Optional:** `description`, `parentTopicId`, normalized lookup key, lifecycle timestamps when persistence is approved.

**Invariants:**

- `id` and `title` are non-empty;
- a parent reference cannot create an unchecked cyclic taxonomy;
- Topic does not own Community membership;
- Topic relevance is computed in projections/queries, not stored as business truth on the Topic.

**Must not contain:** Community member lists, Firebase types, renderer state, or recommendation scores.

Current implementation note: [social_topic.dart](../lib/features/social/models/social_topic.dart) currently contains `id`, `title`, `description`, and `parentTopicId`.

### 2.3 CommunityMembership

**Responsibility:** represent the authoritative persisted relationship between one user and one Community.

**Identity:** deterministic membership ID derived from `communityId` and `userId` is recommended; see Section 5.

**Required fields:**

- `membershipId`;
- `communityId`;
- `userId`;
- `role`;
- `status`;
- `createdAt`;
- `updatedAt`.

**Invariants:**

- `communityId` and `userId` are non-empty;
- a membership references exactly one Community and one user;
- client input cannot self-assign owner/admin/moderator;
- only approved transitions can change `status`;
- timestamps are server-controlled;
- an active membership is unique for the pair `(communityId, userId)`.

**Must not contain:** Orb position, score, renderer state, Firebase `DocumentReference`, or copied user profile data beyond deliberately bounded display projections.

### 2.4 OrbMembership

**Responsibility:** explain why an Orb appears in the current Universe.

Current fields: `orbId`, `contextId`, `kind`, optional `label`, optional `relevance`.

**Invariants:**

- `contextId` identifies the current runtime context;
- `kind` describes contextual inclusion, not authorization;
- `relevance` is optional display/projection input and is not an access decision;
- unknown relationships remain `unknown`.

**Must not replace:** `CommunityMembership` or security rules.

### 2.5 OrbUniverse

**Responsibility:** transient presentation/navigation projection of a domain context.

Current/future fields include `id`, `UniverseType`, title, center Orb, context identifiers, parent ID, bounded Orbs, and local memberships.

**Invariants:**

- exactly one explicit center exists in a Universe projection;
- the center is not treated as an ordinary member Orb;
- positions, physics, selection, breadcrumbs, and route state are runtime-only;
- a Universe can be reconstructed from authorized domain data;
- no persistence is implied by the existence of a Universe.

### 2.6 InteractionScore

**Responsibility:** represent relative relevance/priority for display and layout.

Current components are social relevance, interaction frequency, relationship strength, activity, recency, and presence.

**Invariants:**

- score is bounded by its configured maximum;
- normalization is presentation input;
- score does not grant access or membership;
- score calculation remains in `InteractionScoreService` or a future projection service;
- contextual relevance may be added later as an input, but must not silently change current Personal Universe semantics.

**Must not contain:** authorization, membership status, Firebase references, or UI navigation state.

## 3. Recommended Firestore Model

The following names and shapes are **PROPOSAL ONLY**. They were not created or deployed.

### 3.1 Community document

```text
communities/{communityId}
```

Recommended document ID: immutable generated ID or an approved stable product slug. The ID must not be derived from mutable display names.

Recommended fields:

| Field | Firestore type | Ownership/meaning |
|---|---|---|
| `name` | string | owner/moderator-controlled identity |
| `description` | string, optional | bounded explanatory text |
| `ownerId` | string | server/creation flow controlled |
| `topicIds` | array<string>, optional | curated Topic references; bounded |
| `visibility` | string | controlled value, e.g. `public` or `private` |
| `status` | string | controlled lifecycle, e.g. `active`, `archived`, `suspended` |
| `imageUrl` or `iconKey` | string, optional | identity only; Storage policy separate |
| `memberCount` | integer, optional | derived/server-maintained; never authorization |
| `createdAt` | server timestamp | immutable creation time |
| `updatedAt` | server timestamp | server-controlled update time |

### 3.2 Membership document

```text
community_memberships/{membershipId}
```

Required fields:

| Field | Firestore type | Meaning |
|---|---|---|
| `communityId` | string | target Community |
| `userId` | string | member user |
| `role` | string | proposed values below |
| `status` | string | proposed lifecycle below |
| `createdAt` | server timestamp | relationship creation time |
| `updatedAt` | server timestamp | latest lifecycle change |

No Firebase references are stored in the domain model. Firestore references, if ever useful to an adapter, remain persistence-only implementation details.

### 3.3 Topic document

```text
topics/{topicId}
```

Proposed fields:

- `title`: string;
- `description`: bounded optional string;
- `normalizedKey`: string for controlled lookup;
- `parentTopicId`: optional string;
- `createdAt`: server timestamp;
- `updatedAt`: server timestamp.

A separate `community_topics/{relationId}` collection remains a possible proposal if many-to-many Topic relations cannot be represented safely by a bounded `topicIds` array.

### 3.4 Roles

**Proposed values:**

- `owner`: one accountable owner per Community;
- `admin`: administrative delegate, only if product policy requires it;
- `moderator`: content/member moderation authority;
- `member`: ordinary active participant.

`admin` is a proposal beyond the currently observed backend. It must not be introduced unless its authority is specified separately from owner/moderator.

### 3.5 Statuses

**Proposed values:**

- `active`: access is granted;
- `pending`: approval is required or in progress;
- `blocked`: access is denied/suspended;
- `left`: historical relationship is inactive.

The current backend does not establish whether private approval flows or historical membership retention are required. These statuses therefore remain proposal capabilities.

## 4. CommunityMembership Contract

The canonical conceptual contract is:

```text
CommunityMembership {
  membershipId
  communityId
  userId
  role
  status
  createdAt
  updatedAt
}
```

The repository adapter owns conversion between server timestamps and domain instants. The domain must not depend on Firebase timestamp classes.

Additional fields such as `approvedBy`, `blockedBy`, `leftAt`, or audit reason are intentionally excluded from the MVP contract. They should be added only when moderation and audit requirements justify them.

## 5. Membership Identity

### Option A — Deterministic ID from user and Community

Example conceptual key:

```text
membershipId = normalized(communityId) + "_" + normalized(userId)
```

Advantages:

- idempotent join/create behavior;
- direct `isMember`/`getMembership` lookup;
- prevents duplicate active relationships for the same pair;
- no query required just to discover the document ID;
- predictable security rule target.

Risks:

- key normalization must be stable and collision-free;
- changing identity conventions later is costly;
- client must not be allowed to choose another user's pair.

### Option B — Auto-ID

Advantages:

- simple Firestore creation;
- no key-format policy.

Risks:

- duplicate memberships require a query or transaction check;
- concurrent joins can race;
- `isMember` requires a compound query;
- cleanup and idempotency become service concerns.

### Option C — Alternative composite namespace

A subcollection document ID `{userId}` under `communities/{communityId}/members/{userId}` gives deterministic identity, but does not directly support the required “list Communities for user” query without a reverse relation or collection-group strategy.

### Recommendation

Recommend **Option A**, with a repository-owned deterministic key and server-validated normalization. The client supplies the intended Community operation, not an arbitrary membership ID. Join should be idempotent, and a transaction or server-controlled write must prevent role/status escalation.

## 6. Query Contract

These are future contracts, not implemented functions.

### `getCommunity(communityId)`

- **Input:** stable Community ID.
- **Output:** nullable `SocialCommunity` or typed not-found result.
- **Filter/order:** direct document lookup; require `status` policy at adapter/service boundary.
- **Pagination:** none.
- **Authentication:** provisional authenticated access; public metadata remains an open policy decision.
- **Errors:** invalid ID, not found, permission denied, unavailable.
- **Indexes:** none for direct lookup.

### `listCommunities(pageSize, cursor)`

- **Input:** caller visibility context, bounded page size, optional cursor.
- **Output:** page of discoverable `SocialCommunity` summaries plus next cursor.
- **Filter/order:** likely `status == active`, visibility predicate, stable `updatedAt` or `createdAt` ordering.
- **Pagination:** cursor-based; never unbounded.
- **Authentication:** likely required under current app policy.
- **Errors:** invalid page size, permission denied, unavailable.
- **Indexes:** probable composite index for visibility/status/order, finalized only after policy.

### `listUserCommunities(userId, pageSize, cursor)`

- **Input:** user ID, bounded page size, cursor.
- **Output:** active membership projections and Community summaries.
- **Filter/order:** membership `userId == target`, `status == active`, stable `updatedAt`/`createdAt` ordering.
- **Pagination:** cursor-based over memberships.
- **Authentication:** self or privileged service; arbitrary user enumeration must be denied.
- **Errors:** unauthenticated, forbidden target, invalid cursor, unavailable.
- **Indexes:** likely membership `(userId, status, updatedAt)`.

### `isMember(userId, communityId)`

- **Input:** both stable IDs.
- **Output:** boolean or membership status; service should prefer `getMembership` when role is needed.
- **Filter/order:** deterministic document lookup recommended.
- **Pagination:** none.
- **Authentication:** self, authorized moderator/owner, or server.
- **Errors:** invalid IDs, forbidden lookup, unavailable.
- **Indexes:** none with deterministic ID.

### `getMembership(userId, communityId)`

- **Input:** both IDs.
- **Output:** nullable `CommunityMembership`.
- **Filter/order:** direct deterministic membership lookup.
- **Pagination:** none.
- **Authentication:** same as `isMember`.
- **Errors:** invalid IDs, forbidden lookup, unavailable.
- **Indexes:** none with deterministic ID.

### `listMembers(communityId, pageSize, cursor)`

- **Input:** Community ID, bounded page size, cursor.
- **Output:** bounded member/profile projections plus next cursor.
- **Filter/order:** `communityId == id`, normally `status == active`, stable `createdAt` or `updatedAt` order.
- **Pagination:** mandatory cursor pagination.
- **Authentication:** policy-dependent; member/moderator access must be explicit.
- **Errors:** Community not found, forbidden, invalid cursor, unavailable.
- **Indexes:** likely `(communityId, status, createdAt)`.

### `listCommunitiesByTopic(topicId, pageSize, cursor)`

- **Input:** Topic ID, page size, cursor.
- **Output:** discoverable Community summaries.
- **Filter/order:** relation query or bounded `topicIds` array with active/visibility policy.
- **Pagination:** cursor-based.
- **Authentication:** policy-dependent.
- **Errors:** invalid Topic, forbidden, unavailable.
- **Indexes:** likely relation `(topicId, createdAt)` or array membership plus status/order, subject to measured query shape.

## 7. Mutation Contract

These operations are proposals only.

### `createCommunity`

- **Actor:** authenticated user.
- **Preconditions:** valid name, policy permits creation, rate limit passes.
- **Mutations:** create Community with server-controlled `ownerId`, `status`, timestamps; create owner membership atomically.
- **Effects:** one Community and one active owner membership.
- **Idempotency:** caller-provided request id or deterministic operation key recommended.
- **Conflicts:** duplicate requested slug/name policy; owner membership creation race.
- **Rules needed:** creator-only create, immutable owner, no client role escalation, atomic ownership.

### `updateCommunity`

- **Actor:** owner or authorized admin/moderator for explicitly allowed fields.
- **Preconditions:** Community active, actor role valid.
- **Mutations:** update name/description/identity fields; server updates timestamp.
- **Effects:** existing memberships remain unchanged.
- **Idempotency:** same field update is safe.
- **Conflicts:** stale update and concurrent moderation/archive.
- **Rules needed:** field allow-list, immutable IDs/owner/audit fields.

### `joinCommunity`

- **Actor:** authenticated user for self.
- **Preconditions:** Community exists and is joinable; user is not blocked; no active membership.
- **Mutations:** create or transition deterministic membership to `active` or `pending`.
- **Effects:** optional server-maintained count update; no copied user document.
- **Idempotency:** repeated join returns current active/pending state.
- **Conflicts:** concurrent leave/block/approval.
- **Rules needed:** self-only user ID, no role control, visibility and blocked-state checks.

### `leaveCommunity`

- **Actor:** active member; owner requires transfer/archive policy.
- **Preconditions:** membership exists and is active/pending.
- **Mutations:** transition to `left` or approved deletion policy.
- **Effects:** no access as active member; audit retention policy applies.
- **Idempotency:** repeated leave is safe.
- **Conflicts:** owner leaving, concurrent moderation or rejoin.
- **Rules needed:** self-only leave, owner protection, no arbitrary membership deletion.

### `approveMembership`

- **Actor:** owner/admin/moderator only if approval policy exists.
- **Preconditions:** membership is `pending`, Community active.
- **Mutations:** transition to `active`; server-controlled `updatedAt`.
- **Effects:** member gains the documented access.
- **Idempotency:** approving active membership is a no-op.
- **Conflicts:** blocked/left transition or concurrent decision.
- **Rules needed:** role check, valid transition, immutable user/community IDs.

### `removeMember`

- **Actor:** owner/admin/moderator according to moderation policy.
- **Preconditions:** target membership exists; actor may remove target; owner cannot be removed without transfer policy.
- **Mutations:** transition to `blocked` or `left`, depending on moderation semantics.
- **Effects:** access revoked; audit event may be required.
- **Idempotency:** repeated removal is safe.
- **Conflicts:** rejoin race, role changes, owner protection.
- **Rules needed:** target authorization, no self-escalation, immutable audit fields.

### `changeMemberRole`

- **Actor:** owner or explicitly authorized admin.
- **Preconditions:** target membership active; target role transition allowed.
- **Mutations:** change only `role`; update timestamp.
- **Effects:** permission boundary changes.
- **Idempotency:** setting current role is a no-op.
- **Conflicts:** two owners/admins changing the same member.
- **Rules needed:** client cannot assign owner/admin; role transition and last-owner protection.

## 8. Security Contract

The current rules have no paths for proposed Community collections. This section is a future intent map only and must be converted into tested rules before implementation.

| Operation | Future security intent |
|---|---|
| Read public Community | authenticated users may read only active/discoverable metadata, if product policy approves |
| Read private Community | only members, invitees, moderators, owners, or server according to explicit policy |
| Create Community | authenticated user may create; owner and timestamps are server-controlled |
| Update Community | owner/admin/moderator only for allow-listed fields |
| Delete Community | prefer archive/soft lifecycle; destructive delete restricted to owner/admin/server |
| Read own membership | authenticated user may read their own membership |
| Read another user's membership | deny by default; allow only authorized moderation/service paths |
| Read members | explicit public/member/moderator policy; no accidental enumeration |
| Join public Community | authenticated self-join only; no client role/status control |
| Join private Community | create `pending` only if approval policy exists |
| Leave Community | authenticated member may leave; owner transfer rule required |
| Approve membership | owner/admin/moderator only, if role is granted |
| Remove member | owner/admin/moderator only; owner cannot be removed casually |
| Change role | owner/admin only; protect last owner and immutable identity fields |
| Contextual content | access must be evaluated per content type; Community membership must not automatically expose private stories/chats |

Unresolved security decisions block deployment:

- public versus private discovery;
- member-list visibility;
- approval policy;
- whether moderators may change membership status;
- owner transfer and deletion policy;
- whether membership can be queried by moderators for arbitrary users;
- content visibility inheritance.

No rules were modified.

## 9. Index Strategy

No index file was changed. The following are planning candidates only.

### Probably required when implemented

| Collection | Fields and direction | Reason |
|---|---|---|
| `community_memberships` | `userId ASC`, `status ASC`, `updatedAt DESC` | list active Communities for a user |
| `community_memberships` | `communityId ASC`, `status ASC`, `createdAt ASC` | paginated member listing |
| `community_topics` or equivalent | `topicId ASC`, `createdAt DESC` | list Communities by Topic |

### Likely, depending on policy

| Collection | Fields and direction | Reason |
|---|---|---|
| `communities` | `visibility ASC`, `status ASC`, `updatedAt DESC` | discoverable Community listing |
| `communities` | `topicIds ARRAY_CONTAINS`, `status ASC`, `updatedAt DESC` | direct Topic filtering if bounded arrays are retained |
| `topics` | `normalizedKey ASC`, `status ASC` | exact/normalized Topic lookup if lifecycle is added |

### Future-only

- contextual content relation indexes;
- moderation queues by status/time;
- analytics or popularity ordering;
- recommendation/relevance projections.

Indexes must be generated from finalized query shapes and measured cardinality, not from this document alone.

## 10. Repository Boundary

The future architecture is:

```text
Firestore DTO/adapter
        ↓
CommunityRepository
        ↓
CommunityService
        ↓
SocialCommunity / SocialTopic / CommunityMembership
        ↓
Universe projection builder
        ↓
OrbMembership / OrbUniverse
        ↓
OrbRenderer / OrbPhysicsEngine / UI
```

### CommunityRepository

Owns collection paths, document IDs, DTO serialization, server timestamp conversion, cursors, pagination, and persistence errors. It must not know widgets, routes, animation, or physics.

### CommunityService

Owns domain operations, lifecycle transitions, authorization-aware orchestration, idempotency, and conflict handling. It must not render or persist Orb positions.

### Domain models

Own stable concepts and invariants without Firebase imports. They must not decide whether a caller is authorized; authorization is enforced by service and rules.

### Universe projection

Combines authorized Community, Topic, membership, user, and bounded relation data into transient `OrbUniverse` and `OrbMembership` values.

### UI/social layer

Continues using `CommunityPage`, `CommunityBubbleMap`, `CommunityNode`, `SocialOrb`, `OrbRenderer`, and existing routes. The current Personal Universe must remain on its `users` flow until a separate integration is approved.

`InteractionScore` ranks/display-prioritizes entities; it never authorizes access.

## 11. Migration Strategy

### Phase A — Schemas and models

- **Dependencies:** approved domain contract and open security decisions.
- **Work:** implement/validate DTOs and domain adapters without writes.
- **Risk:** field mismatch with live data.
- **Rollback:** remove new adapter code; no data impact.
- **Validation:** unit tests for invariants and serialization fixtures.

### Phase B — Repository

- **Dependencies:** finalized collection names, identity strategy, query shapes.
- **Work:** read/write repository behind interfaces; no UI integration.
- **Risk:** incorrect paths, cursors, or timestamp conversion.
- **Rollback:** disable repository wiring; no existing collections changed.
- **Validation:** fake/emulator repository tests and error mapping.

### Phase C — Read-only

- **Dependencies:** deployed schema and rules, or approved emulator-only environment.
- **Work:** read Community/Topic/membership and build projections.
- **Risk:** unauthorized reads, excessive fan-out, privacy leaks.
- **Rollback:** feature flag/read path off; Personal Universe remains unchanged.
- **Validation:** rules tests, pagination tests, read-count/latency telemetry.

### Phase D — Membership mutations

- **Dependencies:** approved lifecycle, deterministic identity, security rules, conflict policy.
- **Work:** join/leave/approve/remove/role transitions.
- **Risk:** duplicate memberships, role escalation, race conditions.
- **Rollback:** disable mutations; preserve audit/state according to policy.
- **Validation:** idempotency, concurrency, lifecycle, and rules tests.

### Phase E — Security hardening

- **Dependencies:** observed read/write behavior from earlier phases.
- **Work:** tighten field allow-lists, privacy, moderation, rate limits, and auditability.
- **Risk:** locking out legitimate flows or exposing private data.
- **Rollback:** versioned rules deployment with tested previous rules.
- **Validation:** authenticated/unauthenticated/owner/admin/moderator/member matrix.

### Phase F — UI integration

- **Dependencies:** stable read-only repository and projections.
- **Work:** add Community/Topic/Group Universe entry points while preserving existing routes and Personal Universe.
- **Risk:** loading too many Orbs, selection/navigation regressions, listener duplication.
- **Rollback:** feature flag to existing Community UI.
- **Validation:** widget/integration tests, bounded datasets, performance profiling.

### Phase G — Migration and cleanup

- **Dependencies:** production evidence, approved backfill and rollback plan.
- **Work:** optional data backfill, legacy compatibility cleanup, model convergence planning.
- **Risk:** irreversible data changes and cache incompatibility.
- **Rollback:** backups, dual-read period, reversible scripts, staged rollout.
- **Validation:** counts, referential integrity, permission tests, recovery rehearsal.

No migration or script was executed in Phase 12.

## 12. Compatibility

### Current CommunityPage

Reads `users`, computes existing `InteractionScore`, creates `CommunityNode`, and preserves search/filter behavior. A future Community repository must not replace this path without an explicit integration phase.

### CommunityBubbleMap and CommunityNode

Remain the current visual adapter for person Orbs. A contextual projection may produce `SocialOrb`/`CommunityNode` values, but existing constructors and callbacks must remain compatible.

### SocialProvider

Currently manages social profiles, friend requests, friends, and close-friend state. It does not own Community membership and must not be silently repurposed as a Community repository.

### OrbUniverse

Remains a transient projection. It must receive authorized domain data but must not become persistence infrastructure.

### Profile navigation

Existing `/profile/{userId}` behavior remains unchanged. Community membership must not invent or replace profile identity.

### Existing Firestore domains

- `users`: source for current Personal Universe people and profile data;
- `posts`: global authenticated post domain with existing pagination;
- `chats`: participant-gated messages;
- `groups`: existing group documents and member-gated messages.

The future Community schema must reference or project these domains only where authorization and product semantics are explicitly defined. It must not copy them automatically.

## 13. UserProfile Duplication

Two models remain intentionally unchanged:

- `lib/models/user_profile.dart`: broader profile model with `id`, `displayName`, `bio`, `avatarUrl`, `createdAt`, stats, and Firestore `Timestamp` mapping. Used by profile services and broader app paths.
- `lib/features/social/models/user_profile_model.dart`: social model with `uid`, optional name/email/photo/status, close-friend state, friends, pending requests, and JSON/local-cache mapping. Used by `SocialProvider`.

Impact and risks:

- `id` versus `uid` ambiguity when joining a membership;
- `name`/`displayName` and avatar field naming drift;
- different timestamp and serialization boundaries;
- stale cached social data versus profile data;
- future repository adapters selecting inconsistent identity fields.

Precondition for convergence:

1. inventory all imports and callers;
2. document persisted field aliases;
3. define one canonical identity/display mapping;
4. migrate caches and tests deliberately;
5. provide compatibility adapters during rollout.

This phase does not refactor either model.

## 14. Performance Contract

- Never store an unbounded member array in a Community document.
- Use cursor pagination for members, user Communities, discovery, and relations.
- Apply bounded `limit` values and reject unbounded page requests.
- Keep metadata reads separate from member/content pages.
- Do not create a global Community listener or one listener per member.
- Scope realtime listeners to a specific context only when live behavior is required.
- Reuse existing bounded patterns: paginated posts, 24-hour/limited stories, and parent-scoped group/chat messages.
- Cap the visual projection to the existing approximate 40–50 Orb range; search results remain independent of the visual cap.
- Avoid N+1 profile reads; use bounded projections or batched/repository-controlled reads.
- Compute `InteractionScore` from authorized fields already loaded; never fetch once per Orb solely for scoring.
- Cache Community metadata and cursors with explicit invalidation; do not cache authorization decisions beyond their safe lifetime.
- Treat `memberCount` as a display hint, never as membership truth.
- Measure reads, latency, page sizes, denied reads, empty projections, and listener lifetimes.

## 15. Test Strategy

No new tests were created in Phase 12 because no production implementation was added.

### Domain tests

- required identity and non-empty field invariants;
- valid/invalid visibility and lifecycle values;
- Topic parent relationships;
- CommunityMembership role/status transitions;
- deterministic membership ID generation;
- `fromMap`/`toMap` only at the persistence adapter boundary;
- `OrbMembership` versus `CommunityMembership` separation;
- `OrbUniverse` projection with explicit center.

### Repository tests

- `getCommunity` found/not-found/permission errors;
- paginated Community and member reads;
- cursor continuation and page limits;
- user Community query;
- Topic reverse lookup;
- timestamp conversion;
- network/unavailable errors;
- no unbounded reads.

### Service tests

- owner/admin/moderator/member permissions;
- join idempotency;
- leave idempotency;
- duplicate/concurrent join conflict;
- pending approval lifecycle;
- blocked/left behavior;
- last-owner protection;
- role escalation rejection.

### Rules tests

Matrix must include:

- unauthenticated user;
- authenticated non-member;
- active member;
- pending member;
- blocked/left member;
- owner;
- admin;
- moderator;
- server/admin claims;
- private versus public Community.

### Integration tests

- Community → membership → user profile;
- Community → Topic reference;
- Community → bounded `OrbUniverse`;
- membership → `OrbMembership` explanation;
- Personal Universe remains on `users`;
- existing posts/chats/groups remain compatible;
- no physics position persistence;
- profile navigation remains unchanged.

## 16. Definition of Ready

ORBE is ready to begin real Community implementation only when all items below are explicitly approved:

- [ ] Domain model defined.
- [ ] Community fields and invariants defined.
- [ ] Topic independence/reference policy defined.
- [ ] CommunityMembership lifecycle defined.
- [ ] Roles defined and authority boundaries documented.
- [ ] Firestore collection/document schema approved.
- [ ] Membership identity strategy approved.
- [ ] Query contract defined.
- [ ] Mutation contract defined.
- [ ] Security contract defined.
- [ ] Firestore rules design reviewed.
- [ ] Index strategy defined from finalized queries.
- [ ] Repository boundary defined.
- [ ] Serialization boundary defined.
- [ ] Pagination and listener limits defined.
- [ ] Orb projection and visual cap defined.
- [ ] Migration phases defined.
- [ ] Rollback strategy defined.
- [ ] UserProfile compatibility impact reviewed.
- [ ] Domain, repository, service, rules, and integration tests planned.
- [ ] Live schema verification completed.
- [ ] Explicit approval given to start implementation.

## 17. Open Decisions

The current documents and code cannot determine these items without product/security decisions:

1. Are Community metadata and Community discovery public to authenticated users, or member-only?
2. Can a Topic exist without a Community, and who may create or rename one?
3. Are private Communities and approval-based membership required for MVP?
4. Is `admin` a real role distinct from owner and moderator?
5. Should `blocked` and `left` memberships be retained for audit, or deleted after a policy-defined period?
6. Must Community members be publicly listable?
7. Is a bounded `topicIds` array sufficient, or is `community_topics` required immediately?
8. Should membership use deterministic IDs generated from raw IDs, normalized IDs, or a server-only key function?
9. Should Community content reference existing posts/memories/stories, and what visibility rules apply per content type?
10. Are member counts required, and which server process owns them?
11. Which existing `UserProfile` is the canonical adapter source for future membership projections?
12. Are Community changes realtime, and which screens need listeners rather than reads?
13. What are the first supported Community sizes and latency/read-cost budgets?
14. What owner transfer, archive, and deletion behavior is required?
15. What moderation audit trail is legally/product-required?

These questions must be resolved before rules, indexes, collections, or migration code are authored.

## 18. Fundamental Rule

No decision in this document changed production. The implementation may begin only after explicit approval of Phase 12 and a separate reviewed change that introduces the approved schema, rules, indexes, repository, tests, and migration controls.
