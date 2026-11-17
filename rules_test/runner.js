const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { serverTimestamp } = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

async function run() {
  console.log('\n======================================================');
  console.log('   CSC 4360 HW02 - FIRESTORE SECURITY RULES TEST SUITE');
  console.log('   Spice #2: Automated Rules Unit Testing');
  console.log('======================================================\n');

  const rulesPath = path.resolve(__dirname, '../firestore.rules');
  const testEnv = await initializeTestEnvironment({
    projectId: 'cw-02-rules-test',
    firestore: {
      rules: fs.readFileSync(rulesPath, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });

  let passed = 0;
  let total = 0;

  async function test(name, fn) {
    total++;
    await testEnv.clearFirestore();
    try {
      await fn();
      console.log(`  ✔ [PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`  ✖ [FAIL] ${name}`);
      console.error(err);
    }
  }

  try {
    await test('1. Signed-out read is DENIED by security rules', async () => {
      const unauthed = testEnv.unauthenticatedContext();
      const db = unauthed.firestore();
      await assertFails(db.collection('messages').get());
    });

    await test('2. Correct-author CRUD cycle is ALLOWED', async () => {
      const alice = testEnv.authenticatedContext('alice_uid');
      const db = alice.firestore();

      // CREATE
      const msgRef = db.collection('messages').doc('msg_alice_1');
      await assertSucceeds(
        msgRef.set({
          text: 'Hello from Alice!',
          authorUid: 'alice_uid',
          authorName: 'Alice',
          createdAt: serverTimestamp(),
        })
      );

      // READ
      await assertSucceeds(db.collection('messages').get());

      // UPDATE (own message)
      await assertSucceeds(
        msgRef.update({
          text: 'Updated message by Alice',
          editedAt: serverTimestamp(),
        })
      );

      // DELETE (own message)
      await assertSucceeds(msgRef.delete());
    });

    await test('3. Cross-UID update and delete are DENIED', async () => {
      // Pre-seed a message by Alice using admin context
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await adminDb.collection('messages').doc('msg_alice_shared').set({
          text: 'Alice original message',
          authorUid: 'alice_uid',
          authorName: 'Alice',
          createdAt: serverTimestamp(),
        });
      });

      // Bob attempts to update Alice's message
      const bob = testEnv.authenticatedContext('bob_uid');
      const bobDb = bob.firestore();
      const aliceMsgRef = bobDb.collection('messages').doc('msg_alice_shared');

      await assertFails(
        aliceMsgRef.update({
          text: 'Hacked by Bob!',
          editedAt: serverTimestamp(),
        })
      );

      // Bob attempts to delete Alice's message
      await assertFails(aliceMsgRef.delete());
    });

    await test('4. Forged authorUid create is DENIED', async () => {
      // Bob tries to impersonate Alice
      const bob = testEnv.authenticatedContext('bob_uid');
      const bobDb = bob.firestore();

      await assertFails(
        bobDb.collection('messages').add({
          text: 'I am pretending to be Alice',
          authorUid: 'alice_uid', // forged authorUid
          authorName: 'Bob In Disguise',
          createdAt: serverTimestamp(),
        })
      );
    });

    await test('5. User private profile isolation (users/{uid})', async () => {
      const alice = testEnv.authenticatedContext('alice_uid');
      const bob = testEnv.authenticatedContext('bob_uid');

      // Alice can write and read her own profile
      await assertSucceeds(
        alice.firestore().collection('users').doc('alice_uid').set({
          uid: 'alice_uid',
          firstName: 'Alice',
          lastName: 'Smith',
          role: 'Student',
          registrationDateTime: serverTimestamp(),
        })
      );

      await assertSucceeds(
        alice.firestore().collection('users').doc('alice_uid').get()
      );

      // Bob CANNOT read or write Alice profile
      await assertFails(
        bob.firestore().collection('users').doc('alice_uid').get()
      );

      await assertFails(
        bob.firestore().collection('users').doc('alice_uid').set({
          uid: 'alice_uid',
          firstName: 'Hacked',
          lastName: 'Hacked',
          role: 'Imposter',
          registrationDateTime: serverTimestamp(),
        })
      );
    });

    console.log(`\nResults: ${passed}/${total} tests passed.\n`);
    if (passed !== total) {
      process.exitCode = 1;
    }
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((err) => {
  console.error('Fatal test runner error:', err);
  process.exit(1);
});
