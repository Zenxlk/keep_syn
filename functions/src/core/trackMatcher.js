const AUTO_SUCCESS_THRESHOLD = 85;
const REVIEW_THRESHOLD = 70;
const MAX_REVIEW_OPTIONS = 3;

/**
 * Limpia texto de track para comparar entre plataformas.
 * Quita decoradores comunes: feat, live, remaster, mix, etc.
 * @param {string} value
 * @return {string}
 */
function sanitizeTrackText(value = '') {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/\s*[[(][^\])]*\b(live|feat|ft\.?|featuring|remaster(?:ed)?|mix|version|edit|acoustic|karaoke|mono|stereo|deluxe|bonus track)\b[^\])]*[\])]/gi, ' ')
    .replace(/\s+-\s+(live|remaster(?:ed)?(?:\s+\d{4})?|radio edit|edit|mix|version|acoustic|karaoke|mono|stereo|instrumental).*$/gi, ' ')
    .replace(/\b(feat\.?|ft\.?|featuring)\b.*$/gi, ' ')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\b(the|a|an)\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * @param {Array<string>|string|undefined|null} artists
 * @return {string[]}
 */
function sanitizeArtists(artists) {
  const rawArtists = Array.isArray(artists) ? artists : [artists || ''];
  return rawArtists
    .map((artist) => sanitizeTrackText(artist))
    .filter(Boolean)
    .sort();
}

/**
 * @param {Object} track
 * @return {string}
 */
function createTrackSignature(track = {}) {
  const title = sanitizeTrackText(track.title || track.name || '');
  const artists = sanitizeArtists(getTrackArtists(track));
  return `${title}::${artists.join('|')}`;
}

/**
 * @param {string} left
 * @param {string} right
 * @return {number}
 */
function levenshteinDistance(left = '', right = '') {
  if (left === right) return 0;
  if (!left.length) return right.length;
  if (!right.length) return left.length;

  const matrix = Array.from(
    { length: left.length + 1 },
    (_, row) => Array.from({ length: right.length + 1 }, (_, col) => {
      if (row === 0) return col;
      if (col === 0) return row;
      return 0;
    }),
  );

  for (let row = 1; row <= left.length; row += 1) {
    for (let col = 1; col <= right.length; col += 1) {
      const cost = left[row - 1] === right[col - 1] ? 0 : 1;
      matrix[row][col] = Math.min(
        matrix[row - 1][col] + 1,
        matrix[row][col - 1] + 1,
        matrix[row - 1][col - 1] + cost,
      );
    }
  }

  return matrix[left.length][right.length];
}

/**
 * @param {string} left
 * @param {string} right
 * @return {number}
 */
function similarityPercent(left = '', right = '') {
  const normalizedLeft = sanitizeTrackText(left);
  const normalizedRight = sanitizeTrackText(right);

  if (!normalizedLeft && !normalizedRight) return 100;
  if (!normalizedLeft || !normalizedRight) return 0;

  const distance = levenshteinDistance(normalizedLeft, normalizedRight);
  const maxLength = Math.max(normalizedLeft.length, normalizedRight.length);

  if (!maxLength) return 100;
  return Math.round((1 - (distance / maxLength)) * 100);
}

/**
 * @param {Object} track
 * @return {string[]}
 */
function getTrackArtists(track = {}) {
  if (Array.isArray(track.artists)) {
    return track.artists
      .map((artist) => {
        if (artist && typeof artist === 'object') {
          return artist.name || '';
        }
        return String(artist || '');
      })
      .filter(Boolean);
  }

  if (typeof track.artist === 'string') {
    return [track.artist];
  }

  return [];
}

/**
 * @param {Object} track
 * @return {string|null}
 */
function getTrackIsrc(track = {}) {
  return track.isrc
    || (track.externalIds && track.externalIds.isrc)
    || (track.external_ids && track.external_ids.isrc)
    || null;
}

/**
 * @param {Object} sourceTrack
 * @param {Object} candidate
 * @return {number}
 */
function computeTrackSimilarity(sourceTrack, candidate) {
  const sourceTitle = sourceTrack.title || sourceTrack.name || '';
  const candidateTitle = candidate.title || candidate.name || '';
  const sourceAlbum = sourceTrack.album || '';
  const candidateAlbum = candidate.album || '';
  const sourceArtists = getTrackArtists(sourceTrack);
  const candidateArtists = getTrackArtists(candidate);
  const normalizedSourceTitle = sanitizeTrackText(sourceTitle);
  const normalizedCandidateTitle = sanitizeTrackText(candidateTitle);
  const normalizedSourceArtists = sanitizeArtists(sourceArtists);
  const normalizedCandidateArtists = sanitizeArtists(candidateArtists);

  const titleScore = similarityPercent(sourceTitle, candidateTitle);
  const artistScore = sourceArtists.length && candidateArtists.length ? Math.max(
    ...sourceArtists.flatMap((sourceArtist) => candidateArtists.map(
      (candidateArtist) => similarityPercent(sourceArtist, candidateArtist),
    )),
  ) : 0;
  const albumScore = sourceAlbum && candidateAlbum
    ? similarityPercent(sourceAlbum, candidateAlbum) : 0;

  const sourceSignature = createTrackSignature(sourceTrack);
  const candidateSignature = createTrackSignature(candidate);
  const signatureBonus = sourceSignature === candidateSignature ? 12 : 0;
  const titleContainmentBonus = normalizedSourceTitle && normalizedCandidateTitle
    && (normalizedCandidateTitle.includes(normalizedSourceTitle)
    || normalizedSourceTitle.includes(normalizedCandidateTitle)) ? 10 : 0;
  const artistExactBonus = normalizedSourceArtists.join('|')
    && normalizedSourceArtists.join('|') === normalizedCandidateArtists.join('|')
    ? 8 : 0;

  const weightedScore = Math.round(
    (titleScore * 0.65) + (artistScore * 0.25) + (albumScore * 0.10)
      + signatureBonus + titleContainmentBonus + artistExactBonus,
  );

  return Math.min(weightedScore, 100);
}

/**
 * @param {Object} sourceTrack
 * @param {Array<Object>} candidates
 * @param {Object=} options
 * @return {Object}
 */
function findBestTrackMatch(sourceTrack, candidates = [], options = {}) {
  const autoSuccessThreshold
    = options.autoSuccessThreshold || AUTO_SUCCESS_THRESHOLD;
  const reviewThreshold = options.reviewThreshold || REVIEW_THRESHOLD;
  const maxReviewOptions = options.maxReviewOptions || MAX_REVIEW_OPTIONS;
  const sourceIsrc = getTrackIsrc(sourceTrack);
  const sourceSignature = createTrackSignature(sourceTrack);

  if (!Array.isArray(candidates) || candidates.length === 0) {
    return {
      status: 'failed',
      confidence: 0,
      strategy: 'no_candidates',
      matchedTrack: null,
      reviewOptions: [],
      reason: 'No se encontraron candidatos en la plataforma destino.',
    };
  }

  if (sourceIsrc) {
    const exactIsrcMatch = candidates.find((candidate) => {
      const candidateIsrc = getTrackIsrc(candidate);
      return candidateIsrc && candidateIsrc === sourceIsrc;
    });

    if (exactIsrcMatch) {
      return {
        status: 'success',
        confidence: 100,
        strategy: 'isrc',
        matchedTrack: exactIsrcMatch,
        reviewOptions: [],
      };
    }
  }

  const sanitizedExactMatch = candidates.find((candidate) => {
    return createTrackSignature(candidate) === sourceSignature;
  });

  if (sanitizedExactMatch) {
    return {
      status: 'success',
      confidence: 96,
      strategy: 'sanitized_exact',
      matchedTrack: sanitizedExactMatch,
      reviewOptions: [],
    };
  }

  const scoredCandidates = candidates
    .map((candidate) => ({
      candidate,
      confidence: computeTrackSimilarity(sourceTrack, candidate),
      strategy: 'fuzzy',
    }))
    .sort((left, right) => right.confidence - left.confidence);

  const best = scoredCandidates[0];
  const reviewOptions = scoredCandidates
    .slice(0, maxReviewOptions)
    .map((entry) => ({
      confidence: entry.confidence,
      strategy: entry.strategy,
      track: entry.candidate,
    }));

  if (best.confidence > autoSuccessThreshold) {
    return {
      status: 'success',
      confidence: best.confidence,
      strategy: best.strategy,
      matchedTrack: best.candidate,
      reviewOptions,
    };
  }

  if (best.confidence >= reviewThreshold) {
    return {
      status: 'review_pending',
      confidence: best.confidence,
      strategy: best.strategy,
      matchedTrack: null,
      reviewOptions,
      reason: 'Coincidencia ambigua: requiere confirmacion humana.',
    };
  }

  return {
    status: 'failed',
    confidence: best.confidence,
    strategy: best.strategy,
    matchedTrack: null,
    reviewOptions,
    reason: 'La similitud esta por debajo del umbral minimo aceptado.',
  };
}

module.exports = {
  AUTO_SUCCESS_THRESHOLD,
  REVIEW_THRESHOLD,
  sanitizeTrackText,
  sanitizeArtists,
  createTrackSignature,
  similarityPercent,
  computeTrackSimilarity,
  findBestTrackMatch,
  getTrackArtists,
  getTrackIsrc,
};

