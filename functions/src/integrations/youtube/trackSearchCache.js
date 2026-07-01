const crypto = require("crypto");
const admin = require("firebase-admin");

const CACHE_COLLECTION = "track_search_cache";
const TTL_DAYS = 30;

/**
 * Builds a deterministic cache key from track identity.
 * Prefers ISRC when available; falls back to sanitized title::artists signature.
 * @param {Object} track
 * @return {string}
 */
function _buildKey(track) {
  const isrc =
    track.isrc ||
    (track.externalIds && track.externalIds.isrc) ||
    (track.external_ids && track.external_ids.isrc) ||
    null;

  const raw = isrc
    ? `isrc:${isrc.toUpperCase()}`
    : `sig:${(track.title || track.name || "").toLowerCase()}::${
        Array.isArray(track.artists)
          ? track.artists
              .map((a) => (typeof a === "object" ? a.name : a))
              .join("|")
              .toLowerCase()
          : ""
      }`;

  return crypto.createHash("sha256").update(raw).digest("hex");
}

/**
 * Returns cached search candidates for a track, or null on cache miss.
 * @param {Object} track
 * @return {Promise<Array<Object>|null>}
 */
async function getCachedCandidates(track) {
  const key = _buildKey(track);
  const doc = await admin.firestore().collection(CACHE_COLLECTION).doc(key).get();
  if (!doc.exists) return null;
  const data = doc.data();
  return Array.isArray(data && data.candidates) ? data.candidates : null;
}

/**
 * Stores search candidates in Firestore with a 30-day TTL.
 * @param {Object} track
 * @param {Array<Object>} candidates
 * @return {Promise<void>}
 */
async function setCachedCandidates(track, candidates) {
  const key = _buildKey(track);
  const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + TTL_DAYS * 24 * 60 * 60 * 1000),
  );

  await admin.firestore().collection(CACHE_COLLECTION).doc(key).set({
    candidates,
    cachedAt: admin.firestore.Timestamp.now(),
    expiresAt,
  });
}

module.exports = {getCachedCandidates, setCachedCandidates};
