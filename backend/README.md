# AniMatch Backend API

High-performance Node.js backend for the AniMatch Flutter app. Proxies Jikan and AniList APIs with Redis caching to prevent rate limit issues.

## Tech Stack
- **Runtime**: Node.js 20
- **Framework**: Express
- **Cache**: Upstash Redis
- **HTTP**: Axios
- **Deployment**: Railway

## Deployment Steps

### 1. Upstash Redis Setup
1. Go to [Upstash Console](https://console.upstash.com/).
2. Create a new **Redis** database (Serverless).
3. Copy the **REST URL** and **REST Token**.

### 2. Railway Deployment
1. Go to [Railway](https://railway.app/).
2. Create a new project from your GitHub repository.
3. In the project settings, add the following **Environment Variables**:
   - `UPSTASH_REDIS_REST_URL`: (Paste from Upstash)
   - `UPSTASH_REDIS_REST_TOKEN`: (Paste from Upstash)
   - `PORT`: 3000 (or leave blank for Railway default)
4. Railway will automatically detect the `Procfile` and start the server.

## API Endpoints

### Anime
- `GET /anime/trending`
- `GET /anime/seasonal`
- `GET /anime/top`
- `GET /anime/upcoming`
- `GET /anime/search?q=query`
- `GET /anime/:id`
- `GET /anime/:id/streaming`
- `GET /anime/:id/recommendations`
- `GET /anime/:id/characters`
- `GET /anime/schedule/:day`
- `GET /anime/random`

### Manga
- `GET /manga/trending`
- `GET /manga/top`
- `GET /manga/search?q=query`
- `GET /manga/:id`
- `GET /manga/:id/recommendations`
- `GET /manga/:id/characters`
- `GET /manga/magazines`
- `GET /manga/by-magazine/:id`

### AniList (GraphQL Proxy)
- `GET /anilist/trending`
- `GET /anilist/seasonal`
- `GET /anilist/top-rated`
- `GET /anilist/upcoming`
- `GET /anilist/schedule?start=&end=`
- `GET /anilist/cover/:malId`

### Recommendations
- `POST /recommendations`: Body `QuizAnswers` (mood, genres, episodeRange, status, typeParam, isManga)

---

## Health Check
- `GET /health`: Returns `{ status: 'ok', redis: 'connected' }`
