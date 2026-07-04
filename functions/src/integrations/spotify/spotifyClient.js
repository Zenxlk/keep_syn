const axios = require('axios');

const SPOTIFY_API = 'https://api.spotify.com/v1';

function _authHeaders(accessToken) {
  return { Authorization: `Bearer ${accessToken}` };
}

/**
 * Exchanges an authorization code for Spotify access + refresh tokens.
 * @param {Object} params
 * @param {string} params.code
 * @param {string} params.redirectUri
 * @param {string} params.clientId
 * @param {string} params.clientSecret
 * @return {Promise<Object>} { access_token, refresh_token, expires_in, scope }
 */
async function exchangeAuthCode({ code, redirectUri, clientId, clientSecret }) {
  const b64 = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  const { data } = await axios.post(
    'https://accounts.spotify.com/api/token',
    new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: redirectUri,
    }),
    {
      headers: {
        'Authorization': `Basic ${b64}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    },
  );
  return data;
}

/**
 * Fetches Spotify playlist metadata.
 * @param {Object} params
 * @param {string} params.accessToken
 * @param {string} params.playlistId
 * @return {Promise<Object>}
 */
async function getPlaylist({ accessToken, playlistId }) {
  const { data } = await axios.get(`${SPOTIFY_API}/playlists/${playlistId}`, {
    headers: _authHeaders(accessToken),
    params: { fields: 'id,name,description,images,items.total,owner.display_name' },
  });
  return data;
}

/**
 * Fetches one page of tracks from a Spotify playlist.
 * @param {Object} params
 * @param {string} params.accessToken
 * @param {string} params.playlistId
 * @param {number} [params.offset=0]
 * @param {number} [params.limit=100]
 * @return {Promise<Object>} { items, total, next, offset, limit }
 */
async function getPlaylistTracks({ accessToken, playlistId, offset = 0, limit = 100 }) {
  const { data } = await axios.get(`${SPOTIFY_API}/playlists/${playlistId}/items`, {
    headers: _authHeaders(accessToken),
    params: { offset, limit },
  });
  return data;
}

/**
 * Fetches the authenticated user's Spotify playlists (paginated).
 * @param {Object} params
 * @param {string} params.accessToken
 * @param {number} [params.limit=50]
 * @param {number} [params.offset=0]
 * @return {Promise<Object>} { items, total, next }
 */
async function getUserPlaylists({ accessToken, limit = 50, offset = 0 }) {
  const { data } = await axios.get(`${SPOTIFY_API}/me/playlists`, {
    headers: _authHeaders(accessToken),
    params: { limit, offset },
  });
  return data;
}

module.exports = { exchangeAuthCode, getPlaylist, getPlaylistTracks, getUserPlaylists };
