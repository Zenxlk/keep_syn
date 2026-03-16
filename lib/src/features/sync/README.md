# Sync Feature (P0)

Base de sincronizacion desacoplada para KeepSyn.

## Estado actual

- Dominio: entidades (`Playlist`, `Track`, `SyncJob`, `SyncProgress`, `SyncResult`).
- Contrato: `ISyncRepository`.
- Datos: `ISyncService` + `MockSyncService` + `SyncRepositoryImpl`.
- Presentacion: `SyncControllerState` + `SyncController` (Riverpod v2 generator).

## Objetivo

Permitir evolucionar a servicios reales (Cloud Functions / API) sin tocar UI ni dominio.

## Siguiente paso

- P0.3 persistencia local de ultimo estado y errores.
- Integrar `SyncController` en `SyncScreen` placeholder.

