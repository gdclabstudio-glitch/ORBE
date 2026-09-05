import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize admin if not already
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const systemEventsCollection = 'system_events';
const systemMetricsCollection = 'system_metrics';
const systemMetricsDocumentId = 'overview';

const VALID_ADMIN_ACTIONS = new Set([
  'delete_post',
  'ban_user',
  'mass_fcm',
  'assignRoleClaims',
  'moderate_community',
  'review_story',
  'system_alert',
  'unknown_action',
]);

const VALID_RESOURCE_TYPES = new Set([
  'user',
  'post',
  'story',
  'comment',
  'message',
  'group',
  'community',
  'broadcast',
  'target',
  'unknown',
]);

const MAX_REASON_LENGTH = 500;
const MAX_DETAILS_BYTES = 16384;
const REDACTED_LOG_VALUE = '[REDACTED]';
const SENSITIVE_LOG_KEYS = [
  'password',
  'token',
  'authorization',
  'secret',
  'api_key',
  'apikey',
  'refresh_token',
  'cookie',
  'session',
  'email',
  'phone',
  'cpf',
  'ssn',
];

function sanitizeForLogs(value: unknown, maxDepth = 2): unknown {
  if (value === null || value === undefined) {
    return value;
  }

  if (Array.isArray(value)) {
    return value.slice(0, 8).map((entry) => sanitizeForLogs(entry, maxDepth - 1));
  }

  if (typeof value === 'string') {
    return value.length > 256 ? `${value.slice(0, 253)}...` : value;
  }

  if (typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'object') {
    if (maxDepth < 0) {
      return '[TRUNCATED]';
    }

    const sanitized: Record<string, any> = {};
    for (const [key, raw] of Object.entries(value as Record<string, any>)) {
      const keyLower = key.toLowerCase();
      if (SENSITIVE_LOG_KEYS.some((sensitiveKey) => keyLower.includes(sensitiveKey))) {
        sanitized[key] = REDACTED_LOG_VALUE;
        continue;
      }

      sanitized[key] = sanitizeForLogs(raw, maxDepth - 1);
    }
    return sanitized;
  }

  return String(value);
}

function logStructured(level: 'info' | 'warn' | 'error', event: string, payload: Record<string, any> = {}) {
  const entry = {
    ts: new Date().toISOString(),
    level,
    event,
    payload: sanitizeForLogs(payload),
  };

  if (level === 'error') {
    console.error(JSON.stringify(entry));
    return;
  }

  if (level === 'warn') {
    console.warn(JSON.stringify(entry));
    return;
  }

  console.log(JSON.stringify(entry));
}

function sanitizeString(value: unknown, maxLength: number, fallback: string): string {
  if (typeof value !== 'string') {
    return fallback;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return fallback;
  }

  return trimmed.slice(0, maxLength);
}

function normalizeAdminAction(rawAction: unknown): string {
  if (typeof rawAction !== 'string') {
    return 'unknown_action';
  }

  const normalized = rawAction.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_');
  if (!normalized || normalized.length > 64) {
    return 'unknown_action';
  }

  return normalized;
}

function normalizeResourceType(rawType: unknown): string {
  if (typeof rawType !== 'string') {
    return 'unknown';
  }

  const normalized = rawType.trim().toLowerCase();
  return VALID_RESOURCE_TYPES.has(normalized) ? normalized : 'unknown';
}

function isValidResourceId(value: unknown): boolean {
  if (typeof value !== 'string') {
    return false;
  }

  const normalized = value.trim();
  if (!normalized || normalized.length > 128) {
    return false;
  }

  return /^[A-Za-z0-9._:-]+$/.test(normalized);
}

const VALID_REPORT_CATEGORIES = new Set([
  'spam',
  'harassment',
  'hate',
  'sexual_content',
  'violence',
  'fraud',
  'impersonation',
  'illegal_content',
  'account_compromised',
  'other',
]);

const VALID_REPORT_TYPES = new Set([
  'user',
  'post',
  'comment',
  'story',
  'message',
  'community',
  'group',
  'event',
  'profile',
  'other',
]);

function normalizeReportCategory(rawCategory: unknown): string {
  if (typeof rawCategory !== 'string') {
    return 'other';
  }

  const normalized = rawCategory.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_');
  return VALID_REPORT_CATEGORIES.has(normalized) ? normalized : 'other';
}

function normalizeReportType(rawType: unknown): string {
  if (typeof rawType !== 'string') {
    return 'other';
  }

  const normalized = rawType.trim().toLowerCase();
  return VALID_REPORT_TYPES.has(normalized) ? normalized : 'other';
}

function validateReportPayload(payload: Record<string, any> | null | undefined) {
  if (!payload || typeof payload !== 'object') {
    return { ok: false, error: 'Report payload is required.' };
  }

  const reportType = normalizeReportType(payload.resourceType ?? payload.type ?? 'other');
  const category = normalizeReportCategory(payload.category ?? 'other');
  const resourceId = sanitizeString(payload.resourceId ?? payload.postId ?? payload.userId ?? payload.commentId ?? payload.storyId ?? payload.messageId ?? payload.targetId ?? '', 128, '');
  const reason = sanitizeString(payload.reason ?? payload.details?.reason ?? 'Report submitted via secure backend', MAX_REASON_LENGTH, 'Report submitted via secure backend');

  if (!VALID_REPORT_TYPES.has(reportType)) {
    return { ok: false, error: 'Unsupported report type.' };
  }

  if (!VALID_REPORT_CATEGORIES.has(category)) {
    return { ok: false, error: 'Unsupported report category.' };
  }

  if (!resourceId || !isValidResourceId(resourceId)) {
    return { ok: false, error: 'A valid resourceId is required.' };
  }

  const details = payload.details && typeof payload.details === 'object' && !Array.isArray(payload.details)
    ? payload.details as Record<string, any>
    : {};

  const normalizedDetails = JSON.stringify(details);
  if (normalizedDetails.length > MAX_DETAILS_BYTES) {
    return { ok: false, error: 'Report details exceed the maximum size.' };
  }

  return {
    ok: true,
    category,
    resourceType: reportType,
    resourceId,
    reason,
    details,
  };
}

export function validateAdminActionPayload(payload: Record<string, any> | null | undefined) {
  const rawAction = payload?.type ?? payload?.action ?? 'unknown_action';
  const action = normalizeAdminAction(rawAction);

  if (!VALID_ADMIN_ACTIONS.has(action)) {
    return {
      ok: false,
      action,
      resourceType: 'unknown',
      resourceId: '',
      reason: '',
      details: {},
      error: `Unsupported admin action: ${String(rawAction)}`,
    };
  }

  const resourceType = normalizeResourceType(payload?.resourceType ?? inferResourceType(payload ?? {}));
  if (!VALID_RESOURCE_TYPES.has(resourceType)) {
    return {
      ok: false,
      action,
      resourceType,
      resourceId: '',
      reason: '',
      details: {},
      error: 'Invalid resource type for privileged admin action.',
    };
  }

  const rawResourceId = payload?.resourceId ?? payload?.postId ?? payload?.userId ?? payload?.targetId ?? payload?.storyId ?? payload?.messageId ?? 'unknown';
  const resourceId = sanitizeString(rawResourceId, 128, '');
  if (!isValidResourceId(resourceId)) {
    return {
      ok: false,
      action,
      resourceType,
      resourceId: '',
      reason: '',
      details: {},
      error: 'Admin action requires a valid resourceId.',
    };
  }

  const reason = sanitizeString(payload?.reason ?? 'Administrative action requested from control center', MAX_REASON_LENGTH, 'Administrative action requested from control center');
  const rawDetails = payload?.details && typeof payload.details === 'object' && !Array.isArray(payload.details)
    ? payload.details as Record<string, any>
    : {};

  const detailsJSON = JSON.stringify(rawDetails);
  if (detailsJSON.length > MAX_DETAILS_BYTES) {
    return {
      ok: false,
      action,
      resourceType,
      resourceId,
      reason,
      details: {},
      error: 'Admin action details are too large.',
    };
  }

  return {
    ok: true,
    action,
    resourceType,
    resourceId,
    reason,
    details: rawDetails,
  };
}

export function normalizeRoleName(rawRole: unknown): string {
  if (typeof rawRole !== 'string') {
    return 'user';
  }

  const normalized = rawRole.trim().toLowerCase();
  return ['owner', 'admin', 'moderator', 'user'].includes(normalized) ? normalized : 'user';
}

async function updateOverviewMetric(metricKey: string, delta: number, value?: number | string | boolean) {
  const update: Record<string, any> = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (value !== undefined) {
    update[metricKey] = value;
  } else {
    update[metricKey] = admin.firestore.FieldValue.increment(delta);
  }

  await db.collection(systemMetricsCollection).doc(systemMetricsDocumentId).set(update, { merge: true });
}

async function writeSystemEvent(
  eventType: string,
  payload: Record<string, any>,
  severity: 'info' | 'warning' | 'critical' = 'info',
  source = 'backend'
) {
  const event = {
    eventType,
    severity,
    source,
    payload: payload ?? {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection(systemEventsCollection).add(event);
}

export const onUserCreated = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const userId = context.params.userId as string;
    const payload = {
      userId,
      createdAt: snap.get('createdAt') ?? admin.firestore.Timestamp.now(),
    };

    await writeSystemEvent('user_created', payload, 'info');
    await updateOverviewMetric('newUsersToday', 1);
    return null;
  });

export const onPostCreated = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snap, context) => {
    const postId = context.params.postId as string;
    const authorId = (snap.data()?.authorId as string | undefined) ?? 'unknown';

    await writeSystemEvent('post_created', { postId, authorId }, 'info');
    await updateOverviewMetric('newPostsToday', 1);
    return null;
  });

export const onStoryCreated = functions.firestore
  .document('users/{userId}/stories/{storyId}')
  .onCreate(async (snap, context) => {
    const userId = context.params.userId as string;
    const storyId = context.params.storyId as string;
    const payload = {
      userId,
      storyId,
      createdAt: snap.get('createdAt') ?? admin.firestore.Timestamp.now(),
    };

    await writeSystemEvent('story_created', payload, 'info');
    await updateOverviewMetric('storiesPublishedToday', 1);
    return null;
  });

// Trigger when a reaction doc is created under posts/{postId}/reactions/{reactionId}
export const onPostReactionCreated = functions.firestore
  .document('posts/{postId}/reactions/{reactionId}')
  .onCreate(async (snap, context) => {
    try {
      const reaction = snap.data();
      const postId = context.params.postId as string;
      const reactionId = context.params.reactionId as string;
      const type = reaction?.type as string | undefined;
      const actor = reaction?.userId as string | undefined;

      if (!actor || !type) return null;

      // read post to determine target user (author)
      const postDoc = await db.collection('posts').doc(postId).get();
      const post = postDoc.data() || {};
      const targetUid = post['authorId'] as string | undefined;

      if (!targetUid || targetUid == actor) return null; // don't notify self

      // create notification (deterministic by reaction content)
      const n = {
        'type': 'reaction',
        'subtype': 'post',
        'actor': actor,
        'emoji': type,
        'postId': postId,
        'reactionId': reactionId,
        'createdAt': admin.firestore.FieldValue.serverTimestamp(),
        'read': false
      };

      const deterministicId = `reaction_post_${postId}_${actor}_${type}`;
      await db.collection('users').doc(targetUid).collection('notifications').doc(deterministicId).set(n, { merge: true });
      return null;
    } catch (err) {
      logStructured('error', 'on_post_reaction_created', {
        error: sanitizeForLogs(err),
        postId: context.params.postId,
      });
      return null;
    }
  });

// Trigger when a reaction doc is deleted — could be used to remove aggregated notifications or log
export const onPostReactionDeleted = functions.firestore
  .document('posts/{postId}/reactions/{reactionId}')
  .onDelete(async (snap, context) => {
    // For now: no-op (placeholder for analytics or audit)
    return null;
  });

// Trigger when a reaction is created under a comment
export const onCommentReactionCreated = functions.firestore
  .document('posts/{postId}/comments/{commentId}/reactions/{reactionId}')
  .onCreate(async (snap, context) => {
    try {
      const reaction = snap.data();
      const postId = context.params.postId as string;
      const commentId = context.params.commentId as string;
      const reactionId = context.params.reactionId as string;
      const type = reaction?.type as string | undefined;
      const actor = reaction?.userId as string | undefined;

      if (!actor || !type) return null;

      // fetch the post and comment to find comment author
      const postDoc = await db.collection('posts').doc(postId).get();
      const post = postDoc.data() || {};
      const comments = (post['comments'] as any[] | undefined) ?? [];
      let targetUid: string | undefined;
      for (const c of comments) {
        if (c['id'] == commentId) {
          targetUid = c['authorId'] as string | undefined;
          break;
        }
      }

      if (!targetUid || targetUid == actor) return null;

      const n = {
        'type': 'reaction',
        'subtype': 'comment',
        'actor': actor,
        'emoji': type,
        'postId': postId,
        'commentId': commentId,
        'reactionId': reactionId,
        'createdAt': admin.firestore.FieldValue.serverTimestamp(),
        'read': false
      };

      const deterministicId = `reaction_comment_${commentId}_${actor}_${type}`;
      await db.collection('users').doc(targetUid).collection('notifications').doc(deterministicId).set(n, { merge: true });

      // send FCM to the target if token available
      try {
        const userDoc = await db.collection('users').doc(targetUid).get();
        const userData = userDoc.data() || {};
        const token = (userData.fcmToken || userData.fcm_token || (Array.isArray(userData.fcmTokens) ? userData.fcmTokens[0] : null)) as string | undefined;
        if (token) {
          await admin.messaging().sendToDevice(token, {
            notification: {
              title: 'Nova reação',
              body: `${reaction?.userId} reagiu com ${type}`,
            },
            data: { postId, commentId, type: 'reaction' }
          });
        }
      } catch (e) {
        logStructured('error', 'fcm_send_failed_comment_reaction', {
          error: sanitizeForLogs(e),
          commentId,
          postId,
        });
      }

      return null;
    } catch (err) {
      logStructured('error', 'on_comment_reaction_created', {
        error: sanitizeForLogs(err),
        postId: context.params.postId,
        commentId: context.params.commentId,
      });
      return null;
    }
  });


// Trigger when a new chat message is created: send FCM to recipient(s)
export const onChatMessageCreated = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const chatId = context.params.chatId as string;
    const msg = snap.data();
    const sender = msg?.senderId as string | undefined;
    try {
      const text = msg?.text as string | undefined;

      // Determine recipients from the authoritative chat membership, not from client-supplied
      // fields that can be spoofed or stale. Backfill only for legacy room IDs when needed.
      let recipients: string[] = [];
      const chatDoc = await db.collection('chats').doc(chatId).get();
      const chatData = chatDoc.data() ?? {};
      const participantIds = Array.isArray(chatData?.participants)
        ? (chatData.participants as string[])
        : Array.isArray(chatData?.members)
          ? (chatData.members as string[])
          : [];
      if (participantIds.length > 0) {
        recipients = participantIds.filter((uid) => !!uid && uid !== sender);
      }
      if (recipients.length === 0 && msg?.recipientId) recipients.push(msg.recipientId as string);
      if (recipients.length === 0 && msg?.to) recipients.push(msg.to as string);
      if (recipients.length === 0 && chatId) {
        const parts = chatId.split('_');
        recipients = parts.filter((p) => p && p !== sender);
      }

      recipients = [...new Set(recipients.filter(Boolean))];

      for (const uid of recipients) {
        try {
          const userDoc = await db.collection('users').doc(uid).get();
          const userData = userDoc.data() || {};
          const token = (userData.fcmToken || userData.fcm_token || (Array.isArray(userData.fcmTokens) ? userData.fcmTokens[0] : null)) as string | undefined;
          if (token) {
            await admin.messaging().sendToDevice(token, {
              notification: { title: 'Nova mensagem', body: text ?? 'Você tem uma nova mensagem' },
              data: { chatId, type: 'chat_message', sender: sender ?? '' }
            });
          }
        } catch (e) {
          logStructured('error', 'fcm_send_failed_chat_message', {
            error: sanitizeForLogs(e),
            chatId,
            sender,
          });
        }
      }

      await writeSystemEvent('message_sent', {
        chatId,
        senderId: sender ?? 'unknown',
        recipientCount: recipients.length,
      }, 'info');
      await updateOverviewMetric('messagesSentToday', 1);

      return null;
    } catch (err) {
      logStructured('error', 'on_chat_message_created', {
        error: sanitizeForLogs(err),
        chatId,
        sender,
      });
      return null;
    }
  });

// Trigger when a new group message is created: send FCM to group members
export const onGroupMessageCreated = functions.firestore
  .document('groups/{groupId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const groupId = context.params.groupId as string;
    try {
      const eventId = context.eventId;
      if (eventId) {
        const lockRef = db.collection('system_events_locks').doc(`onGroupMessageCreated_${eventId}`);
        let isDuplicate = false;
        await db.runTransaction(async (txn) => {
          const lockDoc = await txn.get(lockRef);
          if (lockDoc.exists) {
            isDuplicate = true;
            return;
          }
          txn.set(lockRef, { processedAt: admin.firestore.FieldValue.serverTimestamp() });
        });
        if (isDuplicate) {
          logStructured('warn', 'group_message_fanout_duplicate_suppressed', { groupId, eventId });
          return null;
        }
      }

      const msg = snap.data();
      const text = msg?.text as string | undefined;

      // try to load the group's members list
      const groupDoc = await db.collection('groups').doc(groupId).get();
      const members = groupDoc.data()?.members as string[] | undefined;
      if (!members || members.length === 0) return null;

      for (const uid of members) {
        // skip notifying sender if present
        if (uid == msg?.senderId) continue;
        try {
          const userDoc = await db.collection('users').doc(uid).get();
          const userData = userDoc.data() || {};
          const token = (userData.fcmToken || userData.fcm_token || (Array.isArray(userData.fcmTokens) ? userData.fcmTokens[0] : null)) as string | undefined;
          if (token) {
            await admin.messaging().sendToDevice(token, {
              notification: { title: `Novo no canal ${groupDoc.data()?.name ?? ''}`, body: text ?? 'Nova mensagem no canal' },
              data: { groupId, type: 'group_message' }
            });
          }
        } catch (e) {
          logStructured('error', 'fcm_send_failed_group_message', {
            error: sanitizeForLogs(e),
            groupId,
          });
        }
      }

      return null;
    } catch (err) {
      logStructured('error', 'on_group_message_created', {
        error: sanitizeForLogs(err),
        groupId,
      });
      return null;
    }
  });

export const submitReport = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required to submit a report.');
  }

  const validated = validateReportPayload(data as Record<string, any> | null | undefined);
  if (!validated.ok) {
    throw new functions.https.HttpsError('invalid-argument', validated.error ?? 'Invalid report payload.');
  }

  // Use idempotencyKey from client if provided for duplicate suppression.
  const idempotencyKey = String(data?.idempotencyKey ?? '');
  const reporterId = context.auth.uid;
  const reportId = `report_${reporterId}_${validated.resourceType}_${validated.resourceId}`;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const reportDoc = {
    reportId,
    reporterId,
    resourceType: validated.resourceType,
    resourceId: validated.resourceId,
    category: validated.category,
    reason: validated.reason,
    details: validated.details,
    status: 'pending',
    priority: 'normal',
    createdAt: now,
    updatedAt: now,
    source: 'app',
    idempotencyKey: idempotencyKey || null,
  };

  let isDuplicate = false;
  let existingId = '';
  await db.runTransaction(async (txn) => {
    const existingReport = await txn.get(db.collection('reports').doc(reportId));
    if (existingReport.exists) {
      isDuplicate = true;
      existingId = existingReport.id;
      return;
    }
    txn.set(db.collection('reports').doc(reportId), reportDoc);
  });

  if (isDuplicate) {
    logStructured('warn', 'report_duplicate_suppressed', {
      reportId,
      reporterId,
      idempotencyKey,
      existing_id: existingId,
    });
    return { ok: true, reportId, status: 'duplicate', note: 'Report already exists (idempotent)' };
  }

  try {
    await writeSystemEvent('report_submitted', {
      reportId,
      reporterId,
      resourceType: validated.resourceType,
      resourceId: validated.resourceId,
      category: validated.category,
    }, 'info');
  } catch (eventErr) {
    logStructured('error', 'report_system_event_failed', { reportId, error: String(eventErr) });
  }

  return { ok: true, reportId, status: 'pending' };
});

export const onAdminRequestCreated = functions.firestore
  .document('admin_requests/{requestId}')
  .onCreate(async (snap, context) => {
    const requestId = context.params.requestId as string;
    const data = snap.data() ?? {};
    const action = String(data.type ?? 'unknown_action');
    const resourceType = String(data.resourceType ?? 'unknown');
    const actorUid = String(data.createdBy ?? data.actorUid ?? data.requestedBy ?? 'unknown');

    await writeSystemEvent('admin_request_created', {
      requestId,
      actorUid,
      action,
      resourceType,
      reason: String(data.reason ?? 'admin_request_created'),
    }, action === 'mass_fcm' ? 'warning' : 'info');

    await updateOverviewMetric('pendingAdminActions', 1);
    return null;
  });

export const onAdminAuditLogCreated = functions.firestore
  .document('admin_audit_logs/{logId}')
  .onCreate(async (snap, context) => {
    const logId = context.params.logId as string;
    const data = snap.data() ?? {};

    await writeSystemEvent('admin_action_logged', {
      logId,
      action: String(data.action ?? 'unknown_action'),
      actorUid: String(data.actorUid ?? 'unknown'),
      resourceType: String(data.resourceType ?? 'unknown'),
    }, 'info');

    await updateOverviewMetric('adminActionsToday', 1);
    return null;
  });

const CRITICAL_ADMIN_ACTIONS = new Set([
  'delete_post',
  'ban_user',
  'mass_fcm',
  'assignRoleClaims',
  'moderate_community',
  'review_story',
  'system_alert',
]);

const FRESH_AUTH_WINDOW_SECONDS = 15 * 60;

function ensureFreshAdminAuth(context: functions.https.CallableContext, action: string) {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  }

  const authTime = Number(context.auth.token?.auth_time ?? 0);
  const nowSeconds = Math.floor(Date.now() / 1000);

  if (CRITICAL_ADMIN_ACTIONS.has(action) && (!authTime || nowSeconds - authTime > FRESH_AUTH_WINDOW_SECONDS)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Recent authentication is required before executing this protected action.',
    );
  }
}

export const submitAdminRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  }

  const validatedRequest = validateAdminActionPayload(data as Record<string, any> | null | undefined);
  if (!validatedRequest.ok) {
    throw new functions.https.HttpsError('invalid-argument', validatedRequest.error ?? 'Invalid admin action payload.');
  }

  ensureFreshAdminAuth(context, validatedRequest.action);

  const actorUid = context.auth.uid;
  const { action, resourceType, resourceId, reason, details } = validatedRequest;

  const user = await admin.auth().getUser(actorUid);
  const claims = user.customClaims ?? {};
  const isPrivileged = claims.owner === true || claims.isOwner === true || claims.admin === true || claims.isAdmin === true || claims.role === 'owner' || claims.role === 'admin';

  if (!isPrivileged) {
    throw new functions.https.HttpsError('permission-denied', 'Only authorized admin roles can submit backend actions.');
  }

  // Use deterministic ID for idempotency.
  // Combine actorUid, action, and resourceId to create a stable ID.
  // This prevents duplicate requests from the same actor for the same resource.
  const idempotencyKey = String(data?.idempotencyKey ?? '');
  const requestId = idempotencyKey
    ? `admin_req_${actorUid}_${idempotencyKey}`
    : `admin_req_${actorUid}_${action}_${resourceType}_${resourceId}`;

  const doc = {
    id: requestId,
    requestId,
    type: action,
    resourceType,
    resourceId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: actorUid,
    requestedBy: actorUid,
    actorUid,
    authTime: context.auth.token?.auth_time ?? Math.floor(Date.now() / 1000),
    requiresFreshAuth: CRITICAL_ADMIN_ACTIONS.has(action),
    status: 'pending',
    result: 'pending',
    reason,
    details: {
      source: 'control_center',
      ...details,
    },
    idempotencyKey: idempotencyKey || null,
  };

  // Check if this exact request already exists (idempotent write) inside a transaction to prevent races.
  let isDuplicate = false;
  let existingStatus = '';
  await db.runTransaction(async (txn) => {
    const docRef = db.collection('admin_requests').doc(requestId);
    const existingRequest = await txn.get(docRef);
    if (existingRequest.exists) {
      const existing = existingRequest.data() ?? {};
      if (existing.status === 'pending') {
        isDuplicate = true;
        existingStatus = existing.status;
        return;
      }
    }
    txn.set(docRef, doc, { merge: false });
  });

  if (isDuplicate) {
    logStructured('warn', 'admin_request_duplicate_suppressed', {
      requestId,
      actorUid,
      action,
      existing_status: existingStatus,
    });
    return { ok: true, requestId, status: 'duplicate', note: 'Request already pending (idempotent)' };
  }

  try {
    await writeSystemEvent('admin_request_submitted', {
      requestId,
      actorUid,
      action,
      resourceType,
      resourceId,
    }, 'warning');
  } catch (eventErr) {
    logStructured('error', 'admin_request_system_event_failed', { requestId, error: String(eventErr) });
  }

  return { ok: true, requestId, status: 'pending' };
});

export const assignRoleClaims = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  }

  ensureFreshAdminAuth(context, 'assignRoleClaims');

  const actorUid = context.auth.uid;
  const requestedRole = normalizeRoleName(data?.role ?? 'user');
  const targetUid = sanitizeString(data?.uid ?? data?.targetUid ?? actorUid, 128, '');

  if (!['owner', 'admin', 'moderator', 'user'].includes(requestedRole)) {
    throw new functions.https.HttpsError('invalid-argument', 'Unsupported role value.');
  }

  if (!targetUid || !isValidResourceId(targetUid)) {
    throw new functions.https.HttpsError('invalid-argument', 'Target user ID is invalid.');
  }

  const actorClaims = (await admin.auth().getUser(actorUid)).customClaims ?? {};
  const actorEffectiveRole = String(actorClaims.role ?? 'user');
  const isOwnerActor = actorEffectiveRole === 'owner' || actorClaims.owner === true || actorClaims.isOwner === true;

  if (!isOwnerActor) {
    throw new functions.https.HttpsError('permission-denied', 'Only the owner can assign authority roles.');
  }

  if (requestedRole !== 'user' && targetUid !== actorUid && requestedRole === 'owner') {
    throw new functions.https.HttpsError('permission-denied', 'Owner role may only be assigned to the owner account.');
  }

  const claims: Record<string, any> = {
    role: requestedRole,
    owner: requestedRole === 'owner',
    admin: requestedRole === 'admin' || requestedRole === 'owner',
    moderator: requestedRole === 'moderator',
    isOwner: requestedRole === 'owner',
    isAdmin: requestedRole === 'admin' || requestedRole === 'owner',
    isServer: false,
  };

  await admin.auth().setCustomUserClaims(targetUid, claims);
  return { ok: true, uid: targetUid, role: requestedRole };
});

// --- Admin request processor ---
const adminRequestCollection = 'admin_requests';
const auditLogCollection = 'admin_audit_logs';

async function isPrivilegedActor(uid: string): Promise<boolean> {
  try {
    const user = await admin.auth().getUser(uid);
    if (user.customClaims?.admin === true || user.customClaims?.isAdmin === true || user.customClaims?.isServer === true) {
      return true;
    }
  } catch (e) {
    logStructured('warn', 'admin_actor_claim_lookup_failed', {
      actorUid: uid,
      error: sanitizeForLogs(e),
    });
  }

  try {
    const adminProfile = await db.collection('admin_profiles').doc(uid).get();
    return !!adminProfile.exists && adminProfile.data()?.isAdmin === true;
  } catch (e) {
    logStructured('warn', 'admin_actor_profile_lookup_failed', {
      actorUid: uid,
      error: sanitizeForLogs(e),
    });
    return false;
  }
}

async function writeAuditLog(payload: {
  action: string;
  actorUid: string;
  resourceType: string;
  resourceId: string;
  requestId: string;
  status: string;
  result: string;
  reason: string;
  details?: Record<string, any>;
}) {
  const auditDoc = {
    action: payload.action,
    actorUid: payload.actorUid,
    resourceType: payload.resourceType,
    resourceId: payload.resourceId,
    requestId: payload.requestId,
    status: payload.status,
    result: payload.result,
    reason: payload.reason,
    details: payload.details ?? {},
    executedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    source: 'backend',
  };

  await db.collection(auditLogCollection).add(auditDoc);
}

function inferResourceType(requestData: Record<string, any>): string {
  if (requestData.userId) return 'user';
  if (requestData.postId) return 'post';
  if (requestData.targetId) return 'target';
  if (requestData.broadcast) return 'broadcast';
  return 'unknown';
}

export const processAdminRequest = functions.firestore
  .document(`${adminRequestCollection}/{requestId}`)
  .onCreate(async (snap, context) => {
    const requestId = context.params.requestId as string;
    const requestData = snap.data() as Record<string, any> | undefined;
    if (!requestData) {
      return null;
    }

    const currentDoc = await snap.ref.get();
    if (currentDoc.data()?.status !== 'pending') {
      logStructured('info', 'admin_request_already_processed', { requestId });
      return null;
    }

    const validatedRequest = validateAdminActionPayload(requestData as Record<string, any> | null | undefined);
    if (!validatedRequest.ok) {
      await snap.ref.update({
        status: 'rejected',
        result: 'invalid_payload',
        decisionBy: 'backend',
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        reason: validatedRequest.error ?? 'Rejected invalid admin request payload.',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await writeAuditLog({
        action: normalizeAdminAction(requestData?.type ?? requestData?.action ?? 'unknown_action'),
        actorUid: String(requestData?.createdBy ?? requestData?.actorUid ?? requestData?.requestedBy ?? 'unknown'),
        resourceType: normalizeResourceType(requestData?.resourceType ?? inferResourceType(requestData ?? {})),
        resourceId: sanitizeString(requestData?.resourceId ?? requestData?.postId ?? requestData?.userId ?? requestData?.targetId ?? 'unknown', 128, ''),
        requestId,
        status: 'rejected',
        result: 'invalid_payload',
        reason: validatedRequest.error ?? 'Rejected invalid admin request payload.',
        details: { originalRequest: requestData },
      });
      return null;
    }

    const actorUid = (requestData.createdBy || requestData.actorUid || requestData.requestedBy) as string | undefined;
    const action = validatedRequest.action;
    const resourceType = validatedRequest.resourceType;
    const resourceId = validatedRequest.resourceId;

    try {
      if (!actorUid) {
        throw new Error('Missing actorUid on admin request');
      }

      const authTimeSeconds = Number(requestData.authTime ?? 0);
      const actionNeedsFreshAuth = Boolean(requestData.requiresFreshAuth) || CRITICAL_ADMIN_ACTIONS.has(action);
      const nowSeconds = Math.floor(Date.now() / 1000);
      if (actionNeedsFreshAuth && (!authTimeSeconds || nowSeconds - authTimeSeconds > FRESH_AUTH_WINDOW_SECONDS)) {
        const reason = 'Admin action requires recent authentication and was rejected by the backend';
        await snap.ref.update({
          status: 'rejected',
          result: 'fresh_auth_required',
          decisionBy: 'backend',
          rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
          reason,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await writeAuditLog({
          action,
          actorUid,
          resourceType,
          resourceId,
          requestId,
          status: 'rejected',
          result: 'fresh_auth_required',
          reason,
          details: { originalRequest: requestData },
        });
        return null;
      }

      const authorized = await isPrivilegedActor(actorUid);
      if (!authorized) {
        const reason = 'Actor does not have privileged admin access';
        await snap.ref.update({
          status: 'rejected',
          result: 'denied',
          decisionBy: 'backend',
          rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
          reason,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await writeAuditLog({
          action,
          actorUid,
          resourceType,
          resourceId,
          requestId,
          status: 'rejected',
          result: 'denied',
          reason,
          details: { originalRequest: requestData },
        });
        return null;
      }

      switch (action) {
        case 'delete_post': {
          const postId = String(requestData.postId || resourceId);
          const postRef = db.collection('posts').doc(postId);
          const postDoc = await postRef.get();
          if (postDoc.exists) {
            await postRef.update({
              deleted: true,
              moderationState: 'deleted',
              deletedBy: actorUid,
              deletedAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
          await snap.ref.update({
            status: 'executed',
            result: 'success',
            executedBy: actorUid,
            executedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          await writeAuditLog({
            action,
            actorUid,
            resourceType: 'post',
            resourceId: postId,
            requestId,
            status: 'executed',
            result: 'success',
            reason: 'Post deletion approved by backend',
            details: { postId },
          });
          return null;
        }

        case 'ban_user': {
          const userId = String(requestData.userId || resourceId);
          const userRef = db.collection('users').doc(userId);
          await userRef.set({
            banned: true,
            moderationState: 'banned',
            bannedBy: actorUid,
            bannedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });

          await snap.ref.update({
            status: 'executed',
            result: 'success',
            executedBy: actorUid,
            executedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          await writeAuditLog({
            action,
            actorUid,
            resourceType: 'user',
            resourceId: userId,
            requestId,
            status: 'executed',
            result: 'success',
            reason: 'User banned by backend-approved admin action',
            details: { userId },
          });
          return null;
        }

        case 'mass_fcm': {
          const title = String(requestData.title || 'La Bomba');
          const body = String(requestData.body || 'Nova atualização da comunidade');
          const usersSnap = await db.collection('users').select('fcmToken', 'fcm_token', 'fcmTokens').get();

          const tokens: string[] = [];
          for (const userDoc of usersSnap.docs) {
            const userData = userDoc.data() ?? {};
            const token = (userData.fcmToken || userData.fcm_token || (Array.isArray(userData.fcmTokens) ? userData.fcmTokens[0] : null)) as string | undefined;
            if (token) tokens.push(token);
          }

          for (let i = 0; i < tokens.length; i += 500) {
            const chunk = tokens.slice(i, i + 500);
            try {
              await admin.messaging().sendMulticast({
                tokens: chunk,
                notification: { title, body },
                data: { type: 'admin_broadcast', source: 'admin_requests' },
              });
            } catch (error) {
              logStructured('error', 'admin_broadcast_chunk_failed', {
                error: sanitizeForLogs(error),
              });
            }
          }

          await snap.ref.update({
            status: 'executed',
            result: 'success',
            executedBy: actorUid,
            executedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          await writeAuditLog({
            action,
            actorUid,
            resourceType: 'broadcast',
            resourceId: 'mass_fcm',
            requestId,
            status: 'executed',
            result: 'success',
            reason: 'Mass FCM broadcast executed by backend',
            details: { title, sentUsers: usersSnap.docs.length },
          });
          return null;
        }

        default: {
          const reason = `Unsupported admin action: ${action}`;
          await snap.ref.update({
            status: 'rejected',
            result: 'unsupported_action',
            rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
            reason,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          await writeAuditLog({
            action,
            actorUid,
            resourceType,
            resourceId,
            requestId,
            status: 'rejected',
            result: 'unsupported_action',
            reason,
            details: { originalRequest: requestData },
          });
          return null;
        }
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown admin request processing error';
      await snap.ref.update({
        status: 'failed',
        result: 'error',
        failureReason: message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await writeAuditLog({
        action,
        actorUid,
        resourceType,
        resourceId,
        requestId,
        status: 'failed',
        result: 'error',
        reason: message,
        details: { originalRequest: requestData },
      });
      logStructured('error', 'process_admin_request_failed', {
        action,
        actorUid,
        resourceType,
        resourceId,
        requestId,
        error: sanitizeForLogs(error),
      });
      return null;
    }
  });
