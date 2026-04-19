const axios = require("axios");
const admin = require("firebase-admin");
const {getSpotifyConfig} = require("../../../config/spotifyConfig");

const db = admin.firestore();

function createBasicAuthHeader(clientId, clientSecret) {
  const raw = `${clientId}:${clientSecret}`;
  return `Basic ${Buffer.from(raw).toString("base64")}`;
}

async function exchangeCodeForTokens({code, redirectUri}) {
  const {clientId, clientSecret} = getSpotifyConfig();

  const payload = new URLSearchParams({
    grant_type: "authorization_code",
    code,
    redirect_uri: redirectUri,
  }).toString();

  const response = await axios.post(
      "https://accounts.spotify.com/api/token",
      payload,
      {
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Authorization": createBasicAuthHeader(clientId, clientSecret),
        },
        timeout: 10000,
      },
  );

  return response.data;
}

async function refreshSpotifyTokens({refreshToken}) {
  const {clientId, clientSecret} = getSpotifyConfig();

  const payload = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
  }).toString();

  const response = await axios.post(
      "https://accounts.spotify.com/api/token",
      payload,
      {
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Authorization": createBasicAuthHeader(clientId, clientSecret),
        },
        timeout: 10000,
      },
  );

  return response.data;
}

async function saveSpotifySecrets({uid, accessToken, refreshToken, expiresIn}) {
  const expiresAt = Date.now() + (expiresIn * 1000);

  await db.collection("integration_secrets").doc(uid).set({
    spotify: {
      accessToken,
      refreshToken,
      expiresAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  }, {merge: true});

  await db.collection("user_integrations").doc(uid).set({
    spotify: {
      status: "connected",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  }, {merge: true});
}

async function markSpotifyExpired(uid) {
  await db.collection("user_integrations").doc(uid).set({
    spotify: {
      status: "expired",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  }, {merge: true});
}

async function getValidSpotifyAccessToken(uid) {
  const secretDoc = await db.collection("integration_secrets").doc(uid).get();
  const spotify = secretDoc.exists ? secretDoc.data().spotify : null;

  if (!spotify || !spotify.refreshToken) {
    const error = new Error("SPOTIFY_NOT_LINKED");
    error.code = "SPOTIFY_NOT_LINKED";
    throw error;
  }

  const now = Date.now();
  const expiresAt = spotify.expiresAt || 0;
  const hasValidAccessToken = spotify.accessToken && expiresAt > now + 60000;

  if (hasValidAccessToken) {
    return spotify.accessToken;
  }

  try {
    const refreshed = await refreshSpotifyTokens({
      refreshToken: spotify.refreshToken,
    });

    const newAccessToken = refreshed.access_token;
    const nextRefreshToken = refreshed.refresh_token || spotify.refreshToken;
    const expiresIn = refreshed.expires_in || 3600;

    await saveSpotifySecrets({
      uid,
      accessToken: newAccessToken,
      refreshToken: nextRefreshToken,
      expiresIn,
    });

    return newAccessToken;
  } catch (e) {
    await markSpotifyExpired(uid);
    const error = new Error("SPOTIFY_AUTH_EXPIRED");
    error.code = "SPOTIFY_AUTH_EXPIRED";
    throw error;
  }
}

module.exports = {
  exchangeCodeForTokens,
  refreshSpotifyTokens,
  saveSpotifySecrets,
  getValidSpotifyAccessToken,
  markSpotifyExpired,
};

