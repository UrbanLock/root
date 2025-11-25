// src/controllers/lockerController.js
const lockers = require('../data/lockers');

const getAllLockers = (req, res) => {
  res.json(lockers);
};

module.exports = { getAllLockers };
