# 🚀 MEGA RECAP: Applicazione NULL - Frontend Flutter

## 📱 PANORAMICA GENERALE

**NULL** è un'applicazione mobile Flutter per la gestione di **smart locker modulari e connessi** nella città di Trento. L'app permette agli utenti di:

- 🗺️ **Visualizzare lockers su mappa interattiva** con geolocalizzazione
- 🔍 **Cercare e filtrare lockers** per tipologia (Personali, Sportivi, Commerciali)
- 📦 **Gestire celle locker**: prestito, deposito, ritiro oggetti
- 🔔 **Ricevere notifiche** in tempo reale
- 👤 **Autenticazione** con gestione profilo utente
- 💳 **Sistema di pagamento** per depositi
- 📊 **Storico utilizzi** e prenotazioni attive
- 🎨 **Tema dark/light** con supporto sistema

---

## 🏗️ ARCHITETTURA

### **Pattern Architetturali**

- **Clean Architecture**: Separazione tra `domain`, `data` e `presentation` layers
- **Repository Pattern**: Astrazione per accesso ai dati (mock/reale)
- **Dependency Injection**: Gestione centralizzata (`AppDependencies`)
- **State Management**: `StatefulWidget` + `ChangeNotifier` per tema
- **Cupertino Design**: UI stile iOS nativo

### **Struttura Moduli**

```
lib/
├── main.dart                    # Entry point + onboarding/privacy flow
├── core/                        # Componenti core riutilizzabili
│   ├── api/                     # ApiClient, gestione errori HTTP
│   ├── auth/                    # AuthService (SharedPreferences)
│   ├── config/                  # ApiConfig, MapConfig
│   ├── di/                      # AppDependencies (DI container)
│   ├── notifications/           # NotificationService
│   ├── styles/                  # AppColors, AppTextStyles
│   └── theme/                   # ThemeManager (dark/light)
└── features/                    # Moduli funzionali
    ├── auth/                    # Login, onboarding, privacy/terms
    ├── cells/                    # Gestione celle (repository, models)
    ├── home/                     # HomePage (mappa), LockerDetailPage
    ├── lockers/                  # Repository lockers, models
    ├── notifications/            # NotificationsPage, repository
    ├── payment/                  # DepositPaymentPage, DepositOpenCellPage
    ├── profile/                  # DonatePage, HistoryPage, OpenCellPage, ReturnCellPage
    ├── reports/                  # ReportsListPage, ReportIssuePage
    └── settings/                 # SettingsPage, LanguagePage, PrivacyPage
```

---

## 🎯 FUNZIONALITÀ PRINCIPALI

### **1. HomePage - Mappa Interattiva**

**Componenti principali:**
- **Mappa FlutterMap** con tile providers (CartoDB light/dark)
- **Marker lockers** dinamici con clustering
- **Geolocalizzazione utente** con marker blu
- **Barra di ricerca** con debounce (filtro locale)
- **Filtri categoria** (Personali, Sportivi, Commerciali)
- **Tab bar** (Notifiche, Home, Impostazioni)
- **Badge notifiche** con polling automatico

**Ottimizzazioni implementate:**
- ✅ **Cache locale** lockers (`SharedPreferences` + memoria)
- ✅ **Debounce ricerca** (300ms) per performance
- ✅ **Debounce location updates** (600ms + soglia distanza)
- ✅ **Animazioni smooth** per transizioni mappa (`AnimatedSwitcher`)
- ✅ **Auto-centering intelligente** (solo al primo avvio o su azione esplicita)
- ✅ **Caching marker** per evitare rebuild inutili

**Flusso utente:**
1. App si apre → carica lockers da cache (istantaneo)
2. Refresh in background → aggiorna lockers dal backend
3. Utente cerca/filtra → filtraggio locale (istantaneo)
4. Utente clicca marker → mostra popup minimal locker
5. Utente clicca "Dettagli" → naviga a `LockerDetailPage`

---

### **2. LockerDetailPage - Dettaglio Locker**

**Struttura:**
- **PageView** con 2 tab: "Prestito" e "Deposito"
- **Pull-to-refresh** per aggiornare celle
- **Cache celle** (memoria + `SharedPreferences`, TTL 5 minuti)

**Tab "Prestito":**
- Lista celle disponibili per prestito
- Ogni cella mostra: icona tipo, descrizione oggetto, foto, disponibilità
- Click cella → popup dettagli → "Apri" → `OpenCellPage`

**Tab "Deposito":**
- Celle raggruppate per dimensione (Piccola, Media, Grande)
- Ogni gruppo mostra: dimensione, costo, disponibilità
- Click cella → popup dettagli → "Affitta" → `DepositPaymentPage`

**Ottimizzazioni:**
- ✅ Cache celle per caricamento istantaneo
- ✅ Layout responsive (prevenzione overflow pixel)
- ✅ UI minimal e moderna

---

### **3. OpenCellPage - Apertura Cella con Bluetooth**

**Flusso Backend-Centric (implementato):**

#### **Fase 1: Caricamento Info Bluetooth**
- Frontend chiama `GET /api/v1/lockers/:id/bluetooth-info`
- Backend restituisce: `bluetoothUuid`, `bluetoothName`, `verificationRequired`

#### **Fase 2: Scansione Bluetooth**
- Frontend verifica stato Bluetooth
- Se non attivo → richiesta attivazione con listener automatico
- Avvia scansione locale per trovare dispositivo con UUID ricevuto
- ⚠️ **TESTING**: Simula ritrovamento dopo 2 secondi (commentato codice reale)

#### **Fase 3: Verifica Accoppiamento (Backend)**
- Frontend chiama `POST /api/v1/cells/verify-bluetooth-pairing`
- Body: `lockerId`, `cellId`, `bluetoothUuid`, `bluetoothRssi`, `deviceName`, `geolocation`
- Backend verifica:
  - UUID corrisponde al locker
  - Prossimità (RSSI, geolocalizzazione)
  - Cella disponibile
  - Permessi utente
- **Response successo**: `{ verified: true, pairingId: "...", cellAssigned: {...} }`
- **Response fallimento**: `{ verified: false, reason: "...", message: "..." }`

#### **Fase 4: Apertura Cella**
- Se verifica OK → mostra "Locker connesso! Pronto per aprire"
- Utente clicca "Apri cella"
- Frontend chiama `POST /api/v1/cells/open` con `pairingId`, `cellId`, `lockerId`
- Backend verifica `pairingId` e invia comando al locker fisico
- Frontend mostra conferma apertura

**Vantaggi approccio backend-centric:**
- ✅ Sicurezza: backend controlla tutto
- ✅ Flessibilità: criteri verifica modificabili senza aggiornare app
- ✅ Affidabilità: stato reale locker verificato centralmente

---

### **4. Sistema Notifiche**

**Polling automatico:**
- ✅ Timer periodico ogni **30 secondi** (solo se autenticato)
- ✅ Aggiornamento badge anche senza entrare in schermata notifiche
- ✅ Refresh quando app torna in foreground
- ✅ Endpoint dedicato: `GET /api/v1/notifications/unread` (veloce)

**NotificationsPage:**
- Lista notifiche con stato "letta/non letta"
- Mark as read quando utente visualizza
- Accesso ristretto: solo utenti autenticati (mostra dialog login se non loggato)

---

### **5. Autenticazione**

**Flusso:**
1. **Onboarding** (prima volta)
2. **Privacy/Terms** (se autenticato e non accettato)
3. **Login** (se non autenticato)
4. **HomePage** (dopo onboarding/privacy/login)

**AuthService:**
- Gestione token JWT in `SharedPreferences`
- Metodi: `login()`, `logout()`, `isAuthenticated()`, `getToken()`
- Auto-refresh token (se implementato backend)

**AuthRepository:**
- `login(email, password)` → `POST /api/v1/auth/login`
- `acceptTerms(version)` → registra accettazione backend

---

### **6. Profilo Utente**

**Pagine:**
- **ActiveReservationsPage**: Celle attive (prestiti, depositi)
- **HistoryPage**: Storico utilizzi (paginato)
- **DonatePage**: Donazione oggetti
- **HelpPage**: FAQ e supporto
- **ReturnCellPage**: Restituzione cella con foto

**Flussi:**
- **Prestito**: `LockerDetailPage` → `OpenCellPage` → Bluetooth → Apertura
- **Deposito**: `LockerDetailPage` → `DepositPaymentPage` → `DepositOpenCellPage` → Bluetooth → Verifica → Pagamento
- **Ritiro**: `ActiveReservationsPage` → `OpenCellPage` → Bluetooth → Apertura

---

### **7. Impostazioni**

**SettingsPage:**
- Toggle tema dark/light
- Gestione account (logout)
- Link a Privacy Policy, Termini di Servizio
- Selezione lingua (futuro)

**ThemeManager:**
- `ChangeNotifier` per gestione tema globale
- Persistenza preferenza utente
- Supporto tema sistema

---

## 🔄 ULTIME MODIFICHE IMPLEMENTATE

### **1. Sistema Notifiche con Polling** ✅
- **Problema**: Badge notifiche non si aggiornava velocemente
- **Soluzione**:
  - Polling automatico ogni 30 secondi
  - Endpoint dedicato `/notifications/unread` (più veloce)
  - Aggiornamento anche senza entrare in schermata
  - Refresh quando app torna in foreground

### **2. Ottimizzazione Mappa e Performance** ✅
- **Problema**: Mappa laggosa, transizioni non smooth
- **Soluzioni**:
  - **Cache locale lockers**: `SharedPreferences` + memoria (caricamento istantaneo)
  - **Debounce ricerca**: 300ms (riduce chiamate API)
  - **Debounce location**: 600ms + soglia distanza (evita aggiornamenti eccessivi)
  - **Animazioni smooth**: `AnimatedSwitcher` per transizioni marker/card
  - **Auto-centering intelligente**: solo al primo avvio o su azione esplicita (pulsante posizione)
  - **Caching marker**: evita rebuild inutili

### **3. UI/UX Premium** ✅
- **Problema**: UI non abbastanza "premium"
- **Soluzioni**:
  - Transizioni animate (`Tween<Offset>`, `Curves.easeInOutCubic`)
  - Popup locker minimal (solo info essenziali + "Dettagli")
  - LockerDetailPage ridisegnata (PageView con tab, pull-to-refresh)
  - Fix overflow pixel (cell squares responsive)
  - Rimozione pulsanti duplicati

### **4. Flusso Bluetooth Backend-Centric** ✅
- **Problema**: Logica Bluetooth nel frontend (insicura)
- **Soluzione**: Backend controlla tutto
  - **Nuovo endpoint**: `GET /lockers/:id/bluetooth-info` (UUID Bluetooth)
  - **Nuovo endpoint**: `POST /cells/verify-bluetooth-pairing` (verifica accoppiamento)
  - **Endpoint modificato**: `POST /cells/open` (ora usa `pairingId`)
  - Frontend solo scopre dispositivi e invia richieste
  - Backend verifica prossimità (RSSI, geolocalizzazione), assegna cella, genera `pairingId`

**File modificati:**
- `OpenCellPage`: Refactoring completo per flusso backend-centric
- `CellRepository`: Aggiunti `verifyBluetoothPairing()`, `openCellWithPairing()`
- `LockerRepository`: Aggiunto `getLockerBluetoothInfo()`
- Backend: Nuovi controller e route

### **5. Testing Bluetooth senza Hardware** ✅
- **Simulazione**: Ritrovamento dispositivo sempre dopo 2 secondi
- **Commenti**: Codice reale commentato, chiaramente marcato per testing
- **Mock repositories**: Implementati metodi Bluetooth nei mock

### **6. Fix Compilazione** ✅
- Aggiunti metodi mancanti nei mock repositories:
  - `LockerRepositoryMock.getLockerBluetoothInfo()`
  - `CellRepositoryMock.verifyBluetoothPairing()`
  - `CellRepositoryMock.openCellWithPairing()`

---

## 🚧 COSA STIAMO IMPLEMENTANDO / TODO

### **In Corso:**
- ✅ **Flusso prestito completo**: Integrazione backend Bluetooth (completato)
- ✅ **Testing senza hardware**: Simulazione Bluetooth (completato)
- ✅ **Ottimizzazioni performance**: Cache, debounce, animazioni (completato)

### **Prossimi Passi:**
- 🔄 **Flusso deposito completo**: Integrazione pagamento + Bluetooth
- 🔄 **Flusso ritiro completo**: Integrazione Bluetooth per ritiro oggetti
- 🔄 **Notifiche push**: Integrazione Firebase Cloud Messaging
- 🔄 **Foto oggetti**: Upload e gestione foto per restituzione
- 🔄 **QR Code**: Supporto apertura celle tramite QR (alternativa Bluetooth)

### **Miglioramenti Futuri:**
- 📱 **Offline mode**: Cache dati per uso offline
- 🔄 **Real-time updates**: WebSocket per aggiornamenti live
- 🗺️ **Navigazione**: Integrazione Google Maps/Apple Maps per direzioni
- 💬 **Chat supporto**: Integrazione chat in-app
- 📊 **Analytics**: Tracking eventi utente
- 🌍 **Internazionalizzazione**: Supporto multi-lingua completo

---

## 🔌 INTEGRAZIONE BACKEND

### **API Endpoints Utilizzati**

**Lockers:**
- `GET /api/v1/lockers` - Lista lockers
- `GET /api/v1/lockers/:id` - Dettaglio locker
- `GET /api/v1/lockers/:id/cells` - Celle locker
- `GET /api/v1/lockers/:id/bluetooth-info` - Info Bluetooth locker ⭐ **NUOVO**

**Cells:**
- `GET /api/v1/cells/active` - Celle attive utente
- `POST /api/v1/cells/request` - Richiedi cella
- `POST /api/v1/cells/open` - Apri cella (modificato per `pairingId`)
- `POST /api/v1/cells/close` - Chiudi cella
- `POST /api/v1/cells/verify-bluetooth-pairing` - Verifica accoppiamento ⭐ **NUOVO**
- `GET /api/v1/cells/history` - Storico utilizzi

**Auth:**
- `POST /api/v1/auth/login` - Login
- `GET /api/v1/user/info` - Info utente
- `POST /api/v1/auth/accept-terms` - Accetta termini

**Notifications:**
- `GET /api/v1/notifications` - Lista notifiche
- `GET /api/v1/notifications/unread` - Conteggio non lette ⭐ **OTTIMIZZATO**

**Altri:**
- `POST /api/v1/donations` - Donazione oggetto
- `POST /api/v1/reports` - Segnalazione problema

### **Base URL**
```
https://serverurbanlock.onrender.com
```

---

## 📦 TECNOLOGIE E DEPENDENCIES

**Core:**
- Flutter 3.x
- Dart 3.9.2+
- Cupertino Design (iOS style)

**Mappa:**
- `flutter_map: ^8.2.2` - Mappa interattiva
- `latlong2: ^0.9.1` - Coordinate geografiche

**Bluetooth:**
- `flutter_blue_plus: ^1.32.0` - Bluetooth Low Energy

**Storage:**
- `shared_preferences: ^2.2.2` - Persistenza locale

**Location:**
- `location: ^7.0.0` - Geolocalizzazione

**HTTP:**
- `http: ^1.2.0` - Client HTTP
- `dio: ^5.4.0` - Client HTTP avanzato (futuro)

**UI:**
- `url_launcher: ^6.2.4` - Apertura link esterni

---

## 🎨 DESIGN SYSTEM

**Tema:**
- **Light Mode**: Colori chiari, contrasto elevato
- **Dark Mode**: Colori scuri, OLED-friendly
- **Sistema**: Rileva preferenza sistema automaticamente

**Colori:**
- Primary: `#007AFF` (iOS Blue)
- Background: Dinamico (light/dark)
- Text: Dinamico (light/dark)
- Accent: Dinamico per azioni

**Tipografia:**
- System fonts (San Francisco su iOS)
- Stili: `title`, `headline`, `body`, `caption`

---

## 🔐 SICUREZZA

**Autenticazione:**
- JWT token in `SharedPreferences` (non crittografato, ma sufficiente per MVP)
- Token inviato in header `Authorization: Bearer <token>`
- Auto-logout se token scaduto (da implementare)

**Bluetooth:**
- Verifica prossimità backend (RSSI, geolocalizzazione)
- UUID verificato dal backend (previene spoofing)
- `pairingId` temporaneo per apertura cella

**API:**
- HTTPS obbligatorio
- Timeout 30 secondi
- Gestione errori centralizzata (`ApiException`)

---

## 📊 STATO PROGETTO

### **Completato (✅):**
- Architettura Clean Architecture
- HomePage con mappa interattiva
- Sistema ricerca e filtri
- LockerDetailPage con tab Prestito/Deposito
- Autenticazione base
- Sistema notifiche con polling
- Flusso Bluetooth backend-centric
- Cache locale per performance
- UI/UX premium con animazioni
- Testing senza hardware

### **In Sviluppo (🔄):**
- Integrazione completa flusso deposito
- Integrazione completa flusso ritiro
- Notifiche push

### **Pianificato (📋):**
- Offline mode
- Real-time updates
- QR Code support
- Multi-lingua completo

---

## 🐛 NOTE TECNICHE

**Mock vs Reale:**
- `AppDependencies.useMockData = false` → usa repository reali
- Se `_apiClient == null` → fallback a mock automatico
- Mock repositories: `CellRepositoryMock`, `LockerRepositoryMock`

**Cache:**
- Lockers: Cache persistente (`SharedPreferences`) + memoria
- Celle: Cache memoria + `SharedPreferences` (TTL 5 minuti)
- User location: Cache persistente

**Performance:**
- Debounce ricerca: 300ms
- Debounce location: 600ms + soglia 10 metri
- Polling notifiche: 30 secondi
- Cache TTL celle: 5 minuti

---

## 📝 DOCUMENTAZIONE AGGIUNTIVA

- `FLUSSO_BACKEND_BLUETOOTH.md` - Dettagli flusso Bluetooth
- `DOCUMENTAZIONE_NULL.txt` - Documentazione originale
- `PIANIFICAZIONE_FLUSSO_PRESTITO.md` - Pianificazione flusso prestito

---

**Ultimo aggiornamento**: Gennaio 2025
**Versione**: 1.0.0
**Stato**: In sviluppo attivo 🚀

