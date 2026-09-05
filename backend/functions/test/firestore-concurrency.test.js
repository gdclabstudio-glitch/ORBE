const test = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'demo-labomba-concurrency' });
const db = admin.firestore();

const reports = db.collection('community_reports');
const appeals = db.collection('community_moderation_appeals');
const contents = db.collection('community_contents');
const actions = db.collection('community_moderation_actions');

function simultaneousTransactions(callbacks) {
  let arrived = 0;
  let release;
  const released = new Promise((resolve) => {
    release = resolve;
  });
  const barrier = async () => {
    arrived += 1;
    if (arrived === callbacks.length) release();
    await released;
  };
  return Promise.allSettled(callbacks.map((callback) => callback(barrier)));
}

async function reportResolution(reportId, reviewerId, barrier) {
  return db.runTransaction(async (transaction) => {
    const reportRef = reports.doc(reportId);
    const snapshot = await transaction.get(reportRef);
    assert.equal(snapshot.data().status, 'open');
    await barrier();
    const actionRef = actions.doc();
    transaction.update(reportRef, {
      status: 'resolved',
      reviewedBy: reviewerId,
      resolution: 'noAction',
    });
    transaction.create(actionRef, {
      actionId: actionRef.id,
      communityId: 'science',
      actorId: reviewerId,
      actionType: 'reportResolved',
      targetType: 'content',
      targetId: 'content-report',
      reportId,
      reason: 'Concurrent resolution',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

async function appealResolution(appealId, reviewerId, resolution, barrier) {
  return db.runTransaction(async (transaction) => {
    const appealRef = appeals.doc(appealId);
    const appealSnapshot = await transaction.get(appealRef);
    assert.equal(appealSnapshot.data().status, 'underReview');
    const contentRef = contents.doc('content-appeal');
    const contentSnapshot = await transaction.get(contentRef);
    await barrier();

    const appealActionRef = actions.doc();
    const appealAction = {
      actionId: appealActionRef.id,
      communityId: 'science',
      actorId: reviewerId,
      actionType: 'appealResolved',
      targetType: 'content',
      targetId: 'content-appeal',
      appealId,
      reason: resolution,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (resolution === 'overturn') {
      const previousLifecycle = contentSnapshot.data().lifecycle;
      transaction.update(contentRef, { lifecycle: 'active' });
      const lifecycleActionRef = actions.doc();
      transaction.create(lifecycleActionRef, {
        actionId: lifecycleActionRef.id,
        communityId: 'science',
        actorId: reviewerId,
        actionType: 'lifecycleChanged',
        targetType: 'content',
        targetId: 'content-appeal',
        appealId,
        previousLifecycle,
        newLifecycle: 'active',
        reason: 'overturn',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    transaction.update(appealRef, {
      status: resolution === 'uphold' ? 'rejected' : 'accepted',
      resolution,
      reviewedBy: reviewerId,
    });
    transaction.create(appealActionRef, appealAction);
  });
}

async function lifecycleChange(contentId, reviewerId, newLifecycle, barrier) {
  return db.runTransaction(async (transaction) => {
    const contentRef = contents.doc(contentId);
    const snapshot = await transaction.get(contentRef);
    assert.equal(snapshot.data().lifecycle, 'active');
    await barrier();
    const actionRef = actions.doc();
    transaction.update(contentRef, {
      lifecycle: newLifecycle,
      lifecycleUpdatedBy: reviewerId,
    });
    transaction.create(actionRef, {
      actionId: actionRef.id,
      communityId: 'science',
      actorId: reviewerId,
      actionType: 'lifecycleChanged',
      targetType: 'content',
      targetId: contentId,
      previousLifecycle: 'active',
      newLifecycle,
      reason: 'Concurrent lifecycle transition',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

async function actionSnapshot(field, value) {
  return actions.where(field, '==', value).get();
}

test.beforeEach(async () => {
  await Promise.all([
    db.collection('community_reports').listDocuments().then((refs) =>
      Promise.all(refs.map((ref) => ref.delete()))),
    db.collection('community_moderation_appeals').listDocuments().then((refs) =>
      Promise.all(refs.map((ref) => ref.delete()))),
    db.collection('community_contents').listDocuments().then((refs) =>
      Promise.all(refs.map((ref) => ref.delete()))),
    db.collection('community_moderation_actions').listDocuments().then((refs) =>
      Promise.all(refs.map((ref) => ref.delete()))),
  ]);
});

test('report resolution has one winner and one reportResolved action', async () => {
  await reports.doc('report-concurrent').set({
    reportId: 'report-concurrent',
    communityId: 'science',
    status: 'open',
  });

  const results = await simultaneousTransactions([
    (barrier) => reportResolution('report-concurrent', 'moderator-a', barrier),
    (barrier) => reportResolution('report-concurrent', 'moderator-b', barrier),
  ]);

  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(results.filter((result) => result.status === 'rejected').length, 1);
  assert.equal(
    (await actionSnapshot('reportId', 'report-concurrent')).docs
      .filter((doc) => doc.data().actionType === 'reportResolved').length,
    1,
  );
  assert.equal((await reports.doc('report-concurrent').get()).data().status, 'resolved');
});

test('appeal resolution has one winner and atomic lifecycle coordination', async () => {
  await appeals.doc('appeal-concurrent').set({
    appealId: 'appeal-concurrent',
    communityId: 'science',
    targetType: 'content',
    targetId: 'content-appeal',
    createdBy: 'author',
    status: 'underReview',
  });
  await contents.doc('content-appeal').set({
    contentId: 'content-appeal',
    communityId: 'science',
    lifecycle: 'restricted',
  });

  const results = await simultaneousTransactions([
    (barrier) => appealResolution('appeal-concurrent', 'reviewer-a', 'uphold', barrier),
    (barrier) => appealResolution('appeal-concurrent', 'reviewer-b', 'overturn', barrier),
  ]);

  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(results.filter((result) => result.status === 'rejected').length, 1);
  assert.equal(
    (await actionSnapshot('appealId', 'appeal-concurrent')).docs
      .filter((doc) => doc.data().actionType === 'appealResolved').length,
    1,
  );
  const appeal = (await appeals.doc('appeal-concurrent').get()).data();
  assert.ok(['accepted', 'rejected'].includes(appeal.status));
  if (appeal.resolution === 'overturn') {
    assert.equal((await contents.doc('content-appeal').get()).data().lifecycle, 'active');
    assert.equal(
      (await actionSnapshot('appealId', 'appeal-concurrent')).docs
        .filter((doc) => doc.data().actionType === 'lifecycleChanged').length,
      1,
    );
  } else {
    assert.equal((await contents.doc('content-appeal').get()).data().lifecycle, 'restricted');
  }
});

test('lifecycle expected-state contention has one transition and one history entry', async () => {
  await contents.doc('content-lifecycle').set({
    contentId: 'content-lifecycle',
    communityId: 'science',
    lifecycle: 'active',
  });

  const results = await simultaneousTransactions([
    (barrier) => lifecycleChange('content-lifecycle', 'staff-a', 'restricted', barrier),
    (barrier) => lifecycleChange('content-lifecycle', 'staff-b', 'underReview', barrier),
  ]);

  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(results.filter((result) => result.status === 'rejected').length, 1);
  const history = (await actionSnapshot('targetId', 'content-lifecycle')).docs;
  assert.equal(history.filter((doc) => doc.data().actionType === 'lifecycleChanged').length, 1);
  const finalLifecycle = (await contents.doc('content-lifecycle').get()).data().lifecycle;
  assert.ok(['restricted', 'underReview'].includes(finalLifecycle));
  assert.equal(history[0].data().newLifecycle, finalLifecycle);
});

test('failed transactions leave no partial report, appeal creation, or appeal resolution', async () => {
  await reports.doc('report-failure').set({
    reportId: 'report-failure',
    communityId: 'science',
    status: 'open',
  });
  await db.runTransaction(async (transaction) => {
    const reportRef = reports.doc('report-failure');
    const snapshot = await transaction.get(reportRef);
    assert.equal(snapshot.data().status, 'open');
    throw new Error('validation failure before commit');
  }).catch(() => {});
  assert.equal((await reports.doc('report-failure').get()).data().status, 'open');
  assert.equal((await actionSnapshot('reportId', 'report-failure')).docs.length, 0);

  await appeals.doc('appeal-failure').set({
    appealId: 'appeal-failure',
    communityId: 'science',
    targetType: 'content',
    targetId: 'content-failure',
    createdBy: 'author',
    status: 'underReview',
  });
  await actions.doc('appeal-created-failure').set({
    actionId: 'appeal-created-failure',
    appealId: 'appeal-failure',
    actionType: 'appealCreated',
  });
  await db.runTransaction(async (transaction) => {
    const appealRef = appeals.doc('appeal-failure');
    if ((await transaction.get(appealRef)).exists) {
      throw new Error('duplicate appeal');
    }
  }).catch(() => {});
  assert.equal((await actionSnapshot('appealId', 'appeal-failure')).docs.length, 1);

  await db.runTransaction(async (transaction) => {
    const appealRef = appeals.doc('appeal-failure');
    const snapshot = await transaction.get(appealRef);
    assert.equal(snapshot.data().status, 'underReview');
    const actionRef = actions.doc();
    transaction.update(appealRef, { status: 'accepted' });
    transaction.create(actionRef, { appealId: 'appeal-failure', actionType: 'appealResolved' });
    throw new Error('lifecycle validation failure before commit');
  }).catch(() => {});
  assert.equal((await appeals.doc('appeal-failure').get()).data().status, 'underReview');
  assert.equal(
    (await actionSnapshot('appealId', 'appeal-failure')).docs
      .filter((doc) => doc.data().actionType === 'appealResolved').length,
    0,
  );
});
