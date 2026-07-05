const { onCall, onRequest } = require('firebase-functions/v2/https');
const { onTaskDispatched } = require('firebase-functions/v2/tasks');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

const spotifyClientIdSecret = defineSecret('SPOTIFY_CLIENT_ID');
const spotifyClientSecretSecret = defineSecret('SPOTIFY_CLIENT_SECRET');
const spotifyRedirectUriSecret = defineSecret('SPOTIFY_REDIRECT_URI');
const youtubeClientIdSecret = defineSecret('YOUTUBE_CLIENT_ID');
const youtubeClientSecretSecret = defineSecret('YOUTUBE_CLIENT_SECRET');

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const { processSyncJobTask } = require('./src/controllers/syncEngine');
const app = require('./src/app');

exports.verifyAccess = onCall(async (request) => {
  if (!request.auth) {
    return { status: 'UNAUTHORIZED', message: 'No autenticado en Firebase.' };
  }

  const userEmail = request.auth.token.email;

  try {
    const doc = await admin
      .firestore()
      .collection('allowlist')
      .doc(userEmail)
      .get();

    if (!doc.exists) {
      return {
        status: 'UNAUTHORIZED',
        message: 'Tu cuenta no está en la lista de testers autorizados.',
      };
    }

    return {
      status: 'OK',
      message: 'Acceso concedido.',
      data: doc.data(),
    };
  } catch (error) {
    console.error('Error en verifyAccess:', error);
    return { status: 'ERROR', message: 'Error interno del servidor.' };
  }
});
exports.logClientError = onCall(async (request) => {
  const data = request.data || {};

  const requestUser = request.auth
    ? {
      uid: request.auth.uid || null,
      email:
          request.auth.token && request.auth.token.email
            ? request.auth.token.email
            : null,
    }
    : null;

  const clientUser
    = data.user && typeof data.user === 'object'
      ? {
        uid: data.user.uid || null,
        email: data.user.email || null,
      }
      : null;

  const resolvedUser = {
    uid:
      (requestUser && requestUser.uid)
      || (clientUser && clientUser.uid)
      || 'anonymous',
    email:
      (requestUser && requestUser.email)
      || (clientUser && clientUser.email)
      || 'unknown',
    source: requestUser
      ? 'request.auth'
      : clientUser
        ? 'client_payload'
        : 'unknown',
  };

  const logEntry = {
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    severity: data.severity || 'ERROR',
    feature: data.feature || 'general',
    errorType: data.errorType || 'UnknownType',
    message: data.message || 'Sin mensaje de error',
    tag: data.tag || null,
    stackTrace: data.stackTrace || null,
    metadata: data.metadata || {},
    user: resolvedUser,
    requestUser: requestUser,
    clientUser: clientUser,
    platform: data.platform || 'flutter',
  };

  try {
    await admin.firestore().collection('app_logs').add(logEntry);

    return {
      status: 'OK',
      message: 'Log registrado con éxito.',
    };
  } catch (error) {
    console.error('Error crítico al escribir en la colección app_logs:', error);

    return {
      status: 'ERROR',
      message: 'Fallo interno en el logger remoto.',
    };
  }
});

// Exportamos la app de Express envolviéndola en onRequest v2
exports.api = onRequest(
  {
    memory: '256MiB',
    region: 'us-central1',
    secrets: [
      spotifyClientIdSecret,
      spotifyClientSecretSecret,
      spotifyRedirectUriSecret,
      youtubeClientIdSecret,
      youtubeClientSecretSecret,
    ],
  },
  app,
);

exports.syncJobWorker = onTaskDispatched(
  {
    region: 'us-central1',
    memory: '512MiB',
    timeoutSeconds: 540,
    retryConfig: {
      maxAttempts: 5,
      minBackoffSeconds: 5,
      maxBackoffSeconds: 120,
      maxRetrySeconds: 1800,
    },
    rateLimits: {
      maxConcurrentDispatches: 2,
      maxDispatchesPerSecond: 1,
    },
    secrets: [
      spotifyClientIdSecret,
      spotifyClientSecretSecret,
      spotifyRedirectUriSecret,
      youtubeClientIdSecret,
      youtubeClientSecretSecret,
    ],
  },
  async (request) => {
    await processSyncJobTask(request.data || {});
  },
);

