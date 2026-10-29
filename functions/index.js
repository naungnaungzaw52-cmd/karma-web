const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.onUserDelete = functions.auth.user().onDelete(async (user) => {
    const uid = user.uid;
    const db = admin.firestore();

    // ၁။ User ရဲ့ Post တွေကို ဖျက်ခြင်း
    const posts = await db.collection('posts').where('uid', '==', uid).get();
    const batch = db.batch();
    posts.docs.forEach((doc) => batch.delete(doc.ref));

    // ၂။ Notification တွေကို ဖျက်ခြင်း
    const notis = await db.collection('notifications').where('receiverId', '==', uid).get();
    notis.docs.forEach((doc) => batch.delete(doc.ref));

    // ၃။ Users Collection ထဲက Data ဖျက်ခြင်း
    batch.delete(db.collection('users').doc(uid));

    await batch.commit();
});