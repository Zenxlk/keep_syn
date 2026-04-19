# Prompt para Gemini - Servicios Backend de Sync (KeepSyn)

Actua como Arquitecto Backend Senior + DevOps para Google Cloud.
Necesito que disenes e implementes el backend inicial de sincronizacion para una app Flutter llamada KeepSyn.

## Contexto de la app

- App Flutter con Clean Architecture.
- Autenticacion actual: Google Sign-In + Firebase Auth.
- Hay Cloud Functions existentes:
  - `verifyAccess`: valida allowlist en Firestore.
  - `logClientError`: recibe logs del cliente y los guarda en Firestore.
- Quiero mantener el mismo ecosistema (Firebase + Cloud Functions + Firestore), con opcion de migrar a Cloud Run despues.

## Objetivo de esta fase

Crear servicios HTTP/callable para que el cliente Flutter pueda enviar POST y controlar jobs de sincronizacion de playlists.

## Requisitos funcionales de API

1. Crear job de sync
   - Metodo: `POST /v1/sync/jobs`
   - Body JSON:
     - `sourcePlatform` (spotify|tidal|youtube)
     - `targetPlatform` (spotify|tidal|youtube)
     - `sourcePlaylistId`
   - Respuesta:
     - `status: OK|ERROR`
     - `message`
     - `data: { jobId, state, createdAt }`

2. Consultar estado de job
   - Metodo: `GET /v1/sync/jobs/{jobId}`
   - Respuesta:
     - `status`
     - `message`
     - `data: { jobId, state, progress, counters, startedAt, completedAt, errors[] }`

3. Cancelar job
   - Metodo: `POST /v1/sync/jobs/{jobId}/cancel`
   - Respuesta:
     - `status`
     - `message`
     - `data: { jobId, state }`

4. Ultimo resultado por usuario
   - Metodo: `GET /v1/sync/jobs:last`
   - Respuesta con ultimo job del usuario autenticado.

## Requisitos no funcionales

- Seguridad: solo usuarios autenticados por Firebase ID Token.
- Autorizacion: reutilizar validacion allowlist.
- Idempotencia para `POST /v1/sync/jobs` (evitar jobs duplicados por doble click).
- Soportar retries y errores parciales por track.
- Logging estructurado en Firestore con correlacion por `jobId` y `uid`.

## Modelo sugerido en Firestore

- `sync_jobs/{jobId}`
  - `uid`
  - `sourcePlatform`
  - `targetPlatform`
  - `sourcePlaylistId`
  - `state` (idle|preparing|running|partial_success|failed|cancelled|success)
  - `progress` (0..1)
  - `counters` { processed, created, updated, skipped, failed }
  - `errors` []
  - `createdAt`, `startedAt`, `completedAt`, `updatedAt`
  - `attempt`

- `sync_job_events/{eventId}`
  - `jobId`, `uid`, `eventType`, `payload`, `createdAt`

## Entregables que necesito de ti

1. Arquitectura propuesta y diagrama textual de componentes.
2. Codigo de Cloud Functions (Node.js 20, v2) para endpoints arriba.
3. Middleware/utilidades para:
   - validar Firebase ID token,
   - normalizar respuestas estandar (`status`, `message`, `data`),
   - manejo de errores tipados.
4. Reglas de Firestore minimas para proteger `sync_jobs` por `uid`.
5. Instrucciones de despliegue paso a paso (`firebase deploy ...`).
6. Ejemplos de llamadas cURL para cada endpoint.
7. Estrategia de evolucion a Cloud Run sin romper contrato API.

## Formato de respuesta esperado

- Primero: resumen arquitectonico corto.
- Luego: estructura de carpetas propuesta.
- Luego: codigo completo por archivo.
- Luego: comandos de despliegue y pruebas.
- Finalmente: checklist de validacion en produccion.

## Importante

- Mantener compatibilidad con respuestas tipo:
  - `{ status: "OK", message: "...", data: {...} }`
  - `{ status: "ERROR", message: "..." }`
- No usar dependencias innecesarias.
- Si hay decisiones de diseno ambiguas, propon 2 opciones con pros y contras y elige una por defecto.

