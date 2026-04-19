const axios = require("axios");
const axiosRetry = require("axios-retry").default;

const youtubeApi = axios.create({
  baseURL: "https://www.googleapis.com/youtube/v3",
  timeout: 12000,
});

axiosRetry(youtubeApi, {
  retries: 3,
  retryDelay: (retryCount, error) => {
    if (error.response && error.response.status === 429) {
      const retryAfter = error.response.headers["retry-after"];
      if (retryAfter) {
        return Number.parseInt(retryAfter, 10) * 1000;
      }
    }
    return axiosRetry.exponentialDelay(retryCount);
  },
  retryCondition: (error) => {
    const status = error.response ? error.response.status : null;
    return axiosRetry.isNetworkOrIdempotentRequestError(error) ||
      status === 429 ||
      (status >= 500 && status < 600);
  },
});

function createAuthHeaders(accessToken) {
  return {
    Authorization: `Bearer ${accessToken}`,
  };
}

function stripYouTubeDecorators(value = "") {
  return String(value || "")
      .replace(/\s*[\[(][^\])]*(official|video|audio|lyrics?|visualizer|mv|hd|4k)[^\])]*[\])]/gi, " ")
      .replace(/\s+-\s+(official|lyrics?|audio|video|visualizer|mv|topic).*$/gi, " ")
      .replace(/\s+/g, " ")
      .trim();
}

function normalizeChannelName(channelTitle = "") {
  return String(channelTitle || "")
      .replace(/\s+-\s+topic$/i, "")
      .trim();
}

function splitArtistsLabel(rawArtists = "") {
  return String(rawArtists || "")
      .split(/,|&| x | X |\bft\.?\b|\bfeat\.?\b|\bfeaturing\b/gi)
      .map((value) => value.trim())
      .filter(Boolean);
}

function normalizeYouTubeVideo(item = {}) {
  const snippet = item.snippet || {};
  const resourceId = snippet.resourceId || {};
  const rawVideoId = item.id && typeof item.id === "object" ? item.id.videoId : item.id;
  const videoId = rawVideoId || resourceId.videoId ||
    (item.contentDetails && item.contentDetails.videoId) || null;
  const cleanedTitle = stripYouTubeDecorators(snippet.title || "");
  const titleParts = cleanedTitle.split(" - ");
  const hasArtistPrefix = titleParts.length > 1;
  const artists = hasArtistPrefix ?
    splitArtistsLabel(titleParts[0]) :
    [normalizeChannelName(snippet.videoOwnerChannelTitle || snippet.channelTitle || "")]
  ;
  const normalizedTitle = hasArtistPrefix ?
    titleParts.slice(1).join(" - ").trim() : cleanedTitle;

  return {
    id: videoId,
    videoId,
    platform: "youtube",
    title: normalizedTitle || cleanedTitle,
    artists: artists.filter(Boolean),
    album: "",
    isrc: null,
    uri: videoId ? `https://www.youtube.com/watch?v=${videoId}` : null,
    externalIds: {isrc: null},
    rawTitle: snippet.title || "",
    channelTitle: normalizeChannelName(snippet.channelTitle || ""),
    thumbnailUrl: snippet.thumbnails && snippet.thumbnails.default ?
      snippet.thumbnails.default.url : null,
  };
}

function normalizeYouTubePlaylist(item = {}) {
  const snippet = item.snippet || {};
  const contentDetails = item.contentDetails || {};
  const status = item.status || {};

  return {
    id: item.id,
    playlistId: item.id,
    name: snippet.title || "",
    description: snippet.description || "",
    itemCount: contentDetails.itemCount || 0,
    privacyStatus: status.privacyStatus || "private",
  };
}

function buildYouTubeSearchQuery(track = {}) {
  const artists = Array.isArray(track.artists) ? track.artists.filter(Boolean) : [];
  return [track.title || track.name || "", ...artists].filter(Boolean).join(" ").trim();
}

async function listPlaylists({accessToken, limit = 50}) {
  const playlists = [];
  let pageToken;

  while (playlists.length < limit) {
    const response = await youtubeApi.get("/playlists", {
      headers: createAuthHeaders(accessToken),
      params: {
        part: "snippet,contentDetails,status",
        mine: true,
        maxResults: Math.min(50, limit - playlists.length),
        pageToken,
      },
    });

    const items = Array.isArray(response.data.items) ? response.data.items : [];
    playlists.push(...items.map(normalizeYouTubePlaylist));

    pageToken = response.data.nextPageToken;
    if (!pageToken || items.length === 0) {
      break;
    }
  }

  return playlists;
}

async function createPlaylist({accessToken, name, description = ""}) {
  const response = await youtubeApi.post(
      "/playlists",
      {
        snippet: {
          title: name,
          description,
        },
        status: {
          privacyStatus: "private",
        },
      },
      {
        headers: createAuthHeaders(accessToken),
        params: {
          part: "snippet,status",
        },
      },
  );

  return normalizeYouTubePlaylist(response.data);
}

async function listPlaylistTracks({accessToken, playlistId, limit = 500}) {
  const tracks = [];
  let pageToken;

  while (tracks.length < limit) {
    const response = await youtubeApi.get("/playlistItems", {
      headers: createAuthHeaders(accessToken),
      params: {
        part: "snippet,contentDetails",
        playlistId,
        maxResults: Math.min(50, limit - tracks.length),
        pageToken,
      },
    });

    const items = Array.isArray(response.data.items) ? response.data.items : [];
    tracks.push(...items.map(normalizeYouTubeVideo).filter((item) => Boolean(item.id)));

    pageToken = response.data.nextPageToken;
    if (!pageToken || items.length === 0) {
      break;
    }
  }

  return tracks;
}

async function searchTracks({accessToken, track, limit = 5}) {
  const query = buildYouTubeSearchQuery(track);
  if (!query) {
    return [];
  }

  const response = await youtubeApi.get("/search", {
    headers: createAuthHeaders(accessToken),
    params: {
      part: "snippet",
      q: query,
      type: "video",
      videoCategoryId: "10",
      maxResults: Math.min(limit, 25),
      order: "relevance",
    },
  });

  const items = Array.isArray(response.data.items) ? response.data.items : [];
  return items.map(normalizeYouTubeVideo).filter((item) => Boolean(item.id));
}

async function addTrackToPlaylist({accessToken, playlistId, track}) {
  const videoId = track.videoId || track.id;
  const response = await youtubeApi.post(
      "/playlistItems",
      {
        snippet: {
          playlistId,
          resourceId: {
            kind: "youtube#video",
            videoId,
          },
        },
      },
      {
        headers: createAuthHeaders(accessToken),
        params: {
          part: "snippet",
        },
      },
  );

  return {
    playlistItemId: response.data.id,
    videoId,
  };
}

module.exports = {
  addTrackToPlaylist,
  buildYouTubeSearchQuery,
  createPlaylist,
  listPlaylistTracks,
  listPlaylists,
  normalizeYouTubePlaylist,
  normalizeYouTubeVideo,
  searchTracks,
  stripYouTubeDecorators,
};
