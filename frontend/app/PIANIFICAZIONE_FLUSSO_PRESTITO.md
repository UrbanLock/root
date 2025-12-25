# 📋 PIANIFICAZIONE: Flusso Prestito Oggetto - Integrazione Backend

## 🎯 Obiettivo
Collegare il flusso di prestito di un oggetto dal frontend al backend, fino al punto in cui l'utente verifica la prossimità Bluetooth e può cliccare su "Apri cella".

---

## 📊 FLUSSO ATTUALE (Frontend)

### 1. **Selezione Locker e Cella**
- **Schermata**: `LockerDetailPage`
- **Azione**: Utente seleziona una cella di tipo `borrow` dalla lista
- **Codice**: `_handleBorrowCell(LockerCell cell)` in `locker_detail_page.dart`

### 2. **Popup Descrizione Cella**
- **Schermata**: Dialog con descrizione oggetto e foto
- **Azione**: Utente clicca "Apri" dopo aver visto descrizione e avviso foto
- **Navigazione**: Viene aperta `OpenCellPage`

### 3. **Schermata Apri Cella**
- **Schermata**: `OpenCellPage` (`lib/features/profile/presentation/pages/open_cell_page.dart`)
- **Flusso**:
  1. Verifica stato Bluetooth
  2. Se non attivo → richiesta attivazione
  3. Scansione Bluetooth per trovare locker
  4. Una volta trovato → mostra "Locker connesso" + bottone "Apri cella"

---

## 🔌 API BACKEND RICHIESTE

### ✅ **API Esistenti (già definite nel frontend)**

#### 1. **POST `/api/v1/cells/request`** - Richiedi Cella per Prestito
- **Quando**: Prima di aprire la cella (dopo verifica Bluetooth)
- **Body**:
  ```json
  {
    "lockerId": "string",
    "type": "borrow",
    "photo": "base64..." (opzionale),
    "geolocalizzazione": { "lat": number, "lng": number } (opzionale)
  }
  ```
- **Risposta attesa**:
  ```json
  {
    "success": true,
    "cell": {
      "id": "string",
      "lockerId": "string",
      "lockerName": "string",
      "lockerType": "string",
      "cellNumber": "string",
      "cellId": "string",
      "startTime": "ISO8601",
      "endTime": "ISO8601" | null,
      "type": "borrow"
    }
  }
  ```
- **Implementazione frontend**: `CellRepository.requestCell()`

#### 2. **POST `/api/v1/cells/open`** - Apri Cella
- **Quando**: Dopo verifica Bluetooth, quando utente clicca "Apri cella"
- **Body**:
  ```json
  {
    "cell_id": "string",
    "photo": "base64..." (opzionale)
  }
  ```
- **Risposta attesa**:
  ```json
  {
    "success": true,
    "cell_id": "string",
    "door_opened": true
  }
  ```
- **Implementazione frontend**: `CellRepository.openCell()`

#### 3. **POST `/api/v1/cells/close`** - Notifica Chiusura
- **Quando**: Quando lo sportello viene chiuso (rilevato da sensore o manualmente)
- **Body**:
  ```json
  {
    "cell_id": "string",
    "door_closed": true
  }
  ```
- **Implementazione frontend**: `CellRepository.notifyCellClosed()`

---

## ❓ API MANCANTI / DA VERIFICARE

### 1. **GET `/api/v1/lockers/:id/cells`** - Dettagli Celle di un Locker
- **Quando**: Quando si apre `LockerDetailPage`
- **Scopo**: Ottenere lista celle disponibili con dettagli oggetti (per prestito)
- **Risposta attesa**:
  ```json
  {
    "cells": [
      {
        "id": "string",
        "cellNumber": "string",
        "type": "borrow" | "deposit" | "pickup",
        "size": "small" | "medium" | "large" | "extraLarge",
        "isAvailable": boolean,
        "itemName": "string" | null,
        "itemDescription": "string" | null,
        "itemImageUrl": "string" | null,
        "pricePerHour": number,
        "pricePerDay": number,
        "borrowDuration": number (giorni) | null
      }
    ]
  }
  ```
- **Stato**: Attualmente il frontend usa `LockerRepository.getLockerCells()` che potrebbe chiamare questo endpoint

### 2. **GET `/api/v1/lockers/:id`** - Info Locker (con Bluetooth UUID)
- **Quando**: Prima della scansione Bluetooth
- **Scopo**: Ottenere UUID Bluetooth del locker per verifica prossimità
- **Risposta attesa**:
  ```json
  {
    "id": "string",
    "name": "string",
    "type": "string",
    "bluetoothUuid": "string", // UUID del dispositivo Bluetooth
    "bluetoothName": "string" | null, // Nome dispositivo (opzionale)
    "location": {
      "lat": number,
      "lng": number
    }
  }
  ```
- **Stato**: ⚠️ **MANCANTE** - Serve per identificare il locker durante la scansione Bluetooth

### 3. **POST `/api/v1/cells/verify-proximity`** - Verifica Prossimità (Opzionale)
- **Quando**: Dopo scansione Bluetooth riuscita
- **Scopo**: Verificare lato backend che l'utente è effettivamente vicino al locker
- **Body**:
  ```json
  {
    "lockerId": "string",
    "bluetoothUuid": "string",
    "geolocation": { "lat": number, "lng": number }
  }
  ```
- **Risposta attesa**:
  ```json
  {
    "verified": true,
    "distance": number (metri)
  }
  ```
- **Stato**: ⚠️ **OPZIONALE** - La verifica può essere solo lato frontend (Bluetooth), ma questa API aggiunge sicurezza

---

## 🔄 FLUSSO INTEGRATO PROPOSTO

### **Step 1: Selezione Cella** ✅ (Già implementato)
- Utente seleziona cella in `LockerDetailPage`
- Viene mostrato popup con descrizione e foto
- Utente clicca "Apri"

### **Step 2: Navigazione a OpenCellPage** ✅ (Già implementato)
- Viene aperta `OpenCellPage` con `LockerCell`, `lockerName`, `lockerId`

### **Step 3: Verifica Bluetooth e Prossimità** ⚠️ (Da integrare)
**Modifiche necessarie in `OpenCellPage`:**

1. **Caricare info locker dal backend** (se non già disponibile):
   ```dart
   // In initState() o prima della scansione
   final locker = await lockerRepository.getLockerById(widget.lockerId);
   final bluetoothUuid = locker.bluetoothUuid; // ⚠️ Serve nel modello Locker
   ```

2. **Scansione Bluetooth con UUID specifico**:
   ```dart
   // Invece di simulare, verificare UUID reale
   FlutterBluePlus.scanResults.listen((results) {
     for (final result in results) {
       if (result.device.remoteId.toString() == bluetoothUuid) {
         // Locker trovato!
         setState(() {
           _lockerFound = true;
           _lockerConnected = true;
         });
       }
     }
   });
   ```

3. **Opzionale: Verifica prossimità lato backend**:
   ```dart
   // Dopo aver trovato il locker via Bluetooth
   final proximity = await cellRepository.verifyProximity(
     lockerId: widget.lockerId,
     bluetoothUuid: bluetoothUuid,
     geolocation: currentLocation,
   );
   ```

### **Step 4: Richiesta Cella al Backend** ⚠️ (Da integrare)
**Quando**: Dopo verifica Bluetooth riuscita, PRIMA di mostrare "Apri cella"

**Modifiche in `OpenCellPage`:**

```dart
// Dopo _lockerConnected = true
Future<void> _requestCellFromBackend() async {
  try {
    setState(() {
      _statusMessage = 'Richiesta cella in corso...';
    });
    
    // Ottieni posizione utente (opzionale)
    final location = await _getCurrentLocation();
    
    // Richiedi cella al backend
    final activeCell = await AppDependencies.cellRepository.requestCell(
      widget.lockerId,
      type: 'borrow', // Per prestito
      geolocation: location != null ? {
        'lat': location.latitude,
        'lng': location.longitude,
      } : null,
    );
    
    setState(() {
      _activeCell = activeCell;
      _statusMessage = 'Cella assegnata. Pronto per aprire.';
    });
  } catch (e) {
    // Gestisci errore (cella non disponibile, ecc.)
    setState(() {
      _statusMessage = 'Errore: ${e.toString()}';
    });
  }
}
```

### **Step 5: Apertura Cella** ⚠️ (Da integrare)
**Quando**: Utente clicca "Apri cella"

**Modifiche in `OpenCellPage._openCell()`:**

```dart
Future<void> _openCell() async {
  if (_activeCell == null) {
    // Se non abbiamo ancora richiesto la cella, fallo ora
    await _requestCellFromBackend();
    if (_activeCell == null) return;
  }
  
  try {
    setState(() {
      _statusMessage = 'Apertura cella in corso...';
    });
    
    // Chiama API backend per aprire la cella
    await AppDependencies.cellRepository.openCell(
      _activeCell!.cellId,
      // photoBase64: null (foto richiesta solo al ritorno)
    );
    
    setState(() {
      _cellOpened = true;
      _statusMessage = 'Cella aperta!';
    });
    
    // Attendi chiusura sportello (rilevata da sensore o timeout)
    _waitForDoorClose();
  } catch (e) {
    setState(() {
      _statusMessage = 'Errore apertura: ${e.toString()}';
    });
  }
}
```

---

## 📝 MODIFICHE NECESSARIE

### **Frontend**

#### 1. **Modello `Locker`** (`lib/features/lockers/domain/models/locker.dart`)
- ⚠️ **MANCANTE**: Aggiungere campo `bluetoothUuid?: String`
- ⚠️ **MANCANTE**: Aggiungere campo `bluetoothName?: String`
- ⚠️ Aggiornare `fromJson()` per parsare questi campi

#### 2. **`LockerRepository`** (`lib/features/lockers/domain/repositories/locker_repository.dart`)
- ✅ **ESISTE**: `getLockerById(String id)` è già implementato
- ⚠️ Verificare che l'endpoint backend restituisca `bluetoothUuid`

#### 3. **`OpenCellPage`** (`lib/features/profile/presentation/pages/open_cell_page.dart`)
- ✅ **GIÀ IMPLEMENTATO**: `_openCell()` chiama già `requestCell()` e `openCell()`
- ⚠️ **DA MODIFICARE**: Caricare info locker con UUID Bluetooth all'inizio (prima della scansione)
- ⚠️ **DA MODIFICARE**: Modificare scansione Bluetooth per usare UUID reale invece di simulazione
- ⚠️ **DA MIGLIORARE**: Chiamare `requestCell()` DOPO verifica Bluetooth (non quando clicca "Apri")
- ⚠️ Gestire errori (cella non disponibile, locker non raggiungibile, ecc.)

#### 4. **`LockerDetailPage`** (`lib/features/home/presentation/pages/locker_detail_page.dart`)
- ✅ Già passa `lockerId` a `OpenCellPage` → OK

### **Backend** (Da verificare/implementare)

#### 1. **GET `/api/v1/lockers/:id`**
- ⚠️ Restituire info locker incluso `bluetoothUuid` e `bluetoothName`

#### 2. **POST `/api/v1/cells/request`**
- ✅ Verificare che supporti `type: "borrow"`
- ✅ Verificare che assegni correttamente la cella
- ✅ Verificare che restituisca `ActiveCell` nel formato atteso

#### 3. **POST `/api/v1/cells/open`**
- ✅ Verificare che apra fisicamente la cella (comando al locker)
- ✅ Verificare che restituisca conferma

#### 4. **POST `/api/v1/cells/verify-proximity`** (Opzionale)
- ⚠️ Implementare se si vuole verifica lato backend

---

## 🎯 PRIORITÀ IMPLEMENTAZIONE

### **Fase 1: Verifica Backend Esistente** 🔍
1. Verificare se `GET /api/v1/lockers/:id` esiste e restituisce `bluetoothUuid`
2. Verificare se `POST /api/v1/cells/request` supporta `type: "borrow"`
3. Verificare se `POST /api/v1/cells/open` funziona correttamente

### **Fase 2: Modifiche Frontend Minime** 🔧
1. Aggiungere `bluetoothUuid` al modello `Locker`
2. Caricare UUID locker in `OpenCellPage`
3. Usare UUID reale nella scansione Bluetooth

### **Fase 3: Integrazione Backend** 🔌
1. Chiamare `requestCell()` dopo verifica Bluetooth
2. Chiamare `openCell()` quando utente clicca "Apri cella"
3. Gestire errori e stati di caricamento

### **Fase 4: Testing e Refinement** ✅
1. Testare flusso completo
2. Gestire edge cases (Bluetooth non disponibile, locker non trovato, cella non disponibile)
3. Migliorare UX con feedback chiari

---

## ❓ DOMANDE APERTE

1. **Il backend ha già `bluetoothUuid` nel modello Locker?**
2. **Il backend supporta già `type: "borrow"` in `/cells/request`?**
3. **Il backend può aprire fisicamente la cella tramite `/cells/open`?**
4. **Serve verifica prossimità lato backend o basta Bluetooth?**
5. **Come viene rilevata la chiusura dello sportello? (Sensore, timeout, manuale)**

---

## 📌 PROSSIMI PASSI

1. ✅ **Analisi completata** - Questo documento
2. ⏳ **Verifica backend** - Controllare se le API esistono e supportano `bluetoothUuid`
3. ⏳ **Implementazione frontend** - Modifiche a `OpenCellPage` e modelli
4. ⏳ **Testing** - Verificare flusso completo
5. ⏳ **Documentazione** - Aggiornare commenti nel codice

---

## 📋 RIEPILOGO ESECUTIVO

### ✅ **Cosa è già implementato:**
- ✅ Flusso UI completo (selezione cella → popup → OpenCellPage)
- ✅ Verifica Bluetooth (con simulazione)
- ✅ Chiamate API `requestCell()` e `openCell()` (già presenti in `_openCell()`)
- ✅ Metodo `getLockerById()` nel repository

### ⚠️ **Cosa manca/da modificare:**

#### **Backend:**
1. ⚠️ `GET /api/v1/lockers/:id` deve restituire `bluetoothUuid` e `bluetoothName`
2. ✅ `POST /api/v1/cells/request` deve supportare `type: "borrow"` (da verificare)
3. ✅ `POST /api/v1/cells/open` deve aprire fisicamente la cella (da verificare)

#### **Frontend:**
1. ⚠️ Aggiungere `bluetoothUuid` e `bluetoothName` al modello `Locker`
2. ⚠️ Caricare UUID locker in `OpenCellPage` prima della scansione
3. ⚠️ Modificare scansione Bluetooth per usare UUID reale (non simulazione)
4. ⚠️ Chiamare `requestCell()` DOPO verifica Bluetooth (non quando clicca "Apri")
5. ⚠️ Migliorare gestione errori e feedback utente

### 🎯 **Ordine di implementazione suggerito:**
1. **Verificare backend** → Controllare se `GET /lockers/:id` restituisce `bluetoothUuid`
2. **Aggiungere campi al modello** → `Locker.bluetoothUuid` e `bluetoothName`
3. **Modificare OpenCellPage** → Caricare UUID e usarlo nella scansione
4. **Spostare requestCell()** → Chiamarlo dopo verifica Bluetooth
5. **Testing** → Verificare flusso completo end-to-end

