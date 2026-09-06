const test = require('node:test');
const assert = require('node:assert/strict');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8081';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'demo-social-operations' });

const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'demo-social-operations' });
const db = admin.firestore();
const { executeSocialOperation } = require('../lib/social_operations');
const {
  connectionIdentity,
  directionalIdentity,
} = require('../lib/social_identity');

async function clearCollection(name) {
  const refs = await db.collection(name).listDocuments();
  await Promise.all(refs.map((ref) => ref.delete()));
}

async function reset() {
  await Promise.all([
    clearCollection('connections'),
    clearCollection('connection_requests'),
    clearCollection('conversation_requests'),
    clearCollection('blocks'),
    clearCollection('messages'),
  ]);
}

function call(uid, data) {
  return executeSocialOperation(data, uid ? { auth: { uid } } : { auth: null });
}

async function expectCode(promise, code) {
  await assert.rejects(promise, (error) => error.code === code);
}

test.beforeEach(reset);

test('callable authorization uses auth.uid and rejects forged participants or IDs', async () => {
  await expectCode(
    call('alice', {
      operation: 'sendConnectionRequest',
      fromUserId: 'charlie',
      toUserId: 'bob',
    }),
    'permission-denied',
  );
  await expectCode(
    call('alice', {
      operation: 'createBlock',
      blockerId: 'charlie',
      blockedUserId: 'bob',
    }),
    'permission-denied',
  );
  await expectCode(
    call('alice', {
      operation: 'sendConnectionRequest',
      fromUserId: 'alice',
      toUserId: 'bob',
      expectedId: directionalIdentity('connection_request', 'alice', 'carol'),
    }),
    'invalid-argument',
  );
  await expectCode(
    call('alice', {
      operation: 'sendConversationRequest',
      fromUserId: 'alice',
      toUserId: 'bob',
      expectedId: 'arbitrary',
    }),
    'invalid-argument',
  );
  await expectCode(
    call('alice', {
      operation: 'createConnection',
      firstUserId: 'alice',
      secondUserId: 'bob',
      expectedId: connectionIdentity('alice', 'carol'),
    }),
    'invalid-argument',
  );
  await expectCode(
    call('alice', {
      operation: 'createBlock',
      blockerId: 'alice',
      blockedUserId: 'bob',
      expectedId: directionalIdentity('block', 'alice', 'carol'),
    }),
    'invalid-argument',
  );
});

test('request transitions enforce ownership and persisted participant integrity', async () => {
  const requestId = directionalIdentity('connection_request', 'alice', 'bob');
  await call('alice', {
    operation: 'sendConnectionRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: requestId,
  });

  await expectCode(
    call('charlie', {
      operation: 'cancelConnectionRequest',
      fromUserId: 'alice',
      toUserId: 'bob',
      expectedId: requestId,
    }),
    'permission-denied',
  );
  await expectCode(
    call('alice', {
      operation: 'acceptConnectionRequest',
      fromUserId: 'alice',
      toUserId: 'bob',
      expectedId: requestId,
    }),
    'permission-denied',
  );
  await expectCode(
    call('alice', {
      operation: 'declineConnectionRequest',
      fromUserId: 'alice',
      toUserId: 'bob',
      expectedId: requestId,
    }),
    'permission-denied',
  );

  await db.collection('connection_requests').doc(requestId).update({
    fromUserId: 'mallory',
  });
  await expectCode(
    call('bob', {
      operation: 'acceptConnectionRequest',
      fromUserId: 'alice',
      toUserId: 'bob',
      expectedId: requestId,
    }),
    'failed-precondition',
  );
});

test('connection lifecycle rejects outsiders and direct reactivation', async () => {
  const requestId = directionalIdentity('connection_request', 'alice', 'bob');
  await call('alice', {
    operation: 'sendConnectionRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: requestId,
  });
  await call('bob', {
    operation: 'acceptConnectionRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: requestId,
  });
  await expectCode(
    call('alice', {
      operation: 'acceptConversationRequest',
      fromUserId: 'alice',
      toUserId: 'bob',
      expectedId: directionalIdentity('conversation_request', 'alice', 'bob'),
    }),
    'permission-denied',
  );

  const connectionId = connectionIdentity('alice', 'bob');
  await call('alice', {
    operation: 'createConnection',
    firstUserId: 'alice',
    secondUserId: 'bob',
    expectedId: connectionId,
  });
  await expectCode(
    call('charlie', {
      operation: 'removeConnection',
      firstUserId: 'alice',
      secondUserId: 'bob',
      expectedId: connectionId,
    }),
    'permission-denied',
  );
  await call('bob', {
    operation: 'removeConnection',
    firstUserId: 'alice',
    secondUserId: 'bob',
    expectedId: connectionId,
  });
  await expectCode(
    call('alice', {
      operation: 'createConnection',
      firstUserId: 'alice',
      secondUserId: 'bob',
      expectedId: connectionId,
    }),
    'failed-precondition',
  );
});

test('inconsistent connection and block participants cannot be transitioned', async () => {
  const requestId = directionalIdentity('connection_request', 'alice', 'bob');
  const connectionId = connectionIdentity('alice', 'bob');
  await call('alice', {
    operation: 'sendConnectionRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: requestId,
  });
  await call('bob', {
    operation: 'acceptConnectionRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: requestId,
  });
  await call('alice', {
    operation: 'createConnection',
    firstUserId: 'alice',
    secondUserId: 'bob',
    expectedId: connectionId,
  });
  await db.collection('connections').doc(connectionId).update({ userB: 'mallory' });
  await expectCode(
    call('alice', {
      operation: 'removeConnection',
      firstUserId: 'alice',
      secondUserId: 'bob',
      expectedId: connectionId,
    }),
    'failed-precondition',
  );

  const blockId = directionalIdentity('block', 'alice', 'bob');
  await call('alice', {
    operation: 'createBlock',
    blockerId: 'alice',
    blockedUserId: 'bob',
    expectedId: blockId,
  });
  await db.collection('blocks').doc(blockId).update({ blockedUserId: 'mallory' });
  await expectCode(
    call('alice', {
      operation: 'removeBlock',
      blockerId: 'alice',
      blockedUserId: 'bob',
      expectedId: blockId,
    }),
    'failed-precondition',
  );
});

test('concurrent acceptance has one valid winner', async () => {
  const requestId = directionalIdentity('connection_request', 'alice', 'bob');
  await call('alice', {
    operation: 'sendConnectionRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: requestId,
  });
  const results = await Promise.allSettled([
    call('bob', {
      operation: 'acceptConnectionRequest',
      fromUserId: 'alice',
      toUserId: 'bob',
      expectedId: requestId,
    }),
    call('bob', {
      operation: 'acceptConnectionRequest',
      fromUserId: 'alice',
      toUserId: 'bob',
      expectedId: requestId,
    }),
  ]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(results.filter((result) => result.status === 'rejected').length, 1);
  assert.equal((await db.collection('connection_requests').doc(requestId).get()).data().status, 'accepted');
});

test('conversation acceptance changes only the request', async () => {
  const requestId = directionalIdentity('conversation_request', 'alice', 'bob');
  await call('alice', {
    operation: 'sendConversationRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: requestId,
  });
  await call('bob', {
    operation: 'acceptConversationRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: requestId,
  });
  assert.equal((await db.collection('connections').listDocuments()).length, 0);
  assert.equal((await db.collection('messages').listDocuments()).length, 0);
  assert.equal((await db.collection('conversation_requests').doc(requestId).get()).data().status, 'accepted');
});

test('authorized cancel and decline transitions are accepted for both request types', async () => {
  const connectionCancelId = directionalIdentity('connection_request', 'alice', 'bob');
  await call('alice', {
    operation: 'sendConnectionRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: connectionCancelId,
  });
  await call('alice', {
    operation: 'cancelConnectionRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: connectionCancelId,
  });
  assert.equal(
    (await db.collection('connection_requests').doc(connectionCancelId).get()).data().status,
    'cancelled',
  );

  const connectionDeclineId = directionalIdentity('connection_request', 'alice', 'carol');
  await call('alice', {
    operation: 'sendConnectionRequest',
    fromUserId: 'alice',
    toUserId: 'carol',
    expectedId: connectionDeclineId,
  });
  await call('carol', {
    operation: 'declineConnectionRequest',
    fromUserId: 'alice',
    toUserId: 'carol',
    expectedId: connectionDeclineId,
  });

  const conversationCancelId = directionalIdentity('conversation_request', 'alice', 'bob');
  await call('alice', {
    operation: 'sendConversationRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: conversationCancelId,
  });
  await call('alice', {
    operation: 'cancelConversationRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: conversationCancelId,
  });

  const conversationDeclineId = directionalIdentity('conversation_request', 'alice', 'carol');
  await call('alice', {
    operation: 'sendConversationRequest',
    fromUserId: 'alice',
    toUserId: 'carol',
    expectedId: conversationDeclineId,
  });
  await call('carol', {
    operation: 'declineConversationRequest',
    fromUserId: 'alice',
    toUserId: 'carol',
    expectedId: conversationDeclineId,
  });
  assert.equal(
    (await db.collection('conversation_requests').doc(conversationDeclineId).get()).data().status,
    'declined',
  );
});

test('blocks enforce both directions and preserve removal history', async () => {
  const blockId = directionalIdentity('block', 'alice', 'bob');
  await call('alice', {
    operation: 'createBlock',
    blockerId: 'alice',
    blockedUserId: 'bob',
    expectedId: blockId,
  });
  await expectCode(
    call('bob', {
      operation: 'sendConnectionRequest',
      fromUserId: 'bob',
      toUserId: 'alice',
      expectedId: directionalIdentity('connection_request', 'bob', 'alice'),
    }),
    'failed-precondition',
  );
  await expectCode(
    call('bob', {
      operation: 'removeBlock',
      blockerId: 'alice',
      blockedUserId: 'bob',
      expectedId: blockId,
    }),
    'permission-denied',
  );
  await call('alice', {
    operation: 'removeBlock',
    blockerId: 'alice',
    blockedUserId: 'bob',
    expectedId: blockId,
  });
  const block = (await db.collection('blocks').doc(blockId).get()).data();
  assert.equal(block.status, 'removed');
  await expectCode(
    call('alice', {
      operation: 'createBlock',
      blockerId: 'alice',
      blockedUserId: 'bob',
      expectedId: blockId,
    }),
    'failed-precondition',
  );
});

test('retries and concurrent creation remain idempotent', async () => {
  const requestId = directionalIdentity('connection_request', 'alice', 'bob');
  const results = await Promise.all([
    call('alice', {
      operation: 'sendConnectionRequest',
      fromUserId: 'alice',
      toUserId: 'bob',
      expectedId: requestId,
    }),
    call('alice', {
      operation: 'sendConnectionRequest',
      fromUserId: 'alice',
      toUserId: 'bob',
      expectedId: requestId,
    }),
    call('alice', {
      operation: 'sendConnectionRequest',
      fromUserId: 'alice',
      toUserId: 'bob',
      expectedId: requestId,
    }),
  ]);
  assert.equal(results.length, 3);
  assert.equal((await db.collection('connection_requests').listDocuments()).length, 1);
  const retry = await call('alice', {
    operation: 'sendConnectionRequest',
    fromUserId: 'alice',
    toUserId: 'bob',
    expectedId: requestId,
  });
  assert.equal(retry.status, 'pending');

  const blockId = directionalIdentity('block', 'alice', 'bob');
  const blockResults = await Promise.all([
    call('alice', {
      operation: 'createBlock',
      blockerId: 'alice',
      blockedUserId: 'bob',
      expectedId: blockId,
    }),
    call('alice', {
      operation: 'createBlock',
      blockerId: 'alice',
      blockedUserId: 'bob',
      expectedId: blockId,
    }),
  ]);
  assert.equal(blockResults.length, 2);
  assert.equal((await db.collection('blocks').listDocuments()).length, 1);
});
