# ORBE Phase 24: Community Knowledge UX

Status: Implemented. No production deployment was performed.

## 1. Objective

Provide the first usable community knowledge flow: members can read community-scoped content, inspect evidence, sources, and corrections, and create those records without changing the existing social post experience.

## 2. Architecture Chosen

Knowledge is integrated as a contextual section inside `CommunityDetailPage`, using a dedicated `CommunityContentUiController` and the existing `CommunityContentRepository` abstraction.

Flow:

```text
CommunityDiscoveryPage
  -> CommunityDetailPage
      -> CommunityContentUiController
          -> CommunityContentRepository
              -> FirestoreCommunityContentRepository
      -> CommunityContentDetailPage
```

The repository is injected from the application composition root. Existing tests and callers may omit it, so the social Community flow remains compatible and does not create Firebase work in unrelated test fixtures.

## 3. Creation Flow

An authenticated member opens `Criar conhecimento` from the community knowledge section and selects one of the existing `ContentType` values: fact, opinion, hypothesis, discussion, question, or interpretation. The form requires title and context/body. The UI never asks for or accepts `createdBy`; the controller derives authorship from the authenticated identity already supplied by the app.

A submitting guard prevents duplicate content submissions. Repository/Rules failures are presented as understandable UI messages rather than raw Firestore details.

## 4. Reading Flow

The community detail loads bounded content through `listCommunityContent(communityId)`. Content remains isolated by the requested community and uses the existing cursor/pagination contract. Empty, loading, error, and load-more states are explicit. A content card shows its semantic type, title, body excerpt, author, and counts for evidence, associated sources, and corrections. Tapping a card opens the dedicated detail page.

## 5. Evidence

The detail page loads evidence under the content parent. Each evidence item displays description, type, author, date context, optional source ID, and its position: supports, challenges, or contextualizes. Multiple evidence items remain visible. When supporting and challenging evidence coexist, the page states that there are evidences on both sides without choosing a winner. `EvidencePosition` is minimal conflict metadata, not a confidence or truth score.

Evidence is contextual support, not a truth seal. Evidence may be created without a source. The form optionally selects an already-associated community source and does not invent or fetch external sources.

## 6. Source

Sources are displayed as neutral references with title, type, locator, author and publisher when available. The detail page counts only sources referenced by the content's evidence, rather than every source in the community. Members can add a source with title, type, and URL/reference. No crawler, download, URL validation, or automatic credibility judgment exists.

## 7. Correction

Members can register an append-only correction with an explanation and optional proposed body. The detail page displays corrections as history related to the original content. The original content, original author, and original text remain visible; the UI never silently replaces or deletes the claim.

## 8. UI States

The knowledge section and detail page cover loading, loaded, empty, error, submitting, success, and load-more states. Empty relation messages are neutral:

- `Este conteúdo ainda não possui evidências associadas.`
- `Nenhuma fonte foi associada.`
- `Nenhuma correção foi registrada.`

Absence of evidence or source is not presented as falsity. Authorization and network errors are translated into user-facing messages with retry where appropriate.

## 9. Authorization

The UI hides creation actions when no authenticated UID is available, but this is only a convenience. Firestore Rules remain authoritative. The Phase 23 policy continues: only active community members and authorized owner/admin/moderator staff can read or create knowledge records. The UI does not duplicate or weaken those Rules.

## 10. Pagination

Community content uses the existing `CommunityPageRequest` and opaque cursors. It does not load all community content at once and does not expose `DocumentSnapshot` to the UI. Evidence, sources, and corrections use the repository's bounded relation-page methods.

## 11. Accessibility

Type is communicated by text and icon, not color alone. Content cards and actions have semantic labels, reasonable button targets, readable error/loading feedback, and standard Flutter text layout that can expand with text scale. Relation sections use clear headings and neutral explanatory copy.

## 12. CommunityDetail

The knowledge section is explicitly labeled `Conhecimento da comunidade`, making the community context visible and preventing confusion with the global social feed. Community content is never mixed with content from another community. Existing member, topic, join, profile, and universe sections remain in place.

## 13. OrbUniverse

Knowledge content was intentionally not converted into Orbs in this phase. The first presentation uses a traditional contextual surface because evidence, sources, corrections, and uncertainty require readable hierarchy and relationship detail. `OrbUniverse`, `OrbMembership`, `OrbPhysicsEngine`, and `InteractionScore` remain unchanged. Future spatial projection must not use truth or popularity scores for placement without an explicit contract.

## 14. Post Social

`Post`, `PostService`, `posts`, comments, reactions, media behavior, and the global social feed remain unchanged. `CommunityContent` does not inherit from `Post`, and no posts were migrated.

## 15. Changes

Created:

- `lib/features/social/presentation/community/community_content_ui_controller.dart`
- `lib/features/social/views/community_content_pages.dart`
- `test/community_content_ui_test.dart`
- this document

Modified:

- `lib/features/social/views/community_detail_page.dart`: optional contextual knowledge section and navigation.
- `lib/features/social/views/community_discovery_page.dart`: repository injection through detail/card navigation.
- `lib/main.dart`: production provider for `FirestoreCommunityContentRepository`.
- `lib/features/social/domain/content/community_content.dart`: optional `EvidencePosition` and source metadata support.
- `firestore.rules`: optional evidence-position validation, preserving the Phase 23 security model.
- `test/community_content_domain_test.dart`: existing domain compatibility through defaults.

No new collections, migrations, Cloud Functions, Auth changes, or production deployments were introduced in this phase.

## 16. Rules and Firebase

The only Rules change validates the optional `position` field on Evidence. It does not open permissions or change membership policy. The Firestore schema remains the Phase 23 schema. The existing content index remains sufficient for the community content query.

## 17. Testing

Focused knowledge UI/controller tests: `7/7` passed.

Domain and repository regression tests: `9/9` passed.

Full Flutter suite: `86/86` passed.

Firebase Emulator Rules suite: `20/20` passed.

`flutter analyze`: clean.

## 18. What Was Not Implemented

No global feed, social post conversion, likes, comments, notifications, Truth Score, verification badge, automatic fact checking, AI truth judgment, crawler, external source ingestion, peer review, advanced moderation, ban management, migration, version graph, or automatic conflict resolution was implemented.

No changes were made to Authentication, session, route protection, Personal Universe, community physics, profile routes, chat, groups, Cloud Functions, Firebase project identity, branding, or existing social post behavior.

## 19. Risks

Community members can publish claims and references that are incomplete, misleading, or malicious. The UI communicates authorship and evidence relationships but does not certify truth. A future moderation and lifecycle model is needed before broad discovery or sensitive-community use.

## 20. Next Phase

Define moderation/lifecycle and review presentation for community knowledge, including how reports, corrections, conflicting evidence, soft deletion, and content visibility should work before expanding discovery or adding richer spatial projections.
