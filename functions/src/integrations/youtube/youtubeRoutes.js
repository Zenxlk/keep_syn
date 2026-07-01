const express = require("express");
const {getStatus, linkAccount, unlinkAccount} = require("./youtubeController");

const router = express.Router();

const wrap = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

router.get("/status", wrap(getStatus));
router.post("/link", wrap(linkAccount));
router.post("/unlink", wrap(unlinkAccount));

module.exports = router;
