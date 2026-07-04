const express = require('express');
const cors = require('cors');
const { standardResponse } = require('./middlewares/response');
const { verifyToken, checkAllowlist } = require('./middlewares/auth');
const syncRoutes = require('./routes/syncRoutes');
const spotifyRoutes = require('./integrations/spotify/spotifyRoutes');
const youtubeRoutes = require('./integrations/youtube/youtubeRoutes');

const app = express();

app.use(cors({ origin: true }));
app.use(express.json());
app.use(standardResponse);

// Aplicamos seguridad global a todas las rutas bajo /v1/sync/jobs
app.use('/v1/sync/jobs', verifyToken, checkAllowlist, syncRoutes);
app.use('/v1/integrations/spotify', verifyToken, checkAllowlist, spotifyRoutes);
app.use('/v1/integrations/youtube', verifyToken, checkAllowlist, youtubeRoutes);

// Manejo de rutas no encontradas
app.use((req, res) => {
  res.error('Endpoint no encontrado.', 404);
});

// Error handler global — captura errores de next(err) y los devuelve como JSON
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[GlobalErrorHandler]', err);
  const message = err?.message || 'Error interno del servidor.';
  res.error(message, 500);
});

module.exports = app;
