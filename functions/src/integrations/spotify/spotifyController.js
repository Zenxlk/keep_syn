const admin = require("firebase-admin");
const {getSpotifyConfig} = require("../../../config/spotifyConfig");
const {
  exchangeCodeForTokens,
  refreshSpotifyTokens,
  saveSpotifySecrets,
  getValidSpotifyAccessToken,
  markSpotifyExpired,
} = require("./spotifyTokenService");
const {
  getMePlaylists,
  getPlaylistTracks: fetchPlaylistTracks,
} = require("./spotifyClient");

const db = admin.firestore();

async function addEvent(uid, type, payload = {}) {
  await db.collection("app_events").add({
    uid,
    type,
    payload,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

exports.linkAccount = async (req, res) => {
  const {code, redirectUri, clientId} = req.body;
  const uid = req.user.uid;
  const spotifyConfig = getSpotifyConfig();

  if (!code || !redirectUri) {
    return res.error("Faltan parametros requeridos: code y redirectUri.", 400);
  }

  if (spotifyConfig.redirectUri && spotifyConfig.redirectUri !== redirectUri) {
    return res.error("redirectUri no permitida para Spotify.", 400);
  }

  try {
    await addEvent(uid, "spotify_link_started");

    if (clientId && clientId !== spotifyConfig.clientId) {
      return res.error("clientId no permitido para Spotify.", 400, {
        clientIdReceived: clientId,
        clientIdExpectedSuffix: spotifyConfig.clientId.slice(-6),
      });
    }

    const tokenResponse = await exchangeCodeForTokens({code, redirectUri});
    await saveSpotifySecrets({
      uid,
      accessToken: tokenResponse.access_token,
      refreshToken: tokenResponse.refresh_token,
      expiresIn: tokenResponse.expires_in || 3600,
    });

    await addEvent(uid, "spotify_link_success");

    return res.ok("Cuenta de Spotify vinculada exitosamente.", {
      platform: "spotify",
      status: "connected",
    });
  } catch (error) {
    await addEvent(uid, "spotify_link_failed", {
      message: error.message,
      code: error.code || null,
    });

    const spotifyErrorData =
      error && error.response ? error.response.data : error.message;
    console.error("Error vinculando Spotify:", spotifyErrorData);
    return res.error("Fallo al verificar el codigo de autorizacion con Spotify.", 502, {
      spotifyError: spotifyErrorData,
      redirectUriReceived: redirectUri,
      redirectUriExpected: spotifyConfig.redirectUri,
      clientIdReceived: clientId || null,
      clientIdExpectedSuffix: spotifyConfig.clientId.slice(-6),
    });
  }
};

exports.refreshAccount = async (req, res) => {
  const uid = req.user.uid;

  try {
    const secretDoc = await db.collection("integration_secrets").doc(uid).get();
    const spotify = secretDoc.exists ? secretDoc.data().spotify : null;

    if (!spotify || !spotify.refreshToken) {
      return res.error("Spotify no esta vinculado para este usuario.", 400);
    }

    const tokenResponse = await refreshSpotifyTokens({
      refreshToken: spotify.refreshToken,
    });

    await saveSpotifySecrets({
      uid,
      accessToken: tokenResponse.access_token,
      refreshToken: tokenResponse.refresh_token || spotify.refreshToken,
      expiresIn: tokenResponse.expires_in || 3600,
    });

    await addEvent(uid, "spotify_refresh_success");

    return res.ok("Token de Spotify renovado.", {
      platform: "spotify",
      status: "connected",
    });
  } catch (error) {
    await markSpotifyExpired(uid);
    await addEvent(uid, "spotify_refresh_failed", {
      message: error.message,
      code: error.code || null,
    });
    return res.error("No se pudo refrescar el token de Spotify.", 502);
  }
};

exports.unlinkAccount = async (req, res) => {
  const uid = req.user.uid;

  try {
    await db.collection("integration_secrets").doc(uid).set({
      spotify: admin.firestore.FieldValue.delete(),
    }, {merge: true});

    await db.collection("user_integrations").doc(uid).set({
      spotify: {
        status: "notConnected",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    }, {merge: true});

    await addEvent(uid, "spotify_unlink_success");

    return res.ok("Cuenta de Spotify desvinculada.", {
      platform: "spotify",
      status: "notConnected",
    });
  } catch (error) {
    return res.error("Error al desvincular Spotify.", 500);
  }
};

exports.getStatus = async (req, res) => {
  try {
    const uid = req.user.uid;
    const doc = await db.collection("user_integrations").doc(uid).get();
    const status = doc.exists && doc.data().spotify && doc.data().spotify.status ?
      doc.data().spotify.status : "notConnected";

    return res.ok("Estado recuperado.", {
      platform: "spotify",
      status,
    });
  } catch (error) {
    return res.error("Error interno recuperando estado.", 500);
  }
};

exports.getPlaylists = async (req, res) => {
  const uid = req.user.uid;
  const limit = Number.parseInt(req.query.limit, 10) || 20;
  const offset = Number.parseInt(req.query.offset, 10) || 0;

  try {
    const accessToken = await getValidSpotifyAccessToken(uid);
    const data = await getMePlaylists({accessToken, limit, offset});

    return res.ok("Playlists obtenidas.", data);
  } catch (error) {
    if (error.code === "SPOTIFY_NOT_LINKED") {
      return res.error("Spotify no esta vinculado.", 400);
    }
    if (error.code === "SPOTIFY_AUTH_EXPIRED") {
      return res.error("Sesion de Spotify expirada. Vuelve a vincular la cuenta.", 401);
    }

    if (error.response && error.response.status === 429) {
      await addEvent(uid, "spotify_rate_limited", {endpoint: "getPlaylists"});
      return res.error("Spotify rate limit alcanzado. Intenta de nuevo.", 429);
    }

    return res.error("No se pudieron obtener playlists de Spotify.", 502);
  }
};

exports.getPlaylistTracks = async (req, res) => {
  const uid = req.user.uid;
  const {playlistId} = req.params;
  const limit = Number.parseInt(req.query.limit, 10) || 50;
  const offset = Number.parseInt(req.query.offset, 10) || 0;

  if (!playlistId) {
    return res.error("playlistId es requerido.", 400);
  }

  try {
    const accessToken = await getValidSpotifyAccessToken(uid);
    const data = await fetchPlaylistTracks({
      accessToken,
      playlistId,
      limit,
      offset,
    });

    return res.ok("Tracks de playlist obtenidos.", data);
  } catch (error) {
    if (error.code === "SPOTIFY_NOT_LINKED") {
      return res.error("Spotify no esta vinculado.", 400);
    }
    if (error.code === "SPOTIFY_AUTH_EXPIRED") {
      return res.error("Sesion de Spotify expirada. Vuelve a vincular la cuenta.", 401);
    }

    if (error.response && error.response.status === 429) {
      await addEvent(uid, "spotify_rate_limited", {endpoint: "getPlaylistTracks"});
      return res.error("Spotify rate limit alcanzado. Intenta de nuevo.", 429);
    }

    return res.error("No se pudieron obtener tracks de Spotify.", 502);
  }
};
