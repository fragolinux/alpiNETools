# Auto-Remediation System

Sistema automatico per la gestione delle vulnerabilità di sicurezza e l'aggiornamento delle dipendenze.

## 🎯 Funzionalità

Il workflow di auto-remediation esegue automaticamente:

1. **Scansione vulnerabilità** con Trivy
2. **Applicazione fix automatici** per pacchetti vulnerabili
3. **Test delle modifiche** con rebuild e re-scan
4. **Aggiornamento GitHub Actions** obsolete
5. **Creazione automatica di Pull Request** per revisione

## 🔄 Quando si attiva

- **Automaticamente**: ogni lunedì alle 4:00 AM (configurabile)
- **Manualmente**: tramite GitHub Actions UI

## 🛡️ Protezioni e Limiti

Per evitare consumo eccessivo di risorse:

- ✅ **Max 3 tentativi** di fix per vulnerabilità
- ✅ **Rate limiting** sulle chiamate API a GitHub
- ✅ **Verifica automatica** con rebuild e test
- ✅ **Richiede approvazione umana** via PR

## 📋 Workflow

```
┌─────────────────┐
│  Trivy Scan     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      No vulnerabilities
│ Vulnerabilities?├──────────────────────────┐
└────────┬────────┘                          │
         │ Yes                               │
         ▼                                   │
┌─────────────────┐                          │
│ Extract Packages│                          │
└────────┬────────┘                          │
         │                                   │
         ▼                                   │
┌─────────────────┐                          │
│  Apply Fixes    │ (max 3 attempts)        │
└────────┬────────┘                          │
         │                                   │
         ▼                                   │
┌─────────────────┐                          │
│ Rebuild & Test  │                          │
└────────┬────────┘                          │
         │                                   │
         ▼                                   │
┌─────────────────┐                          │
│ Update Actions  │◄─────────────────────────┘
└────────┬────────┘
         │
         ▼
┌─────────────────┐      No changes
│   Has changes?  ├──────────────────────────┐
└────────┬────────┘                          │
         │ Yes                               │
         ▼                                   │
┌─────────────────┐                          │
│   Create PR     │                          │
└─────────────────┘                          │
                                             │
                                             ▼
                                        ┌─────────┐
                                        │   End   │
                                        └─────────┘
```

## 🔧 Script Inclusi

### `fix-vulnerabilities.sh`

Analizza le vulnerabilità rilevate e applica fix automatici:

- Estrae i nomi dei pacchetti vulnerabili
- Li aggiunge alla lista `apk add --no-cache --upgrade`
- Aggiorna sia `Dockerfile` che `cato/Dockerfile.cato`
- Limita a 3 tentativi per evitare loop infiniti

**Utilizzo:**
```bash
.github/scripts/fix-vulnerabilities.sh "zlib libcrypto3 expat"
```

### `update-actions.sh`

Controlla e aggiorna le GitHub Actions obsolete:

- Scansiona tutti i workflow in `.github/workflows/`
- Usa API GitHub per trovare versioni più recenti
- Aggiorna automaticamente i riferimenti
- Implementa rate limiting per evitare blocchi API

**Utilizzo:**
```bash
.github/scripts/update-actions.sh
```

## 📝 Come Revisionare una PR

Quando il workflow crea una PR, verifica:

1. **Pacchetti aggiornati**: controlla che siano appropriati
2. **Action aggiornate**: verifica che non rompano i workflow esistenti
3. **Test**: assicurati che la build sia passata
4. **Vulnerabilità residue**: controlla il conteggio nel corpo della PR

### ✅ Se tutto è OK:
```bash
# Approva la PR su GitHub
# Oppure da CLI:
gh pr review <PR_NUMBER> --approve
gh pr merge <PR_NUMBER> --squash
```

### ❌ Se servono modifiche:
```bash
# Checkout del branch della PR
git fetch origin auto-remediation/security-updates
git checkout auto-remediation/security-updates

# Fai le modifiche necessarie
# ...

git add .
git commit -m "Ajustamenti manuali"
git push origin auto-remediation/security-updates
```

## ⚙️ Configurazione

### Personalizzare la schedulazione

Modifica `.github/workflows/auto-remediation.yaml`:

```yaml
schedule:
  - cron: '0 4 * * 1'   # Lunedì alle 4:00
  # Formato: minuto ora giorno_mese mese giorno_settimana
```

### Cambiare i limiti

In `fix-vulnerabilities.sh`:

```bash
MAX_ATTEMPTS=3  # Aumenta o diminuisci il numero di tentativi
```

### Aggiungere altre action da monitorare

In `update-actions.sh`, aggiungi a `ACTIONS_TO_CHECK`:

```bash
ACTIONS_TO_CHECK=(
    # ... existing actions ...
    "tua-org/tua-action"
)
```

## 🚨 Troubleshooting

### Il workflow non crea PR

**Causa**: Nessuna vulnerabilità trovata o nessuna modifica applicata

**Soluzione**: Controlla i logs del workflow, sezione "Check for changes"

### Lo script fix non funziona

**Causa**: Formato del Dockerfile non riconosciuto

**Soluzione**: Verifica che il Dockerfile abbia la sezione:
```dockerfile
RUN apk upgrade --no-cache && \
    apk add --no-cache --upgrade \
    expat \
    libcrypto3 \
    libssl3 \
```

### API rate limit superato

**Causa**: Troppe richieste alle API GitHub

**Soluzione**: Lo script ha già rate limiting. Se persiste, aumenta il delay in `update-actions.sh`:
```bash
sleep 0.5  # Aumenta a 1 o 2 secondi
```

## 📊 Metriche e Monitoring

Il workflow genera automaticamente:

- **Job Summary**: visibile nella pagina del workflow run
- **PR Body**: include metriche dettagliate su vulnerabilità fissate
- **SARIF Report**: caricato nel tab Security di GitHub

## 🔐 Sicurezza

- Lo script gira con permessi minimi necessari
- Le modifiche richiedono sempre revisione umana
- Nessun push diretto al branch main
- Tutti i fix sono tracciabili via PR

## 📚 Riferimenti

- [Trivy Documentation](https://trivy.dev/)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides)
- [Alpine Package Management](https://wiki.alpinelinux.org/wiki/Alpine_Package_Keeper)

---

**Autore**: Auto-generato  
**Ultima modifica**: 9 marzo 2026  
**Versione**: 1.0.0
