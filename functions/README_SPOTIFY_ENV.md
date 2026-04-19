# Configuracion de envs para Spotify (Functions)

## 1) Crear archivo local

Copia el ejemplo:

```bash
cp .env.example .env
```

## 2) Completar variables

```env
SPOTIFY_CLIENT_ID=tu_client_id
SPOTIFY_CLIENT_SECRET=tu_client_secret
SPOTIFY_REDIRECT_URI=tu_redirect_uri_registrada_en_spotify
```

## 3) Probar en emulador o desplegar

```bash
npm run serve
```

```bash
firebase deploy --only functions:api
```

## Nota

`SPOTIFY_CLIENT_SECRET` nunca debe ir en Flutter. Solo backend.

