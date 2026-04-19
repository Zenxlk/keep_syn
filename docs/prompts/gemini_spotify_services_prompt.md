# Prompt para Gemini - Revisar e implementar servicios Spotify (KeepSyn)

Actua como Arquitecto de Software senior + Backend engineer + Flutter engineer.
Necesito que me ayudes a disenar e implementar la capa de servicios Spotify para KeepSyn, respetando Clean Architecture y la estructura actual del proyecto.

## Contexto del proyecto

- Proyecto Flutter: `keepsyn_app`.
- Estructura principal:
  - `lib/src/core/...`
  - `lib/src/features/auth/...`
  - `lib/src/features/sync/...`
  - `functions/...` (Firebase Cloud Functions + Express API)
- Autenticacion ya implementada:
  - Google Sign-In + Firebase Auth
  - Allowlist con `verifyAccess`
- Logging remoto ya implementado:
  - `logClientError`
- Sync base ya creada en Flutter:
  - Dominio (`Playlist`, `Track`, `SyncJob`, `SyncResult`, `SyncProgress`)
  - `SyncController` con Riverpod
  - `HttpSyncService` para hablar con `/v1/sync/jobs`
  - Persistencia local minima (`shared_preferences`) para estado/fecha/errores

## Objetivo de esta fase (Spotify)

Quiero iniciar la integracion real de Spotify, empezando por servicios backend y contratos estables para que Flutter no quede acoplado al SDK/API de Spotify.

## Lo que necesito que me entregues

1. **Revision de arquitectura actual**
   - Validar si conviene manejar Spotify en:
     - Opcion A: `features/sync`
     - Opcion B: `features/integrations`
   - Elegir opcion por defecto y justificar.

2. **Diseno de servicios Spotify (backend)**
   - Usar `functions/src/...` en Node + Firebase Functions.
   - Proponer estructura de carpetas y archivos (servicios, controladores, middlewares, clientes Spotify).
   - Implementar endpoints (o callables, pero preferible HTTP REST consistente):
     - `POST /v1/integrations/spotify/link`
     - `POST /v1/integrations/spotify/refresh`
     - `POST /v1/integrations/spotify/unlink`
     - `GET /v1/integrations/spotify/status`
     - `GET /v1/integrations/spotify/playlists`
     - `GET /v1/integrations/spotify/playlists/:playlistId/tracks`
   - Mantener contrato estandar de respuesta:
     - `{ status: "OK", message: "...", data: {...} }`
     - `{ status: "ERROR", message: "...", data?: {...} }`

3. **Modelo de datos en Firestore**
   - Definir colecciones/documentos para:
     - Tokens cifrados o almacenados de forma segura por `uid`
     - Estado de vinculacion por plataforma (`connected`, `expired`, `revoked`)
     - Metadatos de ultima sincronizacion Spotify
   - Proponer indices necesarios.

4. **Seguridad y manejo de tokens**
   - Mantener middleware actual de Firebase token + allowlist.
   - Diseñar flujo OAuth Spotify seguro para mobile + backend:
     - intercambio de code por access/refresh token en backend
     - refresh automatico
     - no exponer client secret en Flutter
   - Estrategia de renovacion de token expirada.

5. **Rate limit + retries + errores tipados**
   - Definir manejo de 401/403/429/5xx de Spotify.
   - Backoff exponencial con jitter para 429/5xx.
   - No retry para errores de permisos invalidos.
   - Mapeo a errores de dominio para Flutter (`Failure`) con codigos estables.

6. **Integracion Flutter (cliente)**
   - Proponer/implementar archivos en:
     - `lib/src/features/sync/data/...`
     - `lib/src/features/sync/domain/...`
     - `lib/src/features/sync/presentation/...`
   - Contratos recomendados:
     - `ISpotifyIntegrationRepository`
     - `SpotifyIntegrationRemoteDataSource`
     - `SpotifyIntegrationController` (Riverpod)
   - Estado UI para vinculacion:
     - `notConnected`, `linking`, `connected`, `expired`, `error`

7. **Telemetria funcional**
   - Eventos minimos:
     - `spotify_link_started`
     - `spotify_link_success`
     - `spotify_link_failed`
     - `spotify_refresh_success`
     - `spotify_rate_limited`
   - Mantener consistencia con `logClientError` y/o nuevo logger de eventos.

8. **Pruebas obligatorias**
   - Backend:
     - tests de middleware auth
     - tests de controlador Spotify
     - tests de manejo de errores Spotify API
   - Flutter:
     - tests de mapeo DTO -> entidad
     - tests de controller/estado Riverpod
     - test de flujo de vinculacion basico

## Restricciones tecnicas

- No romper la arquitectura actual.
- No mover ni reescribir auth existente salvo cambios minimos de integracion.
- Mantener nombres claros y consistentes con el proyecto.
- No usar dependencias innecesarias.
- Código listo para produccion, no solo pseudocodigo.

## Formato de respuesta requerido

1. Diagnostico corto de arquitectura actual.
2. Propuesta final elegida (A/B) con razon.
3. Arbol de archivos a crear/modificar.
4. Codigo completo por archivo.
5. Reglas de seguridad Firestore recomendadas.
6. Comandos de despliegue y pruebas.
7. Checklist final de aceptacion.

## Extra importante

- Si hay una decision ambigua, dame 2 opciones con pros/contras y elige una por defecto.
- Prioriza que el cliente Flutter quede desacoplado de Spotify (todo por contratos).
- Primero deja estable el flujo de vinculacion Spotify; luego la lectura de playlists/tracks.

