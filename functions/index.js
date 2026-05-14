const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

async function collectTokens(request) {
  const targetType = request.targetType || 'all';
  const targetUserId = request.targetUserId || null;
  const tokens = new Set();

  if (targetType === 'single' && targetUserId) {
    const userDoc = await db.collection('users').doc(targetUserId).get();
    const userData = userDoc.data() || {};

    if (typeof userData.fcmToken === 'string' && userData.fcmToken.trim()) {
      tokens.add(userData.fcmToken.trim());
    }

    if (Array.isArray(userData.fcmTokens)) {
      userData.fcmTokens.forEach((token) => {
        if (typeof token === 'string' && token.trim()) tokens.add(token.trim());
      });
    }

    const tokenSnapshot = await db
      .collection('users')
      .doc(targetUserId)
      .collection('fcmTokens')
      .get();

    tokenSnapshot.docs.forEach((doc) => {
      const token = doc.data().token || doc.id;
      if (typeof token === 'string' && token.trim()) tokens.add(token.trim());
    });

    return Array.from(tokens);
  }

  const globalTokens = await db.collection('fcmTokens').get();
  globalTokens.docs.forEach((doc) => {
    const token = doc.data().token || doc.id;
    if (typeof token === 'string' && token.trim()) tokens.add(token.trim());
  });

  return Array.from(tokens);
}

async function sendPushForQueueDoc(queueRef, request) {
  const status = request.status || 'pending';
  if (status === 'sent' || status === 'sending') return;

  const scheduledAt = request.scheduledAt;
  if (scheduledAt && scheduledAt.toDate && scheduledAt.toDate() > new Date()) return;

  await queueRef.set({ status: 'sending', startedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

  const tokens = await collectTokens(request);
  if (tokens.length === 0) {
    await queueRef.set({
      status: 'no_tokens',
      finishedAt: admin.firestore.FieldValue.serverTimestamp(),
      successCount: 0,
      failureCount: 0,
    }, { merge: true });
    return;
  }

  let successCount = 0;
  let failureCount = 0;
  const invalidTokens = [];

  for (let i = 0; i < tokens.length; i += 500) {
    const chunk = tokens.slice(i, i + 500);
    const response = await admin.messaging().sendEachForMulticast({
      tokens: chunk,
      notification: {
        title: request.title || 'Daily Kharcha',
        body: request.body || 'New notification received',
      },
      data: Object.fromEntries(
        Object.entries({
          notificationId: request.notificationId || '',
          type: request.type || 'admin_notification',
          screen: 'notifications',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          ...(request.data || {}),
        }).map(([key, value]) => [key, String(value ?? '')]),
      ),
      android: {
        priority: 'high',
        notification: {
          channelId: 'daily_kharcha_admin_alerts',
          sound: 'default',
          priority: 'max',
          visibility: 'public',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    });

    successCount += response.successCount;
    failureCount += response.failureCount;

    response.responses.forEach((result, index) => {
      const code = result.error && result.error.code;
      if (
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/registration-token-not-registered'
      ) {
        invalidTokens.push(chunk[index]);
      }
    });
  }

  await queueRef.set({
    status: failureCount > 0 && successCount === 0 ? 'failed' : 'sent',
    finishedAt: admin.firestore.FieldValue.serverTimestamp(),
    successCount,
    failureCount,
    invalidTokenCount: invalidTokens.length,
  }, { merge: true });

  if (request.notificationId) {
    await db.collection('notifications').doc(request.notificationId).set({
      pushStatus: failureCount > 0 && successCount === 0 ? 'failed' : 'sent',
      pushFinishedAt: admin.firestore.FieldValue.serverTimestamp(),
      pushSuccessCount: successCount,
      pushFailureCount: failureCount,
    }, { merge: true });
  }
}

exports.sendAdminNotificationPush = onDocumentCreated('notification_push_queue/{queueId}', async (event) => {
  const request = event.data.data();
  if (!request || request.status === 'scheduled') return;
  await sendPushForQueueDoc(event.data.ref, request);
});

exports.sendScheduledAdminNotificationPush = onSchedule('every 1 minutes', async () => {
  const now = admin.firestore.Timestamp.now();
  const snapshot = await db
    .collection('notification_push_queue')
    .where('status', '==', 'scheduled')
    .where('scheduledAt', '<=', now)
    .limit(25)
    .get();

  for (const doc of snapshot.docs) {
    await sendPushForQueueDoc(doc.ref, doc.data());
  }
});
