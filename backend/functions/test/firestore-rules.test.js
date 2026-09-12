const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');
const { serverTimestamp } = require('firebase/firestore');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const rulesPath = path.resolve(__dirname, '..', '..', '..', 'firestore.rules');

let testEnv;

const makeUser = (uid, extra = {}) => ({
  displayName: 'User ' + uid,
  bio: 'bio',
  avatarUrl: null,
  private: false,
  settings: {},
  updatedAt: new Date(),
  language: 'pt-BR',
  following: [],
  followers: [],
  outgoingFollowRequests: [],
  incomingFollowRequests: [],
  blocked: [],
  muted: [],
  ...extra,
});

test.before(async () => {
  admin.initializeApp({ projectId: 'demo-labomba-rules' });
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-labomba-rules',
    firestore: {
      rules: fs.readFileSync(rulesPath, 'utf8'),
    },
  });
});

test.after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

test('user A cannot alter user B profile', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const bob = testEnv.authenticatedContext('bob', { email: 'bob@example.com' });

  await assertSucceeds(
    bob.firestore().collection('users').doc('bob').set(makeUser('bob')),
  );

  await assertFails(
    alice.firestore().collection('users').doc('bob').update({
      displayName: 'Hacked Profile',
    }),
  );
});

test('user A cannot delete post of user B', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const bob = testEnv.authenticatedContext('bob', { email: 'bob@example.com' });

  await assertSucceeds(
    bob.firestore().collection('posts').doc('post-b').set({
      authorId: 'bob',
      content: 'Post seguro',
      createdAt: new Date(),
      updatedAt: new Date(),
    }),
  );

  await assertFails(alice.firestore().collection('posts').doc('post-b').delete());
});

test('user A cannot edit story of user B', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await adminDb.collection('users').doc('bob').collection('stories').doc('story-b').set({
      userId: 'bob',
      type: 'image',
      mediaUrl: 'https://example.com/story.jpg',
      createdAt: new Date(),
      duration: 5,
    });
  });

  await assertFails(
    alice.firestore().collection('users').doc('bob').collection('stories').doc('story-b').update({
      mediaUrl: 'https://evil.example/owned-story.jpg',
    }),
  );
});

test('non-admin user cannot execute administrative action', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });

  await assertFails(
    alice.firestore().collection('admin_requests').add({
      type: 'delete_post',
      createdBy: 'alice',
      actorUid: 'alice',
      createdAt: new Date(),
      status: 'pending',
      resourceType: 'post',
      resourceId: 'post-123',
      reason: 'Exploit attempt',
    }),
  );
});

test('chat membership uses only canonical participants for messages', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const bob = testEnv.authenticatedContext('bob', { email: 'bob@example.com' });
  const charlie = testEnv.authenticatedContext('charlie', { email: 'charlie@example.com' });

  await assertSucceeds(
    alice.firestore().collection('chats').doc('test-chat').set({
      participants: ['alice', 'bob'],
      createdAt: new Date(),
      title: 'Private chat',
    }),
  );

  await assertSucceeds(alice.firestore().collection('chats').doc('test-chat').get());
  await assertSucceeds(bob.firestore().collection('chats').doc('test-chat').get());
  await assertFails(charlie.firestore().collection('chats').doc('test-chat').get());

  await assertSucceeds(
    alice.firestore().collection('chats').doc('test-chat').collection('messages').doc('msg-1').set({
      senderId: 'alice',
      text: 'hello',
      createdAt: new Date(),
    }),
  );

  await assertSucceeds(
    bob.firestore().collection('chats').doc('test-chat').collection('messages').doc('msg-2').set({
      senderId: 'bob',
      text: 'hi',
      createdAt: new Date(),
    }),
  );

  await assertFails(
    charlie.firestore().collection('chats').doc('test-chat').collection('messages').doc('msg-3').set({
      senderId: 'charlie',
      text: 'should fail',
      createdAt: new Date(),
    }),
  );

  await assertSucceeds(
    alice.firestore().collection('chats').doc('test-chat').collection('messages').doc('msg-1').get(),
  );
  await assertFails(
    charlie.firestore().collection('chats').doc('test-chat').collection('messages').doc('msg-1').get(),
  );
});

test('non-participant cannot read private conversation', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const bob = testEnv.authenticatedContext('bob', { email: 'bob@example.com' });
  const charlie = testEnv.authenticatedContext('charlie', { email: 'charlie@example.com' });

  await assertSucceeds(
    alice.firestore().collection('chats').doc('chat-1').set({
      participants: ['alice', 'bob'],
      createdAt: new Date(),
      title: 'Private chat',
    }),
  );

  await assertFails(charlie.firestore().collection('chats').doc('chat-1').get());
  await assertSucceeds(bob.firestore().collection('chats').doc('chat-1').get());
});

test('chat creation requires a valid canonical participants array', async () => {
  const alice = testEnv.authenticatedContext('alice');
  const bob = testEnv.authenticatedContext('bob');
  const anonymous = testEnv.unauthenticatedContext();

  await assertSucceeds(
    alice.firestore().collection('chats').doc('valid-chat').set({
      participants: ['alice', 'bob'],
      createdAt: new Date(),
    }),
  );
  await assertFails(
    alice.firestore().collection('chats').doc('members-only-chat').set({
      members: ['alice', 'bob'],
      createdAt: new Date(),
    }),
  );
  await assertFails(
    alice.firestore().collection('chats').doc('missing-participants-chat').set({
      createdAt: new Date(),
    }),
  );
  await assertFails(
    alice.firestore().collection('chats').doc('invalid-participants-chat').set({
      participants: 'alice',
      createdAt: new Date(),
    }),
  );
  await assertFails(
    alice.firestore().collection('chats').doc('creator-not-in-chat').set({
      participants: ['bob'],
      createdAt: new Date(),
    }),
  );
  await assertFails(bob.firestore().collection('chats').doc('members-only-chat').get());
  await assertFails(anonymous.firestore().collection('chats').doc('valid-chat').get());
  await assertFails(anonymous.firestore().collection('chats').doc('valid-chat')
      .collection('messages').doc('anonymous-message').set({
        senderId: 'anonymous',
        text: 'denied',
        createdAt: new Date(),
      }));
});

test('members-only chats cannot authorize message reads or updates', async () => {
  const alice = testEnv.authenticatedContext('alice');
  const chat = alice.firestore().collection('chats').doc('legacy-chat');
  const message = chat.collection('messages').doc('message-1');

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('chats').doc('legacy-chat').set({
      members: ['alice'],
      createdAt: new Date(),
    });
    await context.firestore().collection('chats').doc('legacy-chat')
        .collection('messages').doc('message-1').set({
      senderId: 'alice',
      text: 'legacy message',
      createdAt: new Date(),
    });
  });

  await assertFails(message.get());
  await assertFails(message.update({ text: 'must remain denied' }));
});

test('message updates require canonical chat membership', async () => {
  const alice = testEnv.authenticatedContext('alice');
  const outsider = testEnv.authenticatedContext('outsider');
  const chat = alice.firestore().collection('chats').doc('update-chat');
  const message = chat.collection('messages').doc('message-1');

  await assertSucceeds(chat.set({
    participants: ['alice'],
    createdAt: new Date(),
  }));
  await assertSucceeds(message.set({
    senderId: 'alice',
    text: 'original',
    createdAt: new Date(),
  }));
  await assertSucceeds(message.update({ text: 'updated' }));
  await assertFails(outsider.firestore().collection('chats').doc('update-chat')
      .collection('messages').doc('message-1').update({ text: 'denied' }));
});

test('user cannot change authorId in a post', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });

  await assertSucceeds(
    alice.firestore().collection('posts').doc('post-author-guard').set({
      authorId: 'alice',
      content: 'Texto',
      createdAt: new Date(),
      updatedAt: new Date(),
    }),
  );

  await assertFails(
    alice.firestore().collection('posts').doc('post-author-guard').update({
      authorId: 'mallory',
    }),
  );
});

test('user cannot modify roles field on own user document', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });

  await assertSucceeds(
    alice.firestore().collection('users').doc('alice').set(makeUser('alice')),
  );

  await assertFails(
    alice.firestore().collection('users').doc('alice').update({
      roles: ['admin'],
    }),
  );
});

const socialRequestData = (fromUserId, toUserId, status = 'pending') => ({
  fromUserId,
  toUserId,
  status,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

const socialBlockData = (blockerId, blockedUserId) => ({
  blockerId,
  blockedUserId,
  status: 'active',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

test('social collections reject all direct client writes', async () => {
  const alice = testEnv.authenticatedContext('alice');
  const payload = socialRequestData('alice', 'bob');

  await assertFails(alice.firestore().collection('connection_requests').doc('arbitrary').set(payload));
  await assertFails(alice.firestore().collection('conversation_requests').doc('arbitrary').set(payload));
  await assertFails(alice.firestore().collection('blocks').doc('arbitrary').set(socialBlockData('alice', 'bob')));
  await assertFails(alice.firestore().collection('connections').doc('arbitrary').set({
    userA: 'alice',
    userB: 'bob',
    status: 'connected',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    connectedAt: serverTimestamp(),
  }));
});

test('social participants can read but unrelated users cannot', async () => {
  const alice = testEnv.authenticatedContext('alice');
  const bob = testEnv.authenticatedContext('bob');
  const charlie = testEnv.authenticatedContext('charlie');

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('connection_requests').doc('canonical').set({
      fromUserId: 'alice',
      toUserId: 'bob',
      status: 'pending',
    });
  });
  await assertSucceeds(alice.firestore().collection('connection_requests').doc('canonical').get());
  await assertSucceeds(bob.firestore().collection('connection_requests').doc('canonical').get());
  await assertFails(charlie.firestore().collection('connection_requests').doc('canonical').get());
});

test('social documents cannot be changed or deleted directly', async () => {
  const alice = testEnv.authenticatedContext('alice');
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('blocks').doc('canonical').set({
      blockerId: 'alice',
      blockedUserId: 'bob',
      status: 'active',
    });
  });
  await assertFails(alice.firestore().collection('blocks').doc('canonical').update({ status: 'removed' }));
  await assertFails(alice.firestore().collection('blocks').doc('canonical').delete());
});

test('private profile is not readable by unrelated user', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const bob = testEnv.authenticatedContext('bob', { email: 'bob@example.com' });

  await assertSucceeds(
    bob.firestore().collection('users').doc('bob').set(makeUser('bob', {
      private: true,
      followers: [],
    })),
  );

  await assertFails(alice.firestore().collection('users').doc('bob').get());
});

test('user can create follow relationship docs in subcollections', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });

  await assertSucceeds(
    alice.firestore().collection('users').doc('bob').collection('followers').doc('alice').set({
      userId: 'bob',
      followerId: 'alice',
      createdAt: new Date(),
    }),
  );

  await assertSucceeds(
    alice.firestore().collection('users').doc('alice').collection('following').doc('bob').set({
      userId: 'alice',
      followingId: 'bob',
      createdAt: new Date(),
    }),
  );
});

test('user cannot create follow relationship for another user', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const charlie = testEnv.authenticatedContext('charlie', { email: 'charlie@example.com' });

  await assertFails(
    charlie.firestore().collection('users').doc('alice').collection('followers').doc('bob').set({
      userId: 'alice',
      followerId: 'bob',
      createdAt: new Date(),
    }),
  );
});

test('community and topic metadata reads require authentication', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const unauthenticated = testEnv.unauthenticatedContext();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('communities').doc('physics').set({
      name: 'Physics',
      ownerId: 'alice',
      topicIds: ['science'],
    });
    await db.collection('topics').doc('science').set({ title: 'Science' });
  });

  await assertSucceeds(alice.firestore().collection('communities').doc('physics').get());
  await assertSucceeds(alice.firestore().collection('communities').limit(10).get());
  await assertSucceeds(alice.firestore().collection('communities').where('topicIds', 'array-contains', 'science').orderBy('name').get());
  await assertSucceeds(alice.firestore().collection('topics').doc('science').get());
  await assertSucceeds(alice.firestore().collection('topics').limit(10).get());
  await assertFails(unauthenticated.firestore().collection('communities').doc('physics').get());
  await assertFails(unauthenticated.firestore().collection('communities').limit(10).get());
  await assertFails(unauthenticated.firestore().collection('topics').doc('science').get());
  await assertFails(unauthenticated.firestore().collection('topics').limit(10).get());
});

test('membership reads are self-scoped and active member listing is community-scoped', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const bob = testEnv.authenticatedContext('bob', { email: 'bob@example.com' });
  const charlie = testEnv.authenticatedContext('charlie', { email: 'charlie@example.com' });
  const moderator = testEnv.authenticatedContext('mod', { role: 'moderator' });
  const admin = testEnv.authenticatedContext('admin', { role: 'admin' });
  const unauthenticated = testEnv.unauthenticatedContext();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('communities').doc('owned-by-bob').set({
      name: 'Owned by Bob',
      ownerId: 'bob',
    });
    await db.collection('community_memberships').doc('owned-by-bob::alice').set({
      communityId: 'owned-by-bob',
      userId: 'alice',
      role: 'member',
      status: 'active',
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await db.collection('community_memberships').doc('owned-by-bob::bob').set({
      communityId: 'owned-by-bob',
      userId: 'bob',
      role: 'owner',
      status: 'active',
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });

  await assertSucceeds(alice.firestore().collection('community_memberships').doc('owned-by-bob::alice').get());
  await assertSucceeds(alice.firestore().collection('community_memberships').doc('owned-by-bob::bob').get());
  await assertFails(charlie.firestore().collection('community_memberships').doc('owned-by-bob::alice').get());
  await assertSucceeds(bob.firestore().collection('community_memberships').doc('owned-by-bob::alice').get());
  await assertSucceeds(moderator.firestore().collection('community_memberships').doc('owned-by-bob::alice').get());
  await assertSucceeds(admin.firestore().collection('community_memberships').doc('owned-by-bob::alice').get());

  await assertSucceeds(alice.firestore().collection('community_memberships').where('userId', '==', 'alice').where('status', '==', 'active').orderBy('updatedAt', 'desc').get());
  await assertSucceeds(alice.firestore().collection('community_memberships').where('communityId', '==', 'owned-by-bob').where('status', '==', 'active').orderBy('createdAt', 'desc').get());
  await assertSucceeds(bob.firestore().collection('community_memberships').where('communityId', '==', 'owned-by-bob').where('status', '==', 'active').orderBy('createdAt', 'desc').get());
  await assertSucceeds(moderator.firestore().collection('community_memberships').where('communityId', '==', 'owned-by-bob').where('status', '==', 'active').orderBy('createdAt', 'desc').get());
  await assertSucceeds(admin.firestore().collection('community_memberships').where('communityId', '==', 'owned-by-bob').where('status', '==', 'active').orderBy('createdAt', 'desc').get());
  await assertFails(charlie.firestore().collection('community_memberships').where('communityId', '==', 'owned-by-bob').get());
  await assertFails(unauthenticated.firestore().collection('community_memberships').where('userId', '==', 'alice').get());
});

test('member visibility is active-member-scoped and does not grant private profile access', async () => {
  const owner = testEnv.authenticatedContext('owner', { email: 'owner@example.com' });
  const activeMember = testEnv.authenticatedContext('active-member', { email: 'member@example.com' });
  const pendingMember = testEnv.authenticatedContext('pending-member', { email: 'pending@example.com' });
  const blockedMember = testEnv.authenticatedContext('blocked-member', { email: 'blocked@example.com' });
  const leftMember = testEnv.authenticatedContext('left-member', { email: 'left@example.com' });
  const outsider = testEnv.authenticatedContext('outsider', { email: 'outsider@example.com' });
  const admin = testEnv.authenticatedContext('admin', { role: 'admin' });
  const moderator = testEnv.authenticatedContext('moderator', { role: 'moderator' });
  const unauthenticated = testEnv.unauthenticatedContext();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('communities').doc('community-a').set({
      name: 'Community A',
      ownerId: 'owner',
      status: 'active',
    });
    await db.collection('communities').doc('community-b').set({
      name: 'Community B',
      ownerId: 'owner',
      status: 'active',
    });
    for (const [userId, status] of [
      ['active-member', 'active'],
      ['pending-member', 'pending'],
      ['blocked-member', 'blocked'],
      ['left-member', 'left'],
    ]) {
      await db.collection('community_memberships').doc(`community-a::${userId}`).set({
        communityId: 'community-a',
        userId,
        role: 'member',
        status,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    }
    await db.collection('community_memberships').doc('community-b::other-member').set({
      communityId: 'community-b',
      userId: 'other-member',
      role: 'member',
      status: 'active',
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await db.collection('users').doc('pending-member').set(makeUser('pending-member', {
      private: true,
      followers: [],
    }));
  });

  await assertSucceeds(owner.firestore().collection('community_memberships').where('communityId', '==', 'community-a').where('status', '==', 'active').get());
  await assertSucceeds(admin.firestore().collection('community_memberships').where('communityId', '==', 'community-a').where('status', '==', 'active').get());
  await assertSucceeds(moderator.firestore().collection('community_memberships').where('communityId', '==', 'community-a').where('status', '==', 'active').get());
  const visibleMembers = await activeMember.firestore().collection('community_memberships').where('communityId', '==', 'community-a').where('status', '==', 'active').get();
  assert.deepEqual(visibleMembers.docs.map((doc) => doc.data().userId), ['active-member']);
  for (const context of [pendingMember, blockedMember, leftMember]) {
    await assertFails(context.firestore().collection('community_memberships').where('communityId', '==', 'community-a').where('status', '==', 'active').get());
  }
  await assertFails(outsider.firestore().collection('community_memberships').where('communityId', '==', 'community-a').where('status', '==', 'active').get());
  await assertFails(unauthenticated.firestore().collection('community_memberships').where('communityId', '==', 'community-a').get());

  await assertFails(activeMember.firestore().collection('community_memberships').doc('community-b::other-member').get());
  await assertFails(activeMember.firestore().collection('community_memberships').doc('community-a::pending-member').get());
  await assertFails(activeMember.firestore().collection('community_memberships').doc('community-a::blocked-member').get());
  await assertFails(activeMember.firestore().collection('community_memberships').doc('community-a::left-member').get());
  await assertFails(activeMember.firestore().collection('community_memberships').where('communityId', '==', 'community-b').where('status', '==', 'active').get());
  await assertFails(activeMember.firestore().collection('users').doc('pending-member').get());
});

test('community knowledge persistence is active-member-scoped and author-bound', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const bob = testEnv.authenticatedContext('bob', { email: 'bob@example.com' });
  const pending = testEnv.authenticatedContext('pending', { email: 'pending@example.com' });
  const blocked = testEnv.authenticatedContext('blocked', { email: 'blocked@example.com' });
  const left = testEnv.authenticatedContext('left', { email: 'left@example.com' });
  const outsider = testEnv.authenticatedContext('outsider', { email: 'outsider@example.com' });
  const unauthenticated = testEnv.unauthenticatedContext();
  const timestamp = serverTimestamp();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const communityId of ['knowledge-a', 'knowledge-b']) {
      await db.collection('communities').doc(communityId).set({
        name: communityId,
        ownerId: communityId === 'knowledge-a' ? 'alice' : 'bob',
        status: 'active',
      });
    }
    for (const [userId, status] of [
      ['alice', 'active'],
      ['bob', 'active'],
      ['pending', 'pending'],
      ['blocked', 'blocked'],
      ['left', 'left'],
    ]) {
      await db.collection('community_memberships').doc(`knowledge-a::${userId}`).set({
        communityId: 'knowledge-a',
        userId,
        role: userId === 'alice' ? 'owner' : 'member',
        status,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    }
    await db.collection('community_memberships').doc('knowledge-b::bob').set({
      communityId: 'knowledge-b',
      userId: 'bob',
      role: 'member',
      status: 'active',
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await db.collection('community_contents').doc('content-b').set({
      contentId: 'content-b',
      communityId: 'knowledge-b',
      type: 'fact',
      title: 'Other community',
      body: 'Private to the other community.',
      createdBy: 'bob',
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });

  const content = alice.firestore().collection('community_contents').doc('content-a');
  await assertSucceeds(bob.firestore().collection('community_contents').doc('content-a').set({
    contentId: 'content-a',
    communityId: 'knowledge-a',
    type: 'fact',
    title: 'Observed association',
    body: 'Study X observed an association in population Y.',
    createdBy: 'bob',
    lifecycle: 'active',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
  await assertSucceeds(bob.firestore().collection('community_contents').doc('content-a').get());
  await assertSucceeds(bob.firestore().collection('community_contents').where('communityId', '==', 'knowledge-a').orderBy('createdAt', 'desc').get());
  await assertSucceeds(alice.firestore().collection('community_contents').doc('content-a').get());
  await assertFails(unauthenticated.firestore().collection('community_contents').doc('content-a').get());
  await assertFails(outsider.firestore().collection('community_contents').doc('content-a').get());
  for (const context of [pending, blocked, left]) {
    await assertFails(context.firestore().collection('community_contents').doc('content-a').get());
    await assertFails(context.firestore().collection('community_contents').doc(`forbidden-${context}`).set({}));
  }
  await assertFails(alice.firestore().collection('community_contents').doc('content-b').get());

  await assertFails(bob.firestore().collection('community_contents').doc('forged-author').set({
    contentId: 'forged-author',
    communityId: 'knowledge-a',
    type: 'fact',
    title: 'Forged',
    body: 'Forged author',
    createdBy: 'alice',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
  await assertFails(alice.firestore().collection('community_contents').doc('forged-community').set({
    contentId: 'forged-community',
    communityId: 'knowledge-b',
    type: 'fact',
    title: 'Wrong community',
    body: 'Wrong community',
    createdBy: 'alice',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
  await assertFails(bob.firestore().collection('community_contents').doc('content-a').update({
    createdBy: 'alice',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(bob.firestore().collection('community_contents').doc('content-a').update({
    communityId: 'knowledge-b',
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(bob.firestore().collection('community_contents').doc('content-a').update({
    body: 'Updated context.',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(left.firestore().collection('community_contents').doc('content-a').update({
    body: 'Former member update.',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(bob.firestore().collection('community_contents').doc('content-a').delete());

  const source = bob.firestore().collection('communities').doc('knowledge-a').collection('sources').doc('source-a');
  await assertSucceeds(source.set({
    sourceId: 'source-a',
    title: 'Study X',
    type: 'scientificArticle',
    locator: 'https://example.org/study-x',
    createdBy: 'bob',
    createdAt: timestamp,
  }));
  await assertSucceeds(source.get());
  await assertFails(outsider.firestore().collection('communities').doc('knowledge-a').collection('sources').doc('source-a').get());
  await assertFails(bob.firestore().collection('communities').doc('knowledge-a').collection('sources').doc('forged-source').set({
    sourceId: 'forged-source',
    title: 'Forged source',
    type: 'book',
    locator: 'https://example.org/forged',
    createdBy: 'alice',
    createdAt: timestamp,
  }));

  const evidence = content.collection('evidences').doc('evidence-a');
  await assertSucceeds(evidence.set({
    evidenceId: 'evidence-a',
    contentId: 'content-a',
    type: 'scientificStudy',
    description: 'The study reports the association.',
    createdBy: 'alice',
    createdAt: serverTimestamp(),
  }));
  await assertSucceeds(evidence.get());
  await assertFails(outsider.firestore().collection('community_contents').doc('content-a').collection('evidences').doc('evidence-outside').set({
    evidenceId: 'evidence-outside',
    contentId: 'content-a',
    type: 'observation',
    description: 'Unauthorized evidence.',
    createdBy: 'outsider',
    createdAt: timestamp,
  }));
  await assertFails(bob.firestore().collection('community_contents').doc('content-a').collection('evidences').doc('cross-source').set({
    evidenceId: 'cross-source',
    contentId: 'content-a',
    sourceId: 'source-b',
    type: 'scientificStudy',
    description: 'Cross-community source.',
    createdBy: 'bob',
    createdAt: timestamp,
  }));

  const correction = content.collection('content_corrections').doc('correction-a');
  await assertSucceeds(correction.set({
    correctionId: 'correction-a',
    contentId: 'content-a',
    explanation: 'The population context was missing.',
    createdBy: 'alice',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(correction.get());
  await assertFails(bob.firestore().collection('community_contents').doc('content-a').collection('content_corrections').doc('wrong-content').set({
    correctionId: 'wrong-content',
    contentId: 'content-b',
    explanation: 'Cross-community correction.',
    createdBy: 'bob',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
  await assertFails(correction.delete());
});

test('community reports and lifecycle moderation are isolated and human-resolved', async () => {
  const member = testEnv.authenticatedContext('reporter', { email: 'reporter@example.com' });
  const pending = testEnv.authenticatedContext('pending-report', { email: 'pending@example.com' });
  const moderator = testEnv.authenticatedContext('community-mod', { email: 'mod@example.com' });
  const otherModerator = testEnv.authenticatedContext('other-mod', { email: 'other-mod@example.com' });
  const unauthenticated = testEnv.unauthenticatedContext();
  const now = serverTimestamp();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('communities').doc('moderation-a').set({ name: 'A', ownerId: 'owner-a', status: 'active' });
    await db.collection('communities').doc('moderation-b').set({ name: 'B', ownerId: 'owner-b', status: 'active' });
    for (const [communityId, userId, role, status] of [
      ['moderation-a', 'reporter', 'member', 'active'],
      ['moderation-a', 'community-mod', 'moderator', 'active'],
      ['moderation-a', 'pending-report', 'member', 'pending'],
      ['moderation-b', 'other-mod', 'moderator', 'active'],
    ]) {
      await db.collection('community_memberships').doc(`${communityId}::${userId}`).set({ communityId, userId, role, status, createdAt: new Date(), updatedAt: new Date() });
    }
    await db.collection('community_contents').doc('moderated-content').set({
      contentId: 'moderated-content', communityId: 'moderation-a', type: 'fact',
      title: 'Claim', body: 'Context', createdBy: 'reporter', lifecycle: 'active',
      createdAt: new Date(), updatedAt: new Date(),
    });
    await db.collection('community_contents').doc('other-content').set({
      contentId: 'other-content', communityId: 'moderation-b', type: 'fact',
      title: 'Other', body: 'Other context', createdBy: 'other-mod', lifecycle: 'active',
      createdAt: new Date(), updatedAt: new Date(),
    });
    await db.collection('community_contents').doc('moderated-content').collection('evidences').doc('evidence-1').set({
      evidenceId: 'evidence-1', contentId: 'moderated-content', type: 'observation', description: 'Evidence', createdBy: 'reporter', createdAt: new Date(),
    });
  });

  const report = member.firestore().collection('community_reports').doc('moderation-a::reporter::content::moderated-content::misinformation');
  const payload = {
    reportId: report.id,
    communityId: 'moderation-a',
    targetType: 'content',
    targetId: 'moderated-content',
    reason: 'misinformation',
    description: 'Needs human review',
    reportedBy: 'reporter',
    createdAt: now,
    status: 'open',
  };
  await assertSucceeds(report.set(payload));
  await assertFails(report.set(payload));
  await assertFails(unauthenticated.firestore().collection('community_reports').doc('anonymous').set({ ...payload, reportId: 'anonymous' }));
  await assertFails(pending.firestore().collection('community_reports').doc('pending').set({ ...payload, reportId: 'pending', reportedBy: 'pending-report' }));
  await assertFails(member.firestore().collection('community_reports').doc('forged').set({ ...payload, reportId: 'forged', reportedBy: 'other-user' }));
  await assertFails(member.firestore().collection('community_reports').doc('cross').set({ ...payload, reportId: 'cross', targetId: 'other-content', communityId: 'moderation-a' }));
  await assertFails(member.firestore().collection('community_reports').doc(report.id).get());
  await assertSucceeds(moderator.firestore().collection('community_reports').doc(report.id).get());
  await assertFails(otherModerator.firestore().collection('community_reports').doc(report.id).get());

  await assertSucceeds(moderator.firestore().collection('community_contents').doc('moderated-content').update({
    lifecycle: 'restricted', lifecycleUpdatedBy: 'community-mod', updatedAt: serverTimestamp(),
  }));
  await assertFails(member.firestore().collection('community_contents').doc('moderated-content').get());
  await assertSucceeds(moderator.firestore().collection('community_contents').doc('moderated-content').get());
  await assertFails(member.firestore().collection('community_contents').doc('moderated-content').update({ lifecycle: 'archived', updatedAt: serverTimestamp() }));
  await assertSucceeds(moderator.firestore().collection('community_reports').doc(report.id).update({
    status: 'resolved', resolution: 'restrictContent', reviewedBy: 'community-mod', reviewedAt: serverTimestamp(),
  }));
  await assertFails(moderator.firestore().collection('community_reports').doc(report.id).update({
    status: 'resolved', resolution: 'dismissReport', reviewedBy: 'community-mod', reviewedAt: serverTimestamp(),
  }));
  await assertFails(report.delete());
});

test('moderation audit is private and append-only, and affected users have one appeal', async () => {
  const member = testEnv.authenticatedContext('reporter');
  const staff = testEnv.authenticatedContext('community-mod');
  const outsider = testEnv.authenticatedContext('other-mod');
  const unauthenticated = testEnv.unauthenticatedContext();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('communities').doc('audit-a').set({
      name: 'Audit A', ownerId: 'owner-a', status: 'active',
    });
    await db.collection('communities').doc('audit-b').set({
      name: 'Audit B', ownerId: 'owner-b', status: 'active',
    });
    for (const [communityId, userId, role] of [
      ['audit-a', 'reporter', 'member'],
      ['audit-a', 'community-mod', 'moderator'],
      ['audit-b', 'other-mod', 'moderator'],
    ]) {
      await db.collection('community_memberships').doc(`${communityId}::${userId}`).set({
        communityId, userId, role, status: 'active',
        createdAt: new Date(), updatedAt: new Date(),
      });
    }
    await db.collection('community_contents').doc('audit-content').set({
      contentId: 'audit-content', communityId: 'audit-a', type: 'fact',
      title: 'Audited claim', body: 'Context', createdBy: 'reporter',
      lifecycle: 'restricted', createdAt: new Date(), updatedAt: new Date(),
    });
  });

  const action = staff.firestore().collection('community_moderation_actions').doc('audit-action');
  const actionPayload = {
    actionId: 'audit-action',
    communityId: 'audit-a',
    actorId: 'community-mod',
    actionType: 'lifecycleChanged',
    targetType: 'content',
    targetId: 'audit-content',
    reason: 'policyViolation',
    previousLifecycle: 'active',
    newLifecycle: 'restricted',
    createdAt: serverTimestamp(),
  };
  await assertSucceeds(action.set(actionPayload));
  await assertFails(member.firestore().collection('community_moderation_actions').doc(action.id).get());
  await assertSucceeds(staff.firestore().collection('community_moderation_actions').doc(action.id).get());
  await assertFails(outsider.firestore().collection('community_moderation_actions').doc(action.id).get());
  await assertFails(unauthenticated.firestore().collection('community_moderation_actions').doc(action.id).get());
  await assertFails(action.update({ reason: 'changed' }));
  await assertFails(action.delete());
  await assertFails(staff.firestore().collection('community_moderation_actions').doc('forged').set({
    ...actionPayload, actionId: 'forged', actorId: 'reporter',
  }));
  await assertFails(staff.firestore().collection('community_moderation_actions').doc('cross').set({
    ...actionPayload, actionId: 'cross', communityId: 'audit-b',
  }));

  const appeal = member.firestore().collection('community_moderation_appeals')
      .doc('audit-a::reporter::content::audit-content');
  const appealPayload = {
    appealId: appeal.id,
    communityId: 'audit-a',
    targetType: 'content',
    targetId: 'audit-content',
    createdBy: 'reporter',
    createdAt: serverTimestamp(),
    reason: 'Please review the restriction',
    status: 'open',
  };
  await assertSucceeds(appeal.set(appealPayload));
  await assertFails(appeal.set(appealPayload));
  await assertSucceeds(member.firestore().collection('community_moderation_actions').doc('appeal-created-action').set({
    actionId: 'appeal-created-action',
    communityId: 'audit-a',
    actorId: 'reporter',
    actionType: 'appealCreated',
    targetType: 'content',
    targetId: 'audit-content',
    appealId: appeal.id,
    reason: 'Please review',
    createdAt: serverTimestamp(),
  }));
  await assertSucceeds(appeal.get());
  await assertFails(outsider.firestore().collection('community_moderation_appeals').doc(appeal.id).get());
  await assertSucceeds(staff.firestore().collection('community_moderation_appeals').doc(appeal.id).get());
  await assertFails(unauthenticated.firestore().collection('community_moderation_appeals').doc(appeal.id).get());
  await assertFails(member.firestore().collection('community_moderation_appeals').doc(appeal.id).update({
    status: 'rejected', resolution: 'uphold', reviewedBy: 'reporter',
    reviewedAt: serverTimestamp(), reviewReason: 'self review',
  }));
  await assertSucceeds(staff.firestore().collection('community_moderation_appeals').doc(appeal.id).update({
    status: 'underReview',
  }));
  await assertFails(staff.firestore().collection('community_moderation_appeals').doc(appeal.id).update({
    status: 'underReview',
  }));
  await assertSucceeds(staff.firestore().collection('community_moderation_appeals').doc(appeal.id).update({
    status: 'rejected', resolution: 'uphold', reviewedBy: 'community-mod',
    reviewedAt: serverTimestamp(), reviewReason: 'Decision upheld',
  }));
  await assertFails(staff.firestore().collection('community_moderation_appeals').doc(appeal.id).update({
    status: 'accepted', resolution: 'overturn', reviewedBy: 'community-mod',
    reviewedAt: serverTimestamp(), reviewReason: 'second review',
  }));
});

test('community, membership, and topic writes remain denied for every actor', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const unauthenticated = testEnv.unauthenticatedContext();

  const clients = [alice.firestore(), unauthenticated.firestore()];
  for (const db of clients) {
    await assertFails(db.collection('communities').doc('write-test').set({ name: 'No write' }));
    await assertFails(db.collection('communities').doc('write-test').update({ name: 'No write' }));
    await assertFails(db.collection('communities').doc('write-test').delete());
    await assertFails(db.collection('community_memberships').doc('write-test').set({ userId: 'alice' }));
    await assertFails(db.collection('community_memberships').doc('write-test').update({ status: 'active' }));
    await assertFails(db.collection('community_memberships').doc('write-test').delete());
    await assertFails(db.collection('topics').doc('write-test').set({ title: 'No write' }));
    await assertFails(db.collection('topics').doc('write-test').update({ title: 'No write' }));
    await assertFails(db.collection('topics').doc('write-test').delete());
  }
});

test('authenticated user can create a community and its owner membership atomically', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const community = alice.firestore().collection('communities').doc('created-community');
  const membership = alice.firestore().collection('community_memberships').doc('created-community::alice');
  const createdAt = serverTimestamp();

  const batch = alice.firestore().batch();
  batch.set(community, {
    name: 'Created Community',
    ownerId: 'alice',
    status: 'active',
    createdAt,
    updatedAt: createdAt,
  });
  batch.set(membership, {
    communityId: 'created-community',
    userId: 'alice',
    role: 'owner',
    status: 'active',
    createdAt,
    updatedAt: createdAt,
  });

  await assertSucceeds(batch.commit());
  await assertSucceeds(alice.firestore().collection('communities').doc('created-community').get());
  await assertSucceeds(alice.firestore().collection('community_memberships').doc('created-community::alice').get());
  await assertSucceeds(alice.firestore().collection('communities').orderBy('name').limit(10).get());
  await assertSucceeds(alice.firestore().collection('community_memberships').where('userId', '==', 'alice').where('status', '==', 'active').orderBy('updatedAt', 'desc').limit(10).get());
  await assertSucceeds(alice.firestore().collection('community_memberships').where('communityId', '==', 'created-community').where('status', '==', 'active').orderBy('createdAt', 'desc').limit(10).get());
});

test('community and membership create payloads cannot escalate identity or role', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const bob = testEnv.authenticatedContext('bob', { email: 'bob@example.com' });
  const unauthenticated = testEnv.unauthenticatedContext();
  const timestamp = serverTimestamp();
  const validCommunity = {
    name: 'Valid Community',
    ownerId: 'alice',
    status: 'active',
    createdAt: timestamp,
    updatedAt: timestamp,
  };

  await assertSucceeds(alice.firestore().collection('communities').doc('valid').set(validCommunity));
  await assertFails(unauthenticated.firestore().collection('communities').doc('unauth').set(validCommunity));
  await assertFails(bob.firestore().collection('communities').doc('wrong-owner').set({ ...validCommunity, ownerId: 'alice' }));
  await assertFails(alice.firestore().collection('communities').doc('missing-name').set({ ...validCommunity, name: '' }));
  await assertFails(alice.firestore().collection('communities').doc('role-field').set({ ...validCommunity, role: 'owner' }));

  await assertFails(alice.firestore().collection('community_memberships').doc('valid::alice').set({
    communityId: 'valid',
    userId: 'bob',
    role: 'member',
    status: 'active',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
  await assertFails(alice.firestore().collection('community_memberships').doc('valid::alice').set({
    communityId: 'valid',
    userId: 'alice',
    role: 'owner',
    status: 'active',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
  await assertFails(alice.firestore().collection('community_memberships').doc('valid::alice-admin').set({
    communityId: 'valid',
    userId: 'alice',
    role: 'admin',
    status: 'active',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
  await assertFails(alice.firestore().collection('community_memberships').doc('wrong-membership-id').set({
    communityId: 'valid',
    userId: 'alice',
    role: 'member',
    status: 'active',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
  await assertFails(alice.firestore().collection('community_memberships').doc('valid::alice-moderator').set({
    communityId: 'valid',
    userId: 'alice',
    role: 'moderator',
    status: 'active',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
  await assertFails(alice.firestore().collection('community_memberships').doc('valid::alice').set({
    communityId: 'valid',
    userId: 'alice',
    role: 'member',
    status: 'pending',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
});

test('authenticated user can join an existing community only as an active member', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
  const unauthenticated = testEnv.unauthenticatedContext();
  const timestamp = serverTimestamp();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('communities').doc('joinable').set({
      name: 'Joinable',
      ownerId: 'owner',
      status: 'active',
    });
  });

  const membership = alice.firestore().collection('community_memberships').doc('joinable::alice');
  await assertSucceeds(membership.set({
    communityId: 'joinable',
    userId: 'alice',
    role: 'member',
    status: 'active',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
  await assertSucceeds(membership.get());
  await assertFails(unauthenticated.firestore().collection('community_memberships').doc('joinable::anonymous').set({
    communityId: 'joinable',
    userId: 'anonymous',
    role: 'member',
    status: 'active',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
  await assertFails(membership.set({
    communityId: 'joinable',
    userId: 'alice',
    role: 'member',
    status: 'active',
    createdAt: timestamp,
    updatedAt: timestamp,
  }));
});

test('concurrent direct joins allow one create and preserve one membership', async () => {
  const alice = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('communities').doc('concurrent').set({
      name: 'Concurrent',
      ownerId: 'owner',
      status: 'active',
    });
  });

  const membership = alice.firestore().collection('community_memberships').doc('concurrent::alice');
  const attempts = await Promise.allSettled(
    Array.from({ length: 8 }, () => membership.set({
      communityId: 'concurrent',
      userId: 'alice',
      role: 'member',
      status: 'active',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    })),
  );
  let stored;
  await testEnv.withSecurityRulesDisabled(async (context) => {
    stored = await context.firestore().collection('community_memberships').doc('concurrent::alice').get();
  });

  assert.equal(attempts.filter((attempt) => attempt.status === 'fulfilled').length, 1);
  assert.equal(attempts.filter((attempt) => attempt.status === 'rejected').length, 7);
  assert.equal(stored.data().communityId, 'concurrent');
  assert.equal(stored.data().userId, 'alice');
  assert.equal(stored.data().role, 'member');
  assert.equal(stored.data().status, 'active');
});
