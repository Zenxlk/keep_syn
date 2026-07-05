const admin = require('firebase-admin');
const { getFunctions } = require('firebase-admin/functions');
const {
  createTrackSignature,
  findBestTrackMatch,
  getTrackArtists,
  getTrackIsrc,
} = require('../core/trackMatcher');
const { getValidSpotifyAccessToken } = require('../integrations/spotify/spotifyTokenService');
const { getValidYouTubeAccessToken } = require('../integrations/youtube/youtubeTokenService');
const {
  getPlaylist: getSpotifyPlaylist,
  getPlaylistTracks: getSpotifyPlaylistTracks,
} = require('../integrations/spotify/spotifyClient');
const {
  addTrackToPlaylist: addYouTubeTrackToPlaylist,
  createPlaylist: createYouTubePlaylist,
  listPlaylistTracks: listYouTubePlaylistTracks,
  listPlaylists: listYouTubePlaylists,
  searchTracks: searchYouTubeTracks,
} = require('../integrations/youtube/youtubeClient');

const db = admin.firestore();
const DEFAULT_PAGE_SIZE = 100;
const DEFAULT_QUEUE_NAME = 'syncJobWorker';
const DEFAULT_FUNCTION_REGION = 'us-central1';
const TASK_DISPATCH_DEADLINE_SECONDS = 540;
const MAX_RATE_LIMIT_RETRIES = 5;
const BASE_BACKOFF_MS = 750;
const DEFAULT_DAILY_ESTIMATED_QUOTA_BUDGET = 9000;
const DEFAULT_MIN_QUOTA_BUFFER = 100;
const YOUTUBE_QUOTA_COSTS = {
  listPlaylists: 1,
  listPlaylistTracks: 1,
  searchTracks: 0, // ytmusic-api no consume quota de la Data API
  addTrackToPlaylist: 50,
  createPlaylist: 50,
};

let syncPlatformRegistryOverride = null;

/**
 * @param {number} ms
 * @return {Promise<void>}
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * @param {string} kind
 * @param {string} platform
 * @return {Error}
 */
function createUnsupportedPlatformError(kind, platform) {
  const error = new Error(
    `${kind} platform no soportada todavia: ${platform}. `
      + 'Inyecta un adapter antes de ejecutar el sync.',
  );
  error.code = `${kind.toUpperCase()}_PLATFORM_UNSUPPORTED`;
  return error;
}

/**
 * @param {Object=} registry
 */
function setSyncPlatformRegistry(registry) {
  syncPlatformRegistryOverride = registry;
}

/**
 * @return {Object}
 */
function getSyncPlatformRegistry() {
  if (syncPlatformRegistryOverride) {
    return syncPlatformRegistryOverride;
  }

  return {
    source: {
      spotify: createSpotifySourceAdapter(),
    },
    target: {
      youtube: createYouTubeTargetAdapter(),
    },
  };
}

/**
 * @return {Object}
 */
function createSpotifySourceAdapter() {
  return {
    async getPlaylist({ uid, playlistId }) {
      const accessToken = await getValidSpotifyAccessToken(uid);
      const playlist = await getSpotifyPlaylist({ accessToken, playlistId });

      return {
        id: playlist.id,
        name: playlist.name || `playlist_${playlistId}`,
        description: playlist.description || '',
        totalTracks: playlist.items && typeof playlist.items.total === 'number'
          ? playlist.items.total : 0,
        imageUrl: Array.isArray(playlist.images) && playlist.images[0]
          ? playlist.images[0].url : null,
      };
    },

    async getTracksPage({ uid, playlistId, offset = 0, limit = DEFAULT_PAGE_SIZE }) {
      const accessToken = await getValidSpotifyAccessToken(uid);
      const response = await getSpotifyPlaylistTracks({
        accessToken,
        playlistId,
        offset,
        limit,
      });

      const items = Array.isArray(response.items) ? response.items : [];
      const tracks = items
        .map((item) => normalizeSpotifyTrack(item.item || item))
        .filter((track) => Boolean(track && track.id));

      const total = typeof response.total === 'number' ? response.total : tracks.length;
      const nextOffset = offset + items.length;

      return {
        tracks,
        total,
        offset,
        nextOffset,
        hasMore: Boolean(response.next) || nextOffset < total,
      };
    },
  };
}

/**
 * @return {Object}
 */
function createYouTubeTargetAdapter() {
  return {
    async listPlaylists({ uid, limit = 200 }) {
      const accessToken = await getValidYouTubeAccessToken(uid);
      return listYouTubePlaylists({ accessToken, limit });
    },

    async createPlaylist({ uid, name, description }) {
      const accessToken = await getValidYouTubeAccessToken(uid);
      return createYouTubePlaylist({ accessToken, name, description });
    },

    async listPlaylistTracks({ uid, playlistId, limit = 500 }) {
      const accessToken = await getValidYouTubeAccessToken(uid);
      return listYouTubePlaylistTracks({ accessToken, playlistId, limit });
    },

    async searchTracks({ uid, track, limit = 5 }) {
      const accessToken = await getValidYouTubeAccessToken(uid);
      return searchYouTubeTracks({ accessToken, track, limit });
    },

    async addTrackToPlaylist({ uid, playlistId, track }) {
      const accessToken = await getValidYouTubeAccessToken(uid);
      return addYouTubeTrackToPlaylist({ accessToken, playlistId, track });
    },
  };
}

/**
 * @param {Object} track
 * @return {Object}
 */
function normalizeSpotifyTrack(track) {
  const artists = Array.isArray(track.artists) ? track.artists.map(
    (artist) => artist.name,
  ).filter(Boolean) : [];

  return {
    id: track.id,
    platform: 'spotify',
    title: track.name || '',
    artists,
    album: track.album && track.album.name ? track.album.name : '',
    isrc: track.external_ids && track.external_ids.isrc
      ? track.external_ids.isrc : null,
    durationMs: track.duration_ms || null,
    uri: track.uri || null,
    externalIds: {
      isrc: track.external_ids && track.external_ids.isrc
        ? track.external_ids.isrc : null,
    },
  };
}

/**
 * @param {Object} track
 * @return {Object}
 */
function normalizeTrackForIndex(track = {}) {
  return {
    id: track.id || track.trackId || null,
    title: track.title || track.name || '',
    artists: getTrackArtists(track),
    album: track.album || '',
    isrc: getTrackIsrc(track),
  };
}

/**
 * @param {string[]} initialIds
 * @param {string[]} initialIsrcs
 * @param {string[]} initialSigs
 * @return {Object}
 */
function _buildIndex(initialIds = [], initialIsrcs = [], initialSigs = []) {
  const ids = new Set(initialIds);
  const isrcs = new Set(initialIsrcs);
  const signatures = new Set(initialSigs);

  const addTrack = (track) => {
    const normalized = normalizeTrackForIndex(track);
    if (normalized.id) ids.add(normalized.id);
    if (normalized.isrc) isrcs.add(normalized.isrc);
    const signature = createTrackSignature(normalized);
    if (signature) signatures.add(signature);
  };

  return {
    addTrack,
    hasTrack(track) {
      const normalized = normalizeTrackForIndex(track);
      const signature = createTrackSignature(normalized);
      return (normalized.id && ids.has(normalized.id))
        || (normalized.isrc && isrcs.has(normalized.isrc))
        || (signature && signatures.has(signature));
    },
    toSnapshot() {
      return { ids: [...ids], isrcs: [...isrcs], sigs: [...signatures] };
    },
  };
}

/**
 * @param {Array<Object>} tracks
 * @return {Object}
 */
function createDestinationIndex(tracks = []) {
  const index = _buildIndex();
  tracks.forEach(index.addTrack);
  return index;
}

/**
 * Rebuilds a destination index from a stored Firestore snapshot, avoiding
 * a redundant listPlaylistTracks API call on subsequent sync chunks.
 * @param {Object} snapshot
 * @param {string[]} snapshot.ids
 * @param {string[]} snapshot.isrcs
 * @param {string[]} snapshot.sigs
 * @return {Object}
 */
function rebuildDestinationIndex(snapshot = {}) {
  return _buildIndex(
    Array.isArray(snapshot.ids) ? snapshot.ids : [],
    Array.isArray(snapshot.isrcs) ? snapshot.isrcs : [],
    Array.isArray(snapshot.sigs) ? snapshot.sigs : [],
  );
}

/**
 * @param {Error} error
 * @return {boolean}
 */
function isRateLimitError(error) {
  return Boolean(
    error
      && error.response
      && error.response.status === 429,
  );
}

/**
 * @param {Error} error
 * @param {number} attempt
 * @return {number}
 */
function getRetryDelayMs(error, attempt) {
  if (isRateLimitError(error)) {
    const retryAfter = error.response.headers && error.response.headers['retry-after'];
    if (retryAfter) {
      return Number.parseInt(retryAfter, 10) * 1000;
    }
  }

  return BASE_BACKOFF_MS * (2 ** Math.max(attempt - 1, 0));
}

/**
 * @param {Object|null} providerError
 * @return {string|null}
 */
function extractProviderReason(providerError) {
  if (!providerError || typeof providerError !== 'object') {
    return null;
  }

  const errorObject = providerError.error;
  if (!errorObject || typeof errorObject !== 'object') {
    return null;
  }

  const errors = Array.isArray(errorObject.errors) ? errorObject.errors : [];
  if (!errors.length) {
    return null;
  }

  const reason = errors[0].reason;
  return typeof reason === 'string' ? reason : null;
}

/**
 * @param {number|null} providerStatus
 * @param {string|null} providerReason
 * @return {boolean}
 */
function isQuotaExceededError(providerStatus, providerReason) {
  if (providerStatus !== 403) {
    return false;
  }

  const normalizedReason = typeof providerReason === 'string'
    ? providerReason.toLowerCase() : '';

  return [
    'quotaexceeded',
    'dailylimitexceeded',
    'userratelimitexceeded',
    'ratelimitexceeded',
  ].includes(normalizedReason);
}

/**
 * @param {Date=} now
 * @return {string}
 */
function getQuotaDayKey(now = new Date()) {
  return now.toISOString().slice(0, 10);
}

/**
 * @return {Object}
 */
function getQuotaGuardConfig() {
  const configuredBudget = Number.parseInt(
    process.env.SYNC_YOUTUBE_DAILY_QUOTA_BUDGET
      || `${DEFAULT_DAILY_ESTIMATED_QUOTA_BUDGET}`,
    10,
  );
  const configuredBuffer = Number.parseInt(
    process.env.SYNC_YOUTUBE_MIN_QUOTA_BUFFER
      || `${DEFAULT_MIN_QUOTA_BUFFER}`,
    10,
  );

  return {
    dailyBudget: Number.isFinite(configuredBudget)
      ? Math.max(1000, configuredBudget) : DEFAULT_DAILY_ESTIMATED_QUOTA_BUDGET,
    minBuffer: Number.isFinite(configuredBuffer)
      ? Math.max(0, configuredBuffer) : DEFAULT_MIN_QUOTA_BUFFER,
  };
}

/**
 * @param {string} message
 * @param {Object=} metadata
 * @return {Error}
 */
function createQuotaGuardError(message, metadata = {}) {
  const error = new Error(message);
  error.code = 'TARGET_QUOTA_GUARD';
  error.providerReason = 'quota_guard';
  error.metadata = metadata;
  return error;
}

/**
 * @param {Error} error
 * @param {number|null} providerStatus
 * @param {string|null} providerReason
 * @return {boolean}
 */
function isQuotaAbortError(error, providerStatus, providerReason) {
  return Boolean(
    error && error.code === 'TARGET_QUOTA_GUARD',
  ) || isQuotaExceededError(providerStatus, providerReason);
}

/**
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function consumeEstimatedYouTubeQuota({ uid, jobId, units, operation }) {
  if (!units || units <= 0) {
    return {
      dayKey: getQuotaDayKey(),
      consumed: 0,
      remaining: getQuotaGuardConfig().dailyBudget,
      budget: getQuotaGuardConfig().dailyBudget,
      minBuffer: getQuotaGuardConfig().minBuffer,
    };
  }

  const config = getQuotaGuardConfig();
  const dayKey = getQuotaDayKey();
  const quotaDocId = `${uid}_${dayKey}`;
  const quotaRef = db.collection('sync_quota_controls').doc(quotaDocId);

  const txResult = await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(quotaRef);
    const data = snapshot.exists ? snapshot.data() : {};
    const currentEstimated = typeof data.estimatedUsed === 'number'
      ? data.estimatedUsed : 0;
    const remainingBefore = config.dailyBudget - currentEstimated;
    const remainingAfter = remainingBefore - units;

    if (remainingAfter < config.minBuffer) {
      throw createQuotaGuardError(
        'Presupuesto de cuota estimada agotado para hoy.',
        {
          budget: config.dailyBudget,
          minBuffer: config.minBuffer,
          estimatedUsed: currentEstimated,
          attemptedUnits: units,
          remainingBefore,
          dayKey,
          operation,
        },
      );
    }

    tx.set(quotaRef, {
      uid,
      dayKey,
      estimatedUsed: currentEstimated + units,
      budget: config.dailyBudget,
      minBuffer: config.minBuffer,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastJobId: jobId || null,
      lastOperation: operation || null,
    }, { merge: true });

    return {
      dayKey,
      consumed: units,
      remaining: remainingAfter,
      budget: config.dailyBudget,
      minBuffer: config.minBuffer,
    };
  });

  return txResult;
}

/**
 * @param {Function} operation
 * @param {Object=} context
 * @return {Promise<*>}
 */
async function withRateLimitRetry(operation, context = {}) {
  let attempt = 0;

  while (attempt < MAX_RATE_LIMIT_RETRIES) {
    attempt += 1;
    try {
      return await operation();
    } catch (error) {
      if (!isRateLimitError(error) || attempt >= MAX_RATE_LIMIT_RETRIES) {
        throw error;
      }

      const waitMs = getRetryDelayMs(error, attempt);
      await addJobEvent(context.jobId || null, context.uid || null,
        'SYNC_RATE_LIMIT_RETRY', {
          attempt,
          waitMs,
          operation: context.operation || 'unknown',
          platform: context.platform || 'unknown',
        });
      await sleep(waitMs);
    }
  }

  throw new Error('RATE_LIMIT_RETRY_EXHAUSTED');
}

/**
 * @param {?string} jobId
 * @param {?string} uid
 * @param {string} eventType
 * @param {Object=} payload
 * @return {Promise<void>}
 */
async function addJobEvent(jobId, uid, eventType, payload = {}) {
  await db.collection('sync_job_events').add({
    jobId,
    uid,
    eventType,
    payload,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * @param {Object} options
 * @return {Promise<void>}
 */
async function logSyncError({ uid, message, error, metadata = {}, severity = 'ERROR' }) {
  await db.collection('app_logs').add({
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    severity,
    feature: 'sync_engine',
    errorType: error && error.code ? error.code : 'SyncEngineError',
    message,
    tag: 'SyncEngine',
    stackTrace: error && error.stack ? error.stack : null,
    metadata,
    user: {
      uid: uid || 'unknown',
      email: null,
      source: 'sync_engine',
    },
    platform: 'functions',
  });
}

/**
 * @param {Object} params
 * @return {Object}
 */
function buildInitialJobData({
  uid,
  sourcePlatform,
  targetPlatform,
  sourcePlaylistId,
  attempt = 1,
}) {
  return {
    uid,
    sourcePlatform,
    targetPlatform,
    sourcePlaylistId,
    state: 'preparing',
    progress: 0,
    attempt,
    cursor: {
      offset: 0,
      pageSize: DEFAULT_PAGE_SIZE,
      hasMore: true,
    },
    counters: {
      processed: 0,
      created: 0,
      updated: 0,
      skipped: 0,
      failed: 0,
    },
    errors: [],
    failed_tracks: [],
    review_pending: [],
    sourceSnapshot: null,
    destination: null,
    execution: {
      mode: 'task_queue_chunked',
      pageSize: DEFAULT_PAGE_SIZE,
      queueName: DEFAULT_QUEUE_NAME,
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    startedAt: null,
    completedAt: null,
  };
}

/**
 * @param {Object} jobData
 * @param {Object} sourcePlaylist
 * @return {string}
 */
function getDesiredTargetPlaylistName(jobData, sourcePlaylist) {
  return sourcePlaylist.name || jobData.sourcePlaylistId;
}

/**
 * @param {Object} jobData
 * @param {Object} countersDelta
 * @return {string}
 */
function resolveFinalState(jobData, countersDelta) {
  const existingFailed = Array.isArray(jobData.failed_tracks) ? jobData.failed_tracks.length : 0;
  const existingReview = Array.isArray(jobData.review_pending) ? jobData.review_pending.length : 0;
  const totalFailed = existingFailed + countersDelta.failed;
  const totalReview = existingReview + countersDelta.reviewPending;
  const totalCreated = (jobData.counters && jobData.counters.created || 0) + countersDelta.created;
  const totalSkipped = (jobData.counters && jobData.counters.skipped || 0) + countersDelta.skipped;

  if (!totalFailed && !totalReview) {
    return 'success';
  }

  if (totalCreated || totalSkipped) {
    return 'partial_success';
  }

  return 'failed';
}

/**
 * @param {Object} jobData
 * @return {number}
 */
function getProcessedCount(jobData) {
  return jobData && jobData.counters && typeof jobData.counters.processed === 'number'
    ? jobData.counters.processed : 0;
}

/**
 * @param {Object} jobData
 * @return {number}
 */
function getTotalTracks(jobData) {
  return jobData && jobData.sourceSnapshot
    && typeof jobData.sourceSnapshot.totalTracks === 'number'
    ? jobData.sourceSnapshot.totalTracks : 0;
}

/**
 * @param {Object} jobData
 * @param {number} processedDelta
 * @return {number}
 */
function computeProgress(jobData, processedDelta) {
  const totalTracks = getTotalTracks(jobData);
  if (!totalTracks) return 0;
  const processed = getProcessedCount(jobData) + processedDelta;
  return Math.min(100, Math.round((processed / totalTracks) * 100));
}

/**
 * @param {Object} jobRef
 * @param {Object} jobData
 * @return {Promise<boolean>}
 */
async function isCancelled(jobRef, jobData) {
  if (jobData.state === 'cancelled') {
    return true;
  }

  const snapshot = await jobRef.get();
  return snapshot.exists && snapshot.data().state === 'cancelled';
}

/**
 * @param {Object} jobRef
 * @param {Object} jobData
 * @param {Object} sourceAdapter
 * @return {Promise<Object>}
 */
async function ensureSourceSnapshot(jobRef, jobData, sourceAdapter) {
  if (jobData.sourceSnapshot && jobData.sourceSnapshot.id) {
    return jobData.sourceSnapshot;
  }

  const sourceSnapshot = await withRateLimitRetry(() => sourceAdapter.getPlaylist({
    uid: jobData.uid,
    playlistId: jobData.sourcePlaylistId,
  }), {
    jobId: jobRef.id,
    uid: jobData.uid,
    operation: 'get_source_playlist',
    platform: jobData.sourcePlatform,
  });

  await jobRef.set({
    sourceSnapshot,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return sourceSnapshot;
}

/**
 * @param {Object} targetAdapter
 * @return {void}
 */
function assertTargetAdapterContract(targetAdapter) {
  const requiredMethods = [
    'listPlaylists',
    'createPlaylist',
    'listPlaylistTracks',
    'searchTracks',
    'addTrackToPlaylist',
  ];

  requiredMethods.forEach((method) => {
    if (!targetAdapter || typeof targetAdapter[method] !== 'function') {
      const error = new Error(`Target adapter incompleto: falta ${method}.`);
      error.code = 'TARGET_ADAPTER_INVALID';
      throw error;
    }
  });
}

/**
 * @param {Object} jobRef
 * @param {Object} jobData
 * @param {Object} sourceSnapshot
 * @param {Object} targetAdapter
 * @return {Promise<Object>}
 */
async function ensureTargetPlaylist(jobRef, jobData, sourceSnapshot, targetAdapter) {
  if (jobData.destination && jobData.destination.playlistId) {
    return jobData.destination;
  }

  assertTargetAdapterContract(targetAdapter);
  const desiredName = getDesiredTargetPlaylistName(jobData, sourceSnapshot);
  await consumeEstimatedYouTubeQuota({
    uid: jobData.uid,
    jobId: jobRef.id,
    units: YOUTUBE_QUOTA_COSTS.listPlaylists,
    operation: 'list_target_playlists',
  });
  const existingPlaylists = await withRateLimitRetry(() => targetAdapter.listPlaylists({
    uid: jobData.uid,
    limit: 200,
  }), {
    jobId: jobRef.id,
    uid: jobData.uid,
    operation: 'list_target_playlists',
    platform: jobData.targetPlatform,
  });

  const found = Array.isArray(existingPlaylists) ? existingPlaylists.find((playlist) => {
    const playlistName = playlist.snippet?.title || playlist.name || '';
    return String(playlistName).trim().toLowerCase()
      === String(desiredName).trim().toLowerCase();
  }) : null;

  if (!found) {
    await consumeEstimatedYouTubeQuota({
      uid: jobData.uid,
      jobId: jobRef.id,
      units: YOUTUBE_QUOTA_COSTS.createPlaylist,
      operation: 'create_target_playlist',
    });
  }

  const playlist = found || await withRateLimitRetry(() => targetAdapter.createPlaylist({
    uid: jobData.uid,
    name: desiredName,
    description: sourceSnapshot.description || 'Playlist sincronizada por KeepSyn.',
  }), {
    jobId: jobRef.id,
    uid: jobData.uid,
    operation: 'create_target_playlist',
    platform: jobData.targetPlatform,
  });

  const destination = {
    playlistId: playlist.id || playlist.playlistId,
    name: playlist.name || desiredName,
    existed: Boolean(found),
  };

  await jobRef.set({
    destination,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return destination;
}

/**
 * @param {Object} sourceTrack
 * @param {Object} matchResult
 * @return {Object}
 */
function buildReviewItem(sourceTrack, matchResult) {
  return {
    sourceTrack,
    confidence: matchResult.confidence,
    strategy: matchResult.strategy,
    options: matchResult.reviewOptions,
    createdAt: new Date().toISOString(),
  };
}

/**
 * @param {Object} sourceTrack
 * @param {Object} matchResult
 * @return {Object}
 */
function buildFailedItem(sourceTrack, matchResult) {
  return {
    sourceTrack,
    confidence: matchResult.confidence,
    strategy: matchResult.strategy,
    options: matchResult.reviewOptions,
    reason: matchResult.reason || 'Sin match valido en la plataforma destino.',
    createdAt: new Date().toISOString(),
  };
}

/**
 * @param {Object} sourceTrack
 * @param {string} code
 * @param {string} message
 * @param {boolean=} retriable
 * @return {Object}
 */
function buildTrackError(sourceTrack, code, message, retriable = false) {
  return {
    trackId: sourceTrack.id || sourceTrack.uri || sourceTrack.title || 'unknown',
    code,
    message,
    retriable,
  };
}

/**
 * @param {Object} jobRef
 * @param {Object} jobData
 * @param {number} processedDelta
 * @param {Object=} extra
 * @return {Promise<void>}
 */
async function markCancelled(jobRef, jobData, processedDelta, extra = {}) {
  await jobRef.update({
    state: 'cancelled',
    progress: computeProgress(jobData, processedDelta),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...extra,
  });

  await addJobEvent(jobRef.id, jobData.uid, 'SYNC_JOB_CANCELLED', {
    processed: getProcessedCount(jobData) + processedDelta,
  });
}

/**
 * @param {Object} params
 * @return {Promise<void>}
 */
async function applyChunkUpdate({
  jobRef,
  jobData,
  cursor,
  countersDelta,
  reviewPending,
  failedTracks,
  errors,
  state,
  hasMore,
  forceComputedProgress = false,
  extraPayload = {},
}) {
  const nextProgress = hasMore || forceComputedProgress
    ? computeProgress(jobData, countersDelta.processed) : 100;

  const updatePayload = {
    state,
    'progress': nextProgress,
    'cursor': {
      offset: cursor.offset,
      pageSize: cursor.pageSize,
      hasMore,
    },
    'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    'counters.processed': admin.firestore.FieldValue.increment(countersDelta.processed),
    'counters.created': admin.firestore.FieldValue.increment(countersDelta.created),
    'counters.updated': admin.firestore.FieldValue.increment(countersDelta.updated),
    'counters.skipped': admin.firestore.FieldValue.increment(countersDelta.skipped),
    'counters.failed': admin.firestore.FieldValue.increment(countersDelta.failed),
    ...extraPayload,
  };

  if (!hasMore) {
    updatePayload.completedAt = admin.firestore.FieldValue.serverTimestamp();
  }

  if (reviewPending.length) {
    updatePayload.review_pending = admin.firestore.FieldValue.arrayUnion(...reviewPending);
  }

  if (failedTracks.length) {
    updatePayload.failed_tracks = admin.firestore.FieldValue.arrayUnion(...failedTracks);
  }

  if (errors.length) {
    updatePayload.errors = admin.firestore.FieldValue.arrayUnion(...errors);
  }

  await jobRef.update(updatePayload);
}

/**
 * @param {Object} params
 * @return {Promise<void>}
 */
async function enqueueSyncJob({ jobId, uid, delaySeconds = 0 }) {
  const queue = getFunctions().taskQueue(
    `locations/${DEFAULT_FUNCTION_REGION}/functions/${DEFAULT_QUEUE_NAME}`,
  );
  await queue.enqueue({ jobId, uid }, {
    scheduleDelaySeconds: delaySeconds,
    dispatchDeadlineSeconds: TASK_DISPATCH_DEADLINE_SECONDS,
  });
}

/**
 * @param {Object} params
 * @return {Promise<void>}
 */
async function processSyncJobTask({ jobId, uid }) {
  if (!jobId || !uid) {
    return;
  }

  const jobRef = db.collection('sync_jobs').doc(jobId);
  const snapshot = await jobRef.get();

  if (!snapshot.exists) {
    return;
  }

  const jobData = snapshot.data();
  if (jobData.uid !== uid) {
    return;
  }

  if (['success', 'partial_success', 'failed', 'cancelled'].includes(jobData.state)) {
    return;
  }

  try {
    const registry = getSyncPlatformRegistry();
    const sourceAdapter = registry.source[jobData.sourcePlatform];
    const targetAdapter = registry.target[jobData.targetPlatform];

    if (!sourceAdapter) {
      throw createUnsupportedPlatformError('source', jobData.sourcePlatform);
    }

    if (!targetAdapter) {
      throw createUnsupportedPlatformError('target', jobData.targetPlatform);
    }

    const sourceSnapshot = await ensureSourceSnapshot(jobRef, jobData, sourceAdapter);
    const destination = await ensureTargetPlaylist(
      jobRef,
      jobData,
      sourceSnapshot,
      targetAdapter,
    );

    if (await isCancelled(jobRef, jobData)) {
      await markCancelled(jobRef, jobData, 0);
      return;
    }

    const cursor = jobData.cursor || {
      offset: 0,
      pageSize: DEFAULT_PAGE_SIZE,
      hasMore: true,
    };

    await jobRef.set({
      state: 'running',
      startedAt: jobData.startedAt || admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const page = await withRateLimitRetry(() => sourceAdapter.getTracksPage({
      uid,
      playlistId: jobData.sourcePlaylistId,
      offset: cursor.offset,
      limit: cursor.pageSize,
    }), {
      jobId,
      uid,
      operation: 'get_source_tracks_page',
      platform: jobData.sourcePlatform,
    });

    let destinationIndex;
    const storedSnapshot = jobData.destinationIndex || null;

    if (storedSnapshot && Array.isArray(storedSnapshot.ids)) {
      // Chunks after the first: rebuild from Firestore snapshot (0 quota cost).
      destinationIndex = rebuildDestinationIndex(storedSnapshot);
    } else {
      // First chunk: fetch existing tracks and save the snapshot for future chunks.
      await consumeEstimatedYouTubeQuota({
        uid,
        jobId,
        units: YOUTUBE_QUOTA_COSTS.listPlaylistTracks,
        operation: 'list_target_playlist_tracks',
      });

      const existingDestinationTracks = await withRateLimitRetry(() =>
        targetAdapter.listPlaylistTracks({
          uid,
          playlistId: destination.playlistId,
        }), {
        jobId,
        uid,
        operation: 'list_target_playlist_tracks',
        platform: jobData.targetPlatform,
      });

      destinationIndex = createDestinationIndex(existingDestinationTracks);

      await jobRef.set({
        destinationIndex: destinationIndex.toSnapshot(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    const reviewPending = [];
    const failedTracks = [];
    const errors = [];
    const addedTracks = [];
    let quotaAbortContext = null;
    const countersDelta = {
      processed: 0,
      created: 0,
      updated: 0,
      skipped: 0,
      failed: 0,
      reviewPending: 0,
    };

    for (let index = 0; index < page.tracks.length; index += 1) {
      const sourceTrack = page.tracks[index];

      if (index % 10 === 0 && await isCancelled(jobRef, jobData)) {
        const consumed = cursor.offset + countersDelta.processed;
        await markCancelled(jobRef, jobData, countersDelta.processed, {
          cursor: {
            offset: consumed,
            pageSize: cursor.pageSize,
            hasMore: true,
          },
        });
        return;
      }

      try {
        if (destinationIndex.hasTrack(sourceTrack)) {
          countersDelta.processed += 1;
          countersDelta.skipped += 1;
          continue;
        }

        await consumeEstimatedYouTubeQuota({
          uid,
          jobId,
          units: YOUTUBE_QUOTA_COSTS.searchTracks,
          operation: 'search_target_tracks',
        });

        const candidates = await withRateLimitRetry(() => targetAdapter.searchTracks({
          uid,
          track: sourceTrack,
          limit: 5,
        }), {
          jobId,
          uid,
          operation: 'search_target_tracks',
          platform: jobData.targetPlatform,
        });

        const matchResult = findBestTrackMatch(sourceTrack, candidates);

        if (matchResult.status === 'success' && matchResult.matchedTrack) {
          if (destinationIndex.hasTrack(matchResult.matchedTrack)) {
            countersDelta.processed += 1;
            countersDelta.skipped += 1;
            continue;
          }

          await consumeEstimatedYouTubeQuota({
            uid,
            jobId,
            units: YOUTUBE_QUOTA_COSTS.addTrackToPlaylist,
            operation: 'add_track_to_playlist',
          });

          await withRateLimitRetry(() => targetAdapter.addTrackToPlaylist({
            uid,
            playlistId: destination.playlistId,
            track: matchResult.matchedTrack,
          }), {
            jobId,
            uid,
            operation: 'add_track_to_playlist',
            platform: jobData.targetPlatform,
          });

          destinationIndex.addTrack(matchResult.matchedTrack);
          addedTracks.push(matchResult.matchedTrack);
          countersDelta.processed += 1;
          countersDelta.created += 1;
          continue;
        }

        if (matchResult.status === 'review_pending') {
          reviewPending.push(buildReviewItem(sourceTrack, matchResult));
          countersDelta.processed += 1;
          countersDelta.reviewPending += 1;
          continue;
        }

        failedTracks.push(buildFailedItem(sourceTrack, matchResult));
        errors.push(buildTrackError(
          sourceTrack,
          'TRACK_MATCH_FAILED',
          matchResult.reason || 'No hubo coincidencia suficiente.',
        ));
        countersDelta.processed += 1;
        countersDelta.failed += 1;
      } catch (trackError) {
        const providerStatus = trackError && trackError.response
          ? trackError.response.status : null;
        const providerError = trackError && trackError.response
          ? trackError.response.data : null;
        const providerReason = extractProviderReason(providerError);
        const quotaExceeded = isQuotaAbortError(
          trackError,
          providerStatus,
          providerReason,
        );
        const isAlreadyInPlaylist = providerStatus === 409
          || providerReason === 'videoAlreadyInPlaylist';

        if (isAlreadyInPlaylist) {
          countersDelta.processed += 1;
          countersDelta.skipped += 1;
          continue;
        }

        const message = trackError && trackError.message
          ? trackError.message : 'Error inesperado procesando track.';
        const reason = providerReason
          ? `${message} (${providerReason})` : message;
        const guardMetadata = trackError && trackError.metadata
          ? trackError.metadata : null;
        const fullReason = guardMetadata
          ? `${reason} [quotaGuard=${JSON.stringify(guardMetadata)}]` : reason;

        failedTracks.push({
          sourceTrack,
          confidence: 0,
          strategy: 'runtime_error',
          options: [],
          reason,
          quotaGuard: guardMetadata,
          createdAt: new Date().toISOString(),
        });

        errors.push(buildTrackError(
          sourceTrack,
          quotaExceeded ? 'TARGET_QUOTA_EXCEEDED'
            : (providerStatus ? `TARGET_HTTP_${providerStatus}` : 'TARGET_RUNTIME_ERROR'),
          fullReason,
          quotaExceeded || providerStatus === 429
              || (providerStatus != null && providerStatus >= 500),
        ));

        countersDelta.processed += 1;
        countersDelta.failed += 1;

        if (quotaExceeded) {
          quotaAbortContext = {
            providerStatus,
            providerReason: providerReason || trackError.providerReason || 'quota_guard',
            message: 'Se alcanzo la cuota de la API destino durante la sincronizacion.',
            quotaGuard: guardMetadata,
          };
          break;
        }
      }
    }

    if (addedTracks.length > 0) {
      const newEntries = rebuildDestinationIndex({});
      addedTracks.forEach((t) => newEntries.addTrack(t));
      const diff = newEntries.toSnapshot();
      const indexUpdate = {};
      if (diff.ids.length) {
        indexUpdate['destinationIndex.ids']
          = admin.firestore.FieldValue.arrayUnion(...diff.ids);
      }
      if (diff.isrcs.length) {
        indexUpdate['destinationIndex.isrcs']
          = admin.firestore.FieldValue.arrayUnion(...diff.isrcs);
      }
      if (diff.sigs.length) {
        indexUpdate['destinationIndex.sigs']
          = admin.firestore.FieldValue.arrayUnion(...diff.sigs);
      }
      if (Object.keys(indexUpdate).length) {
        await jobRef.update(indexUpdate);
      }
    }

    const hasMore = quotaAbortContext ? false : Boolean(page.hasMore);
    const nextOffset = quotaAbortContext
      ? cursor.offset + countersDelta.processed
      : (typeof page.nextOffset === 'number'
        ? page.nextOffset : cursor.offset + page.tracks.length);
    const nextState = hasMore ? 'running' : resolveFinalState(jobData, countersDelta);

    await applyChunkUpdate({
      jobRef,
      jobData,
      cursor: {
        offset: nextOffset,
        pageSize: cursor.pageSize,
      },
      countersDelta,
      reviewPending,
      failedTracks,
      errors,
      state: nextState,
      hasMore,
      forceComputedProgress: Boolean(quotaAbortContext),
      extraPayload: quotaAbortContext ? {
        abortReason: 'target_quota_exceeded',
        quotaExceeded: true,
        providerStatus: quotaAbortContext.providerStatus,
        providerReason: quotaAbortContext.providerReason,
        lastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
      } : {},
    });

    await addJobEvent(jobId, uid, quotaAbortContext
      ? 'SYNC_JOB_ABORTED_QUOTA'
      : (hasMore ? 'SYNC_BATCH_PROCESSED' : 'SYNC_JOB_COMPLETED'), {
      nextOffset,
      hasMore,
      countersDelta,
      destinationPlaylistId: destination.playlistId,
      quotaAbort: quotaAbortContext,
    });

    if (hasMore && !quotaAbortContext) {
      await enqueueSyncJob({ jobId, uid });
    } else {
      const terminalState = quotaAbortContext ? 'failed' : nextState;
      const playlistName = jobData.sourceSnapshot && jobData.sourceSnapshot.name;
      await sendSyncNotification(uid, terminalState, playlistName);
    }
  } catch (error) {
    const providerStatus = error && error.response ? error.response.status : null;
    const providerError = error && error.response ? error.response.data : null;
    const providerReason = extractProviderReason(providerError);
    const quotaExceeded = isQuotaAbortError(error, providerStatus, providerReason);

    await jobRef.set({
      state: 'failed',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      abortReason: quotaExceeded ? 'target_quota_exceeded' : null,
      quotaExceeded,
      providerStatus,
      providerReason: providerReason || (quotaExceeded ? 'quota_guard' : null),
      lastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
      errors: admin.firestore.FieldValue.arrayUnion({
        trackId: 'job',
        code: quotaExceeded ? 'TARGET_QUOTA_EXCEEDED'
          : (error.code || 'SYNC_ENGINE_FAILED'),
        message: quotaExceeded
          ? 'Cuota de YouTube API alcanzada. Reintenta luego.'
          : (error.message || 'Error inesperado en sync engine.'),
        retriable: quotaExceeded,
      }),
    }, { merge: true });

    await addJobEvent(jobId, uid, 'SYNC_JOB_FAILED', {
      code: error.code || null,
      message: error.message,
      providerStatus,
      providerError,
    });

    const failedPlaylistName = jobData && jobData.sourceSnapshot && jobData.sourceSnapshot.name;
    await sendSyncNotification(uid, 'failed', failedPlaylistName);

    await logSyncError({
      uid,
      message: 'Fallo el procesamiento del job de sincronizacion.',
      error,
      metadata: {
        jobId,
        sourcePlatform: jobData.sourcePlatform,
        targetPlatform: jobData.targetPlatform,
        providerStatus,
        providerError,
      },
    });
  }
}

/**
 * Sends an FCM push notification to all devices registered for a user.
 * Silently ignores errors so a notification failure never breaks the sync flow.
 *
 * @param {string} uid
 * @param {string} state  Final job state (success | partial_success | failed | cancelled)
 * @param {string=} playlistName
 */
async function sendSyncNotification(uid, state, playlistName) {
  try {
    const deviceDoc = await admin.firestore()
      .collection('user_devices').doc(uid).get();
    if (!deviceDoc.exists) return;

    const tokens = deviceDoc.data().fcmTokens;
    if (!Array.isArray(tokens) || tokens.length === 0) return;

    const titles = {
      success: 'Sync completado',
      partial_success: 'Sync completado con errores',
      failed: 'Sync fallido',
      cancelled: 'Sync cancelado',
    };
    const title = titles[state] || 'Sync finalizado';
    const body = playlistName
      ? `Playlist: ${playlistName}`
      : 'Tu sincronización terminó.';

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { type: 'sync_complete', state },
      android: { priority: 'high' },
    });

    // Remove tokens that are no longer valid
    const staleTokens = tokens.filter((_, i) => !response.responses[i].success);
    if (staleTokens.length > 0) {
      await admin.firestore()
        .collection('user_devices').doc(uid).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens),
        });
    }
  } catch (err) {
    console.warn('sendSyncNotification error (non-fatal):', err && err.message);
  }
}

module.exports = {
  DEFAULT_PAGE_SIZE,
  buildInitialJobData,
  createDestinationIndex,
  enqueueSyncJob,
  processSyncJobTask,
  setSyncPlatformRegistry,
};

