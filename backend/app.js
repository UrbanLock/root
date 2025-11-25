const express = require('express');
const cors = require('cors');
require('dotenv').config();


const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

const lockerRoutes = require('./src/routes/lockerRoutes');
app.use('/api/lockers', lockerRoutes);

app.listen(port, () => {

});

