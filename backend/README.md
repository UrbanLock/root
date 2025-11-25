# Backend Node.js con Express

## Descrizione
Questo progetto contiene il backend della nostra applicazione, sviluppato con Node.js e Express. Gestisce le API REST per interfacciarsi con il frontend Flutter/Dart e il database.

## Prerequisiti
- Node.js (consigliata versione LTS)
- npm (incluso con Node.js)

## Setup e avvio

### Passaggi eseguiti finora

1. Inizializzazione del progetto Node.js nella cartella backend
    npm init -y
2. Installazione delle dipendenze essenziali:
    npm install express dotenv cors
3. Creazione e modifica del file `app.js` con la configurazione di base del server Express.
4. Avvio del server con:
    npm install

Il server è ora in ascolto sulla porta 3000 di default.

### Come avviare il server

1. Clonare la repository e posizionarsi nella cartella `backend`
2. Assicurarsi di avere Node.js e npm installati.
3. Eseguire:
    node app.js
5. Verificare che il server risponda visitando nel browser o Postman:
    http://localhost:3000


## Struttura cartelle

- `app.js`: Punto di ingresso e configurazione del server.
- `src/routes/`: Contiene le definizioni delle rotte API.
- `src/controllers/`: Logica di gestione delle richieste.
- `src/models/`: Definizione dei modelli e interazione con il database.
- `src/middleware/`: Middleware personalizzati (es. autenticazione).

## Prossimi passi

- Aggiungere nuove rotte e controller per le funzionalità specifiche.
- Configurare la connessione al database (es. PostgreSQL, MongoDB).
- Implementare autenticazione, validazione, e gestione errori.


---
