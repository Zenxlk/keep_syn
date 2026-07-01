const SINGLETON_KEY = "__ytmusicInstance";

async function _getClient() {
  if (global[SINGLETON_KEY]) return global[SINGLETON_KEY];

  const {default: YTMusic} = await import("ytmusic-api");
  const client = new YTMusic();
  await client.initialize();
  global[SINGLETON_KEY] = client;
  return client;
}

/**
 * Maps a ytmusic-api song result to the candidate shape expected by trackMatcher.
 * @param {Object} song
 * @return {Object}
 */
function _mapSong(song) {
  return {
    id: song.videoId || "",
    title: song.name || "",
    artists: song.artist ? [{name: song.artist.name || ""}] : [],
    album: song.album ? (song.album.name || "") : "",
    duration_ms: typeof song.duration === "number" ? song.duration * 1000 : null,
  };
}

/**
 * Search for tracks on YouTube Music without consuming Data API quota.
 * @param {Object} params
 * @param {Object} params.track - Source track {title, artists, album}
 * @param {number} [params.limit=5]
 * @return {Promise<Array<Object>>}
 */
async function searchYTMusicTracks({track, limit = 5}) {
  const artistName = Array.isArray(track.artists) && track.artists.length > 0
    ? (typeof track.artists[0] === "object" ? track.artists[0].name : track.artists[0])
    : "";

  const query = [track.title || track.name || "", artistName]
      .filter(Boolean)
      .join(" ");

  const client = await _getClient();
  const results = await client.searchSongs(query);

  return (Array.isArray(results) ? results : [])
      .slice(0, limit)
      .map(_mapSong)
      .filter((s) => s.id);
}

module.exports = {searchYTMusicTracks};
