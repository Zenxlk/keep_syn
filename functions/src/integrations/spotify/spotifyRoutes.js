const express = require("express");
const spotifyController = require("./spotifyController");

const router = express.Router();

router.post("/link", spotifyController.linkAccount);
router.post("/refresh", spotifyController.refreshAccount);
router.post("/unlink", spotifyController.unlinkAccount);
router.get("/status", spotifyController.getStatus);
router.get("/playlists", spotifyController.getPlaylists);
router.get("/playlists/:playlistId/tracks", spotifyController.getPlaylistTracks);

module.exports = router;

