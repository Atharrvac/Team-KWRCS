# CIH App - Full-Stack React Application

A production-ready full-stack application built with React (frontend) and Express (backend).

## 🚀 Features

- ⚡ **Vite** - Lightning fast build tool
- ⚛️ **React 19** - Latest React features
- 🎨 **Modern UI** - Clean and responsive design
- 🔐 **Authentication Ready** - JWT token setup
- 🛣️ **React Router** - Client-side routing
- 📡 **Axios** - HTTP client with interceptors
- 🔧 **Express Backend** - RESTful API server
- 🎯 **ESLint & Prettier** - Code quality and formatting
- 🧪 **Vitest** - Unit testing framework
- 🔄 **Hot Module Replacement** - Fast development
- 📦 **Production Ready** - Optimized builds

## 📋 Prerequisites

Before you begin, ensure you have the following installed:
- **Node.js** >= 18.0.0
- **npm** >= 9.0.0

## 🛠️ Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd Cih3.0
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment variables**

   For the **frontend**, copy `.env.example` to `.env.development`:
   ```bash
   cp .env.example .env.development
   ```

   For the **backend**, copy `server/.env.example` to `server/.env`:
   ```bash
   cp server/.env.example server/.env
   ```

   Update the values in both files according to your setup.

## 🚀 Running the Application

### Development Mode

**Run frontend and backend together:**
```bash
npm run dev:all
```

**Or run them separately:**

Frontend only:
```bash
npm run dev
```

Backend only:
```bash
npm run dev:server
```

The application will be available at:
- Frontend: http://localhost:5173
- Backend API: http://localhost:3000/api

### Production Mode

1. **Build the frontend:**
   ```bash
   npm run build:prod
   ```

2. **Preview the production build:**
   ```bash
   npm run preview
   ```

3. **Run the backend:**
   ```bash
   npm run server
   ```

## 📁 Project Structure

```
Cih3.0/
├── .github/              # GitHub Actions workflows
│   └── workflows/
├── docs/                 # Documentation files
├── public/               # Static assets
├── scripts/              # Build and utility scripts
├── server/               # Backend Express server
│   ├── config/          # Server configuration
│   ├── controllers/     # Route controllers
│   ├── middleware/      # Express middleware
│   ├── models/          # Database models
│   ├── routes/          # API routes
│   ├── services/        # Business logic
│   ├── utils/           # Server utilities
│   └── index.js         # Server entry point
├── src/                  # Frontend React application
│   ├── assets/          # Images, fonts, icons
│   ├── components/      # Reusable components
│   ├── config/          # App configuration
│   ├── constants/       # App constants
│   ├── context/         # React Context providers
│   ├── hooks/           # Custom React hooks
│   ├── layouts/         # Page layouts
│   ├── pages/           # Page components
│   ├── services/        # API services
│   ├── styles/          # Global styles
│   ├── types/           # TypeScript types (if using TS)
│   ├── utils/           # Utility functions
│   ├── App.jsx          # Main App component
│   └── main.jsx         # Application entry point
├── tests/                # Test files
│   ├── unit/            # Unit tests
│   ├── integration/     # Integration tests
│   └── e2e/             # End-to-end tests
├── .editorconfig        # Editor configuration
├── .env.example         # Environment variables template
├── .eslintrc.js         # ESLint configuration
├── .gitignore           # Git ignore rules
├── .prettierrc          # Prettier configuration
├── package.json         # Project dependencies
├── README.md            # This file
└── vite.config.js       # Vite configuration
```

## 🧪 Testing

Run tests:
```bash
npm run test
```

Run tests with UI:
```bash
npm run test:ui
```

Generate coverage report:
```bash
npm run test:coverage
```

## 🎨 Code Quality

**Lint your code:**
```bash
npm run lint
```

**Fix linting issues:**
```bash
npm run lint:fix
```

**Format your code:**
```bash
npm run format
```

**Check formatting:**
```bash
npm run format:check
```

## 📝 Available Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Start frontend development server |
| `npm run dev:server` | Start backend development server |
| `npm run dev:all` | Start both frontend and backend |
| `npm run build` | Build frontend for production |
| `npm run build:prod` | Build with production environment |
| `npm run preview` | Preview production build |
| `npm run lint` | Run ESLint |
| `npm run lint:fix` | Fix ESLint issues |
| `npm run format` | Format code with Prettier |
| `npm run format:check` | Check code formatting |
| `npm run test` | Run tests |
| `npm run test:ui` | Run tests with UI |
| `npm run test:coverage` | Generate test coverage |
| `npm run server` | Start production backend server |

## 🔧 Configuration

### Environment Variables

**Frontend (.env.development):**
- `VITE_API_URL` - Backend API URL
- `VITE_APP_NAME` - Application name
- `VITE_APP_VERSION` - Application version
- `VITE_NODE_ENV` - Environment (development/production)

**Backend (server/.env):**
- `PORT` - Server port (default: 3000)
- `NODE_ENV` - Environment
- `CORS_ORIGIN` - Allowed CORS origin
- `DATABASE_URL` - Database connection string
- `JWT_SECRET` - JWT secret key

## 🤝 Contributing

1. Create a new branch: `git checkout -b feature/your-feature-name`
2. Make your changes
3. Run tests and linting: `npm run test && npm run lint`
4. Commit your changes: `git commit -m 'Add some feature'`
5. Push to the branch: `git push origin feature/your-feature-name`
6. Submit a pull request

## 📚 Additional Resources

- [React Documentation](https://react.dev)
- [Vite Documentation](https://vitejs.dev)
- [Express Documentation](https://expressjs.com)
- [React Router Documentation](https://reactrouter.com)

## 📄 License

This project is licensed under the MIT License.

## 👥 Team

- Your Team Name
- Add team members here

## 🐛 Issues

If you encounter any issues, please file them in the [issue tracker](your-repo-url/issues).

---

**Happy Coding! 🚀**
