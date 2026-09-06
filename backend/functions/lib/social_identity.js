"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SOCIAL_IDENTITY_VERSION = void 0;
exports.connectionIdentity = connectionIdentity;
exports.directionalIdentity = directionalIdentity;
exports.assertExpectedIdentity = assertExpectedIdentity;
const node_crypto_1 = require("node:crypto");
exports.SOCIAL_IDENTITY_VERSION = 'v1';
function validateUid(uid, field) {
    if (typeof uid !== 'string' || uid.length === 0 || uid.trim() !== uid) {
        throw new Error(`${field} must be a non-empty Firebase Auth UID`);
    }
    if (Array.from(uid).length > 128) {
        throw new Error(`${field} exceeds the Firebase Auth UID limit`);
    }
}
function canonicalId(purpose, participants) {
    participants.forEach((uid, index) => validateUid(uid, `participant${index}`));
    const tuple = JSON.stringify([exports.SOCIAL_IDENTITY_VERSION, purpose, ...participants]);
    return (0, node_crypto_1.createHash)('sha256').update(tuple, 'utf8').digest('hex');
}
function connectionIdentity(firstUid, secondUid) {
    validateUid(firstUid, 'firstUid');
    validateUid(secondUid, 'secondUid');
    if (firstUid === secondUid)
        throw new Error('Connection participants must differ');
    return canonicalId('connection', [firstUid, secondUid].sort());
}
function directionalIdentity(purpose, fromUid, toUid) {
    validateUid(fromUid, 'fromUid');
    validateUid(toUid, 'toUid');
    if (fromUid === toUid)
        throw new Error('Directional participants must differ');
    return canonicalId(purpose, [fromUid, toUid]);
}
function assertExpectedIdentity(expectedId, actualId) {
    if (expectedId !== undefined && expectedId !== actualId) {
        throw new Error('The supplied document ID does not match the canonical identity');
    }
}
//# sourceMappingURL=social_identity.js.map