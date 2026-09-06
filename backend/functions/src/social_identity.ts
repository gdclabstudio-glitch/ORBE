import { createHash } from 'node:crypto';

export const SOCIAL_IDENTITY_VERSION = 'v1';

export type SocialIdentityPurpose =
  | 'connection'
  | 'connection_request'
  | 'conversation_request'
  | 'block';

function validateUid(uid: unknown, field: string): asserts uid is string {
  if (typeof uid !== 'string' || uid.length === 0 || uid.trim() !== uid) {
    throw new Error(`${field} must be a non-empty Firebase Auth UID`);
  }
  if (Array.from(uid).length > 128) {
    throw new Error(`${field} exceeds the Firebase Auth UID limit`);
  }
}

function canonicalId(
  purpose: SocialIdentityPurpose,
  participants: string[],
): string {
  participants.forEach((uid, index) => validateUid(uid, `participant${index}`));
  const tuple = JSON.stringify([SOCIAL_IDENTITY_VERSION, purpose, ...participants]);
  return createHash('sha256').update(tuple, 'utf8').digest('hex');
}

export function connectionIdentity(firstUid: string, secondUid: string): string {
  validateUid(firstUid, 'firstUid');
  validateUid(secondUid, 'secondUid');
  if (firstUid === secondUid) throw new Error('Connection participants must differ');
  return canonicalId(
    'connection',
    [firstUid, secondUid].sort(),
  );
}

export function directionalIdentity(
  purpose: Exclude<SocialIdentityPurpose, 'connection'>,
  fromUid: string,
  toUid: string,
): string {
  validateUid(fromUid, 'fromUid');
  validateUid(toUid, 'toUid');
  if (fromUid === toUid) throw new Error('Directional participants must differ');
  return canonicalId(purpose, [fromUid, toUid]);
}

export function assertExpectedIdentity(
  expectedId: unknown,
  actualId: string,
): void {
  if (expectedId !== undefined && expectedId !== actualId) {
    throw new Error('The supplied document ID does not match the canonical identity');
  }
}
