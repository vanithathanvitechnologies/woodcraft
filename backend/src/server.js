const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const { PRODUCTION_STAGES, WOODWORK_CATEGORIES, WOOD_SPECIES, POLISH_SHADES } = require('./config/constants');
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const catalogRoutes = require('./routes/catalog');
const customerRoutes = require('./routes/customers');
const orderRoutes = require('./routes/orders');
const productionRoutes = require('./routes/production');
const customerPortalRoutes = require('./routes/customerPortal');
const reportRoutes = require('./routes/reports');

const app = express();
const PORT = Number(process.env.PORT || 5000);

app.use(cors());
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true }));

// Static uploads (Design Catalog, AI Outputs, Workshop Progress Photos)
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// Health & Metadata endpoint
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    service: 'Wooden Door & Frame Customizer MySQL API',
    timestamp: new Date().toISOString(),
  });
});

app.get('/api/meta', (req, res) => {
  res.json({
    success: true,
    stages: PRODUCTION_STAGES,
    categories: WOODWORK_CATEGORIES,
    wood_species: WOOD_SPECIES,
    polish_shades: POLISH_SHADES,
  });
});

// Mount Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/catalog', catalogRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/production', productionRoutes);
app.use('/api/customer', customerPortalRoutes);
app.use('/api/reports', reportRoutes);

app.use((err, req, res, next) => {
  console.error('Unhandled API error:', err);
  res.status(500).json({ success: false, message: err.message || 'Internal Server Error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Wooden Door MySQL API running at http://localhost:${PORT}`);
});
