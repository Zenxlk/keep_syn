const axios = require("axios");
const axiosRetry = require("axios-retry").default;

const spotifyApi = axios.create({
  baseURL: "https://api.spotify.com/v1",
  timeout: 10000,
});

axiosRetry(spotifyApi, {
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

async function getMePlaylists({accessToken, limit = 20, offset = 0}) {
  const response = await spotifyApi.get("/me/playlists", {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
    params: {limit, offset},
  });

  return response.data;
}

async function getPlaylist({accessToken, playlistId}) {
  const response = await spotifyApi.get(`/playlists/${playlistId}`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
    params: {
      market: "from_token",
    },
  });

  return response.data;
}

async function getPlaylistTracks({accessToken, playlistId, limit = 50, offset = 0}) {
  const response = await spotifyApi.get(`/playlists/${playlistId}/tracks`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
    params: {
      limit,
      offset,
      market: "from_token",
    },
  });

  return response.data;
}

module.exports = {
  getMePlaylists,
  getPlaylist,
  getPlaylistTracks,
};

