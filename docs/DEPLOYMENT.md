# Deployment Guide

This guide covers deploying the CIH App to various platforms.

## 📋 Pre-Deployment Checklist

- [ ] All tests passing
- [ ] Environment variables configured
- [ ] Production build tested locally
- [ ] Database migrations ready (if applicable)
- [ ] API endpoints tested
- [ ] Security headers configured
- [ ] CORS settings verified
- [ ] Error logging configured

## 🚀 Deployment Options

### Option 1: Vercel (Frontend) + Railway/Render (Backend)

#### Frontend (Vercel)

1. **Install Vercel CLI:**
   ```bash
   npm i -g vercel
   ```

2. **Login to Vercel:**
   ```bash
   vercel login
   ```

3. **Deploy:**
   ```bash
   vercel --prod
   ```

4. **Set Environment Variables:**
   - Go to Vercel Dashboard → Settings → Environment Variables
   - Add all variables from `.env.production`

#### Backend (Railway)

1. **Install Railway CLI:**
   ```bash
   npm i -g @railway/cli
   ```

2. **Login:**
   ```bash
   railway login
   ```

3. **Initialize:**
   ```bash
   railway init
   ```

4. **Deploy:**
   ```bash
   railway up
   ```

5. **Set Environment Variables:**
   ```bash
   railway variables set PORT=3000
   railway variables set NODE_ENV=production
   ```

### Option 2: Netlify (Frontend) + Heroku (Backend)

#### Frontend (Netlify)

1. **Install Netlify CLI:**
   ```bash
   npm i -g netlify-cli
   ```

2. **Login:**
   ```bash
   netlify login
   ```

3. **Deploy:**
   ```bash
   netlify deploy --prod
   ```

#### Backend (Heroku)

1. **Install Heroku CLI:**
   ```bash
   brew tap heroku/brew && brew install heroku
   ```

2. **Login:**
   ```bash
   heroku login
   ```

3. **Create app:**
   ```bash
   heroku create your-app-name
   ```

4. **Deploy:**
   ```bash
   git push heroku main
   ```

5. **Set environment variables:**
   ```bash
   heroku config:set NODE_ENV=production
   heroku config:set PORT=3000
   ```

### Option 3: Docker (Full Stack)

1. **Create Dockerfile for Frontend:**
   ```dockerfile
   FROM node:18-alpine
   WORKDIR /app
   COPY package*.json ./
   RUN npm ci
   COPY . .
   RUN npm run build
   EXPOSE 5173
   CMD ["npm", "run", "preview"]
   ```

2. **Create Dockerfile for Backend:**
   ```dockerfile
   FROM node:18-alpine
   WORKDIR /app
   COPY server/package*.json ./
   RUN npm ci --only=production
   COPY server/ .
   EXPOSE 3000
   CMD ["node", "index.js"]
   ```

3. **Create docker-compose.yml:**
   ```yaml
   version: '3.8'
   services:
     frontend:
       build:
         context: .
         dockerfile: Dockerfile.frontend
       ports:
         - "5173:5173"
       environment:
         - VITE_API_URL=http://backend:3000/api

     backend:
       build:
         context: .
         dockerfile: Dockerfile.backend
       ports:
         - "3000:3000"
       environment:
         - NODE_ENV=production
         - PORT=3000
   ```

4. **Deploy:**
   ```bash
   docker-compose up -d
   ```

### Option 4: AWS (Full Stack)

#### Using AWS Amplify (Frontend) + Elastic Beanstalk (Backend)

1. **Frontend (Amplify):**
   - Connect your GitHub repository
   - Configure build settings
   - Set environment variables
   - Deploy automatically on push

2. **Backend (Elastic Beanstalk):**
   ```bash
   eb init
   eb create production-env
   eb deploy
   ```

## 🔒 Security Considerations

1. **Environment Variables:**
   - Never commit `.env` files
   - Use platform-specific secret management
   - Rotate secrets regularly

2. **HTTPS:**
   - Always use HTTPS in production
   - Configure SSL certificates

3. **CORS:**
   - Set specific origins, not `*`
   - Update CORS_ORIGIN in production

4. **Rate Limiting:**
   - Implement rate limiting on API
   - Use services like Cloudflare

5. **Database:**
   - Use connection pooling
   - Enable SSL for database connections
   - Regular backups

## 📊 Monitoring

1. **Frontend:**
   - Google Analytics
   - Sentry for error tracking
   - Lighthouse for performance

2. **Backend:**
   - PM2 for process management
   - Winston for logging
   - New Relic / DataDog for monitoring

## 🔄 CI/CD

The project includes GitHub Actions workflows:
- Automatic testing on PR
- Automatic deployment on merge to main
- Code quality checks

## 📝 Post-Deployment

1. **Verify deployment:**
   - Check all endpoints
   - Test critical user flows
   - Monitor error logs

2. **Performance:**
   - Run Lighthouse audit
   - Check API response times
   - Monitor resource usage

3. **Documentation:**
   - Update API documentation
   - Document any deployment-specific configurations

## 🆘 Troubleshooting

### Build Fails
- Check Node version matches requirements
- Verify all dependencies are installed
- Check for environment variable issues

### API Not Connecting
- Verify CORS settings
- Check API URL in frontend config
- Ensure backend is running

### Database Connection Issues
- Verify connection string
- Check firewall rules
- Ensure database is accessible from deployment platform

---

For more help, see the [main README](../README.md) or create an issue.
