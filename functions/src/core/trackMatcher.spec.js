const test = require('node:test');
const assert = require('node:assert/strict');
const {
  createTrackSignature,
  findBestTrackMatch,
  sanitizeTrackText,
  similarityPercent,
} = require('./trackMatcher');

test('sanitizeTrackText elimina ruido comun de metadata', () => {
  assert.equal(
    sanitizeTrackText('Blinding Lights (Live) feat. Rosalía - Remaster 2024'),
    'blinding lights',
  );
});

test('createTrackSignature normaliza titulo y artistas', () => {
  const signature = createTrackSignature({
    title: 'Song Title (Live)',
    artists: ['The Weeknd', 'ROSALÍA'],
  });

  assert.equal(signature, 'song title::rosalia|weeknd');
});

test('findBestTrackMatch prioriza match exacto por ISRC', () => {
  const result = findBestTrackMatch(
    {
      id: 'src-1',
      title: 'Track A',
      artists: ['Artist A'],
      isrc: 'USRC17607839',
    },
    [
      {
        id: 'dst-1',
        title: 'Track A - Live',
        artists: ['Artist A'],
        isrc: 'USRC17607839',
      },
    ],
  );

  assert.equal(result.status, 'success');
  assert.equal(result.strategy, 'isrc');
  assert.equal(result.matchedTrack.id, 'dst-1');
});

test('findBestTrackMatch detecta match por firma sanitizada', () => {
  const result = findBestTrackMatch(
    {
      id: 'src-2',
      title: 'Save Your Tears (Remastered)',
      artists: ['The Weeknd'],
    },
    [
      {
        id: 'dst-2',
        title: 'Save Your Tears',
        artists: ['Weeknd'],
      },
    ],
  );

  assert.equal(result.status, 'success');
  assert.equal(result.strategy, 'sanitized_exact');
});

test('findBestTrackMatch marca review_pending en zona gris', () => {
  const result = findBestTrackMatch(
    {
      id: 'src-3',
      title: 'Sunflower',
      artists: ['Post Malone', 'Swae Lee'],
    },
    [
      {
        id: 'dst-3',
        title: 'Sunflower demo',
        artists: ['Post Malone', 'Swae Lee'],
      },
    ],
    {
      autoSuccessThreshold: 95,
      reviewThreshold: 70,
    },
  );

  assert.equal(result.status, 'review_pending');
  assert.ok(result.reviewOptions.length >= 1);
});

test('similarityPercent devuelve score bajo para cadenas distintas', () => {
  assert.ok(similarityPercent('Track One', 'Another Song') < 70);
});

