# ORBE Phase 18 - Membership Integrity, Concurrency and Lifecycle Safety

Status: integrity hardening for Community creation and join. No UI, moderation, lifecycle mutation, Cloud Function, migration, Authentication change, deploy, or production data access was performed.

## Audit Notes

The required Phase 13 document remains absent from the workspace. It was not recreated or inferred. The current `CommunityService` remains the broad future mutation contract; the narrow `CommunityWriteService` continues to expose only creation and join.

## Invariants

- A membership ID is the deterministic `communityId::userId` identity for the effective generated-ID/UID format.
- Membership fields must match the authenticated user and target Community.
- Ordinary create/join accepts only `role: member` and `status: active`.
- Owner membership is only accepted atomically with a newly-created Community whose `ownerId` is the caller.
- Membership timestamps are server timestamps equal to `request.time`.
- Existing memberships are never overwritten, promoted, or repaired by join.
- Community creation writes the Community and owner membership in one batch.
- Topics remain read-only.

The Rules now reject a membership document ID that does not equal `communityId::userId`. The Dart identity helper still URI-encodes components; generated Community IDs and Firebase UIDs used by these writes are safe for the Rule expression. Special-character identity compatibility remains a documented future constraint.

## Join Semantics

| Existing state | Join result | State change |
|---|---|---|
| `active` | Return existing membership | None |
| `pending` | `CommunityError.conflict` | None |
| `blocked` | `CommunityError.forbidden` | None |
| `left` | `CommunityError.conflict` | None |
| Missing | Create `member/active` transactionally | One create |

No state is promoted automatically. Join is not a moderation operation.

## Concurrency Strategy

`FirestoreCommunityWriteService.joinCommunity` now uses Firestore `runTransaction` to read the Community and deterministic membership, then create only when the membership is absent. A retry that observes the committed membership returns it, so concurrent service calls converge to one result. Existing create-only Rules remain the final guard against direct client races and reject competing writes without overwriting.

Community creation remains a single batch containing the Community and owner membership. The owner rule uses `getAfter` and the server timestamp to prevent creating owner membership later or for another Community.

## Rules and Access

`communities.create` validates the exact supported field set, authenticated owner, active status, non-empty name, and server timestamps. `community_memberships.create` validates exact fields, deterministic ID, self UID, active status, timestamps, active target Community, and the restricted member/atomic-owner roles. All Community and membership updates/deletes remain denied. Topics have no writes.

The Phase 16 read policy remains intact: authenticated metadata reads, self membership reads, and staff-only member enumeration. Owner/admin/moderator read privileges do not grant write or role escalation.

## Tests

The existing Firebase Emulator and `@firebase/rules-unit-testing` suite was reused. It passes `18/18` tests, including:

- valid atomic Community plus owner membership;
- owner mismatch, missing/extra fields, invalid status/timestamps, and privileged role payloads;
- inconsistent membership document ID and mismatched Community/user fields;
- owner membership outside the creation batch and for a third party;
- unauthenticated and non-member denial;
- existing Phase 16 read/query compatibility;
- eight concurrent direct membership creates, exactly one success, seven rejected, one final consistent document;
- update/delete denial for Community, membership, and topics.

Dart tests in `firestore_community_write_service_test.dart` pass `5/5`, covering missing/active/pending/blocked/left memberships, repeated joins, ten concurrent transactional joins converging to one membership, authentication errors, and missing Communities. The full Flutter suite passes `71` tests.

## Verified Queries and Indexes

Verified in Emulator after creation: Community get/list, user membership query ordered by `updatedAt`, member listing ordered by `createdAt`, direct `getMembership`, and `isMember` behavior. `listCommunitiesByTopic` remains a read-only Phase 16 query. `firestore.indexes.json` was not modified; compound index requirements remain deployment preconditions based on actual production query errors.

## Limitations and Debt

- The Emulator concurrency test validates competing direct creates and final state; it does not reproduce network timing across multiple production clients. The Dart fake test validates transaction convergence in the available local implementation.
- Concurrent transaction retries depend on Firestore's native transaction behavior. No custom retry loop or Cloud Function was added.
- Rejoining `left` or resolving `pending` requires an explicit future lifecycle policy and operation.
- The existing domain still does not model visibility or full persisted Community metadata.
- Phase 13 foundation documentation is still missing.

## Phase 19 Preconditions

Define and security-test lifecycle operations such as leave, approval, blocking, role changes, and Community updates; decide whether concurrent join needs server-owned idempotency keys; finalize visibility and status policy; add only measured indexes; and preserve the Personal Universe/UI boundary. No Phase 19 operation is started here.