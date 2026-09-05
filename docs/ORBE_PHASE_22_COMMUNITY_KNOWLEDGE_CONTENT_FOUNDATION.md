# ORBE Phase 22: Community Knowledge & Content Foundation

Status: Domain foundation implemented. No Firestore deployment, migration, or production data change was performed.

## 1. Vision

ORBE evolves from social connection toward community-built knowledge: connection brings people closer, evidence supports claims, and communities build context together. Knowledge is contributed organically by members rather than seeded as a large artificial database.

## 2. Problem

The existing content system is social-first. It stores global `posts` with author display fields, text, pin state, timestamps, comments, reactions, and media-related feed behavior. That model supports conversation and popularity-oriented interaction, but it does not express a claim, its evidence, its source, its limitations, or a correction history.

## 3. Social Content vs Knowledge Content

Social content includes casual posts, comments, opinions, conversation, likes, and reactions. Knowledge content needs explicit semantic type, authorship, source/evidence relationships, context, and correction history. The two domains may eventually share low-level infrastructure such as authentication, timestamps, storage, and reporting, but they must not share semantics by convenience.

The existing `Post` and `PostService` remain unchanged and are not community knowledge repositories.

## 4. Factuality Principles

A publication is not automatically true because a person submitted it. ORBE will not infer truth from authorship, popularity, likes, votes, or an `InteractionScore`. Claims should state what was observed or asserted, identify context, point to evidence where available, and preserve limitations and disagreement. The system does not manufacture verification and does not claim that AI can determine absolute truth.

## 5. Evidence

The implemented `Evidence` value object is the smallest relationship needed to attach support to a factual claim. It contains `evidenceId`, `claimId`, `type`, `description`, optional `sourceId`, `createdBy`, and `createdAt`. Evidence types cover scientific study, book, institutional document, historical source, official website, interview, public document, observation, and other material. It describes support; it does not certify truth.

## 6. Sources

The implemented `Source` value object identifies origin with `sourceId`, `type`, `title`, `locator`, `createdBy`, and `createdAt`. Source types include scientific article, book, institutional document, historical source, official website, interview, public document, and other. `locator` can be a URL or another verifiable reference. ORBE does not crawl, import, or automatically validate the internet in this phase.

## 7. Authorship

Every content item, source, evidence record, and correction requires `createdBy` and `createdAt`. Content also retains `updatedAt`. No anonymous knowledge is created by default, and correcting content does not replace or erase the original author.

## 8. Corrections

`ContentCorrection` records `correctionId`, the original `contentId`, an explanation, optional `proposedBody`, `createdBy`, `createdAt`, and `updatedAt`. This is an append-oriented correction record: it points to the original instead of silently deleting or rewriting it. Approval, version selection, conflict resolution, and moderation remain future behavior.

## 9. Anti-Disinformation Policy

The domain is prepared to support reports, review, corrections, restrictions, suspension, and future bans. It must not support fabricated evidence, fabricated sources, false citations, invented sources, manipulated context, or deliberate presentation of false information as established fact. A good-faith error is distinct from deliberate disinformation. No automatic ban or truth judgment is implemented here.

## 10. Science

Scientific communities can represent a claim as a `CommunityContent` item with `type == fact`, attach multiple `Evidence` records, identify `Source` records, and preserve context in the content/evidence descriptions. Conflicting evidence is representable because multiple evidence records may point to the same claim; no evidence is silently treated as decisive. Peer review, scientific certification, councils, automated validation, AI truth judgment, and scientific database integrations are out of scope.

## 11. Other Communities

The same semantic type system supports cinema, music, art, history, technology, astronomy, education, literature, sports, and local communities. For example, a release date can be a `fact`, while a ranking can be an `opinion`. A proposed explanation can be a `hypothesis`, a prompt can be a `question`, and a contextual reading can be an `interpretation`.

## 12. Domain Chosen

The smallest model that lets ORBE grow from a social network into community-built, evidence-aware knowledge is:

- `ContentType`: `fact`, `opinion`, `hypothesis`, `discussion`, `question`, `interpretation`;
- `CommunityContent`: community-scoped authored text with semantic type and timestamps;
- `Source`: verifiable origin metadata;
- `Evidence`: authored support linked to a claim/content ID and optionally a source;
- `ContentCorrection`: authored, linked correction that preserves the original identity.

A separate `KnowledgeClaim` class was deliberately not added. A factual claim is a `CommunityContent` item with `ContentType.fact`; this avoids two competing text/author/timestamp aggregates while retaining a stable `claimId` relationship through `contentId`. No Truth Score or verification state is persisted yet.

The models are immutable at the field/API level, contain no Firebase types, validate required IDs/text/authorship and timestamp ordering, and provide map serialization for future adapters.

## 13. Proposed Firestore Model

No collections were created. When persistence is approved, the conservative proposal is:

```text
community_contents/{contentId}
  communityId, type, title, body, createdBy, createdAt, updatedAt

sources/{sourceId}
  type, title, locator, createdBy, createdAt

evidences/{evidenceId}
  claimId, type, description, sourceId?, createdBy, createdAt

content_corrections/{correctionId}
  contentId, explanation, proposedBody?, createdBy, createdAt, updatedAt
```

The proposal is intentionally separate from `posts`. A future implementation must decide whether evidence/source/correction documents are top-level or community-scoped subcollections, add immutable identity checks, and define lifecycle/version fields before deployment. Existing posts are not migrated.

## 14. Proposed Security Rules

No Rules were changed. Future collection Rules should require authentication, an `active` membership in the target community for ordinary reads/writes, and owner/admin/moderator privileges for moderation actions. Queries must be community-scoped. Creation must bind `createdBy` to `request.auth.uid`; clients must not set moderation, verification, or authority fields. Updates must preserve original author and identity, and corrections must be additive rather than destructive. Pending, blocked, and left memberships must not read or publish community content.

## 15. Proposed Repository

A future `CommunityContentRepository` should be independent from `CommunityRepository` and `CommunityReadService`. It should own bounded community-content reads, creation, evidence/source linking, and correction records. It must not make `OrbUniverse`, `OrbMembership`, `InteractionScore`, or UI controllers authoritative. No repository or service was added in this phase.

## 16. What Was Implemented

- Firebase-free domain models and enums in `lib/features/social/domain/content/community_content.dart`.
- Validation of IDs, required text, authorship, and timestamp ordering.
- Map serialization/deserialization for content, sources, evidence, and corrections.
- Focused domain tests covering valid creation, invalid input, type distinction, round trips, relationships, and correction history.
- This architectural document.

## 17. What Was Not Implemented

No feed, community post UI, Firestore collections, repository, service, migrations, indexes, Rules, content creation flow, evidence upload, source crawler, truth score, verification authority, peer review, moderation system, notifications, likes, comments, invitations, ban management, global user discovery, profile model convergence, or Personal Universe changes were implemented.

Existing social posts behavior, Auth/session, routes, profile navigation, chat, groups, Cloud Functions, ORBE branding, Firebase project ID, `OrbUniverse`, `OrbMembership`, `OrbPhysicsEngine`, `InteractionScore`, `CommunityPage`, `CommunityBubbleMap`, and `CommunityBubble` were preserved.

## 18. Risks

A future community knowledge system may be misused to give unsupported claims an appearance of authority. The domain must keep claim type, evidence, source, uncertainty, disagreement, and correction history visible. Member-created sources may be incomplete or malicious, and a source locator alone does not prove credibility.

## 19. Limitations

The current foundation does not store a dedicated verification state, evidence conflict state, content version graph, moderation decision, visibility policy, edit history, source snapshots, or private evidence metadata. It also does not validate external locators. These are deliberate boundaries, not hidden claims of verification.

## 20. Next Phase

The next phase should define the persisted `CommunityContent` contract, community-scoped Rules, bounded repository operations, and a minimal member-authorized creation/read flow. It should first decide whether content is top-level or community-subcollection data and how corrections and conflicting evidence are presented before building UI or migrating any posts.
