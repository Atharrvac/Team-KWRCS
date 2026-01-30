# API Documentation

## Base URL
```
Development: http://localhost:3000/api
Production: https://your-api-domain.com/api
```

## Authentication

Most endpoints require authentication using JWT tokens. Include the token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

## Endpoints

### Health Check

**GET** `/health`

Check if the API is running.

**Response:**
```json
{
  "status": "OK",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "uptime": 12345
}
```

### API Info

**GET** `/api`

Get API information and available endpoints.

**Response:**
```json
{
  "message": "API is running",
  "version": "1.0.0",
  "endpoints": {
    "health": "/health",
    "api": "/api"
  }
}
```

---

## Adding New Endpoints

### 1. Create a Controller

Create a new file in `server/controllers/`:

```javascript
// server/controllers/exampleController.js
export const getExample = async (req, res, next) => {
  try {
    // Your logic here
    res.json({ message: 'Success' });
  } catch (error) {
    next(error);
  }
};
```

### 2. Create a Route

Create a new file in `server/routes/`:

```javascript
// server/routes/exampleRoutes.js
import express from 'express';
import { getExample } from '../controllers/exampleController.js';

const router = express.Router();

router.get('/', getExample);

export default router;
```

### 3. Register the Route

Add to `server/routes/index.js`:

```javascript
import exampleRoutes from './exampleRoutes.js';

router.use('/example', exampleRoutes);
```

---

## Error Handling

All errors are handled by the global error handler middleware. Errors should be thrown with a `statusCode` property:

```javascript
const error = new Error('Resource not found');
error.statusCode = 404;
throw error;
```

**Error Response Format:**
```json
{
  "success": false,
  "message": "Error message",
  "stack": "Stack trace (development only)"
}
```

---

## Common Status Codes

- `200` - OK
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `500` - Internal Server Error

---

## Rate Limiting

(To be implemented)

---

## Versioning

API versioning is handled through the URL path:
- v1: `/api/v1/...`
- v2: `/api/v2/...`

---

For more details, see the [main README](../README.md).
