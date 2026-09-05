# ORBE Phase 21: Community Member Visibility & Privacy

Status: Implemented. No production deployment was performed.

## 1. Objective

Define and enforce who may discover community members before community feed/content work proceeds.

## 2. Previous State

`listMembers(communityId)` queried `community_memberships` with `communityId == id`, `status == active`, and descending `createdAt` pagination. Firestore Rules allowed the query only for the community owner or global admin/moderator. The Community Detail UI already rendered real active membership IDs and navigated to `/profile/{userId}`, while showing a privacy message on `forbidden`.

## 3. Problem

The UI loads the member section for a community detail, but ordinary active members were denied even though the product experience presents community members as contextual content. Relaxing the collection to every authenticated user would permit member enumeration and violate least privilege.

## 4. Visibility Policy

ORBE adopts a conservative hybrid policy:

- An authenticated user with an `active` membership in community A may list only `active` memberships in community A.
- Community owners and users with admin/moderator privileges retain community membership reads for moderation.
- Unauthenticated users, non-members, and users whose membership is `pending`, `blocked`, or `left` cannot list members.
- The list query must constrain `communityId` and `status == active`.
- No global user discovery is introduced.

This policy is explicit and can later be tightened or replaced with a bounded profile projection for larger communities.

## 5. Authorization Matrix

| Actor | List active members in requested community | Read inactive membership | Read private user profile | Write membership |
|---|---|---|---|---|
| Unauthenticated | Deny | Deny | Deny | Deny |
| No membership | Deny | Deny | Existing profile policy | Deny |
| Pending / blocked / left | Deny | Deny | Existing profile policy | Deny |
| Active member | Allow, same community only | Deny | Not granted by discovery | Deny |
| Owner | Allow | Existing moderation read | Existing profile policy | Existing policy |
| Admin / moderator | Allow | Existing moderation read | Existing profile policy | Existing policy |

Authorization uses community membership status/identity and role privileges. It does not use `InteractionScore`, `OrbMembership`, `OrbUniverse`, or any social score.

## 6. Discoverable and Private Data

Member discovery returns the existing `CommunityMembership` projection, whose relevant identity is `userId` plus membership context/status/role. The current UI uses only `userId` to create a real person Orb and navigate to `/profile/{userId}`. No `users/{uid}` read is performed by `listMembers`, and no display name, avatar, private field, settings, follower data, or other user document field is copied.

Discovering that a user is an active member is distinct from listing members, reading a public profile, and reading private user data. Existing `/users/{uid}` Rules continue to govern profile access; member discovery does not bypass them. A full profile repository or convergence of duplicate `UserProfile` models is out of scope.

## 7. Repository and Service

No Dart contract change was needed. `CommunityRepository.listMembers` and `CommunityReadService.listMembers` remain bounded and cursor-paginated. `FirestoreCommunityRepository` continues to query:

```text
community_memberships
  where communityId == communityId
  where status == active
  orderBy createdAt descending
  limit page.limit + 1
```

The service remains a thin forwarding adapter. Empty results return an empty page; invalid IDs/cursors and mapped Firestore failures retain existing error behavior. The query is intentionally compatible with the Rules predicate.

## 8. Firestore Rules

A new `isActiveCommunityMember(communityId)` helper verifies the deterministic membership document for the authenticated UID, including matching `communityId`, matching `userId`, and `status == active`. Membership reads allow the caller's own record, staff reads, or an active document when the caller is an active member of that same community. Writes, role escalation, status manipulation, and cross-community reads remain denied.

The Rules do not use `allow read: if request.auth != null` for memberships and do not open the collection globally.

## 9. Tests

The Emulator suite was updated to cover active-member success, owner/admin/moderator success, unauthenticated denial, non-member denial, pending/blocked/left exclusion, cross-community denial, and private-profile denial. Existing write tests continue to cover inconsistent identity/community IDs, role/status escalation, and all membership writes.

The Flutter Community UI suite continues to verify active-only rendering, exclusion of pending members, real profile navigation, privacy error messaging, topic preservation when member loading is forbidden, empty states, and existing membership states. No fake members are created.

The repository tests remain focused on mapping and contract behavior. `fake_cloud_firestore` does not reliably support this compound filtered/order query, so query authorization is validated by the Firebase Emulator rather than by weakening the production query.

## 10. UI Impact

Authorized users see real member Orbs and retain profile navigation. Unauthorized users see the existing ORBE privacy message, `Os membros desta comunidade não estão disponíveis para visualização.`, with retry behavior and no raw technical error. Community identity, topic content, Personal Universe, and existing routes remain unchanged.

## 11. Indexes

No new index was added and no deployment was performed. The existing composite query shape remains a deployment precondition for production Firestore if the project requires `(communityId, status, createdAt)`.

## 12. Known Risks

Member discovery reveals active membership in a community to other active members. This is an intentional product decision and should be revisited for sensitive/private communities. Large communities may need a dedicated bounded `MemberDiscovery` or `ProfilePreview` projection, rate limits, and stronger pagination/search controls.

## 13. Limitations

This phase does not create a profile repository, add display names/avatars, represent community visibility, or distinguish sensitive community categories. The current staff privilege model includes global admin/moderator claims. The fake Firestore limitation described above remains a test constraint.

This phase does not implement feed, community posts, comments, likes, notifications, advanced moderation, invitations, ban management, global user discovery, UserProfile convergence, or Personal Universe changes.

## 14. Next Steps

After Phase 21 approval, define the bounded community feed/content contract and its independent authorization rules. Reassess member projection and privacy controls before scaling community membership discovery.
