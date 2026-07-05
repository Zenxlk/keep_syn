const axios = require('axios');
const { storeYouTubeTokens, clearYouTubeTokens, isYouTubeConnected } = require('./youtubeTokenService');

const TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';

/**
 * GET /v1/integrations/youtube/status
 */
async function getStatus(req, res) {
  const uid = req.user.uid;
  const connected = await isYouTubeConnected(uid);
  return res.ok('Estado de YouTube obtenido.', {
    status: connected ? 'connected' : 'notConnected',
  });
}

/**
 * POST /v1/integrations/youtube/link
 * Body: { serverAuthCode: string }
 */
async function linkAccount(req, res) {
  const uid = req.user.uid;
  const { serverAuthCode } = req.body || {};

  if (!serverAuthCode) {
    return res.error('serverAuthCode es requerido.', 400);
  }

  const { data: tokens } = await axios.post(TOKEN_ENDPOINT, null, {
    params: {
      grant_type: 'authorization_code',
      code: serverAuthCode,
      client_id: process.env.YOUTUBE_CLIENT_ID,
      client_secret: process.env.YOUTUBE_CLIENT_SECRET,
      redirect_uri: process.env.YOUTUBE_REDIRECT_URI || '',
    },
  });

  if (!tokens.access_token || !tokens.refresh_token) {
    return res.error('No se recibieron tokens de YouTube.', 502);
  }

  await storeYouTubeTokens(uid, {
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token,
    expiresInSeconds: tokens.expires_in || 3600,
    scope: tokens.scope,
  });

  return res.ok('YouTube vinculado correctamente.', { status: 'connected' });
}

/**
 * POST /v1/integrations/youtube/unlink
 */
async function unlinkAccount(req, res) {
  const uid = req.user.uid;
  await clearYouTubeTokens(uid);
  return res.ok('YouTube desvinculado.', { status: 'notConnected' });
}

module.exports = { getStatus, linkAccount, unlinkAccount };
