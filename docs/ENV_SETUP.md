# Configuracion de variables de entorno

## Flutter (cliente)

En Flutter no se guardan secretos reales. Solo valores publicos/configuracion:

1. Copia el ejemplo:

```bash
cp env/app_config.example.json env/app_config.local.json
```

2. Completa tus valores en `env/app_config.local.json`.

3. Ejecuta con `--dart-define-from-file`:

```bash
flutter run --dart-define-from-file=env/app_config.local.json
```

## Functions (backend) - recomendado seguro

No subas secretos en `.env` al repo. Usa Secret Manager:

```bash
cd functions
firebase functions:secrets:set SPOTIFY_CLIENT_ID
firebase functions:secrets:set SPOTIFY_CLIENT_SECRET
firebase functions:secrets:set SPOTIFY_REDIRECT_URI
firebase functions:secrets:set YOUTUBE_CLIENT_ID
firebase functions:secrets:set YOUTUBE_CLIENT_SECRET
```

Despues despliega la API:

```bash
firebase deploy --only functions:api
```

Para YouTube con `google_sign_in` incremental scopes, Flutter solo necesita
`SERVER_CLIENT_ID` (para solicitar `serverAuthCode`).
