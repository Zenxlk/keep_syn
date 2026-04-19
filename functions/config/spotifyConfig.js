function getSpotifyConfig() {
  const clientId = process.env.SPOTIFY_CLIENT_ID;
  const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;
  const redirectUri = process.env.SPOTIFY_REDIRECT_URI || null;

  if (!clientId || !clientSecret || !redirectUri) {
    throw new Error(
        "Faltan SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET o SPOTIFY_REDIRECT_URI en el entorno.",
    );
  }

  return {
    clientId,
    clientSecret,
    redirectUri,
  };
}

module.exports = {
  getSpotifyConfig,
};
