const axios = require("axios");
const admin = require("firebase-admin");
const {getYouTubeConfig} = require("../../../config/youtubeConfig");

const db = admin.firestore();

async function exchangeCodeForTokens({code}) {
  const {clientId, clientSecret} = getYouTubeConfig();

  const payloadObject = {
    code,
    client_id: clientId,
    client_secret: clientSecret,
    grant_type: "authorization_code",
  };


  const payload = new URLSearchParams(payloadObject).toString();

  const response = await axios.post(
    "https://oauth2.googleapis.com/token",
    payload,
    {
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      timeout: 10000,
    },
  );

  return response.data;
}

async function refreshYouTubeTokens({refreshToken}) {
  const {clientId, clientSecret} = getYouTubeConfig();

  const payload = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
    grant_type: "refresh_token",
  }).toString();

  const response = await axios.post(
    "https://oauth2.googleapis.com/token",
    payload,
    {
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      timeout: 10000,
    },
  );

  return response.data;
}

async function saveYouTubeSecrets({uid, accessToken, refreshToken, expiresIn}) {
  const expiresAt = Date.now() + (expiresIn * 1000);

  await db.collection("integration_secrets").doc(uid).set(
    {
      youtube: {
        accessToken,
        refreshToken,
        expiresAt,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    },
    {merge: true},
  );

  await db.collection("user_integrations").doc(uid).set(
    {
      youtube: {
        status: "connected",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    },
    {merge: true},
  );
}

async function markYouTubeExpired(uid) {
  await db.collection("user_integrations").doc(uid).set(
    {
      youtube: {
        status: "expired",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    },
    {merge: true},
  );
}

async function getValidYouTubeAccessToken(uid) {
  const secretDoc = await db.collection("integration_secrets").doc(uid).get();
  const youtube = secretDoc.exists ? secretDoc.data().youtube : null;

  if (!youtube || !youtube.refreshToken) {
    const error = new Error("YOUTUBE_NOT_LINKED");
    error.code = "YOUTUBE_NOT_LINKED";
    throw error;
  }

  const now = Date.now();
  const expiresAt = youtube.expiresAt || 0;
  const hasValidAccessToken = youtube.accessToken && expiresAt > now + 60000;

  if (hasValidAccessToken) {
    return youtube.accessToken;
  }

  try {
    const refreshed = await refreshYouTubeTokens({
      refreshToken: youtube.refreshToken,
    });

    const newAccessToken = refreshed.access_token;
    const nextRefreshToken = refreshed.refresh_token || youtube.refreshToken;
    const expiresIn = refreshed.expires_in || 3600;

    await saveYouTubeSecrets({
      uid,
      accessToken: newAccessToken,
      refreshToken: nextRefreshToken,
      expiresIn,
    });

    return newAccessToken;
  } catch (error) {
    await markYouTubeExpired(uid);
    const authError = new Error("YOUTUBE_AUTH_EXPIRED");
    authError.code = "YOUTUBE_AUTH_EXPIRED";
    throw authError;
  }
}

module.exports = {
  exchangeCodeForTokens,
  getValidYouTubeAccessToken,
  refreshYouTubeTokens,
  saveYouTubeSecrets,
  markYouTubeExpired,
};
