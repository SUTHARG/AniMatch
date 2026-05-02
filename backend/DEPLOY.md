# 🚀 Deploying the AniMatch Streaming Backend

This backend acts as a proxy for the Hianime API and AniSkip, providing Redis caching to ensure fast load times and bypass rate limits.

## 1. Prerequisites
- **Node.js** (v18 or higher)
- **Redis** (e.g., Upstash Redis or a local instance)
- **Hianime API URL** (You can use `https://api-aniwatch.onrender.com` or your own instance)

## 2. Environment Variables
Create a `.env` file in the `backend/` directory (or set these in your hosting provider's dashboard):

```env
PORT=3000
REDIS_URL=redis://your-redis-url:6379
ANIWATCH_API_URL=https://api-aniwatch.onrender.com
```

## 3. Deployment Options

### Option A: Railway (Recommended)
1. **Push to GitHub**: Ensure your `backend/` folder is part of your repository.
2. **Create New Project**: On Railway, click "New Project" -> "Deploy from GitHub repo".
3. **Set Root Directory**: In the settings, set the **Root Directory** to `backend`.
4. **Add Variables**: Add `REDIS_URL` and `ANIWATCH_API_URL` in the Variables tab.
5. **Provision Redis**: If you don't have Redis, click "Add Service" -> "Redis" inside the same project. Railway will automatically set the `REDIS_URL`.

### Option B: Render
1. **Create Web Service**: Connect your GitHub repo.
2. **Root Directory**: Set to `backend`.
3. **Build Command**: `npm install`
4. **Start Command**: `npm start`
5. **Environment Variables**: Add your `.env` keys in the "Environment" tab.

## 4. Local Testing
To test the backend locally before deploying:

```bash
cd backend
npm install
npm run dev
```

The server will start at `http://localhost:3000`. You can verify it by visiting `http://localhost:3000/health`.

---

### ⚠️ Important Update for Flutter
Once deployed, remember to update the `BACKEND_URL` in your Flutter `.env` file:
`BACKEND_URL=https://your-deployed-app.railway.app`
