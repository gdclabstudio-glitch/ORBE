const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {
  connectionIdentity,
  directionalIdentity,
  assertExpectedIdentity,
} = require('../lib/social_identity');

function expected(purpose, participants) {
  const tuple = JSON.stringify(['v1', purpose, ...participants]);
  return crypto.createHash('sha256').update(tuple, 'utf8').digest('hex');
}

test('canonical identities use versioned purpose tuples', () => {
  assert.equal(connectionIdentity('alice', 'bob'), expected('connection', ['alice', 'bob']));
  assert.equal(connectionIdentity('bob', 'alice'), connectionIdentity('alice', 'bob'));
  assert.notEqual(
    directionalIdentity('connection_request', 'alice', 'bob'),
    directionalIdentity('connection_request', 'bob', 'alice'),
  );
  assert.notEqual(
    directionalIdentity('conversation_request', 'alice', 'bob'),
    directionalIdentity('connection_request', 'alice', 'bob'),
  );
});

test('canonical identities support arbitrary UID characters', () => {
  for (const uid of ['a/b', 'a:b', 'a%b', 'a b', 'á世界']) {
    const id = directionalIdentity('block', uid, 'recipient');
    assert.match(id, /^[0-9a-f]{64}$/);
  }
});

test('canonical identities reject invalid or equal participants', () => {
  assert.throws(() => connectionIdentity('', 'bob'));
  assert.throws(() => connectionIdentity('alice', 'alice'));
  assert.throws(() => directionalIdentity('block', 'alice', 'alice'));
  assert.throws(() => directionalIdentity('block', 'a'.repeat(129), 'bob'));
});

test('client-supplied IDs cannot replace the canonical identity', () => {
  const id = directionalIdentity('block', 'alice', 'bob');
  assert.doesNotThrow(() => assertExpectedIdentity(id, id));
  assert.throws(() => assertExpectedIdentity('arbitrary', id));
});
