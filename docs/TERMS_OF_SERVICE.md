# Términos de Servicio — KeepSyn

**Última actualización:** 2 de julio de 2026

---

## 1. Aceptación de los Términos

Al acceder o utilizar KeepSyn ("la Aplicación"), aceptas quedar vinculado por estos Términos de Servicio ("Términos"). Si no estás de acuerdo con alguna parte de estos Términos, no podrás utilizar la Aplicación.

---

## 2. Descripción del Servicio

KeepSyn es una aplicación de sincronización de playlists musicales que permite a los usuarios:

- **Conectar** sus cuentas de Spotify y YouTube Music mediante autenticación OAuth 2.0.
- **Sincronizar** playlists desde Spotify hacia YouTube Music de forma automática o manual.
- **Consultar** el historial y estado de las sincronizaciones realizadas.

KeepSyn actúa como intermediario técnico entre las plataformas de terceros (Spotify y YouTube Music). No produce, distribuye ni almacena contenido musical.

---

## 3. Elegibilidad

La Aplicación está actualmente en fase de **acceso restringido** (lista de acceso autorizado). Solo pueden utilizarla los usuarios expresamente autorizados por el desarrollador. Debes tener al menos 13 años de edad para utilizar este servicio.

---

## 4. Cuentas de Terceros y Tokens de Autenticación

### 4.1 Autorización OAuth

Para operar, KeepSyn solicita acceso a tus cuentas de Spotify y YouTube Music a través del protocolo estándar OAuth 2.0. Al conceder este acceso, autorizas a la Aplicación a:

**Spotify:**
- Leer tu biblioteca de playlists y sus pistas.
- Obtener metadatos de canciones (nombre, artista, álbum, ISRC).

**YouTube Music:**
- Crear y modificar playlists en tu nombre.
- Buscar contenido musical para encontrar equivalencias.

### 4.2 Almacenamiento de Tokens

Los tokens de acceso (access token) y de refresco (refresh token) de Spotify y YouTube Music se almacenan de forma cifrada en **Google Firestore**, asociados únicamente a tu identificador de usuario (UID de Firebase). Estos tokens:

- Se utilizan **exclusivamente** para ejecutar las sincronizaciones que tú solicites.
- No se comparten con terceros bajo ningún concepto.
- Pueden ser revocados en cualquier momento desde los ajustes de seguridad de tu cuenta Spotify o Google.

### 4.3 Revocación de Acceso

Puedes retirar el acceso de KeepSyn a tus cuentas de terceros en cualquier momento:

- **Spotify:** [spotify.com/account/apps](https://www.spotify.com/account/apps)
- **Google/YouTube:** [myaccount.google.com/permissions](https://myaccount.google.com/permissions)

Al revocar el acceso, los tokens almacenados en Firestore quedarán inválidos y las sincronizaciones dejarán de funcionar hasta que vuelvas a autorizarlas.

---

## 5. Privacidad y Datos del Usuario

### 5.1 Datos que recopilamos

| Dato | Finalidad | Almacenamiento |
|---|---|---|
| UID de Firebase / email | Autenticación e identificación | Firebase Auth |
| Access token y refresh token de Spotify | Leer playlists y pistas | Firestore (`user_integrations/{uid}`) |
| Access token y refresh token de YouTube | Crear/modificar playlists | Firestore (`user_integrations/{uid}`) |
| Historial de sincronizaciones | Mostrar estado y errores al usuario | Firestore (`sync_jobs`, `sync_job_events`) |
| Caché de búsqueda de canciones | Reducir solicitudes redundantes | Firestore (`track_search_cache`, TTL 30 días) |

### 5.2 Datos que NO recopilamos

- No almacenamos el contenido de tus canciones ni archivos de audio.
- No vendemos ni cedemos tus datos a anunciantes.
- No construimos perfiles de comportamiento más allá del uso estrictamente necesario para la sincronización.

### 5.3 Retención de Datos

Los datos de sincronización se conservan mientras tu cuenta permanezca activa. Al solicitar la eliminación de tu cuenta, se eliminarán todos tus tokens, historial de sincronizaciones y datos asociados en un plazo máximo de 30 días.

---

## 6. Uso Aceptable

Aceptas no utilizar KeepSyn para:

- Violar los términos de servicio de Spotify, YouTube o Google.
- Intentar acceder a cuentas de otros usuarios.
- Realizar ingeniería inversa, descompilar o manipular la Aplicación.
- Usar el servicio de forma masiva o automatizada sin autorización expresa.
- Cualquier actividad ilegal o fraudulenta.

---

## 7. Servicios de Terceros

KeepSyn depende de los siguientes servicios externos, sujetos a sus propios términos:

- **Spotify:** [spotify.com/legal/end-user-agreement](https://www.spotify.com/legal/end-user-agreement/)
- **YouTube / Google:** [policies.google.com/terms](https://policies.google.com/terms)
- **Firebase / Google Cloud:** [firebase.google.com/terms](https://firebase.google.com/terms)

KeepSyn no se responsabiliza de interrupciones, cambios de API o modificaciones de términos realizados por estas plataformas que puedan afectar el funcionamiento del servicio.

---

## 8. Disponibilidad del Servicio

La Aplicación se ofrece **"tal cual"** y **"según disponibilidad"**. No garantizamos disponibilidad ininterrumpida. Las sincronizaciones pueden fallar por cambios en las APIs de Spotify o YouTube, cuotas de uso o mantenimiento. El desarrollador se reserva el derecho de suspender o discontinuar el servicio en cualquier momento sin previo aviso.

---

## 9. Limitación de Responsabilidad

En la máxima medida permitida por la ley aplicable, el desarrollador de KeepSyn no será responsable de:

- Pérdida de playlists o datos musicales derivada del uso de la Aplicación.
- Cambios en las APIs de Spotify o YouTube que interrumpan el servicio.
- Acceso no autorizado a tus cuentas de terceros derivado de brechas en los propios servicios de Spotify o Google.
- Daños indirectos, incidentales o consecuentes.

---

## 10. Propiedad Intelectual

El código fuente, diseño y lógica de KeepSyn son propiedad del desarrollador. No se otorga ninguna licencia sobre el software más allá del uso personal del servicio. El contenido musical (canciones, álbumes, playlists) sigue siendo propiedad de sus respectivos titulares y plataformas.

---

## 11. Modificaciones

Estos Términos pueden actualizarse periódicamente. Las modificaciones sustanciales se notificarán mediante la Aplicación o por correo electrónico. El uso continuado de KeepSyn tras la publicación de cambios implica la aceptación de los nuevos Términos.

---

## 12. Ley Aplicable

Estos Términos se rigen por la legislación española. Cualquier disputa se someterá a los tribunales competentes de la jurisdicción del desarrollador.

---

## 13. Contacto

Para preguntas sobre estos Términos, solicitudes de eliminación de datos o reportar un problema:

**Email:** jorgejair5678@gmail.com

---

*KeepSyn es un proyecto personal, no afiliado a Spotify AB ni a Google LLC.*
