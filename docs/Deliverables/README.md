# UrbanLock: Roadmap di Sviluppo (D1 - D4)

Questo documento mappa il progetto UrbanLock sulle fasi richieste dal corso di Ingegneria del Software, definendo gli output specifici per ogni scadenza.

---

## D1: Idea Progetto (Prime 4 Settimane)

**Obiettivo**: Definire "Cosa" stiamo costruendo e "Per chi". Nessuna riga di codice, solo analisi.

### 1. Design Thinking & Requisiti

- **Problem Statement:**  
  I cittadini mancano di punti di scambio sicuri; i negozi locali soffrono la logistica dell'ultimo miglio.

- **User Personas:**
  - Marco (Studente): Cerca un posto per lo zaino in stazione.
  - Giulia (Negoziante): Vuole lasciare un pacco per un cliente fuori orario.
  - Luca (Turista): Cerca le chiavi del BnB.

### 2. User Stories & Backlog (Kanban)

- "Come utente, voglio autenticarmi con SPID per garantire la mia identità."
- "Come manutentore, voglio aprire uno slot da remoto in caso di guasto."
- "Come sistema, voglio inviare un token BLE valido solo 30 secondi."

### 3. Modellazione Iniziale

- **Use Case Diagram:** Attori (Utente, Admin, Hardware Locker) e casi d'uso (Login, Prenota Slot, Sblocca, Paga).
- **Sequence Diagram:** Il flusso critico dell'apertura (App → Richiesta Token → Server → Token → App → BLE → Locker).
- **Activity Diagram:** Flusso di prenotazione e gestione errori (es. slot pieno o occupato).

---

## D2: Implementazione (10 Settimane - Coding)

**Obiettivo**: Costruire il sistema funzionante ("Il Prodotto").  
_NB: Stack tecnologico adattato alle specifiche del progetto UrbanLock ma allineato ai requisiti del corso._

### 1. Backend & API

- **Tech:** Node.js (Express o Fastify).
- **RESTful API / OpenAPI:** Definizione delle rotte:
  - `POST /auth/login` (Integrazione Mock SPID/GoogleAuth)
  - `POST /lockers/{id}/reserve` (Logica di prenotazione)
  - `GET /lockers/status` (Monitoraggio stato slot)
- **Database:**  
  L'immagine suggerisce MongoDB. Per UrbanLock era stato ipotizzato PostgreSQL, ma MongoDB (NoSQL) è molto adatto per i log dei sensori IoT e configurazioni flessibili dei locker. **Confermare scelta.**

### 2. Frontend & Mobile

- **Tech:** Flutter (o React Native se preferito web-based)
- **Funzionalità:**  
  Mappa dei locker, Wallet prenotazioni, Interfaccia di sblocco Bluetooth.

### 3. DevOps & Qualità

- **Git/GitHub:** Gestione versionamento con Branch Protection Rules.
- **CI/CD:** Pipeline (GitHub Actions) che lancia i test automatici ad ogni push.
- **Testing:** Test unitari (Jest) per logica di assegnazione slot e validazione token.

---

## D3: Analisi e Progettazione (Parallelo a D2)

**Obiettivo**: Documentare "Come" è fatto il sistema e le scelte architetturali.

### 1. Architettura

- Descrizione dell'architettura Ibrida (Cloud + Edge Computing sul Locker).
- Scelta dei pattern (MVC per il backend, Repository Pattern per i dati).

### 2. Diagrammi UML Evoluti

- **Class Diagram:** Struttura di database e classi (User, Locker, Slot, Reservation, Transaction).
- **Component Diagram:** Relazioni tra App, API Gateway, Database, Servizio Auth e Modulo IoT Fisico.

### 3. Processo Agile

- Documentazione degli Sprint (cosa è stato fatto ogni 2 settimane).
- Gestione del Backlog e **burndown chart**.

---

## D4: Report Finale

**Obiettivo**: Presentazione e chiusura.

- **Manuale Utente:** Come usare l'app UrbanLock.
- **Manuale Installatore:** Come configurare un nuovo Locker Master Unit.
- **Analisi dei Costi/Sostenibilità:** (Ripresa dal Business Model).
- **Conclusioni e Sviluppi Futuri:** (Es: Integrazione droni, pannelli solari, ecc.).
