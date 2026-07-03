const express = require("express");
const {getStatus, linkAccount, unlinkAccount} = require("./youtubeController");

const router = express.Router();

router.get("/status", getStatus);
router.post("/link", linkAccount);
router.post("/unlink", unlinkAccount);

module.exports = router;
