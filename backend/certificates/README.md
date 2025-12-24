# Certificati TLS/SSL

Questa cartella contiene i certificati TLS/SSL per abilitare HTTPS sul server.

## ⚠️ Sicurezza

**NON committare mai certificati reali o chiavi private nel repository!**

I file `.pem`, `.key`, `.crt` sono già esclusi da git tramite `.gitignore`.

## Sviluppo (Self-Signed Certificate)

Per generare un certificato self-signed per sviluppo locale:

```bash
cd certificates
openssl req -x509 -newkey rsa:4096 -nodes -keyout key.pem -out cert.pem -days 365
```

Durante la generazione, rispondi alle domande (puoi lasciare tutto di default premendo Invio).

**Nota**: I browser mostreranno un avviso di sicurezza per certificati self-signed. Questo è normale in sviluppo.

## Produzione

**RNF4 - Sicurezza**: Il sistema richiede TLS 1.3 per la sicurezza dei dati in transito. Node.js supporta TLS 1.3 di default (da v12+).

Per produzione, usa certificati reali da:

### Let's Encrypt (Gratuito)
```bash
# Usa certbot per ottenere certificati
sudo certbot certonly --standalone -d api.null.app
```

I certificati saranno in `/etc/letsencrypt/live/api.null.app/`

**Nota**: Assicurati che il server supporti TLS 1.3 in produzione per compliance RNF4.

### Altri Provider
- Cloudflare
- AWS Certificate Manager
- Google Cloud SSL
- Altri provider SSL

## Configurazione

Dopo aver ottenuto i certificati, configura il file `.env`:

```env
TLS_ENABLED=true
TLS_KEY_PATH=./certificates/key.pem
TLS_CERT_PATH=./certificates/cert.pem
```

## Verifica

Dopo aver configurato i certificati, avvia il server e verifica:

```bash
curl https://localhost:3443/health
```

Se tutto è configurato correttamente, dovresti ricevere una risposta JSON dal server.

