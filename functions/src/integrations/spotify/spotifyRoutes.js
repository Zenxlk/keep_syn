const axios = require('axios');
const express = require('express');
const {
  getStatus,
  linkAccount,
  unlinkAccount,
  listPlaylists,
  listPlaylistTracks,
} = require('./spotifyController');

const router = express.Router();

router.get('/status', getStatus);
router.post('/link', linkAccount);
router.post('/unlink', unlinkAccount);
router.get('/playlists', listPlaylists);
router.get('/playlists/:playlistId/tracks', listPlaylistTracks);

// Handles Axios errors from Spotify API (401 / 403) before they reach the global handler
router.use((err, req, res, next) => {
  if (axios.isAxiosError(err)) {
    const status = err.response?.status;
    const spotifyBody = err.response?.data;
    console.error('[SpotifyRouteError] status:', status, 'body:', JSON.stringify(spotifyBody));
    if (status === 403) {
      const spotifyMsg = spotifyBody?.error?.message ?? '';
      const isScopeError = spotifyMsg.toLowerCase().includes('scope');
      const userMsg = isScopeError
        ? 'Tu token de Spotify no tiene los permisos necesarios. '
          + 'Desvincula y vuelve a conectar Spotify para renovar los permisos.'
        : 'Esta playlist no puede sincronizarse: Spotify no permite acceder a sus '
          + 'tracks por API. Puede ser una playlist privada de otro usuario o una '
          + 'playlist generada por Spotify (Daily Mix, On Repeat, etc.).';
      return res.error(userMsg, 403);
    }
    if (status === 401) {
      return res.error(
        'La sesión de Spotify expiró. Desvincula y vuelve a conectar Spotify.',
        401,
      );
    }
  }
  next(err);
});

module.exports = router;
