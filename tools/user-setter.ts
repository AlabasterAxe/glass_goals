
import * as admin from 'firebase-admin';


async function doIt() {

    await admin.auth().setCustomUserClaims(uid, { deviceId })
}