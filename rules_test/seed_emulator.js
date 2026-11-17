const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { serverTimestamp } = require('firebase/firestore');

async function seed() {
  const env = await initializeTestEnvironment({
    projectId: 'demo-emulator-board',
    firestore: { host: '127.0.0.1', port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('users').doc('user_ada').set({
      uid: 'user_ada',
      firstName: 'Ada',
      lastName: 'Lovelace',
      role: 'Student',
      registrationDateTime: serverTimestamp(),
    });
    await db.collection('messages').doc('msg_seed_1').set({
      text: 'First emulated message on local suite! Verified offline.',
      authorUid: 'user_ada',
      authorName: 'Ada Lovelace',
      createdAt: serverTimestamp(),
    });
    console.log('Successfully seeded emulated Firestore with test user and message.');
  });
  await env.cleanup();
}

seed().catch(console.error);
