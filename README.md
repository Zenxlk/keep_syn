# KeepSyn

Sincroniza tus playlists de **Spotify** a **YouTube Music** de forma automatica, preservando el orden y los metadatos de cada cancion.

## Que hace

- Conecta tu cuenta de Spotify y tu cuenta de Google (YouTube Music).
- Seleccionas una playlist de Spotify y KeepSyn la replica en YouTube Music.
- El motor de matching busca cada cancion por ISRC exacto, firma normalizada y similitud fuzzy.
- El progreso es visible en tiempo real y el proceso es tolerante a errores: si una cancion no se encuentra, continua con el resto y reporta los fallos.
- Playlists grandes se procesan en chunks para evitar timeouts y controlar la quota de la API de YouTube.

## Arquitectura general

```
Flutter (Android/iOS)
  └─ Firebase Auth (Google Sign-In)
  └─ Spotify OAuth (PKCE)
  └─ API REST  ──►  Firebase Cloud Functions (Node.js)
                         └─ syncJobWorker (Cloud Tasks)
                               └─ Spotify API (source)
                               └─ ytmusic-api + YouTube Data API v3 (target)
                         └─ Firestore (estado del job, cache de busqueda)
```

**Stack:**
- **Frontend:** Flutter · Riverpod · GoRouter · Dio · cloud_firestore
- **Backend:** Firebase Cloud Functions v2 · Cloud Tasks · Firestore · Secret Manager
- **Busqueda de musica:** ytmusic-api (sin quota) + YouTube Data API v3 (operaciones de playlist)

## Requisitos

- Flutter 3.x
- Node.js 22+
- Firebase CLI (`npm install -g firebase-tools`)
- Proyecto en Firebase con Firestore, Functions y Authentication habilitados
- App registrada en [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
- OAuth app en [Google Cloud Console](https://console.cloud.google.com) con YouTube Data API v3 habilitada

## Configuracion rapida

### 1. Variables de entorno Flutter

```bash
cp env/app_config.example.json env/app_config.local.json
# Edita app_config.local.json con tus valores reales
```

```bash
flutter run --dart-define-from-file=env/app_config.local.json
```

Ver [docs/ENV_SETUP.md](docs/ENV_SETUP.md) para descripcion de cada variable.

### 2. Secretos del backend

```bash
cd functions
firebase functions:secrets:set SPOTIFY_CLIENT_ID
firebase functions:secrets:set SPOTIFY_CLIENT_SECRET
firebase functions:secrets:set SPOTIFY_REDIRECT_URI
firebase functions:secrets:set YOUTUBE_CLIENT_ID
firebase functions:secrets:set YOUTUBE_CLIENT_SECRET
```

Ver [docs/DEPLOY_FUNCTIONS.md](docs/DEPLOY_FUNCTIONS.md) para el proceso completo de despliegue, incluyendo la cola de Cloud Tasks y el TTL de Firestore.

## Documentacion

| Documento | Contenido |
|---|---|
| [docs/ENV_SETUP.md](docs/ENV_SETUP.md) | Variables de entorno Flutter y backend |
| [docs/DEPLOY_FUNCTIONS.md](docs/DEPLOY_FUNCTIONS.md) | Despliegue de Cloud Functions paso a paso |
| [docs/SYNC_ENGINE_BACKEND.md](docs/SYNC_ENGINE_BACKEND.md) | Arquitectura del sync engine, matching pipeline, Firestore schema, debugging |

## Licencia

MIT — ver [LICENSE](LICENSE).
