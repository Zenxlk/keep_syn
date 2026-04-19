const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildYouTubeSearchQuery,
  normalizeYouTubeVideo,
  stripYouTubeDecorators,
} = require("./youtubeClient");

test("stripYouTubeDecorators limpia sufijos comunes de YouTube", () => {
  assert.equal(
      stripYouTubeDecorators("The Weeknd - Blinding Lights (Official Video) [4K]"),
      "The Weeknd - Blinding Lights",
  );
});

test("normalizeYouTubeVideo extrae artista y titulo desde snippet.title", () => {
  const video = normalizeYouTubeVideo({
    id: {videoId: "abc123"},
    snippet: {
      title: "The Weeknd - Blinding Lights (Official Video)",
      channelTitle: "The Weeknd",
    },
  });

  assert.equal(video.id, "abc123");
  assert.equal(video.title, "Blinding Lights");
  assert.deepEqual(video.artists, ["The Weeknd"]);
});

test("normalizeYouTubeVideo usa channelTitle cuando el titulo no tiene separador", () => {
  const video = normalizeYouTubeVideo({
    id: {videoId: "xyz987"},
    snippet: {
      title: "Blinding Lights",
      channelTitle: "The Weeknd - Topic",
    },
  });

  assert.equal(video.title, "Blinding Lights");
  assert.deepEqual(video.artists, ["The Weeknd"]);
});

test("buildYouTubeSearchQuery concatena titulo y artistas del track origen", () => {
  const query = buildYouTubeSearchQuery({
    title: "Blinding Lights",
    artists: ["The Weeknd"],
  });

  assert.equal(query, "Blinding Lights The Weeknd");
});

