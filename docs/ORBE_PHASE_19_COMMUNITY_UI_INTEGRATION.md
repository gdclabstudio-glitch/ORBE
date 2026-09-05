# ORBE Phase 19 - Community UI Integration

Status: discovery, detail, membership entry, and creation UI. No moderation, lifecycle mutation, migration, Cloud Function, Authentication, Rules, index, or production schema changes were made.

## Architecture

```text
Provider composition root
  -> CommunityReadService / CommunityWriteService
  -> CommunityUiController
  -> CommunityDiscoveryPage
  -> CommunityDetailPage
  -> CommunityUniverseProjection / OrbUniverse.community
```

The UI receives abstractions, not Firestore objects. Firestore construction remains in the infrastructure/composition layer. `CommunityUiController` is the single state owner for the discovery list, pagination, membership cache, join loading, creation loading, and read errors.

## Discovery and Detail

The new `/communities` route is independent from `/community`. Discovery uses `listCommunities` with bounded `CommunityPageRequest` pages and an explicit `Carregar mais` action. It provides loading, empty, retryable error, responsive one/two/three-column layouts, name/description search over loaded results, and a create entry point.

`CommunityDetailPage` loads the current user's real membership through the read service. It displays `Não membro`, `Membro ativo`, `Membership pendente`, `Acesso bloqueado`, or `Membership encerrada`. Only a non-member with a known authenticated UID receives the join action. Pending, blocked, and left states cannot be promoted locally.

## Join and Create

Join calls `CommunityWriteService.joinCommunity` only after the user action, disables the action while pending, and updates the membership cache only after the service succeeds. Errors preserve the previous state and are translated to user-facing messages without exposing Firebase exceptions.

Creation is a minimal dialog with required trimmed name, 80-character validation, optional 240-character description, loading state, and duplicate-submit protection from the controller. On success it opens the returned Community detail and reads its owner membership from the backend. The UI never supplies `ownerId` or writes Firestore directly.

## Orb Universe and Personal Universe

The detail view represents the Community with `OrbType.community` and opens `OrbUniverse.community` through the existing `CommunityUniverseProjection`. It provides the real Community ID as `contextId`, uses the existing navigation stack, and supplies no invented members or content. The empty contextual universe remains empty until bounded real projections exist.

The existing `/community` route and `AppHomePage` tab remain the Personal Universe. `CommunityPage` still reads `users`, builds `CommunityNode`, calculates `InteractionScore`, uses `CommunityBubbleMap` and existing physics, supports search/filter/selection/profile navigation, and opens `OrbUniverse.personal`.

## Files

Created:

- `community_ui_controller.dart`;
- `community_discovery_page.dart`;
- `community_detail_page.dart`;
- `community_ui_integration_test.dart`;
- this document.

Modified:

- `main.dart`: registered read/write services and added `/communities`.
- `main_navigation_drawer.dart`: added the Communities entry.

No CommunityPage, CommunityBubbleMap, SocialProvider, OrbUniverse model, OrbMembership, InteractionScore, Auth, Rules, indexes, or Firestore schema files were modified.

## Tests and States

The new UI tests cover discovery, empty/error states, active join success, pending/blocked/left display, create validation, and successful creation. Existing Personal Universe widget coverage remains in place. The full Flutter suite passes `75` tests; `flutter analyze` reports no issues. The existing Rules Emulator suite passes `18/18`.

## Decisions, Risks, and Limitations

- `/community` was preserved to avoid converting the Personal Universe into a persisted Community experience.
- Search is local to loaded pages because the repository contract has no search query; it does not load unlimited data.
- Member counts, topics, activity, images, and internal content are not displayed without real fields/projections.
- `MemberAccessGate` remains the existing route gate; no authentication or session behavior was changed.
- The route provider construction assumes Firebase initialization follows the existing app bootstrap.
- The existing Phase 13 foundation document remains absent and was not recreated.
- The UI uses existing `LaBomba*` technical design tokens while presenting ORBE labels; no second design system or dependency was added.

Future phases may address moderation, leave/rejoin policy, private visibility, contextual member projections, content feeds, richer search, and measured indexes. No Phase 20 work was started.