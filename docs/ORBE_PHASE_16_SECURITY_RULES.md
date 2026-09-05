# ORBE Phase 16 - Firestore Security Rules

Status: Community read security only. No Community mutation, Cloud Function, data migration, deployment, or production write was performed.

## Security Model

| Actor | Definition | Community read access |
|---|---|---|
| UNAUTHENTICATED | `request.auth == null` | No access to the new collections |
| AUTHENTICATED | Any signed-in user | Read `communities` and `topics`; read own memberships |
| MEMBER | Authenticated user with an active membership record | Active memberships in that same community only |
| OWNER | `communities/{id}.ownerId == request.auth.uid` | Community memberships for that community |
| ADMIN | Existing `isAdmin()` custom-claim helper | Community memberships for moderation reads |
| MODERATOR | Existing `isModerator()` custom-claim helper | Community memberships for moderation reads |
| NON-MEMBER | Authenticated user without an active membership | Community/topic metadata only; no membership enumeration |

`SocialCommunity` currently has no `visibility` field. Therefore the Rules do not invent public/private behavior: authenticated users can read metadata, while unauthenticated users cannot. Lifecycle/status filtering is also not added because the current repository queries do not constrain a field represented in the current domain.

## Rules Changed

Added one local helper pair:

- `isCommunityOwner(communityId)` checks the persisted `ownerId`.
- `isCommunityStaff(communityId)` composes community owner, existing admin, and existing moderator helpers.

Added read-only matches for `communities`, `community_memberships`, and `topics`. Every create/update/delete operation in those matches is explicitly denied.

## Query Constraints

- `getCommunity`, `listCommunities`, and `listCommunitiesByTopic`: authenticated reads are allowed. The topic query is supported by the proposed `topicIds` field; required composite indexes remain a deployment precondition and `firestore.indexes.json` was not changed.
- `getMembership`, `isMember`: a user may read a membership only when its stored `userId` is their UID, or when they are staff for the stored community.
- `listUserCommunities`: supported only for a query constrained to the caller's own `userId`; arbitrary user enumeration is denied by the document predicate.
- `listMembers`: supported for active members of the requested community and owner/admin/moderator callers. The query must constrain `communityId` and `status == active`; non-members and inactive members cannot enumerate records.

The deterministic `MembershipIdentity` value is compatible with secure reads because Rules authorize the stored identity fields, not an untrusted document ID. Rules do not attempt to reproduce Dart's URI encoding, so the ID convention is not itself an authorization primitive.

## Test Matrix

The runtime suite in `backend/functions/test/firestore-rules.test.js` covers:

| Operation | Unauthenticated | Authenticated | Member | Owner | Admin | Moderator | Non-member |
|---|---|---|---|---|---|---|---|
| communities get/list | deny | allow | allow | allow | allow | allow | allow |
| membership own | deny | allow when own UID | allow | allow | allow | allow | deny |
| membership other | deny | deny | deny | staff policy | allow | allow | deny |
| members list | deny | deny by default | deny | allow | allow | allow | deny |
| topics get/list | deny | allow | allow | allow | allow | allow | allow |
| any new-collection write | deny | deny | deny | deny | deny | deny | deny |

The test data is emulator-only and seeded with Rules disabled. Production Firestore is never written.

## Limitations and Preconditions

- Current Rules cannot distinguish public/private communities because the current domain contract does not expose `visibility` to the adapter/UI policy.
- Owner-scoped reads require a community document with `ownerId`; records without it are not owner-readable, though metadata remains authenticated-readable.
- The proposed compound queries may require indexes for `(userId, status, updatedAt)`, `(communityId, status, createdAt)`, and `topicIds` plus `name`. No index was added.
- Existing Rules for users, posts, chats, groups, stories, reports, and admin collections were preserved.
- All Community mutation operations remain blocked and require an explicit future policy, validation, and server-side design before implementation.

These are **PRECONDITIONS FOR PHASE 17**, not implicit permissions.