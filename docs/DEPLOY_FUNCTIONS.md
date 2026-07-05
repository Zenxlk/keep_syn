# Despliegue de Cloud Functions a Firebase

## Requisitos previos

- [Firebase CLI](https://firebase.google.com/docs/cli) instalado: `npm install -g firebase-tools`
- Node.js 24 instalado localmente
- Sesión activa: `firebase login`
- Proyecto vinculado: `firebase use keepsyn-0001`

---

## 1. Configurar secretos en Secret Manager

Los secretos **nunca** van en `.env` ni en el repo. Se suben una sola vez a Google Secret Manager:

```bash
cd functions

firebase functions:secrets:set SPOTIFY_CLIENT_ID
firebase functions:secrets:set SPOTIFY_CLIENT_SECRET
firebase functions:secrets:set SPOTIFY_REDIRECT_URI
firebase functions:secrets:set YOUTUBE_CLIENT_ID
firebase functions:secrets:set YOUTUBE_CLIENT_SECRET
```

Cada comando te pedirá el valor por stdin. Para verificar que están cargados:

```bash
firebase functions:secrets:access SPOTIFY_CLIENT_ID
```

> Si necesitas actualizar un secreto ya existente, vuelve a ejecutar el mismo comando — Secret Manager crea una nueva versión y la función la usará en el próximo despliegue.

---

## 2. Configurar TTL de Firestore para la cache de búsqueda

La colección `track_search_cache` usa el campo `expiresAt` para expirar documentos automáticamente a los 30 días. Necesitas activar la política TTL **una sola vez** en la consola de Firebase o con `gcloud`:

```bash
gcloud firestore fields ttls update expiresAt \
  --collection-group=track_search_cache \
  --enable-ttl \
  --project=keepsyn-0001
```

O desde la consola: **Firestore → Índices → TTL → Agregar política TTL** con colección `track_search_cache` y campo `expiresAt`.

---

## 3. Crear la cola de Cloud Tasks

La cola `syncJobWorker` procesa los jobs de sync de forma chunked. Si no existe todavía:

```bash
gcloud tasks queues create syncJobWorker \
  --location=us-central1 \
  --max-concurrent-dispatches=2 \
  --max-dispatches-per-second=1 \
  --project=keepsyn-0001
```

Si ya existe y necesitas actualizarla:

```bash
gcloud tasks queues update syncJobWorker \
  --location=us-central1 \
  --max-concurrent-dispatches=2 \
  --max-dispatches-per-second=1 \
  --project=keepsyn-0001
```

---

## 4. Desplegar las funciones

### Despliegue completo

```bash
firebase deploy --only functions
```

### Despliegue de una función específica

```bash
# Solo la API HTTP (rutas Express: sync, spotify, youtube)
firebase deploy --only functions:api

# Solo el worker de Cloud Tasks
firebase deploy --only functions:syncJobWorker

# Varias a la vez
firebase deploy --only functions:api,functions:syncJobWorker
```

### Funciones desplegadas

| Nombre | Tipo | Descripción |
|---|---|---|
| `api` | `onRequest` | API REST Express (Spotify, YouTube, sync jobs) |
| `syncJobWorker` | `onTaskDispatched` | Procesador chunked de sync por Cloud Tasks |
| `verifyAccess` | `onCall` | Verifica si el usuario está en el allowlist |
| `logClientError` | `onCall` | Recibe logs de error desde la app Flutter |

---

## 5. Verificar el despliegue

### Revisar que las funciones están activas

```bash
firebase functions:list
```

### Ver logs en tiempo real

```bash
# Todos los logs
firebase functions:log

# Solo la API
firebase functions:log --only api

# Solo el worker
firebase functions:log --only syncJobWorker
```

### Probar el endpoint de estado

```bash
# Reemplaza TOKEN con un Firebase ID token válido
curl -H "Authorization: Bearer TOKEN" \
  https://us-central1-keepsyn-0001.cloudfunctions.net/api/v1/integrations/spotify/status
```

---

## 6. Primera vez: habilitar APIs en GCP

Si es un proyecto nuevo, habilita las APIs necesarias en Google Cloud Console o con `gcloud`:

```bash
gcloud services enable \
  cloudfunctions.googleapis.com \
  cloudtasks.googleapis.com \
  secretmanager.googleapis.com \
  firestore.googleapis.com \
  youtube.googleapis.com \
  --project=keepsyn-0001
```

---

## Referencia rápida

```bash
# Login y selección de proyecto
firebase login
firebase use keepsyn-0001

# Despliegue completo
cd /ruta/al/proyecto
firebase deploy --only functions

# Ver logs de error recientes
firebase functions:log --only api --severity=ERROR
```
