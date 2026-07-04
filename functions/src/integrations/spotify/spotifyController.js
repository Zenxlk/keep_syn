const {exchangeAuthCode, getUserPlaylists, getPlaylistTracks} = require("./spotifyClient");
const {storeSpotifyTokens, clearSpotifyTokens, isSpotifyConnected, getValidSpotifyAccessToken, hasRequiredSpotifyScope} = require("./spotifyTokenService");

/**
 * GET /v1/integrations/spotify/status
 */
async function getStatus(req, res) {
  const uid = req.user.uid;
  const connected = await isSpotifyConnected(uid);
  return res.ok("Estado de Spotify obtenido.", {
    status: connected ? "connected" : "notConnected",
  });
}

/**
 * POST /v1/integrations/spotify/link
 * Body: { code: string, redirectUri: string, clientId?: string }
 */
async function linkAccount(req, res) {
  const uid = req.user.uid;
  const {code, redirectUri, clientId} = req.body || {};

  if (!code || !redirectUri) {
    return res.error("code y redirectUri son requeridos.", 400);
  }

  const usedClientId = clientId || process.env.SPOTIFY_CLIENT_ID;
  const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;

  const tokens = await exchangeAuthCode({
    code,
    redirectUri,
    clientId: usedClientId,
    clientSecret,
  });

  if (!tokens.access_token || !tokens.refresh_token) {
    return res.error("No se recibieron tokens de Spotify.", 502);
  }

  await storeSpotifyTokens(uid, {
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token,
    expiresInSeconds: tokens.expires_in || 3600,
    scope: tokens.scope,
  });

  return res.ok("Spotify vinculado correctamente.", {status: "connected"});
}

/**
 * POST /v1/integrations/spotify/unlink
 */
async function unlinkAccount(req, res) {
  const uid = req.user.uid;
  await clearSpotifyTokens(uid);
  return res.ok("Spotify desvinculado.", {status: "notConnected"});
}

/**
 * GET /v1/integrations/spotify/playlists
 * Query: { limit?, offset? }
 */
async function listPlaylists(req, res) {
  const uid = req.user.uid;
  const limit = Math.min(parseInt(req.query.limit) || 50, 50);
  const offset = parseInt(req.query.offset) || 0;

  const accessToken = await getValidSpotifyAccessToken(uid);
  const data = await getUserPlaylists({accessToken, limit, offset});

  return res.ok("Playlists obtenidas.", {
    items: (data.items || []).map((p) => ({
      id: p.id,
      name: p.name,
      tracksTotal: p.items ? p.items.total : 0,
      imageUrl: p.images && p.images[0] ? p.images[0].url : null,
      ownerName: p.owner ? p.owner.display_name : null,
      ownerId: p.owner ? p.owner.id : null,
    })),
    total: data.total || 0,
    next: data.next || null,
    offset,
    limit,
  });
}

/**
 * GET /v1/integrations/spotify/playlists/:playlistId/tracks
 * Query: { limit?, offset? }
 */
async function listPlaylistTracks(req, res) {
  const uid = req.user.uid;
  const {playlistId} = req.params;
  const limit = Math.min(parseInt(req.query.limit) || 100, 100);
  const offset = parseInt(req.query.offset) || 0;

  const hasScope = await hasRequiredSpotifyScope(uid, "playlist-read-private");
  if (!hasScope) {
    return res.error(
        "Tu token de Spotify no tiene el permiso 'playlist-read-private'. " +
        "Desvincula y vuelve a conectar Spotify para renovar los permisos.",
        403,
    );
  }

  const accessToken = await getValidSpotifyAccessToken(uid);
  console.log("[getPlaylistTracks] uid:", uid, "playlist:", playlistId);
  const data = await getPlaylistTracks({accessToken, playlistId, limit, offset});

  const tracks = (data.items || [])
      .map((item) => item.item)
      .filter(Boolean)
      .map((track) => ({
        id: track.id,
        name: track.name,
        artists: (track.artists || []).map((a) => ({id: a.id, name: a.name})),
        album: track.album ? {id: track.album.id, name: track.album.name} : null,
        externalIds: track.external_ids || {},
        durationMs: track.duration_ms || null,
        uri: track.uri || null,
      }));

  return res.ok("Tracks obtenidos.", {
    items: tracks,
    total: data.total || 0,
    next: data.next || null,
    offset,
    limit,
  });
}

module.exports = {getStatus, linkAccount, unlinkAccount, listPlaylists, listPlaylistTracks};
