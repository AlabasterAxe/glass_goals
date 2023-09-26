

async function doIt() {

    await admin.auth().setCustomUserClaims(uid, { deviceId })
}