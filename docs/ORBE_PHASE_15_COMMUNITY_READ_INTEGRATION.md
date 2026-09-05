# ORBE Phase 15 - Community Read Integration

Status: read-only integration. No mutations, real Firestore data, Rules, indexes, authentication, or UI behavior were changed.

## Read Architecture

```text
FirebaseFirestore
  -> FirestoreCommunityRepository
  -> CommunityRepository
  -> FirestoreCommunityReadService
  -> domain models / read callers
  -> optional CommunityUniverseProjection
```

`CommunityService` remains the existing mutation contract and has no implementation in this phase. `CommunityReadService` is a separate read contract so no mutation method can be reached through the new integration.

`FirestoreCommunityReadService` is deliberately thin: it forwards all seven read use cases, preserving `CommunityPageRequest`, cursors, limits, and `CommunityError` from the repository.

## Projection Boundary

`CommunityUniverseProjection` uses the existing `OrbUniverse.community` factory. It requires an explicit center and accepts only already-loaded member Orbs and memberships. With the default empty lists, a community produces an empty universe and no fictional members are created. `CommunityMembershipOrbAdapter` maps persisted membership identity to contextual `OrbMembership`; it does not change either model or make an authorization decision.

The existing `CommunityPage` remains the Personal Universe: it continues to read `users`, build `CommunityNode`, calculate `InteractionScore`, use `CommunityBubbleMap`, filters, selection, profile navigation, and `OrbUniverse.personal`. Nothing routes `CommunityPage` to `communities` automatically.

## Security and Operational Preconditions

Firebase types remain confined to the infrastructure repository. Firebase exceptions are converted there to `CommunityError`. All reads remain bounded and one-shot; there are no listeners, writes, fan-out persistence, or unbounded member loading.

The proposed Community collections still have no current Rules paths. Read authorization, visibility, member enumeration, and compound-query indexes are **PRECONDITION FOR PHASE 16**. `firestore.rules` and `firestore.indexes.json` were not changed. The queries and pagination strategy are documented in the Phase 14 repository document.

Tests use only `fake_cloud_firestore`; no real collection or document was created.