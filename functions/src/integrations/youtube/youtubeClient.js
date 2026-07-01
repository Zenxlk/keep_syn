const axios = require("axios");
const {searchYTMusicTracks} = require("./ytmusicSearchClient");
const {getCachedCandidates, setCachedCandidates} = require("./trackSearchCache");

const YT_API = "https://www.googleapis.com/youtube/v3";

function _authHeaders(accessToken) {
  return {Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json"};
}

/**
 * Lists the authenticated user's YouTube playlists.
 * @param {Object} params
 * @param {string} params.accessToken
 * @param {number} [params.limit=200]
 * @return {Promise<Array<Object>>}
 */
async function listPlaylists({accessToken, limit = 200}) {
  const items = [];
  let pageToken;

  while (items.length < limit) {
    const {data} = await axios.get(`${YT_API}/playlists`, {
      headers: _authHeaders(accessToken),
      params: {
        part: "snippet",
        mine: true,
        maxResults: Math.min(50, limit - items.length),
        ...(pageToken ? {pageToken} : {}),
      },
    });

    items.push(...(data.items || []));
    pageToken = data.nextPageToken;
    if (!pageToken) break;
  }

  return items;
}

/**
 * Creates a new private YouTube playlist.
 * @param {Object} params
 * @param {string} params.accessToken
 * @param {string} params.name
 * @param {string} [params.description]
 * @return {Promise<Object>}
 */
async function createPlaylist({accessToken, name, description = ""}) {
  const {data} = await axios.post(
      `${YT_API}/playlists`,
      {
        snippet: {title: name, description},
        status: {privacyStatus: "private"},
      },
      {
        headers: _authHeaders(accessToken),
        params: {part: "snippet,status"},
      },
  );
  return data;
}

/**
 * Lists all tracks in a YouTube playlist.
 * @param {Object} params
 * @param {string} params.accessToken
 * @param {string} params.playlistId
 * @param {number} [params.limit=500]
 * @return {Promise<Array<Object>>}
 */
async function listPlaylistTracks({accessToken, playlistId, limit = 500}) {
  const items = [];
  let pageToken;

  while (items.length < limit) {
    const {data} = await axios.get(`${YT_API}/playlistItems`, {
      headers: _authHeaders(accessToken),
      params: {
        part: "snippet",
        playlistId,
        maxResults: 50,
        ...(pageToken ? {pageToken} : {}),
      },
    });

    items.push(...(data.items || []));
    pageToken = data.nextPageToken;
    if (!pageToken) break;
  }

  return items;
}

/**
 * Searches for tracks on YouTube Music using ytmusic-api (no quota cost).
 * Results are cached in Firestore to avoid redundant searches.
 * Falls back to empty array if ytmusic-api is unavailable.
 * @param {Object} params
 * @param {string} params.accessToken - Kept for interface compatibility (unused)
 * @param {Object} params.track
 * @param {number} [params.limit=5]
 * @return {Promise<Array<Object>>}
 */
async function searchTracks({accessToken, track, limit = 5}) {
  const cached = await getCachedCandidates(track);
  if (cached) return cached.slice(0, limit);

  let candidates;
  try {
    candidates = await searchYTMusicTracks({track, limit});
  } catch (_) {
    candidates = [];
  }

  if (candidates.length > 0) {
    setCachedCandidates(track, candidates).catch(() => {});
  }

  return candidates;
}

/**
 * Adds a track to a YouTube playlist.
 * @param {Object} params
 * @param {string} params.accessToken
 * @param {string} params.playlistId
 * @param {Object} params.track - Must have `id` (videoId)
 * @return {Promise<Object>}
 */
async function addTrackToPlaylist({accessToken, playlistId, track}) {
  const {data} = await axios.post(
      `${YT_API}/playlistItems`,
      {
        snippet: {
          playlistId,
          resourceId: {kind: "youtube#video", videoId: track.id},
        },
      },
      {
        headers: _authHeaders(accessToken),
        params: {part: "snippet"},
      },
  );
  return data;
}

module.exports = {
  listPlaylists,
  createPlaylist,
  listPlaylistTracks,
  searchTracks,
  addTrackToPlaylist,
};
