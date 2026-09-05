# ORBE Phase 17 - Community Creation and Join

Status: controlled Community writes for creation and join only. No UI integration, deployment, migration, Cloud Function, Authentication change, or production data write was performed.

## Scope and Contract

The new `CommunityWriteService` exposes only:

- `createCommunity(name, description?)`;
- `joinCommunity(communityId)`.

The existing broad `CommunityService` remains a future mutation contract and was not implemented, so update, leave, approval, removal, role changes, and deletion are still unavailable.

The required Phase 13 document was not present in the workspace and was not recreated or inferred. This is recorded as a documentation debt.

## Effective Schema

`createCommunity` uses a Firestore-generated Community ID and persists only:

```text
communities/{generatedCommunityId}
  name
  description (optional)
  ownerId
  status = active
  createdAt (server timestamp)
  updatedAt (server timestamp)
```

Creation also atomically persists the required owner relationship:

```text
community_memberships/{MembershipIdentity.forPair(communityId, ownerId)}
  communityId
  userId
  role = owner
  status = active
  createdAt (server timestamp)
  updatedAt (server timestamp)
```

`topicIds`, visibility, counts, images, and other proposal fields are not accepted by this narrow operation because they are not represented by the current `SocialCommunity` write API. `topics` remains read-only.

## Identity and Idempotency

The service obtains the actor UID from the injected current-user provider, or the existing `FirebaseAuth` abstraction at the infrastructure boundary. It does not accept `ownerId` or `userId` as write authority.

`MembershipIdentity.forPair` remains the sole membership ID strategy. `joinCommunity` first reads the target Community and the deterministic membership. An existing active membership is returned unchanged, making repeated sequential joins idempotent. Existing blocked, pending, or left memberships return a `CommunityError` and are not overwritten. The Rules allow membership `create`, not `update`, so concurrent duplicate creates fail closed rather than overwriting data; a future server-side idempotency strategy may improve that race behavior.

## Security Rules

`communities.create` requires authentication, an exact allow-list of fields, non-empty string `name`, `ownerId == request.auth.uid`, `status == active`, and both timestamps equal to `request.time`. Updates and deletes remain denied.

`community_memberships.create` requires an exact field allow-list, authenticated self `userId`, active status, server timestamps, and either:

- role `member` for an existing active Community; or
- role `owner` only in the same atomic write as a newly-created Community owned by the caller.

Admin and moderator roles cannot be supplied by an ordinary join. Updates and deletes remain denied. `topics` has no writes.

The deterministic document ID is used by Dart for lookup and idempotency. Rules authorize the stored identity fields; they do not attempt to reproduce Dart URI encoding and therefore do not treat the ID string as the authorization mechanism.

## Authorization Matrix

| Operation | Unauthenticated | Authenticated user | Member | Owner | Admin | Moderator | Non-member |
|---|---|---|---|---|---|---|---|
| Create Community | deny | allow for own owner | allow | allow | allow | allow | allow |
| Create member join | deny | allow for own UID, active Community | allow | allow | allow | allow | allow |
| Create owner membership | deny | deny outside atomic create | deny | only own atomic create | deny as role escalation | deny as role escalation | deny |
| Update/delete Community | deny | deny | deny | deny | deny | deny | deny |
| Update/delete membership | deny | deny | deny | deny | deny | deny | deny |
| Topic writes | deny | deny | deny | deny | deny | deny | deny |
| Read behavior | deny | Phase 16 policy | Phase 16 policy | Phase 16 policy | Phase 16 policy | Phase 16 policy | Phase 16 policy |

## Tests

The existing `@firebase/rules-unit-testing` and Firebase Emulator infrastructure was reused. The Rules suite passes `17/17` tests, covering:

- valid atomic Community + owner membership creation;
- unauthenticated creation denial;
- mismatched owner and missing/extra authorization fields;
- member creation with arbitrary owner/admin/moderator roles denied;
- arbitrary status denied;
- join for an existing active Community;
- third-party membership denial;
- duplicate direct write denial;
- all Community/membership/topic update and delete attempts denied;
- post-creation `get`, list, user-membership, and member-list queries;
- existing Phase 16 staff and membership-read protections.

Dart tests in `firestore_community_write_service_test.dart` pass `3/3`, covering schema persistence, owner membership, deterministic identity, sequential idempotent join, missing Community, and unauthenticated service calls. All data in tests is fake or Emulator-only.

## Validation and Limitations

- `npm --prefix backend/functions run test:security`: pass, `17/17`.
- `flutter analyze`: pass.
- `flutter test`: pass, `69` tests.
- `firestore.indexes.json`: unchanged; existing compound-query index needs remain future preconditions.
- No Firebase deploy or production write was performed.
- The current domain still lacks visibility/lifecycle fields beyond the write-time `status`, so private/public discovery policy remains unresolved.
- Join is sequentially idempotent; concurrent duplicate creation is rejected by create-only Rules rather than reconciled.
- Owner creation depends on client batch atomicity and Rules `getAfter`; no Cloud Function was added.

## Preserved and Blocked

Personal Universe, `CommunityPage`, `CommunityBubbleMap`, `SocialProvider`, `OrbUniverse`, `OrbMembership`, `InteractionScore`, Authentication, and the Phase 16 read path were not changed. No Community write was connected to UI.

Phase 18 preconditions: decide visibility and lifecycle policy, choose whether concurrent join idempotency needs a server transaction, define update/leave/moderation authorization, finalize indexes from deployed query evidence, and restore/read the missing Phase 13 foundation document if it is required as project source of truth.