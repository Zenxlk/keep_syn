const express = require("express");
const youtubeController = require("./youtubeController");

const router = express.Router();

router.post("/link", youtubeController.linkAccount);
router.post("/refresh", youtubeController.refreshAccount);
router.post("/unlink", youtubeController.unlinkAccount);
router.get("/status", youtubeController.getStatus);

module.exports = router;

