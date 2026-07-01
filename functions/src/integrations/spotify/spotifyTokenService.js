const axios = require("axios");
const admin = require("firebase-admin");

const TOKEN_ENDPOINT = "https://accounts.spotify.com/api/token";
const INTEGRATION_COLLECTION = "user_integrations";

function _docRef(uid) {
  return admin.firestore().collection(INTEGRATION_COLLECTION).doc(uid);
}

/**
 * Stores Spotify OAuth tokens in Firestore for the given user.
 * @param {string} uid
 * @param {Object} tokens
 * @param {string} tokens.accessToken
 * @param {string} tokens.refreshToken
 * @param {number} tokens.expiresInSeconds
 * @param {string} [tokens.scope]
 * @return {Promise<void>}
 */
async function storeSpotifyTokens(uid, {accessToken, refreshToken, expiresInSeconds, scope}) {
  const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + (expiresInSeconds - 60) * 1000),
  );

  await _docRef(uid).set(
      {
        spotify: {
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
 * Removes stored Spotify tokens for the given user.
 * @param {string} uid
 * @return {Promise<void>}
 */
async function clearSpotifyTokens(uid) {
  await _docRef(uid).set(
      {spotify: {connected: false, accessToken: null, refreshToken: null}},
      {merge: true},
  );
}

/**
 * Returns a valid Spotify access token, refreshing it if expired.
 * @param {string} uid
 * @return {Promise<string>}
 */
async function getValidSpotifyAccessToken(uid) {
  const doc = await _docRef(uid).get();
  if (!doc.exists) throw new Error("Spotify no conectado para este usuario.");

  const data = doc.data();
  const spotifyData = data && data.spotify;
  if (!spotifyData || !spotifyData.connected || !spotifyData.refreshToken) {
    throw new Error("Spotify no conectado para este usuario.");
  }

  const now = admin.firestore.Timestamp.now();
  const isExpired = !spotifyData.expiresAt || spotifyData.expiresAt.seconds <= now.seconds;

  if (!isExpired && spotifyData.accessToken) {
    return spotifyData.accessToken;
  }

  const clientId = process.env.SPOTIFY_CLIENT_ID;
  const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;
  const b64 = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");

  const response = await axios.post(
      TOKEN_ENDPOINT,
      new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token: spotifyData.refreshToken,
      }),
      {headers: {Authorization: `Basic ${b64}`, "Content-Type": "application/x-www-form-urlencoded"}},
  );

  const {access_token: accessToken, expires_in: expiresIn, refresh_token: newRefreshToken} = response.data;

  await storeSpotifyTokens(uid, {
    accessToken,
    refreshToken: newRefreshToken || spotifyData.refreshToken,
    expiresInSeconds: expiresIn || 3600,
  });

  return accessToken;
}

/**
 * Returns true if the user has Spotify connected.
 * @param {string} uid
 * @return {Promise<boolean>}
 */
async function isSpotifyConnected(uid) {
  try {
    const doc = await _docRef(uid).get();
    if (!doc.exists) return false;
    const data = doc.data();
    return Boolean(data && data.spotify && data.spotify.connected && data.spotify.refreshToken);
  } catch (_) {
    return false;
  }
}

module.exports = {
  storeSpotifyTokens,
  clearSpotifyTokens,
  getValidSpotifyAccessToken,
  isSpotifyConnected,
};
