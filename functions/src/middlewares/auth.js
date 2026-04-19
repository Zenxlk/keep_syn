const admin = require('firebase-admin');

// Valida el ID Token de Firebase
exports.verifyToken = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.error('Token de autorización faltante o mal formado.', 401);
  }

  const idToken = authHeader.split('Bearer ')[1];
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.user = decodedToken; // Inyectamos el usuario en la request
    next();
  } catch (error) {
    console.error('Error verificando token:', error);
    return res.error('Token inválido o expirado.', 401);
  }
};

// Reutiliza la lógica de allowlist validando el email en Firestore
exports.checkAllowlist = async (req, res, next) => {
  const email = req.user.email;
  if (!email) return res.error('El token no contiene un email válido.', 403);

  try {
    const doc = await admin.firestore().collection('allowlist').doc(email).get();
    if (!doc.exists) {
      return res.error('Usuario no autorizado para interactuar con la API de Sync.', 403);
    }
    next();
  } catch (error) {
    console.error('Error comprobando allowlist:', error);
    return res.error('Error interno verificando permisos.', 500);
  }
};