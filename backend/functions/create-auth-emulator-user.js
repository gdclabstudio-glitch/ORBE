const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9091';

initializeApp({ projectId: 'labomba-b202a' });

const email = 'test@labomba.com';
const password = 'password123';

(async () => {
  try {
    const user = await getAuth().createUser({
      email,
      emailVerified: true,
      password,
      displayName: 'Test User',
      disabled: false,
    });

    console.log('USER_CREATED');
    console.log(JSON.stringify({
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      password,
      projectId: 'labomba-b202a',
      emulatorHost: '127.0.0.1:9091',
    }, null, 2));
  } catch (error) {
    if (error && error.code === 'auth/email-already-exists') {
      console.log('USER_ALREADY_EXISTS');
      console.log(JSON.stringify({
        email,
        password,
        projectId: 'labomba-b202a',
        emulatorHost: '127.0.0.1:9091',
      }, null, 2));
      return;
    }

    console.error('ERROR_CREATING_USER');
    console.error(error && error.stack ? error.stack : error);
    process.exitCode = 1;
  }
})();
