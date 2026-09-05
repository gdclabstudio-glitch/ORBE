# ORBE Phase 25: Moderation, Lifecycle, Reports and Historical Preservation

Status: Implemented. No production deployment was performed.

## 1. Audit

Community Knowledge had no lifecycle field or formal report path. The existing `ModerationService` and `AdminModerationPage` target legacy memory reports and are not reused for Community Knowledge. `Post`, `PostService`, social reports, Auth, and OrbUniverse remain separate.

## 2. Architecture

Knowledge moderation uses a dedicated `CommunityModerationRepository` and `FirestoreCommunityModerationRepository`. Reports live in `community_reports/{reportId}`. The report stores the owning community, target type/id, optional parent content ID for nested Evidence/Correction, reason, reporter and review fields. This supports community isolation, bounded staff queries and deterministic duplicate prevention without changing existing content subcollections.

## 3. Lifecycle

`CommunityContentLifecycle` contains only `active`, `underReview`, `restricted`, `corrected`, and `archived`. Lifecycle is moderation/history state, never a truth state:

- `underReview` does not mean false;
- `restricted` does not mean false;
- `corrected` does not mean false;
- `archived` does not mean false.

New content starts `active`. Authors may edit content fields without changing lifecycle. Active owner/admin/moderator roles may change lifecycle through Rules-authorized moderation operations.

## 4. CommunityContent

Content now serializes lifecycle while remaining independent from social posts. Existing Phase 23 documents without lifecycle remain readable and are interpreted by the domain as `active`; no migration was performed.

Restricted content is hidden from ordinary members but remains readable by community moderation staff. Physical deletion remains blocked.

## 5. Reports

Reports are private review requests. A report does not assert that content is false and never changes lifecycle automatically. Targets are `content`, `evidence`, `source`, or `correction`. Nested targets require `parentContentId`, and Rules verify that the parent/target belongs to the declared community.

Report IDs are deterministic by community, reporter, target, and reason. A duplicate attempt from the same reporter for the same target/reason therefore fails rather than creating priority manipulation.

## 6. Reasons

The small controlled set is `misinformation`, `fabricatedEvidence`, `misleadingSource`, `harassment`, `spam`, `offTopic`, and `other`. `misinformation` is the reporter's allegation for review, not an automatic label.

## 7. Resolution

Resolutions are `noAction`, `warning`, `restrictContent`, `archiveContent`, `requestCorrection`, and `dismissReport`. Reports move from `open` to `resolved` once. A second resolution attempt fails. No automatic strike, ban, suspension, truth decision or majority threshold exists.

## 8. Moderation

Active owner/admin/moderator roles may list reports for their own community, inspect targets, resolve reports and update content lifecycle. Ordinary members may create reports but cannot read or resolve reports or update lifecycle. Review fields are server-controlled by Rules and preserve the original reporter and creation timestamp.

## 9. Good Faith vs Intent

The system does not infer intent and does not store an algorithmic `isMalicious` decision. A moderator may use the report reason and evidence context in a future human decision, but this phase does not accuse an author or classify deception automatically.

## 10. Evidence

Evidence remains preserved and append-only. Reporting an Evidence record does not delete it or remove it from the content. Nested evidence reports identify both `targetId` and `parentContentId` to prevent cross-community references.

## 11. Source

Sources remain preserved and append-only. A reported source is not automatically called false and does not automatically invalidate its parent content. Source targets are resolved under the declared community path.

## 12. Correction

Corrections remain append-only and visible as historical context. A report or lifecycle decision does not erase the original content or correction. Corrections do not automatically change lifecycle.

## 13. Historical Preservation

Content, Evidence, Source, Correction and Report documents are not physically deleted by clients. Restricted and archived content remain available to authorized moderators, preserving the review trail. Original `createdBy`, `communityId`, `createdAt`, and target identities are immutable.

## 14. Soft Delete / Archive

No physical soft-delete was introduced. `archived` is a lifecycle state on the original document, with `updatedAt` and `lifecycleUpdatedBy`. This preserves data and avoids silently destroying history.

## 15. Privacy

Reports are not readable by ordinary members or reporters after submission. Only staff authorized for the target community can list or resolve them. Reporter identity is not rendered in the ordinary Community Knowledge UI. Cross-community reads and reports are denied.

## 16. UI

Knowledge detail displays neutral lifecycle notices. Content can be reported through a non-dominant contextual action and shows `Seu report foi enviado para revisão.` on success. Moderation review is a compact community-scoped list, not a global dashboard. Lifecycle notices never say `Fake News` or claim a truth decision.

## 17. CommunityDetail

The detail surface remains the home for knowledge. Active moderation roles receive a review action from the knowledge section; ordinary members see only the report action. Existing member/topic/universe flows are unchanged.

## 18. Rules

Rules validate authentication, active membership, target community, target existence, deterministic report identity, allowed reason/status/resolution values, `reportedBy`, `reviewedBy`, immutable fields, one-way resolution, and lifecycle role separation. Restricted content is readable by moderation staff only. Missing lifecycle on legacy documents is treated as active for reads.

## 19. Pagination

Open reports use `CommunityPageRequest` and opaque document-ID cursors, ordered by `createdAt DESC`. The repository does not load all reports and does not expose Firestore snapshots to UI.

## 20. Concurrency

Report resolution uses a Firestore transaction and Rules require the current report status to be `open`. Concurrent resolution therefore has one winning transition; later attempts receive a conflict/permission failure. No distributed locking system was added.

## 21. Anti-abuse

Duplicate same-user/target/reason reports are prevented by deterministic IDs. Cross-community targets, forged reporter/reviewer identity and nonexistent targets are denied. There is no reporter reputation, report-count punishment, ban, strike or automatic suspension.

## 22. Tests

Domain tests cover report serialization and lifecycle defaults. Existing knowledge UI/domain/repository tests remain green. Emulator Rules tests cover active report creation, inactive/non-member denial, forged identity, duplicate reports, cross-community targets, private report reads, same-community moderator access, restricted content visibility, immutable lifecycle, one-time resolution and denied deletion.

## 23. Firebase

No new Cloud Functions, Auth changes, migrations or production writes were made. The new `community_reports` collection is protected by Rules and is not deployed automatically.

## 24. What Was Not Implemented

No Truth Score, automatic truth decision, AI arbitration, peer review, popularity authority, majority proof, automatic ban, strike system, user suspension, advanced moderation dashboard, soft-delete collection, moderation of social Posts, Notifications, or OrbUniverse changes were implemented.

## 25. Risks and Limitations

Human moderation can still be inconsistent or biased. Lifecycle state does not establish truth. Report reasons are allegations and require future review quality processes. The current role model includes existing admin/moderator claim behavior and community membership roles; a future role governance phase may unify those sources.

## 26. Next Phase

Define moderation evidence presentation, audit history, appeals and role governance before expanding report analytics or automated abuse controls.
