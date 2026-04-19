// Inyecta helpers en 'res' para garantizar el contrato de respuesta
exports.standardResponse = (req, res, next) => {
  res.ok = (message, data = null) => {
    res.status(200).json({ status: "OK", message, data });
  };

  res.error = (message, statusCode = 400, data = null) => {
    res.status(statusCode).json({ status: "ERROR", message, data });
  };

  next();
};