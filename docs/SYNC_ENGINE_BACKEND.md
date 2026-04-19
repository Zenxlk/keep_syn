# Sync Engine Backend - KeepSyn

## Estrategia de ejecucion para playlists grandes

Para la fase actual, la mejor relacion costo/beneficio **no** es simplemente subir el timeout de la HTTP Function.

La estrategia implementada es:

1. `POST /v1/sync/jobs` crea el documento en `sync_jobs`.
2. La API encola un task en `syncJobWorker`.
3. `syncJobWorker` procesa el job en **chunks/paginas** (`pageSize = 100`).
4. Si quedan tracks por procesar, vuelve a encolarse a si misma.
5. El estado y progreso viven en Firestore, por lo que el cliente puede hacer polling sin depender de una request larga.

### Por que esta opcion es mejor que solo aumentar timeout

- Evita request HTTP largas y fragiles.
- Reduce riesgo de timeout con playlists de 500-1000 tracks.
- Permite reintentos naturales por chunk.
- Facilita cancelacion del job.
- Controla mejor cuota/rate limit al limitar concurrencia y velocidad del worker.
- Mantiene costo predecible porque el trabajo se fracciona.

## Matching pipeline

Implementado en `functions/src/core/trackMatcher.js`.

Orden de evaluacion:

1. **ISRC exacto** -> `success`
2. **Firma sanitizada exacta** (titulo + artistas limpios) -> `success`
3. **Fuzzy matching**
   - `> 85` -> `success`
   - `70 - 85` -> `review_pending`
   - `< 70` -> `failed`

## Idempotencia

El engine evita duplicados en dos niveles:

1. **Playlist destino**
   - Busca por nombre en la cuenta del usuario.
   - Si existe, reutiliza `playlistId`.
   - Si no existe, la crea.

2. **Tracks ya sincronizados**
   - Construye un indice local con `trackId`, `ISRC` y firma normalizada.
   - Si el track ya esta dentro de la playlist destino, lo marca como `skipped`.

## Rate limit y resiliencia

- Reintentos con backoff exponencial para `429`.
- Respeta `retry-after` cuando el proveedor lo entrega.
- Registra eventos `SYNC_RATE_LIMIT_RETRY` en `sync_job_events`.

## Contrato Firestore recomendado para `sync_jobs/{jobId}`

```json
{
  "uid": "user_uid",
  "sourcePlatform": "spotify",
  "targetPlatform": "youtube",
  "sourcePlaylistId": "spotify_playlist_id",
  "state": "preparing|running|success|partial_success|failed|cancelled",
  "progress": 42,
  "attempt": 1,
  "cursor": {
    "offset": 100,
    "pageSize": 100,
    "hasMore": true
  },
  "counters": {
    "processed": 100,
    "created": 72,
    "updated": 0,
    "skipped": 18,
    "failed": 10
  },
  "sourceSnapshot": {
    "id": "spotify_playlist_id",
    "name": "Mi playlist",
    "description": "...",
    "totalTracks": 240,
    "imageUrl": "https://..."
  },
  "destination": {
    "playlistId": "target_playlist_id",
    "name": "Mi playlist",
    "existed": true
  },
  "review_pending": [
    {
      "sourceTrack": {
        "id": "src-1",
        "title": "Song A",
        "artists": ["Artist A"],
        "album": "Album A",
        "isrc": "USRC..."
      },
      "confidence": 78,
      "strategy": "fuzzy",
      "options": [
        {
          "confidence": 78,
          "strategy": "fuzzy",
          "track": {
            "id": "yt-1",
            "title": "Song A - Demo",
            "artists": ["Artist A"]
          }
        }
      ],
      "createdAt": "2026-03-15T20:00:00.000Z"
    }
  ],
  "failed_tracks": [
    {
      "sourceTrack": {
        "id": "src-2",
        "title": "Song B",
        "artists": ["Artist B"]
      },
      "confidence": 52,
      "strategy": "fuzzy",
      "options": [],
      "reason": "La similitud esta por debajo del umbral minimo aceptado.",
      "createdAt": "2026-03-15T20:00:00.000Z"
    }
  ],
  "errors": [
    {
      "trackId": "src-2",
      "code": "TRACK_MATCH_FAILED",
      "message": "No hubo coincidencia suficiente.",
      "retriable": false
    }
  ],
  "execution": {
    "mode": "task_queue_chunked",
    "pageSize": 100,
    "queueName": "syncJobWorker"
  },
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp",
  "startedAt": "serverTimestamp",
  "completedAt": "serverTimestamp"
}
```

## Notas de integracion

- El source adapter real implementado hoy es Spotify.
- El target adapter real implementado hoy es **YouTube Data API** (`youtube`).
- Contrato soportado por el engine: `listPlaylists`, `createPlaylist`, `listPlaylistTracks`, `searchTracks`, `addTrackToPlaylist`.
- Si en el futuro migras a **YouTube Music nativo**, convendra crear otro adapter especifico con el mismo contrato y registrarlo en `syncEngine`.

