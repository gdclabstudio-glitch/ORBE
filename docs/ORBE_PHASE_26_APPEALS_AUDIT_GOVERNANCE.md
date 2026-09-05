# ORBE Phase 26 — Appeals, Audit Governance and Moderation History

## Objective

This phase adds a minimal but auditable moderation layer that preserves the existing Fase 25 model without turning moderation into truth certification. The core principle is:

- Moderation state is not truth state.
- Fact is a user or community content classification, not an ORBE truth certification.
- A moderation action records policy application, not absolute truth.

This implementation is intentionally conservative and incremental.

## Initial audit

The current domain already includes:

- community content lifecycle;
- community report status and resolution;
- membership role and status tracking;
- moderation repository and UI controller for report handling;
- Firestore rules that restrict moderation reads and lifecycle updates to community staff.

The actual implementation was reviewed against the real code before any change. The existing moderation design already separated state from report resolution, but it did not yet preserve an append-only audit trail or a private appeal lifecycle. The Fase 25 model was also missing a formal distinction between lifecycle history and the present state of content.

## Architecture implemented

The minimal architecture preserves what exists and adds the missing accountable layer:

- `community_reports` remains the report collection;
- `community_moderation_actions` stores append-only admin history;
- `community_moderation_appeals` stores privileged appeal review records;
- `CommunityContent` keeps the live lifecycle state;
- the new domains keep history separate from state;
- the service layer records the audit action and maintains deterministic shapes.

This avoids rewriting the social stack or changing Auth, OrbUniverse, or the non-community Post system.

## Audit trail

The new `CommunityModerationAction` domain records the minimum data needed for accountability:

- actionId
- communityId
- actorId
- actionType
- targetType
- targetId
- reportId (optional)
- appealId (optional)
- reason
- previousLifecycle (optional)
- newLifecycle (optional)
- createdAt

The allowed action types are intentionally small and limited to the operational needs of moderation:

- reportCreated
- reportResolved
- lifecycleChanged
- correctionRequested
- appealCreated
- appealResolved

The action record is append-only and does not represent a truth judgment. It only represents a moderation event.

## Lifecycle history

The current lifecycle remains in the content document. That state is the current state. The new action entries preserve the historical view:

- previousLifecycle
- newLifecycle
- actorId
- reason
- communityId
- targetId
- createdAt

This ensures a content record can show:

- current state: restricted
- historical trail: active -> restricted

without confusing the two concepts.

## Appeals

The `CommunityModerationAppeal` model adds a minimal private contestation flow for relevant moderation actions. Relevant cases include restricted content, archived content, warning actions, and correction requests.

Fields include:

- appealId
- communityId
- targetType
- targetId
- parentContentId (when nested)
- originalActionId (optional)
- reportId (optional)
- createdBy
- createdAt
- status
- resolution (optional)
- reviewedBy (optional)
- reviewedAt (optional)
- reason
- reviewReason (optional)

States:

- open
- underReview
- accepted
- rejected
- withdrawn

Resolutions:

- uphold
- overturn
- modify

The appeal flow is not a truth contest. It is a structured request to review whether the moderation decision was applied correctly and fairly under the relevant community rule.

## Appeal resolution

Appeal review is restricted to moderator/admin/owner staff in the same community. Review is intentionally minimal and does not create a tribunal.

If a decision is upheld, the original moderation action remains in place.

If an appeal is overturned or modified, the system records the new lifecycle state explicitly and writes the resulting action records. This avoids silently changing content state to active without recording the previous and new lifecycle.

## Role governance

The phase does not add a full role-management system. It formalizes the existing governance model and protects against the most important abuses:

- member cannot self-promote;
- moderator cannot create another moderator;
- client cannot forge role claims;
- cross-community role or access is rejected;
- owner remains the community owner unless explicit future governance changes are added.

This phase intentionally documents the role gap rather than inventing a large new role-management architecture.

## Permissions

The minimal permission model is:

- Members may create reports.
- Members may not resolve reports.
- Members may not change lifecycle.
- Members may not read private moderation history.
- Community staff may read reports and appeals for their own community.
- Affected users may create appeals for their own relevant action.
- Staff may review appeals in the same community.

Additionally, all client-supplied identity data remains untrusted and is treated as informational only.

## Privacy

Reports, appeals, and audit actions remain private to authorized community staff and the affected user when appropriate.

This avoids exposing:

- the identity of a reporter to other members;
- appeal history for unrelated users;
- internal moderation analysis notes;
- targeted data for third parties.

The UI uses neutral wording such as:

- “Sua denúncia foi enviada para revisão.”
- “Esta decisão pode ser contestada.”
- “Esta decisão está em revisão.”

## Community isolation

Every moderation record is bound to a `communityId`, and targets are validated against the declared community. Cross-community target or cross-community access is denied.

This keeps moderation records inside the relevant community and prevents a user from creating actions that refer to another community’s resources.

## Transactions

Implemented:

- report resolution commits the report state and `reportResolved` audit in one
  Firestore transaction;
- appeal creation commits the appeal and `appealCreated` audit together;
- `beginAppealReview` conditionally changes `open` to `underReview`;
- appeal resolution commits the appeal, `appealResolved` audit, and any
  overturn/modify lifecycle transition and `lifecycleChanged` audit together;
- lifecycle changes validate the expected/current state and write the state and
  history entry together.

## Concurrency

Concurrency is kept deterministic and lightweight:

- actions are append-only;
- report or appeal resolution is conditioned on the existing current status;
- lifecycle updates require the expected state before they apply;
- if the condition no longer holds, the second operation fails with conflict.

No distributed lock or complex moderation queue is introduced. Real contention
was executed against the Firestore Emulator with independent concurrent
transactions: report resolution (one winner), appeal resolution (`uphold` vs
`overturn`, one winner), and lifecycle transition (one winner). The losing
transaction failed safely after the winning state change; no duplicate
resolution or audit action was persisted.

## Repository

The architecture keeps the repositories separate:

- `CommunityModerationRepository` for report flow;
- `CommunityModerationActionRepository` for append-only action trail;
- `CommunityModerationAppealRepository` for appeal flow.

This avoids one large “everything repository” that mixes content, reports, actions, and appeals into a single concern.

## Service

The service layer is the source of business validation and consistency. It is responsible for:

- validating authenticated actors;
- validating role and membership context;
- validating target existence and community isolation;
- validating lifecycle transitions;
- recording audit actions;
- ensuring atomic updates where necessary.

The UI never becomes the authority for moderation decisions.

## UI

The existing community detail and moderation pages remain intact. This phase adds only the minimal accountability surfaces needed:

- neutral moderation notices;
- appeal entry for affected users;
- private moderation review UI for staff;
- clear separation between current state and historical action trail.

This phase does not add a truth score, vote-based fact checking, or a public moderation leaderboard.

## Firestore

The schema stays minimal and readable:

- `community_reports/{reportId}`
- `community_moderation_actions/{actionId}`
- `community_moderation_appeals/{appealId}`

These collections are deliberately separated by concern. This keeps queries simple, maintains clear access control, and supports audit without making the database structure more complicated than needed.

## Rules

The rules continue to enforce that moderation actions are not writable by arbitrary clients. The focus is on identity, access, and immutability. Client-supplied fields such as actorId, reviewedBy, or communityId are treated as untrusted and must be validated by the backend logic and/or rule checks.

The allowable pattern is:

- staff can read audit and appeal records in their community;
- affected user can access their own appeal;
- outsider or cross-community users are denied;
- all historical identity fields remain immutable.

## Pagination

The minimal ordering strategy is `createdAt DESC` with opaque cursor pagination. This supports audit and appeals without forcing the UI to fetch all records.

## Backward compatibility

The existing content model remains readable. If a legacy item does not carry an explicit lifecycle, it continues to be treated as `active` on read for compatibility. No large migration was introduced. This phase keeps the pre-existing Phase 23–25 content and report flows intact.

## Validation status

Implemented domain coverage:

- valid moderation action creation;
- valid appeal creation;
- lifecycle data serialization;
- actor and reason capture;
- immutable audit semantics.

Repository coverage validates atomic report resolution, atomic appeal creation,
explicit appeal review, appeal resolution, lifecycle changes for overturn/modify,
and the corresponding audit actions.

## Firebase Emulator

Validated in this session with:

- `npm run test:security`: **22/22 tests passed**;
- `npm run test:concurrency`: **4/4 tests passed** against the real
  Firestore Emulator, including report, appeal, lifecycle contention and
  transaction-failure atomicity.

## Risks and limitations

This phase is intentionally minimal. It does not fully solve:

- role governance maturity;
- moderation policy quality;
- fairness or bias in human review;
- appeal escalation beyond a single review stage;
- automated source verification.

The result is accountability and traceability, not a fully bureaucratized moderation system.

## Definition of done

### IMPLEMENTADO

- report resolution writes `reportResolved` atomically;
- appeal creation writes `appealCreated` atomically;
- `beginAppealReview` permits only an active, independent staff reviewer;
- appeal resolution writes `appealResolved` atomically;
- `uphold` preserves the current lifecycle;
- `overturn` and `modify` require an explicit domain lifecycle and atomically
  update lifecycle, appeal, and audit;
- concurrent state transitions are guarded by transaction preconditions;
- audit records are private, append-only, and identity-bound;
- appeal access is restricted to the affected user and staff in the same
  community.

### VALIDADO

- audit actions are private and append-only in Rules;
- lifecycle changes can atomically preserve previous and new state through `changeLifecycleWithHistory`;
- affected users can create one deterministic open appeal;
- appeal privacy, staff review, self-resolution denial, and cross-community denial are enforced;
- no truth scoring or automatic punishments were introduced;
- existing social/Post/Auth/OrbUniverse flows remain untouched.

### NÃO IMPLEMENTADO

- appeal-review audit action: no existing action type expresses
  `underReview`, so the status transition is persisted without inventing a new
  action type;
- Truth Score, AI arbitration, voting, automatic bans/strikes, notifications,
  escalation workflows, and public audit visibility.

## Test results

- `flutter test`: **101/101 passed**
- `flutter analyze`: **No issues found**
- `npm run test:security`: **22/22 passed**
- `npm run test:concurrency`: **4/4 passed**
- focused audit transaction tests: **2/2 passed**

## Phase status

**PHASE 26 — COMPLETE**

All required atomicity, audit, privacy, identity, reviewer-independence,
cross-community, contention, Flutter, analyzer, and Emulator security checks
listed for this phase have passed. The concurrency evidence is from the real
Firestore Emulator; `fake_cloud_firestore` is used only for repository unit
coverage and is not treated as contention evidence. No Phase 27 work was
started.
