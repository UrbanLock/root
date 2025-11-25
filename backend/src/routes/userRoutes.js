const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json([{ id: 1, name: 'Mario Rossi' }, { id: 2, name: 'Anna Bianchi' }]);
});

module.exports = router;
