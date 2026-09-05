La Bomba — Cloud Functions (stubs) and deployment notes

This folder contains TypeScript Cloud Functions stubs used by the La Bomba app for
notifications and background processing. The functions are lightweight and intended
as a starting point — they must be reviewed and extended before production use.

Prerequisites
- Node.js 18.x (recommended)
- npm
- Firebase CLI (install: npm install -g firebase-tools) and authenticated (firebase login)
- A Firebase project configured (firebase use <projectId> or firebase use --add)
- Service account / credentials for server-side admin SDK when running locally (optional for emulator)

Install & build
1. cd backend/functions
2. npm ci
3. npm run build

Local testing with emulator
- The Firebase emulator can run Firestore and Functions together for local integration tests.
  1. Install emulator: part of firebase-tools
  2. Start emulator: firebase emulators:start --only firestore,functions
  3. Deploy functions locally (auto-built by emulator) and exercise triggers via the emulator UI or via test scripts.

Deploy to Firebase
1. Ensure you are targeting the correct project: firebase use <projectId>
2. Build TypeScript: npm run build
3. Deploy functions: firebase deploy --only functions

Important notes about FCM and credentials
- The admin.messaging().sendToDevice() call requires the Admin SDK (service account) to be able
to send FCM messages. When deploying to Cloud Functions in Firebase, the functions run with
sufficient privileges. When running locally you must either point to a service account JSON via
GOOGLE_APPLICATION_CREDENTIALS or use the emulator (emulator does NOT emulate FCM sending).
- The functions look for device tokens in Firestore under the user document. Current check accepts
  either 'fcmToken' (camelCase), 'fcm_token' (snake_case) or the first token from 'fcmTokens' array.
  Ensure your client writes the token to the user document when the app obtains it.

Client: persist FCM token example (Flutter)
Add this after obtaining the token in PushNotificationService.init():

```dart
final uid = FirebaseAuth.instance.currentUser?.uid;
if (uid != null && token != null) {
  await FirebaseFirestore.instance.collection('users').doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
}
```

Security considerations
- The functions currently send notifications directly to tokens read from user documents. For
production, consider storing tokens per-device (e.g. users/{uid}/fcmTokens/{deviceId}) and
support multiple tokens per user.
- Protect sensitive fields in Firestore with safety rules — this repo includes firestore.rules with
examples that restrict writes for `vip` and `stats` fields and only allow the admin SDK to write
notifications.
- The functions assume `members` array exists on group documents for group notifications.

Custom claims for Admins
- The security rules reference request.auth.token.admin to allow admin-only operations. To set
custom claims for a user, run a small admin script (server-side) or use the Firebase Admin SDK:

```js
// run with node and admin SDK configured
admin.auth().setCustomUserClaims(uid, { admin: true });
```

Testing and QA
- Use the emulator and seed test users/docs in Firestore to simulate triggers.
- The emulator will not deliver FCM messages — to verify payloads, use admin.messaging().sendToDevice
  but mock the admin.messaging() in unit tests, or log the payload to the emulator's console.

Checklist before production
- [ ] Review and harden Cloud Functions error handling and retries
- [ ] Add rate limiting / throttling for high-volume events
- [ ] Use per-device tokens and rotate tokens on sign-out
- [ ] Ensure billing is enabled if required (FCM + other services)
- [ ] Add monitoring/alerts for failed sends

If you want, I can:
- Add scripts to set admin custom claims from the functions folder
- Add an example client-side token writer in PushNotificationService
- Prepare a firebase.json snippet for emulator configuration and CI steps
