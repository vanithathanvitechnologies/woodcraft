const jwt = require('jsonwebtoken');

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, message: 'Authentication token required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'wooden_door_super_secret_jwt_key_2026');
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }
}

function requireRoles(...roles) {
  return (req, res, next) => {
    if (!req.user || req.user.type !== 'staff') {
      return res.status(403).json({ success: false, message: 'Staff access required' });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Access denied. Required role: ${roles.join(', ')}`,
      });
    }
    next();
  };
}

function requireCustomer(req, res, next) {
  if (!req.user || req.user.type !== 'customer') {
    return res.status(403).json({ success: false, message: 'Customer access required' });
  }
  next();
}

module.exports = {
  authenticateToken,
  requireRoles,
  requireCustomer,
};
