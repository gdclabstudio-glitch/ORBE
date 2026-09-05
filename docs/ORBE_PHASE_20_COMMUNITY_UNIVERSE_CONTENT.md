# ORBE Phase 20 - Community Universe Content

Status: read-only enrichment of the Community detail/universe. No Firestore schema, writes, Rules, indexes, Authentication, moderation, or Personal Universe changes were made.

## Audit and Plan

The existing Community flow is `CommunityDiscoveryPage -> CommunityDetailPage -> OrbUniverse.community`. `CommunityPage` remains the separate `users`-backed Personal Universe. Existing contracts provide paginated `listMembers` and an embedded optional `SocialCommunity.topic`; there is no TopicRepository, independent topic list method, or batch profile loader in the Community architecture.

The minimum implementation therefore extended the existing `CommunityUiController`, reused `listMembers`, filtered active memberships at the read/state boundary, and projected only already available topic data. No new Firestore query or collection was introduced.

## Members

`CommunityUiController.loadMembers` and `loadMoreMembers` preserve `CommunityPageRequest` cursors and bounded pages. Only `CommunityMembershipStatus.active` entries are retained for visual projection; `pending`, `blocked`, and `left` are excluded before rendering.

Each active membership becomes a `SocialOrb` with `OrbType.person`. The detail view uses `OrbRenderer` and the existing `/profile/{userId}` route, without creating a profile model or loading profiles one by one. Since the membership contract contains no display name/avatar, the UI does not fabricate either.

The existing Rules intentionally restrict `listMembers` to community owner/admin/moderator. Authorized callers see real members; callers without that permission receive a localized access error and retry action while the rest of the Community detail remains available. Rules were not relaxed.

## Topics

Only the optional `SocialCommunity.topic` already mapped by the repository is shown. It is rendered as a contextual `SocialOrb` with `OrbType.topic` when opening the Community Universe and as a topic chip in the detail view. Missing topic data produces no fabricated topic. `topicIds` references are not expanded because the current contracts provide no bounded topic fetch for this screen.

## Community Universe

`CommunityUniverseProjection` remains the existing bridge to `OrbUniverse.community`. The real Community ID remains `contextId`; active member Orbs and the real embedded topic are passed as contextual Orbs. The Community remains the center, and existing `OrbUniversePage` stack/breadcrumb/back behavior is reused. No new physics or `OrbUniverse` model was added.

If members or topics are absent, the detail view shows contextual empty states and the universe contains only the center. A members read error does not remove a successfully available topic or the Community identity.

## Loading, Errors, Pagination, Performance

Membership status and member content load independently. Members have their own loading, empty, error/retry, and load-more states. Discovery pagination remains bounded. There are no realtime listeners, profile fan-out queries, topic fan-out queries, or writes.

Errors continue through `CommunityError` and are translated only at the UI boundary: forbidden becomes an access message, unavailable becomes a retryable connection message, and missing/conflict behavior remains controlled by the existing mapper.

## Files

Modified:

- `community_ui_controller.dart`: bounded member loading, cursor state, active filtering, and member errors.
- `community_detail_page.dart`: active member Orbs, profile navigation, topic display, and contextual universe projection.
- `community_ui_integration_test.dart`: real active/inactive member, profile, topic, and independent error coverage.

Created:

- this document.

Unchanged: `CommunityPage`, `CommunityBubbleMap`, `CommunityBubble`, `SocialProvider`, `OrbPhysicsEngine`, `InteractionScore`, `OrbMembership`, `OrbUniverse` model, repository contracts, Firestore schema, Rules, indexes, Auth, and Discovery route behavior.

## Tests and Limitations

The focused UI suite passes `6/6`; the full Flutter suite passes `77` tests and `flutter analyze` is clean. The existing Rules Emulator suite remains `18/18` because no Rules/query contract changed.

The current schema cannot provide independent Topic records to this view. Active community members may read the bounded active-member listing under the Phase 21 policy; non-members and inactive memberships remain denied. Display names and avatars are intentionally omitted rather than obtained through N+1 reads. A future bounded profile projection can improve that experience.

No Firestore data, collections, indexes, dependencies, migrations, or deployments were added. Future work may address bounded profile projections, independent topic reads, member visibility policy, contextual content, and richer universe interactions.