import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v1/https';
import {
  assertExpectedIdentity,
  connectionIdentity,
  directionalIdentity,
} from './social_identity';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const requests = db.collection('connection_requests');
const conversationRequests = db.collection('conversation_requests');
const connections = db.collection('connections');
const blocks = db.collection('blocks');

type OperationData = Record<string, unknown>;

function stringValue(data: OperationData, field: string): string {
  const value = data[field];
  if (typeof value !== 'string' || value.length === 0) {
    throw new HttpsError('invalid-argument', `${field} is required`);
  }
  return value;
}

function requireCaller(context: { auth?: { uid: string } | null }): string {
  if (!context.auth) throw new HttpsError('unauthenticated', 'Authentication required.');
  return context.auth.uid;
}

function fail(error: unknown): never {
  if (error instanceof HttpsError) throw error;
  throw new HttpsError('invalid-argument', error instanceof Error ? error.message : 'Invalid social operation.');
}

function requireParticipants(
  data: FirebaseFirestore.DocumentData | undefined,
  expected: Record<string, string>,
): void {
  if (!data || Object.entries(expected).some(([field, value]) => data[field] !== value)) {
    throw new HttpsError(
      'failed-precondition',
      'The stored social document does not match the requested participants.',
    );
  }
}

function blockRefs(firstUid: string, secondUid: string) {
  return [
    blocks.doc(directionalIdentity('block', firstUid, secondUid)),
    blocks.doc(directionalIdentity('block', secondUid, firstUid)),
  ];
}

async function assertNotBlocked(
  transaction: FirebaseFirestore.Transaction,
  firstUid: string,
  secondUid: string,
) {
  const snapshots = await Promise.all(blockRefs(firstUid, secondUid).map((ref) => transaction.get(ref)));
  if (snapshots.some((snapshot) => snapshot.exists && snapshot.data()?.status === 'active')) {
    throw new HttpsError('failed-precondition', 'This social interaction is blocked.');
  }
}

export async function executeSocialOperation(
  data: unknown,
  context: { auth?: { uid: string } | null },
) {
  const input = (data ?? {}) as OperationData;
  const caller = requireCaller(context);
  const operation = stringValue(input, 'operation');

  try {
    switch (operation) {
      case 'sendConnectionRequest':
        return await sendRequest(caller, input, requests, 'connection_request');
      case 'acceptConnectionRequest':
        return await transitionRequest(caller, input, requests, 'accepted', 'connection_request');
      case 'declineConnectionRequest':
        return await transitionRequest(caller, input, requests, 'declined', 'connection_request');
      case 'cancelConnectionRequest':
        return await transitionRequest(caller, input, requests, 'cancelled', 'connection_request');
      case 'createConnection':
        return await createConnection(caller, input);
      case 'removeConnection':
        return await removeConnection(caller, input);
      case 'sendConversationRequest':
        return await sendRequest(caller, input, conversationRequests, 'conversation_request');
      case 'acceptConversationRequest':
        return await transitionRequest(caller, input, conversationRequests, 'accepted', 'conversation_request');
      case 'declineConversationRequest':
        return await transitionRequest(caller, input, conversationRequests, 'declined', 'conversation_request');
      case 'cancelConversationRequest':
        return await transitionRequest(caller, input, conversationRequests, 'cancelled', 'conversation_request');
      case 'createBlock':
        return await createBlock(caller, input);
      case 'removeBlock':
        return await removeBlock(caller, input);
      default:
        throw new HttpsError('invalid-argument', 'Unsupported social operation.');
    }
  } catch (error) {
    return fail(error);
  }
}

async function sendRequest(
  caller: string,
  input: OperationData,
  collection: FirebaseFirestore.CollectionReference,
  purpose: 'connection_request' | 'conversation_request',
) {
  const from = stringValue(input, 'fromUserId');
  const to = stringValue(input, 'toUserId');
  if (caller !== from || from === to) throw new HttpsError('permission-denied', 'Caller is not the requester.');
  const id = directionalIdentity(purpose, from, to);
  assertExpectedIdentity(input.expectedId, id);
  await db.runTransaction(async (transaction) => {
    await assertNotBlocked(transaction, from, to);
    const ref = collection.doc(id);
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      transaction.create(ref, {
        ...(purpose === 'connection_request'
          ? { fromUserId: from, toUserId: to }
          : { fromUserId: from, toUserId: to }),
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }
    const status = snapshot.data()?.status;
    requireParticipants(snapshot.data(), { fromUserId: from, toUserId: to });
    if (status === 'pending' || status === 'accepted') {
      return;
    }
    if (status !== 'declined' && status !== 'cancelled') {
      throw new HttpsError('failed-precondition', 'Invalid request lifecycle.');
    }
    transaction.update(ref, {
      status: 'pending',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  return { id, status: 'pending' };
}

async function transitionRequest(
  caller: string,
  input: OperationData,
  collection: FirebaseFirestore.CollectionReference,
  target: 'accepted' | 'declined' | 'cancelled',
  purpose: 'connection_request' | 'conversation_request',
) {
  const from = stringValue(input, 'fromUserId');
  const to = stringValue(input, 'toUserId');
  const id = directionalIdentity(purpose, from, to);
  assertExpectedIdentity(input.expectedId, id);
  if ((target === 'cancelled' && caller !== from) || (target !== 'cancelled' && caller !== to)) {
    throw new HttpsError('permission-denied', 'Caller is not authorized for this transition.');
  }
  await db.runTransaction(async (transaction) => {
    const ref = collection.doc(id);
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists || snapshot.data()?.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'Request is not pending.');
    }
    requireParticipants(snapshot.data(), { fromUserId: from, toUserId: to });
    if (target === 'accepted') await assertNotBlocked(transaction, from, to);
    transaction.update(ref, {
      status: target,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  return { id, status: target };
}

async function createConnection(caller: string, input: OperationData) {
  const first = stringValue(input, 'firstUserId');
  const second = stringValue(input, 'secondUserId');
  if (caller !== first && caller !== second) throw new HttpsError('permission-denied', 'Caller is not a participant.');
  const users = [first, second].sort();
  const id = connectionIdentity(users[0], users[1]);
  assertExpectedIdentity(input.expectedId, id);
  const requestId = directionalIdentity('connection_request', first, second);
  const reverseRequestId = directionalIdentity('connection_request', second, first);
  await db.runTransaction(async (transaction) => {
    await assertNotBlocked(transaction, first, second);
    const connectionRef = connections.doc(id);
    const requestSnapshots = await Promise.all([
      transaction.get(requests.doc(requestId)),
      transaction.get(requests.doc(reverseRequestId)),
    ]);
    if (!requestSnapshots.some((snapshot) => snapshot.exists && snapshot.data()?.status === 'accepted')) {
      throw new HttpsError('failed-precondition', 'An accepted connection request is required.');
    }
    const existing = await transaction.get(connectionRef);
    if (existing.exists) {
      requireParticipants(existing.data(), { userA: users[0], userB: users[1] });
    }
    if (existing.exists && existing.data()?.status === 'removed') {
      throw new HttpsError('failed-precondition', 'A removed connection cannot be reactivated directly.');
    }
    if (!existing.exists) {
      transaction.create(connectionRef, {
        userA: users[0],
        userB: users[1],
        status: 'connected',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        connectedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
  return { id, status: 'connected' };
}

async function removeConnection(caller: string, input: OperationData) {
  const first = stringValue(input, 'firstUserId');
  const second = stringValue(input, 'secondUserId');
  if (caller !== first && caller !== second) throw new HttpsError('permission-denied', 'Caller is not a participant.');
  const id = connectionIdentity(first, second);
  assertExpectedIdentity(input.expectedId, id);
  await db.runTransaction(async (transaction) => {
    const ref = connections.doc(id);
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists || snapshot.data()?.status !== 'connected') return;
    requireParticipants(snapshot.data(), { userA: [first, second].sort()[0], userB: [first, second].sort()[1] });
    transaction.update(ref, {
      status: 'removed',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      removedAt: admin.firestore.FieldValue.serverTimestamp(),
      removedBy: caller,
    });
  });
  return { id, status: 'removed' };
}

async function createBlock(caller: string, input: OperationData) {
  const blocker = stringValue(input, 'blockerId');
  const blocked = stringValue(input, 'blockedUserId');
  if (caller !== blocker || blocker === blocked) throw new HttpsError('permission-denied', 'Caller is not the blocker.');
  const id = directionalIdentity('block', blocker, blocked);
  assertExpectedIdentity(input.expectedId, id);
  await db.runTransaction(async (transaction) => {
    const ref = blocks.doc(id);
    const snapshot = await transaction.get(ref);
    if (snapshot.exists) {
      requireParticipants(snapshot.data(), { blockerId: blocker, blockedUserId: blocked });
    }
    if (snapshot.exists && snapshot.data()?.status === 'active') return;
    if (snapshot.exists) throw new HttpsError('failed-precondition', 'A removed block cannot be reactivated.');
    const relationRefs: Array<{
      ref: FirebaseFirestore.DocumentReference;
      snapshot: FirebaseFirestore.DocumentSnapshot;
      kind: 'request' | 'conversation';
    }> = [];
    for (const [from, to] of [[blocker, blocked], [blocked, blocker]]) {
      const requestRef = requests.doc(directionalIdentity('connection_request', from, to));
      const conversationRef = conversationRequests.doc(directionalIdentity('conversation_request', from, to));
      const [request, conversation] = await Promise.all([
        transaction.get(requestRef),
        transaction.get(conversationRef),
      ]);
      relationRefs.push(
        { ref: requestRef, snapshot: request, kind: 'request' },
        { ref: conversationRef, snapshot: conversation, kind: 'conversation' },
      );
    }
    transaction.create(ref, {
      blockerId: blocker,
      blockedUserId: blocked,
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    for (const relation of relationRefs) {
      if (relation.snapshot.exists && relation.snapshot.data()?.status === 'pending') {
        transaction.update(relation.ref, {
          status: 'cancelled',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  });
  return { id, status: 'active' };
}

async function removeBlock(caller: string, input: OperationData) {
  const blocker = stringValue(input, 'blockerId');
  const blocked = stringValue(input, 'blockedUserId');
  if (caller !== blocker) throw new HttpsError('permission-denied', 'Caller is not the blocker.');
  const id = directionalIdentity('block', blocker, blocked);
  assertExpectedIdentity(input.expectedId, id);
  await db.runTransaction(async (transaction) => {
    const ref = blocks.doc(id);
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists || snapshot.data()?.status !== 'active') return;
    requireParticipants(snapshot.data(), { blockerId: blocker, blockedUserId: blocked });
    transaction.update(ref, {
      status: 'removed',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      removedAt: admin.firestore.FieldValue.serverTimestamp(),
      removedBy: caller,
    });
  });
  return { id, status: 'removed' };
}
