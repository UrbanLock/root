const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Importa le rotte utenti
const userRoutes = require('./src/routes/userRoutes'); 
app.use('/users', userRoutes);

app.get('/', (req, res) => {
  res.send('Backend con Express attivo!');
});

app.listen(port, () => {
  console.log(`Server in ascolto sulla porta ${port}`);
});
