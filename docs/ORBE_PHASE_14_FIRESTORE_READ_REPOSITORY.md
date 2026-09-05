# ORBE Phase 14 - Firestore Community Read Repository

Status: read-only implementation. No Firestore production data, rules, indexes, or mutations were changed.

## Architecture

`FirestoreCommunityRepository` is the only Community adapter that imports `cloud_firestore`. It converts Firestore snapshots and timestamps into `SocialCommunity`, `SocialTopic`, and `CommunityMembership`; Firebase types do not cross the repository/domain boundary.

## Collections and Queries

- `communities/{communityId}`: direct read for `getCommunity`.
- `communities`: `orderBy(name)` with `limit(request.limit + 1)` for `listCommunities`.
- `community_memberships`: `where(userId == ...)`, `where(status == active)`, `orderBy(updatedAt desc)` for `listUserCommunities`, followed by one community read per membership in the bounded page. Firestore has no join, so this fan-in is limited to the requested page.
- `community_memberships`: `where(communityId == ...)`, `where(status == active)`, `orderBy(createdAt desc)` for `listMembers`.
- `communities`: `where(topicIds array-contains topicId)`, `orderBy(name)` for `listCommunitiesByTopic`. This uses the proposed bounded `topicIds` array directly; it does not query `topics` or invent a relation.

The adapter performs no writes and no realtime listeners. Missing collections/documents remain missing and are not replaced with fake data.

## Pagination and Preconditions

The public cursor is a URL-safe base64 token containing only the last document ID. The adapter decodes it privately, obtains a reference in the same collection, and uses Firestore cursor pagination. Page sizes remain bounded by `CommunityPageRequest` (1-100). A production query using compound filters/order may require composite indexes; `firestore.indexes.json` was intentionally not changed.

Current rules contain no Community paths. Authentication, visibility, member-list authorization, and topic discovery rules are preconditions for a future deployment and should be addressed in Phase 16.

## Limitations

The current domain `SocialCommunity` only represents one embedded topic, while the proposed persisted shape represents topic IDs. The adapter therefore maps an optional legacy/explicit embedded `topic` object only; it does not perform unbounded topic fan-out. Membership lookup uses the deterministic `MembershipIdentity` convention from Phase 12.

Tests use `fake_cloud_firestore` only. No real Firestore data, collections, migrations, Rules, indexes, UI, providers, or mutation operations were added or changed.