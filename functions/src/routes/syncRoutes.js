const express = require('express');
const router = express.Router();
const syncController = require('../controllers/syncController');

router.post('/', syncController.createJob);
router.get('/last', syncController.getLastJob); // Debe ir antes de /:jobId para no chocar
router.get('/:jobId', syncController.getJobStatus);
router.post('/:jobId/cancel', syncController.cancelJob);

module.exports = router;