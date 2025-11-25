// src/routes/lockerRoutes.js
const express = require('express');
const router = express.Router();

const { getAllLockers } = require('../controllers/lockerController');

router.get('/', getAllLockers);

module.exports = router;
