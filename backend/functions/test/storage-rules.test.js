const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const firestoreRulesPath = path.resolve(__dirname, '..', '..', '..', 'firestore.rules');
const storageRulesPath = path.resolve(__dirname, '..', '..', '..', 'storage.rules');
const projectId = 'demo-labomba-storage-rules';

let testEnv;

const chatData = (field) => ({
  [field]: ['alice', 'bob'],
  createdAt: new Date(),
});

const mediaMetadata = (ownerUid) => ({
  contentType: 'image/png',
  customMetadata: { ownerUid },
});

const upload = (context, chatId, ownerUid) =>
  context.storage().ref(`chats/${chatId}/photo.png`)
    .putString('chat-media', 'raw', mediaMetadata(ownerUid));

const readMetadata = (context, chatId) =>
  context.storage().ref(`chats/${chatId}/photo.png`).getMetadata();

test.before(async () => {
  admin.initializeApp({ projectId });
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(firestoreRulesPath, 'utf8'),
    },
    storage: {
      rules: fs.readFileSync(storageRulesPath, 'utf8'),
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
  await testEnv.clearStorage();
});

test('chat Storage authorization uses participants and rejects members-only bypasses', async () => {
  const alice = testEnv.authenticatedContext('alice');
  const bob = testEnv.authenticatedContext('bob');
  const outsider = testEnv.authenticatedContext('outsider');
  const anonymous = testEnv.unauthenticatedContext();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('chats').doc('chatCanonical').set(chatData('participants'));
    await context.firestore().collection('chats').doc('chatLegacy').set(chatData('members'));
    await context.storage().ref('chats/chatCanonical/photo.png')
      .putString('canonical-media', 'raw', mediaMetadata('alice'));
    await context.storage().ref('chats/chatLegacy/photo.png')
      .putString('legacy-media', 'raw', mediaMetadata('alice'));
  });

  await assertSucceeds(upload(alice, 'chatCanonical', 'alice'));
  await assertSucceeds(upload(bob, 'chatCanonical', 'bob'));
  await assertFails(upload(outsider, 'chatCanonical', 'outsider'));
  await assertFails(upload(anonymous, 'chatCanonical', 'anonymous'));
  await assertFails(upload(alice, 'chatLegacy', 'alice'));

  await assertSucceeds(readMetadata(alice, 'chatCanonical'));
  await assertSucceeds(readMetadata(bob, 'chatCanonical'));
  await assertFails(readMetadata(outsider, 'chatCanonical'));
  await assertFails(readMetadata(anonymous, 'chatCanonical'));
  await assertFails(readMetadata(alice, 'chatLegacy'));
});
