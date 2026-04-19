# Postman - KeepSyn Sync API

## Archivos

- `KeepSyn-Sync.postman_collection.json`
- `KeepSyn-Sync.local.postman_environment.json`

## Uso rapido

1. Importa la coleccion y el environment en Postman.
2. Selecciona el environment `KeepSyn Local`.
3. Pega un Firebase ID token valido en `idToken`.
4. Ejecuta en este orden:
   - `1 - Crear Job`
   - `2 - Obtener Estado Job`
   - `3 - Cancelar Job` (opcional)
   - `4 - Ultimo Job`

## Notas

- `1 - Crear Job` guarda automaticamente `jobId` en el environment.
- Si ves `Token invalido o expirado`, renueva el ID token del usuario.
- El usuario debe estar en la coleccion `allowlist` para pasar el middleware.

