# ORBE Phase 23: Community Knowledge Persistence & Firestore Contract

Status: Implemented. No production deployment was performed.

## 1. Objective

Persist the first community knowledge resources without converting the existing social `Post` model into knowledge content. The implementation is intentionally small, community-scoped, author-bound, paginated, and ready for future evidence-aware workflows.

## 2. Architecture

Social and knowledge remain separate domains:

```text
Social: PostService -> posts -> comments/reactions/media
Knowledge: CommunityContentRepository -> community_contents
                                      -> community sources
                                      -> content evidences
                                      -> content corrections
```

The repository is independent from `CommunityRepository` and `CommunityReadService`. Firebase types remain in the infrastructure adapter; the domain models remain Firebase-free.

## 3. Firestore Schema

Implemented paths:

```text
community_contents/{contentId}
  contentId, communityId, type, title, body,
  createdBy, createdAt, updatedAt

communities/{communityId}/sources/{sourceId}
  sourceId, title, type, locator, author?, publisher?,
  createdBy, createdAt

community_contents/{contentId}/evidences/{evidenceId}
  evidenceId, contentId, sourceId?, type, description,
  createdBy, createdAt

community_contents/{contentId}/content_corrections/{correctionId}
  correctionId, contentId, explanation, proposedBody?,
  createdBy, createdAt, updatedAt
```

Evidence and corrections are nested below their content. Sources are nested below their community. This makes the parent relationship explicit in both the repository path and the Rules, preventing cross-community evidence/source references without duplicating community IDs in every value object.

## 4. CommunityContent

`CommunityContent` is the authored, community-scoped envelope. It requires stable `contentId`, `communityId`, semantic `ContentType`, title, body, `createdBy`, `createdAt`, and `updatedAt`. Document ID and `contentId` must match. The type enum contains `fact`, `opinion`, `hypothesis`, `discussion`, `question`, and `interpretation`.

A `fact` means that a member presented an assertion as factual. It does not mean ORBE confirmed the assertion.

## 5. Evidence

`Evidence` requires `evidenceId`, `contentId`, `type`, description, `createdBy`, and `createdAt`; `sourceId` is optional. It is stored below the content it supports or contextualizes. Multiple evidence records can coexist, including conflicting records. No evidence is ranked as true automatically.

## 6. Source

`Source` is stored under the owning community and requires stable ID, title, type, locator, author/publisher when available, creator, and creation time. The locator identifies origin but is not treated as proof. ORBE does not crawl, download, or automatically validate external material.

## 7. Correction

`ContentCorrection` is stored below the original content. It requires a correction ID, original `contentId`, explanation, creator, creation time, and update time, with an optional proposed body. Physical deletion is denied. The original content and original author remain intact; approval and full version selection are future concerns.

## 8. Authorship

Rules derive authorization from `request.auth.uid == createdBy`. Clients cannot create content, sources, evidence, or corrections in another user's name. Content updates preserve `createdBy`, `communityId`, `contentId`, and `createdAt`. Nested resource identity fields must match their document/path IDs.

## 9. Read Policy

Authenticated users need an `ACTIVE` membership in the relevant community. Community owner, admin, and moderator privileges continue to grant community-scoped staff access. `pending`, `blocked`, `left`, non-members, and unauthenticated users are denied. Content listing requires `where('communityId', isEqualTo: communityId)` and orders by `createdAt` descending, matching the Rules boundary.

Evidence and corrections inherit the community authorization of their parent content. Sources inherit the authorization of their community parent.

## 10. Publication Policy

Only active community members may create knowledge resources. Owners and global admin/moderator staff are also permitted through the existing staff helper. The target community must exist and be active for content creation. The client cannot publish into another community by changing `communityId` or by supplying a forged author.

## 11. Update Policy

Only the original content author may update `type`, `title`, and `body`. `updatedAt` is a server timestamp. `contentId`, `communityId`, `createdBy`, and `createdAt` are immutable. Sources, Evidence, and Corrections are append-only in this phase and cannot be updated from the client.

## 12. Delete Policy

Delete is denied for content, sources, evidence, and corrections. This is the conservative choice because knowledge history and correction context should not disappear for UI convenience. A future soft-delete or moderation workflow can introduce explicit lifecycle states without weakening authorship history.

## 13. Factuality

The database records what a member presented and what evidence was attached. It does not write `truth`, `verified`, or `truthScore`. Likes, votes, popularity, and `InteractionScore` have no role in factual status.

## 14. Science

Scientific communities can preserve claim context, traceable sources, multiple evidence records, hypotheses, and disagreement. A hypothesis is not a fact, and an opinion is not scientific consensus. Peer review, certification, scientific councils, automated validation, and AI truth judgment are not implemented.

## 15. Firestore Rules

Rules were added only for the resources created in this phase. Content Rules validate allowed fields, stable identity, active target community, content type, non-empty text, authenticated authorship, and server timestamps. Update Rules preserve identity and author fields. Nested Rules verify parent content existence and community access. Evidence source IDs, when present, must resolve under the same community. All client deletes for these resources are denied.

Existing Auth, Community membership, social post, chat, group, profile, report, notification, and unrelated collection Rules were preserved.

## 16. Queries

`FirestoreCommunityContentRepository` implements bounded operations:

- `getContent` and `createContent` by stable document ID;
- `listCommunityContent` filtered by `communityId`, ordered by `createdAt DESC`;
- `updateContent` by stable content ID;
- community-scoped source creation/listing;
- content-scoped evidence creation/listing;
- content-scoped correction creation/listing.

Pages use the existing `CommunityPageRequest` and opaque base64 document-ID cursors. `DocumentSnapshot` is not exposed to callers. Timestamps are converted at the infrastructure boundary.

## 17. Indexes

One index was added to `firestore.indexes.json` for the implemented content query:

```text
community_contents: communityId ASC, createdAt DESC
```

No deployment was performed. Source, evidence, and correction listings use a single `createdAt` ordering and do not add speculative composite indexes.

## 18. Repository

The new `CommunityContentRepository` owns content, source, evidence, and correction persistence. `FirestoreCommunityContentRepository` maps domain objects to Firestore, applies server timestamps, maps Firebase errors to `CommunityError`, and keeps pagination bounded. It does not contain UI logic or make Rules redundant.

## 19. Service

No separate `CommunityContentService` was added. The repository already provides the minimal boundary for this persistence phase, while domain constructors validate required values. A service can be introduced when orchestration, draft validation, or multi-document workflows become real requirements.

## 20. Tests

Domain tests cover typed content, required IDs, timestamp ordering, source/evidence relationships, serialization, and correction history. Repository tests cover stable IDs, create/read/update, nested source/evidence/correction persistence, and invalid request IDs. Emulator Rules tests cover active-member access, inactive/non-member denial, unauthenticated denial, cross-community isolation, forged authorship/community, immutable fields, invalid relationships, and denied deletes.

No artificial Firestore migration data was created, and no posts were converted.

## 21. Atomicity

There is no multi-document create operation in this phase. Content, Source, Evidence, and Correction are created independently because each is valid as an authored record and no UI workflow currently requires an atomic bundle. A future compound workflow should use a batch/transaction only after its failure and retry semantics are defined.

## 22. Limitations

There is no verification state, Truth Score, evidence weighting, source snapshot, source credibility judgment, moderation decision, soft-delete state, complete version graph, conflict resolution, or external URL validation. The repository does not automatically verify that a provided locator is reachable or truthful.

## 23. What Was Not Implemented

No feed, UI, likes, comments, notifications, advanced moderation, peer review, certification, crawler, AI truth judgment, post migration, Cloud Functions, UserProfile changes, Personal Universe changes, or changes to existing social post behavior were made.

## 24. Next Phase

The next phase should define the first member-authorized content workflow and its presentation of claims, evidence, sources, uncertainty, and corrections. It should also decide whether moderation/lifecycle states are needed before exposing broader content discovery.
