import express from 'express';

const router = express.Router();

// Example route
router.get('/', (req, res) => {
  res.json({
    message: 'API is running',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      api: '/api',
    },
  });
});

// Add your routes here
// Example:
// import userRoutes from './userRoutes.js';
// router.use('/users', userRoutes);

export default router;
