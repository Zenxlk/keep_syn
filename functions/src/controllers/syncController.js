const admin = require('firebase-admin');
const { randomUUID } = require('crypto');
const {
  buildInitialJobData,
  enqueueSyncJob,
} = require('./syncEngine');
const { getValidYouTubeAccessToken } = require('../integrations/youtube/youtubeTokenService');
const { addTrackToPlaylist } = require('../integrations/youtube/youtubeClient');

const db = admin.firestore();

async function addDebugLog({ uid, severity = 'INFO', message, metadata = {} }) {
  await db.collection('app_logs').add({
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    severity,
    feature: 'sync_api',
    errorType: 'SyncApiTrace',
    message,
    tag: 'SyncController',
    stackTrace: null,
    metadata,
    user: {
      uid: uid || 'unknown',
      email: null,
      source: 'sync_api',
    },
    platform: 'functions',
  });
}

exports.createJob = async (req, res) => {
  const { sourcePlatform, targetPlatform, sourcePlaylistId } = req.body;
  const uid = req.user.uid;
  const correlationId = randomUUID();

  if (!sourcePlatform || !targetPlatform || !sourcePlaylistId) {
    return res.error('Faltan parámetros requeridos.', 400);
  }

  try {
    await addDebugLog({
      uid,
      message: 'SYNC_JOB_CREATE_REQUEST',
      metadata: {
        correlationId,
        sourcePlatform,
        targetPlatform,
        sourcePlaylistId,
      },
    });

    // IDEMPOTENCIA: Verificar si ya hay un job activo para esta misma playlist
    const activeJobs = await db.collection('sync_jobs')
      .where('uid', '==', uid)
      .where('sourcePlaylistId', '==', sourcePlaylistId)
      .where('state', 'in', ['idle', 'preparing', 'running'])
      .get();

    if (!activeJobs.empty) {
      const existingJob = activeJobs.docs[0];
      const existingData = existingJob.data();
      const existingState = existingData.state || null;
      let reEnqueued = false;
      let reEnqueueError = null;

      if (['idle', 'preparing'].includes(existingState)) {
        try {
          await enqueueSyncJob({jobId: existingJob.id, uid});
          reEnqueued = true;

          await existingJob.ref.set({
            state: 'preparing',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});

          await db.collection('sync_job_events').add({
            jobId: existingJob.id,
            uid,
            eventType: 'JOB_REENQUEUED',
            payload: {
              correlationId,
              previousState: existingState,
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          await addDebugLog({
            uid,
            message: 'SYNC_JOB_REENQUEUED',
            metadata: {
              correlationId,
              jobId: existingJob.id,
              previousState: existingState,
            },
          });
        } catch (reEnqueueFailure) {
          reEnqueueError = reEnqueueFailure && reEnqueueFailure.message ?
            reEnqueueFailure.message : 'Error desconocido re-encolando job existente.';

          await db.collection('sync_job_events').add({
            jobId: existingJob.id,
            uid,
            eventType: 'JOB_REENQUEUE_FAILED',
            payload: {
              correlationId,
              previousState: existingState,
              code: reEnqueueFailure.code || null,
              message: reEnqueueError,
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          await addDebugLog({
            uid,
            severity: 'ERROR',
            message: 'SYNC_JOB_REENQUEUE_FAILED',
            metadata: {
              correlationId,
              jobId: existingJob.id,
              previousState: existingState,
              code: reEnqueueFailure.code || null,
              message: reEnqueueError,
            },
          });
        }
      }

      await addDebugLog({
        uid,
        message: 'SYNC_JOB_DUPLICATE_ACTIVE',
        metadata: {
          correlationId,
          jobId: existingJob.id,
          sourcePlaylistId,
          state: existingState,
          reEnqueued,
          reEnqueueError,
        },
      });

      const duplicateMessage = reEnqueued ?
        'Ya existia un job activo y fue re-encolado para continuar.' :
        'Ya existe un job de sincronización activo para esta playlist.';

      return res.ok('Ya existe un job de sincronización activo para esta playlist.', {
        jobId: existingJob.id,
        correlationId,
        reEnqueued,
        reEnqueueError,
        duplicateMessage,
        ...existingData,
      });
    }

    // Crear nuevo Job
    const newJobRef = db.collection('sync_jobs').doc();
    const jobData = buildInitialJobData({
      uid,
      sourcePlatform,
      targetPlatform,
      sourcePlaylistId,
      attempt: 1,
    });
    jobData.correlationId = correlationId;

    await newJobRef.set(jobData);
    await addDebugLog({
      uid,
      message: 'SYNC_JOB_CREATED',
      metadata: {
        correlationId,
        jobId: newJobRef.id,
        state: jobData.state,
      },
    });

    let enqueued = true;
    let enqueueErrorMessage = null;

    try {
      await enqueueSyncJob({jobId: newJobRef.id, uid});
      await addDebugLog({
        uid,
        message: 'SYNC_JOB_ENQUEUE_OK',
        metadata: {
          correlationId,
          jobId: newJobRef.id,
        },
      });
    } catch (enqueueError) {
      enqueued = false;
      enqueueErrorMessage = enqueueError && enqueueError.message ?
        enqueueError.message : 'Error desconocido encolando job.';

      // No rompemos el flujo: el job queda creado para debug/reintento manual.
      await newJobRef.set({
        errors: admin.firestore.FieldValue.arrayUnion({
          trackId: 'job',
          code: enqueueError.code || 'JOB_ENQUEUE_FAILED',
          message: enqueueErrorMessage,
          retriable: true,
        }),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      await db.collection('sync_job_events').add({
        jobId: newJobRef.id,
        uid,
        eventType: 'JOB_ENQUEUE_FAILED',
        payload: {
          correlationId,
          code: enqueueError.code || null,
          message: enqueueErrorMessage,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await addDebugLog({
        uid,
        severity: 'ERROR',
        message: 'SYNC_JOB_ENQUEUE_FAILED',
        metadata: {
          correlationId,
          jobId: newJobRef.id,
          code: enqueueError.code || null,
          enqueueErrorMessage,
        },
      });

      console.error('Error encolando job:', {
        uid,
        jobId: newJobRef.id,
        code: enqueueError.code || null,
        message: enqueueErrorMessage,
      });
    }

    // Registro del evento
    await db.collection('sync_job_events').add({
      jobId: newJobRef.id,
      uid,
      eventType: 'JOB_CREATED',
      payload: {
        correlationId,
        sourcePlatform,
        targetPlatform,
        executionMode: 'task_queue_chunked',
        enqueued,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    const message = enqueued ?
      'Job creado exitosamente.' :
      'Job creado, pero no se pudo encolar para ejecucion automatica.';

    return res.ok(message, {
      jobId: newJobRef.id,
      correlationId,
      state: jobData.state,
      executionMode: jobData.execution.mode,
      enqueued,
      enqueueError: enqueueErrorMessage,
      // Usamos fecha local para la respuesta inicial
      createdAt: new Date().toISOString()
    });

  } catch (error) {
    await addDebugLog({
      uid,
      severity: 'ERROR',
      message: 'SYNC_JOB_CREATE_FAILED',
      metadata: {
        correlationId,
        sourcePlatform,
        targetPlatform,
        sourcePlaylistId,
        code: error.code || null,
        message: error.message,
      },
    });

    console.error('Error creando job:', {
      uid,
      correlationId,
      sourcePlatform,
      targetPlatform,
      sourcePlaylistId,
      code: error.code || null,
      message: error.message,
      stack: error.stack,
    });
    return res.error('Fallo al crear el job de sincronización.', 500);
  }
};

exports.getJobStatus = async (req, res) => {
  const { jobId } = req.params;
  try {
    const doc = await db.collection('sync_jobs').doc(jobId).get();
    if (!doc.exists || doc.data().uid !== req.user.uid) {
      return res.error('Job no encontrado o sin permisos.', 404);
    }
    return res.ok('Estado del job recuperado.', { jobId: doc.id, ...doc.data() });
  } catch (error) {
    return res.error('Error al consultar el job.', 500);
  }
};

exports.cancelJob = async (req, res) => {
  const { jobId } = req.params;
  try {
    const docRef = db.collection('sync_jobs').doc(jobId);
    const doc = await docRef.get();

    if (!doc.exists || doc.data().uid !== req.user.uid) {
      return res.error('Job no encontrado.', 404);
    }

    const currentState = doc.data().state;
    if (['success', 'cancelled', 'failed'].includes(currentState)) {
      return res.error(`No se puede cancelar un job en estado: ${currentState}`, 400);
    }

    await docRef.update({
      state: 'cancelled',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return res.ok('Job cancelado exitosamente.', { jobId, state: 'cancelled' });
  } catch (error) {
    return res.error('Error al cancelar el job.', 500);
  }
};

exports.submitReview = async (req, res) => {
  const { jobId } = req.params;
  const uid = req.user.uid;
  const { decisions } = req.body;

  if (!Array.isArray(decisions) || decisions.length === 0) {
    return res.error('Se requiere un array de decisiones no vacío.', 400);
  }

  try {
    const docRef = db.collection('sync_jobs').doc(jobId);
    const doc = await docRef.get();

    if (!doc.exists || doc.data().uid !== uid) {
      return res.error('Job no encontrado o sin permisos.', 404);
    }

    const jobData = doc.data();
    const playlistId = jobData.destination && jobData.destination.playlistId;
    if (!playlistId) {
      return res.error('El job no tiene playlist de destino configurada.', 400);
    }

    const pendingItems = Array.isArray(jobData.review_pending) ? jobData.review_pending : [];
    const pendingById = new Map(
      pendingItems.map((item) => [item.sourceTrack && item.sourceTrack.id, item]),
    );

    const accessToken = await getValidYouTubeAccessToken(uid);

    const results = [];
    let approvedCount = 0;
    let skippedCount = 0;
    const processedSourceIds = new Set();

    for (const decision of decisions) {
      const { sourceTrackId, action, videoId } = decision;
      if (!sourceTrackId || !action) {
        results.push({ sourceTrackId, status: 'error', reason: 'Campos requeridos ausentes.' });
        continue;
      }

      if (!pendingById.has(sourceTrackId)) {
        results.push({ sourceTrackId, status: 'error', reason: 'Track no encontrado en review_pending.' });
        continue;
      }

      if (action === 'approve') {
        if (!videoId) {
          results.push({ sourceTrackId, status: 'error', reason: 'videoId requerido para aprobar.' });
          continue;
        }
        try {
          await addTrackToPlaylist({ accessToken, playlistId, track: { id: videoId } });
          approvedCount++;
          processedSourceIds.add(sourceTrackId);
          results.push({ sourceTrackId, status: 'approved', videoId });
        } catch (addError) {
          results.push({ sourceTrackId, status: 'error', reason: addError.message });
        }
      } else if (action === 'skip') {
        skippedCount++;
        processedSourceIds.add(sourceTrackId);
        results.push({ sourceTrackId, status: 'skipped' });
      } else {
        results.push({ sourceTrackId, status: 'error', reason: `Acción desconocida: ${action}` });
      }
    }

    // Remove processed items from review_pending
    const remainingPending = pendingItems.filter(
      (item) => !processedSourceIds.has(item.sourceTrack && item.sourceTrack.id),
    );

    const updatePayload = {
      review_pending: remainingPending,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (approvedCount > 0) {
      updatePayload['counters.created'] = admin.firestore.FieldValue.increment(approvedCount);
    }
    if (skippedCount > 0) {
      updatePayload['counters.skipped'] = admin.firestore.FieldValue.increment(skippedCount);
    }

    await docRef.update(updatePayload);

    return res.ok('Revisión procesada.', {
      jobId,
      results,
      approvedCount,
      skippedCount,
      remainingReviewCount: remainingPending.length,
    });
  } catch (error) {
    console.error('Error procesando revisión:', { uid, jobId, message: error.message, stack: error.stack });
    return res.error('Error al procesar la revisión.', 500);
  }
};

exports.getLastJob = async (req, res) => {
  try {
    const includeEvents = req.query.includeEvents === '1';
    const eventsLimitRaw = Number.parseInt(req.query.eventsLimit, 10);
    const eventsLimit = Number.isFinite(eventsLimitRaw) ?
      Math.max(1, Math.min(eventsLimitRaw, 50)) : 15;

    const snapshot = await db.collection('sync_jobs')
      .where('uid', '==', req.user.uid)
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();

    if (snapshot.empty) {
      return res.ok('No hay jobs previos.', null);
    }

    const doc = snapshot.docs[0];
    const payload = { jobId: doc.id, ...doc.data() };

    if (includeEvents) {
      const eventsSnapshot = await db.collection('sync_job_events')
        .where('jobId', '==', doc.id)
        .orderBy('createdAt', 'desc')
        .limit(eventsLimit)
        .get();

      payload.events = eventsSnapshot.docs.map((eventDoc) => ({
        eventId: eventDoc.id,
        ...eventDoc.data(),
      }));
    }

    return res.ok('Último job recuperado.', payload);
  } catch (error) {
    return res.error('Error recuperando el último job.', 500);
  }
};