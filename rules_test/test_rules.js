const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');
const assert = require('assert');

let testEnv;

describe('Firestore Security Rules Unit Tests (Spice #2)', function () {
  this.timeout(10000);

  before(async () => {
    const rulesPath = path.resolve(__dirname, '../firestore.rules');
    testEnv = await initializeTestEnvironment({
      projectId: 'cw-02-rules-test',
      firestore: {
        rules: fs.readFileSync(rulesPath, 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    if (testEnv) {
      await testEnv.clearFirestore();
    }
  });

  it('1. Signed-out read is DENIED by security rules', async () => {
    const unauthed = testEnv.unauthenticatedContext();
    const db = unauthed.firestore();
    await assertFails(db.collection('messages').get());
  });

  it('2. Correct-author CRUD cycle is ALLOWED', async () => {
    const alice = testEnv.authenticatedContext('alice_uid');
    const db = alice.firestore();

    // CREATE
    const msgRef = db.collection('messages').doc('msg_alice_1');
    await assertSucceeds(
      msgRef.set({
        text: 'Hello from Alice!',
        authorUid: 'alice_uid',
        authorName: 'Alice',
        createdAt: new Date(),
      })
    );

    // READ
    await assertSucceeds(db.collection('messages').get());

    // UPDATE (own message)
    await assertSucceeds(
      msgRef.update({
        text: 'Updated message by Alice',
        editedAt: new Date(),
      })
    );

    // DELETE (own message)
    await assertSucceeds(msgRef.delete());
  });

  it('3. Cross-UID update and delete are DENIED', async () => {
    // Pre-seed a message by Alice using admin context
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('messages').doc('msg_alice_shared').set({
        text: 'Alice original message',
        authorUid: 'alice_uid',
        authorName: 'Alice',
        createdAt: new Date(),
      });
    });

    // Bob attempts to update Alice's message
    const bob = testEnv.authenticatedContext('bob_uid');
    const bobDb = bob.firestore();
    const aliceMsgRef = bobDb.collection('messages').doc('msg_alice_shared');

    await assertFails(
      aliceMsgRef.update({
        text: 'Hacked by Bob!',
        editedAt: new Date(),
      })
    );

    // Bob attempts to delete Alice's message
    await assertFails(aliceMsgRef.delete());
  });

  it('4. Forged authorUid create is DENIED', async () => {
    // Bob tries to impersonate Alice
    const bob = testEnv.authenticatedContext('bob_uid');
    const bobDb = bob.firestore();

    await assertFails(
      bobDb.collection('messages').add({
        text: 'I am pretending to be Alice',
        authorUid: 'alice_uid', // forged authorUid
        authorName: 'Bob In Disguise',
        createdAt: new Date(),
      })
    );
  });

  it('5. User private profile isolation (users/{uid})', async () => {
    const alice = testEnv.authenticatedContext('alice_uid');
    const bob = testEnv.authenticatedContext('bob_uid');

    // Alice can write and read her own profile
    await assertSucceeds(
      alice.firestore().collection('users').doc('alice_uid').set({
        uid: 'alice_uid',
        firstName: 'Alice',
        lastName: 'Smith',
        role: 'Student',
        registrationDateTime: new Date(),
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
        registrationDateTime: new Date(),
      })
    );
  });
});
