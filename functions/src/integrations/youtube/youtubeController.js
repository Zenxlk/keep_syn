const admin = require("firebase-admin");
const {getYouTubeConfig} = require("../../../config/youtubeConfig");
const {
  exchangeCodeForTokens,
  refreshYouTubeTokens,
  saveYouTubeSecrets,
  markYouTubeExpired,
} = require("./youtubeTokenService");

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
  const {serverAuthCode} = req.body;
  const uid = req.user.uid;
  getYouTubeConfig();

  if (!serverAuthCode) {
    return res.error("Falta parametro requerido: serverAuthCode.", 400);
  }

  try {
    await addEvent(uid, "youtube_link_started", {flow: "google_sign_in"});

    const tokenResponse = await exchangeCodeForTokens({
      code: serverAuthCode,
    });

    let refreshToken = tokenResponse.refresh_token;

    if (!refreshToken) {
      const existingSecret = await db.collection("integration_secrets").doc(uid).get();
      refreshToken =
        existingSecret.exists && existingSecret.data().youtube
          ? existingSecret.data().youtube.refreshToken
          : null;
    }

    if (!refreshToken) {
      throw new Error(
        "Google no devolvio refresh_token. Desvincula y vuelve a vincular para consentir acceso offline.",
      );
    }

    await saveYouTubeSecrets({
      uid,
      accessToken: tokenResponse.access_token,
      refreshToken,
      expiresIn: tokenResponse.expires_in || 3600,
    });

    await addEvent(uid, "youtube_link_success");

    return res.ok("Cuenta de YouTube vinculada exitosamente.", {
      platform: "youtube",
      status: "connected",
    });
  } catch (error) {
    await addEvent(uid, "youtube_link_failed", {
      message: error.message,
      code: error.code || null,
    });

    const providerError =
      error && error.response ? error.response.data : error.message;
    console.error("Error vinculando YouTube:", providerError);

    return res.error("Fallo al verificar el codigo de autorizacion con YouTube.", 502, {
      providerError,
    });
  }
};

exports.refreshAccount = async (req, res) => {
  const uid = req.user.uid;

  try {
    const secretDoc = await db.collection("integration_secrets").doc(uid).get();
    const youtube = secretDoc.exists ? secretDoc.data().youtube : null;

    if (!youtube || !youtube.refreshToken) {
      return res.error("YouTube no esta vinculado para este usuario.", 400);
    }

    const refreshed = await refreshYouTubeTokens({
      refreshToken: youtube.refreshToken,
    });

    await saveYouTubeSecrets({
      uid,
      accessToken: refreshed.access_token,
      refreshToken: youtube.refreshToken,
      expiresIn: refreshed.expires_in || 3600,
    });

    await addEvent(uid, "youtube_refresh_success");

    return res.ok("Token de YouTube renovado.", {
      platform: "youtube",
      status: "connected",
    });
  } catch (error) {
    await markYouTubeExpired(uid);
    await addEvent(uid, "youtube_refresh_failed", {
      message: error.message,
      code: error.code || null,
    });
    return res.error("No se pudo refrescar el token de YouTube.", 502);
  }
};

exports.unlinkAccount = async (req, res) => {
  const uid = req.user.uid;

  try {
    await db.collection("integration_secrets").doc(uid).set(
      {
        youtube: admin.firestore.FieldValue.delete(),
      },
      {merge: true},
    );

    await db.collection("user_integrations").doc(uid).set(
      {
        youtube: {
          status: "notConnected",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {merge: true},
    );

    await addEvent(uid, "youtube_unlink_success");

    return res.ok("Cuenta de YouTube desvinculada.", {
      platform: "youtube",
      status: "notConnected",
    });
  } catch (error) {
    return res.error("Error al desvincular YouTube.", 500);
  }
};

exports.getStatus = async (req, res) => {
  try {
    const uid = req.user.uid;
    const doc = await db.collection("user_integrations").doc(uid).get();
    const status =
      doc.exists && doc.data().youtube && doc.data().youtube.status
        ? doc.data().youtube.status
        : "notConnected";

    return res.ok("Estado recuperado.", {
      platform: "youtube",
      status,
    });
  } catch (_) {
    return res.error("Error interno recuperando estado de YouTube.", 500);
  }
};
