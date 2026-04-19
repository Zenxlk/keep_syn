function getYouTubeConfig() {
  const clientId = process.env.YOUTUBE_CLIENT_ID;
  const clientSecret = process.env.YOUTUBE_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    throw new Error(
      "Faltan YOUTUBE_CLIENT_ID o YOUTUBE_CLIENT_SECRET en el entorno.",
    );
  }

  return {
    clientId,
    clientSecret,
  };
}

module.exports = {
  getYouTubeConfig,
};

