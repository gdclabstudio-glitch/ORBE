const test = require('node:test');
const assert = require('node:assert/strict');
const { validateAdminActionPayload, normalizeRoleName } = require('../lib/index.js');

test('valid admin action payload is accepted', () => {
  const result = validateAdminActionPayload({
    type: 'delete_post',
    resourceType: 'post',
    resourceId: 'post_123',
    reason: 'Remoção por abuso',
    details: { source: 'control_center' },
  });

  assert.equal(result.ok, true);
  assert.equal(result.action, 'delete_post');
  assert.equal(result.resourceType, 'post');
  assert.equal(result.resourceId, 'post_123');
});

test('unsupported action is rejected before backend execution', () => {
  const result = validateAdminActionPayload({
    type: 'drop_database',
    resourceType: 'post',
    resourceId: 'post_123',
  });

  assert.equal(result.ok, false);
  assert.match(result.error, /Unsupported admin action/);
});

test('invalid resourceId and oversized details are rejected', () => {
  const badId = validateAdminActionPayload({
    type: 'ban_user',
    resourceType: 'user',
    resourceId: 'bad/../id',
  });

  const oversized = validateAdminActionPayload({
    type: 'mass_fcm',
    resourceType: 'broadcast',
    resourceId: 'broadcast_01',
    details: { payload: 'x'.repeat(20000) },
  });

  assert.equal(badId.ok, false);
  assert.match(badId.error, /valid resourceId/i);
  assert.equal(oversized.ok, false);
  assert.match(oversized.error, /too large/i);
});

test('role normalization blocks unsupported values', () => {
  assert.equal(normalizeRoleName('OWNER'), 'owner');
  assert.equal(normalizeRoleName('superadmin'), 'user');
  assert.equal(normalizeRoleName('admin'), 'admin');
});
