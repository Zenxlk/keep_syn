const axios = require("axios");
const admin = require("firebase-admin");

const TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token";
const INTEGRATION_COLLECTION = "user_integrations";

function _docRef(uid) {
  return admin.firestore().collection(INTEGRATION_COLLECTION).doc(uid);
}

/**
 * Stores YouTube OAuth tokens in Firestore for the given user.
 * @param {string} uid
 * @param {Object} tokens
 * @param {string} tokens.accessToken
 * @param {string} tokens.refreshToken
 * @param {number} tokens.expiresInSeconds
 * @param {string} [tokens.scope]
 * @return {Promise<void>}
 */
async function storeYouTubeTokens(uid, {accessToken, refreshToken, expiresInSeconds, scope}) {
  const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + (expiresInSeconds - 60) * 1000),
  );

  await _docRef(uid).set(
      {
        youtube: {
          accessToken,
          refreshToken,
          expiresAt,
          scope: scope || "",
          connected: true,
        },
      },
      {merge: true},
  );
}

/**
 * Removes stored YouTube tokens for the given user.
 * @param {string} uid
 * @return {Promise<void>}
 */
async function clearYouTubeTokens(uid) {
  await _docRef(uid).set(
      {youtube: {connected: false, accessToken: null, refreshToken: null}},
      {merge: true},
  );
}

/**
 * Returns a valid YouTube access token, refreshing it if expired.
 * @param {string} uid
 * @return {Promise<string>}
 */
async function getValidYouTubeAccessToken(uid) {
  const doc = await _docRef(uid).get();
  if (!doc.exists) throw new Error("YouTube no conectado para este usuario.");

  const data = doc.data();
  const ytData = data && data.youtube;
  if (!ytData || !ytData.connected || !ytData.refreshToken) {
    throw new Error("YouTube no conectado para este usuario.");
  }

  const now = admin.firestore.Timestamp.now();
  const isExpired = !ytData.expiresAt || ytData.expiresAt.seconds <= now.seconds;

  if (!isExpired && ytData.accessToken) {
    return ytData.accessToken;
  }

  const response = await axios.post(TOKEN_ENDPOINT, null, {
    params: {
      grant_type: "refresh_token",
      refresh_token: ytData.refreshToken,
      client_id: process.env.YOUTUBE_CLIENT_ID,
      client_secret: process.env.YOUTUBE_CLIENT_SECRET,
    },
  });

  const {access_token: accessToken, expires_in: expiresIn} = response.data;

  await storeYouTubeTokens(uid, {
    accessToken,
    refreshToken: ytData.refreshToken,
    expiresInSeconds: expiresIn || 3600,
  });

  return accessToken;
}

/**
 * Returns true if the user has YouTube connected.
 * @param {string} uid
 * @return {Promise<boolean>}
 */
async function isYouTubeConnected(uid) {
  try {
    const doc = await _docRef(uid).get();
    if (!doc.exists) return false;
    const data = doc.data();
    return Boolean(data && data.youtube && data.youtube.connected && data.youtube.refreshToken);
  } catch (_) {
    return false;
  }
}

module.exports = {
  storeYouTubeTokens,
  clearYouTubeTokens,
  getValidYouTubeAccessToken,
  isYouTubeConnected,
};
