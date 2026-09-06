"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.executeSocialOperation = executeSocialOperation;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v1/https");
const social_identity_1 = require("./social_identity");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
const requests = db.collection('connection_requests');
const conversationRequests = db.collection('conversation_requests');
const connections = db.collection('connections');
const blocks = db.collection('blocks');
function stringValue(data, field) {
    const value = data[field];
    if (typeof value !== 'string' || value.length === 0) {
        throw new https_1.HttpsError('invalid-argument', `${field} is required`);
    }
    return value;
}
function requireCaller(context) {
    if (!context.auth)
        throw new https_1.HttpsError('unauthenticated', 'Authentication required.');
    return context.auth.uid;
}
function fail(error) {
    if (error instanceof https_1.HttpsError)
        throw error;
    throw new https_1.HttpsError('invalid-argument', error instanceof Error ? error.message : 'Invalid social operation.');
}
function requireParticipants(data, expected) {
    if (!data || Object.entries(expected).some(([field, value]) => data[field] !== value)) {
        throw new https_1.HttpsError('failed-precondition', 'The stored social document does not match the requested participants.');
    }
}
function blockRefs(firstUid, secondUid) {
    return [
        blocks.doc((0, social_identity_1.directionalIdentity)('block', firstUid, secondUid)),
        blocks.doc((0, social_identity_1.directionalIdentity)('block', secondUid, firstUid)),
    ];
}
async function assertNotBlocked(transaction, firstUid, secondUid) {
    const snapshots = await Promise.all(blockRefs(firstUid, secondUid).map((ref) => transaction.get(ref)));
    if (snapshots.some((snapshot) => snapshot.exists && snapshot.data()?.status === 'active')) {
        throw new https_1.HttpsError('failed-precondition', 'This social interaction is blocked.');
    }
}
async function executeSocialOperation(data, context) {
    const input = (data ?? {});
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
                throw new https_1.HttpsError('invalid-argument', 'Unsupported social operation.');
        }
    }
    catch (error) {
        return fail(error);
    }
}
async function sendRequest(caller, input, collection, purpose) {
    const from = stringValue(input, 'fromUserId');
    const to = stringValue(input, 'toUserId');
    if (caller !== from || from === to)
        throw new https_1.HttpsError('permission-denied', 'Caller is not the requester.');
    const id = (0, social_identity_1.directionalIdentity)(purpose, from, to);
    (0, social_identity_1.assertExpectedIdentity)(input.expectedId, id);
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
            throw new https_1.HttpsError('failed-precondition', 'Invalid request lifecycle.');
        }
        transaction.update(ref, {
            status: 'pending',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    return { id, status: 'pending' };
}
async function transitionRequest(caller, input, collection, target, purpose) {
    const from = stringValue(input, 'fromUserId');
    const to = stringValue(input, 'toUserId');
    const id = (0, social_identity_1.directionalIdentity)(purpose, from, to);
    (0, social_identity_1.assertExpectedIdentity)(input.expectedId, id);
    if ((target === 'cancelled' && caller !== from) || (target !== 'cancelled' && caller !== to)) {
        throw new https_1.HttpsError('permission-denied', 'Caller is not authorized for this transition.');
    }
    await db.runTransaction(async (transaction) => {
        const ref = collection.doc(id);
        const snapshot = await transaction.get(ref);
        if (!snapshot.exists || snapshot.data()?.status !== 'pending') {
            throw new https_1.HttpsError('failed-precondition', 'Request is not pending.');
        }
        requireParticipants(snapshot.data(), { fromUserId: from, toUserId: to });
        if (target === 'accepted')
            await assertNotBlocked(transaction, from, to);
        transaction.update(ref, {
            status: target,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    return { id, status: target };
}
async function createConnection(caller, input) {
    const first = stringValue(input, 'firstUserId');
    const second = stringValue(input, 'secondUserId');
    if (caller !== first && caller !== second)
        throw new https_1.HttpsError('permission-denied', 'Caller is not a participant.');
    const users = [first, second].sort();
    const id = (0, social_identity_1.connectionIdentity)(users[0], users[1]);
    (0, social_identity_1.assertExpectedIdentity)(input.expectedId, id);
    const requestId = (0, social_identity_1.directionalIdentity)('connection_request', first, second);
    const reverseRequestId = (0, social_identity_1.directionalIdentity)('connection_request', second, first);
    await db.runTransaction(async (transaction) => {
        await assertNotBlocked(transaction, first, second);
        const connectionRef = connections.doc(id);
        const requestSnapshots = await Promise.all([
            transaction.get(requests.doc(requestId)),
            transaction.get(requests.doc(reverseRequestId)),
        ]);
        if (!requestSnapshots.some((snapshot) => snapshot.exists && snapshot.data()?.status === 'accepted')) {
            throw new https_1.HttpsError('failed-precondition', 'An accepted connection request is required.');
        }
        const existing = await transaction.get(connectionRef);
        if (existing.exists) {
            requireParticipants(existing.data(), { userA: users[0], userB: users[1] });
        }
        if (existing.exists && existing.data()?.status === 'removed') {
            throw new https_1.HttpsError('failed-precondition', 'A removed connection cannot be reactivated directly.');
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
async function removeConnection(caller, input) {
    const first = stringValue(input, 'firstUserId');
    const second = stringValue(input, 'secondUserId');
    if (caller !== first && caller !== second)
        throw new https_1.HttpsError('permission-denied', 'Caller is not a participant.');
    const id = (0, social_identity_1.connectionIdentity)(first, second);
    (0, social_identity_1.assertExpectedIdentity)(input.expectedId, id);
    await db.runTransaction(async (transaction) => {
        const ref = connections.doc(id);
        const snapshot = await transaction.get(ref);
        if (!snapshot.exists || snapshot.data()?.status !== 'connected')
            return;
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
async function createBlock(caller, input) {
    const blocker = stringValue(input, 'blockerId');
    const blocked = stringValue(input, 'blockedUserId');
    if (caller !== blocker || blocker === blocked)
        throw new https_1.HttpsError('permission-denied', 'Caller is not the blocker.');
    const id = (0, social_identity_1.directionalIdentity)('block', blocker, blocked);
    (0, social_identity_1.assertExpectedIdentity)(input.expectedId, id);
    await db.runTransaction(async (transaction) => {
        const ref = blocks.doc(id);
        const snapshot = await transaction.get(ref);
        if (snapshot.exists) {
            requireParticipants(snapshot.data(), { blockerId: blocker, blockedUserId: blocked });
        }
        if (snapshot.exists && snapshot.data()?.status === 'active')
            return;
        if (snapshot.exists)
            throw new https_1.HttpsError('failed-precondition', 'A removed block cannot be reactivated.');
        const relationRefs = [];
        for (const [from, to] of [[blocker, blocked], [blocked, blocker]]) {
            const requestRef = requests.doc((0, social_identity_1.directionalIdentity)('connection_request', from, to));
            const conversationRef = conversationRequests.doc((0, social_identity_1.directionalIdentity)('conversation_request', from, to));
            const [request, conversation] = await Promise.all([
                transaction.get(requestRef),
                transaction.get(conversationRef),
            ]);
            relationRefs.push({ ref: requestRef, snapshot: request, kind: 'request' }, { ref: conversationRef, snapshot: conversation, kind: 'conversation' });
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
async function removeBlock(caller, input) {
    const blocker = stringValue(input, 'blockerId');
    const blocked = stringValue(input, 'blockedUserId');
    if (caller !== blocker)
        throw new https_1.HttpsError('permission-denied', 'Caller is not the blocker.');
    const id = (0, social_identity_1.directionalIdentity)('block', blocker, blocked);
    (0, social_identity_1.assertExpectedIdentity)(input.expectedId, id);
    await db.runTransaction(async (transaction) => {
        const ref = blocks.doc(id);
        const snapshot = await transaction.get(ref);
        if (!snapshot.exists || snapshot.data()?.status !== 'active')
            return;
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
//# sourceMappingURL=social_operations.js.map