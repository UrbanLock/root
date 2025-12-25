# 🔄 Flusso Backend-Centric per Bluetooth e Accoppiamento

## 🎯 Principio
**Il backend è l'autorità centrale** che verifica e autorizza tutte le operazioni. Il frontend è solo un "messaggero" che:
1. Chiede informazioni al backend
2. Cerca dispositivi Bluetooth localmente
3. Invia richieste di verifica al backend
4. Riceve conferme/negazioni dal backend

---

## 📋 FLUSSO DETTAGLIATO

### **Fase 1: Utente seleziona cella**
- Frontend: Utente clicca su cella di prestito
- Frontend: Mostra popup con dettagli
- Frontend: Utente clicca "Apri"
- Frontend: Naviga a `OpenCellPage`

---

### **Fase 2: Frontend chiede UUID Bluetooth al backend**
**Endpoint**: `GET /api/v1/lockers/:id/bluetooth-info`

**Request**:
```http
GET /api/v1/lockers/123/bluetooth-info
Authorization: Bearer <token>
```

**Response**:
```json
{
  "lockerId": "123",
  "bluetoothUuid": "12:34:56:78:90:AB",
  "bluetoothName": "Locker-001",
  "verificationRequired": true
}
```

**Cosa fa il frontend**:
- Chiama questo endpoint quando `OpenCellPage` si apre
- Salva `bluetoothUuid` per la scansione locale
- Se `verificationRequired: true`, sa che deve verificare l'accoppiamento

---

### **Fase 3: Frontend cerca dispositivo Bluetooth**
- Frontend: Avvia scansione Bluetooth locale
- Frontend: Cerca dispositivo con UUID ricevuto dal backend
- Frontend: Quando trova il dispositivo, **NON** assume che sia valido
- Frontend: Invia richiesta di verifica al backend

---

### **Fase 4: Frontend richiede verifica accoppiamento al backend**
**Endpoint**: `POST /api/v1/cells/verify-bluetooth-pairing`

**Request**:
```http
POST /api/v1/cells/verify-bluetooth-pairing
Authorization: Bearer <token>
Content-Type: application/json

{
  "lockerId": "123",
  "cellId": "cell-456",  // ID della cella selezionata
  "bluetoothUuid": "12:34:56:78:90:AB",  // UUID trovato
  "bluetoothRssi": -45,  // Segnale RSSI (opzionale, per verifica prossimità)
  "deviceName": "Locker-001",  // Nome dispositivo (opzionale)
  "geolocation": {  // Opzionale, per verifica aggiuntiva
    "lat": 46.0748,
    "lng": 11.1217
  }
}
```

**Response (Successo)**:
```json
{
  "verified": true,
  "pairingId": "pair-789",  // ID univoco dell'accoppiamento
  "cellAssigned": {
    "id": "active-cell-123",
    "cellId": "cell-456",
    "cellNumber": "Cella 1",
    "lockerId": "123",
    "lockerName": "Locker Centrale",
    "startTime": "2024-01-15T10:30:00Z",
    "endTime": "2024-01-22T10:30:00Z",
    "type": "borrow"
  },
  "message": "Accoppiamento verificato. Cella assegnata."
}
```

**Response (Fallimento)**:
```json
{
  "verified": false,
  "reason": "device_not_found" | "too_far" | "unauthorized" | "cell_unavailable",
  "message": "Dispositivo non trovato o troppo distante dal locker."
}
```

**Cosa fa il backend**:
1. Verifica che l'UUID corrisponda al locker richiesto
2. Verifica che l'utente abbia i permessi
3. Verifica che la cella sia disponibile
4. (Opzionale) Verifica prossimità tramite RSSI o geolocalizzazione
5. Se tutto OK:
   - Crea record di accoppiamento (`pairingId`)
   - Assegna la cella all'utente
   - Restituisce `ActiveCell` assegnata
6. Se qualcosa non va:
   - Restituisce `verified: false` con motivo

---

### **Fase 5: Frontend mostra risultato**
- Se `verified: true`:
  - Mostra "Locker connesso! Pronto per aprire"
  - Salva `pairingId` e `cellAssigned`
  - Abilita pulsante "Apri cella"
- Se `verified: false`:
  - Mostra messaggio di errore con `reason`
  - Permette di riprovare

---

### **Fase 6: Utente clicca "Apri cella"**
**Endpoint**: `POST /api/v1/cells/open`

**Request**:
```http
POST /api/v1/cells/open
Authorization: Bearer <token>
Content-Type: application/json

{
  "pairingId": "pair-789",  // ID accoppiamento verificato
  "cellId": "cell-456",
  "lockerId": "123"
}
```

**Response**:
```json
{
  "success": true,
  "cellId": "cell-456",
  "doorOpened": true,
  "message": "Cella aperta con successo"
}
```

**Cosa fa il backend**:
1. Verifica che `pairingId` sia valido e attivo
2. Verifica che la cella sia ancora assegnata all'utente
3. Invia comando al locker fisico per aprire la cella
4. Restituisce conferma

---

## 🔐 VANTAGGI DI QUESTO APPROCCIO

### **Sicurezza**
- Il backend controlla tutto: nessuna logica critica nel frontend
- Verifica prossimità centralizzata (RSSI, geolocalizzazione)
- Prevenzione di attacchi (es. spoofing UUID)

### **Flessibilità**
- Il backend può cambiare criteri di verifica senza aggiornare l'app
- Supporto per verifiche aggiuntive (es. geolocalizzazione)
- Logging centralizzato di tutti gli accoppiamenti

### **Affidabilità**
- Il backend può verificare lo stato reale del locker
- Gestione errori centralizzata
- Possibilità di revocare accoppiamenti

---

## 📝 API ENDPOINTS NECESSARI

### 1. **GET /api/v1/lockers/:id/bluetooth-info**
Ottiene informazioni Bluetooth del locker.

**Response**:
```json
{
  "lockerId": "123",
  "bluetoothUuid": "12:34:56:78:90:AB",
  "bluetoothName": "Locker-001",
  "verificationRequired": true
}
```

### 2. **POST /api/v1/cells/verify-bluetooth-pairing**
Verifica accoppiamento Bluetooth e assegna cella.

**Request**:
```json
{
  "lockerId": "123",
  "cellId": "cell-456",
  "bluetoothUuid": "12:34:56:78:90:AB",
  "bluetoothRssi": -45,
  "deviceName": "Locker-001",
  "geolocation": { "lat": 46.0748, "lng": 11.1217 }
}
```

**Response**:
```json
{
  "verified": true,
  "pairingId": "pair-789",
  "cellAssigned": { ... }
}
```

### 3. **POST /api/v1/cells/open** (già esistente, da modificare)
Apre la cella usando `pairingId`.

**Request**:
```json
{
  "pairingId": "pair-789",
  "cellId": "cell-456",
  "lockerId": "123"
}
```

