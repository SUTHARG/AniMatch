require('dotenv').config();
const express = require('express');
const { Redis } = require('@upstash/redis');
const axios = require('axios');
const cors = require('cors');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3000;

// Upstash Redis Initialization
const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL,
  token: process.env.UPSTASH_REDIS_REST_TOKEN,
});

// Middleware
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

// Constants
const JIKAN_BASE = 'https://api.jikan.moe/v4';
const ANILIST_BASE = 'https://graphql.anilist.co';

// Rate Limiting Logic for Jikan
let lastRequestTime = 0;
const MIN_DELAY = 800; // 800ms between requests

const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function fetchWithRetry(url, params = {}, retryCount = 0) {
  // Global Throttle
  const now = Date.now();
  const timeSinceLast = now - lastRequestTime;
  if (timeSinceLast < MIN_DELAY) {
    await wait(MIN_DELAY - timeSinceLast);
  }
  lastRequestTime = Date.now();

  try {
    const response = await axios.get(url, { params });
    return response.data;
  } catch (error) {
    if (error.response && error.response.status === 429 && retryCount < 1) {
      console.warn(`Rate limited (429) on ${url}. Retrying in 2 seconds...`);
      await wait(2000);
      return fetchWithRetry(url, params, retryCount + 1);
    }
    throw error;
  }
}

// Caching Wrapper
async function getCached(key, fetcher, ttlSeconds) {
  try {
    const cached = await redis.get(key);
    if (cached) {
      console.log(`Cache HIT: ${key}`);
      return cached;
    }
  } catch (err) {
    console.error(`Redis Get Error: ${err.message}`);
  }

  console.log(`Cache MISS: ${key}. Fetching fresh data...`);
  const data = await fetcher();
  
  try {
    await redis.set(key, JSON.stringify(data), { ex: ttlSeconds });
  } catch (err) {
    console.error(`Redis Set Error: ${err.message}`);
  }
  
  return data;
}

// --- Health Check ---
app.get('/health', async (req, res) => {
  try {
    await redis.ping();
    res.json({ status: 'ok', redis: 'connected' });
  } catch (err) {
    res.status(500).json({ status: 'error', redis: 'disconnected', error: err.message });
  }
});

// --- Anime Endpoints ---

app.get('/anime/trending', async (req, res) => {
  const data = await getCached('anime:trending', () => fetchWithRetry(`${JIKAN_BASE}/top/anime`, { limit: 20 }), 3600);
  res.json(data);
});

app.get('/anime/seasonal', async (req, res) => {
  const data = await getCached('anime:seasonal', () => fetchWithRetry(`${JIKAN_BASE}/seasons/now`, { limit: 20 }), 3600);
  res.json(data);
});

app.get('/anime/top', async (req, res) => {
  const data = await getCached('anime:top', () => fetchWithRetry(`${JIKAN_BASE}/top/anime`, { limit: 20 }), 21600);
  res.json(data);
});

app.get('/anime/upcoming', async (req, res) => {
  const data = await getCached('anime:upcoming', () => fetchWithRetry(`${JIKAN_BASE}/seasons/upcoming`, { limit: 20 }), 21600);
  res.json(data);
});

app.get('/anime/search', async (req, res) => {
  const { q, page = 1 } = req.query;
  const data = await getCached(`anime:search:${q}:${page}`, () => fetchWithRetry(`${JIKAN_BASE}/anime`, { 
    q, 
    page, 
    limit: 20, 
    order_by: 'score', 
    sort: 'desc' 
  }), 900);
  res.json(data);
});

app.get('/anime/random', async (req, res) => {
  // Random anime shouldn't be cached
  try {
    const data = await fetchWithRetry(`${JIKAN_BASE}/random/anime`);
    res.json(data);
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

app.get('/anime/schedule/:day', async (req, res) => {
  const { day } = req.params;
  const data = await getCached(`anime:schedule:${day}`, () => fetchWithRetry(`${JIKAN_BASE}/schedules`, { filter: day, limit: 15 }), 3600);
  res.json(data);
});

app.get('/anime/:id', async (req, res) => {
  const { id } = req.params;
  const data = await getCached(`anime:detail:${id}`, () => fetchWithRetry(`${JIKAN_BASE}/anime/${id}/full`), 86400);
  res.json(data);
});

app.get('/anime/:id/streaming', async (req, res) => {
  const { id } = req.params;
  const data = await getCached(`anime:streaming:${id}`, () => fetchWithRetry(`${JIKAN_BASE}/anime/${id}/streaming`), 604800);
  res.json(data);
});

app.get('/anime/:id/recommendations', async (req, res) => {
  const { id } = req.params;
  const data = await getCached(`anime:recommendations:${id}`, () => fetchWithRetry(`${JIKAN_BASE}/anime/${id}/recommendations`), 86400);
  res.json(data);
});

app.get('/anime/:id/characters', async (req, res) => {
  const { id } = req.params;
  const data = await getCached(`anime:characters:${id}`, () => fetchWithRetry(`${JIKAN_BASE}/anime/${id}/characters`), 86400);
  res.json(data);
});

// --- Manga Endpoints ---

app.get('/manga/trending', async (req, res) => {
  const data = await getCached('manga:trending', () => fetchWithRetry(`${JIKAN_BASE}/top/manga`, { limit: 20 }), 3600);
  res.json(data);
});

app.get('/manga/top', async (req, res) => {
  const data = await getCached('manga:top', () => fetchWithRetry(`${JIKAN_BASE}/top/manga`, { limit: 20 }), 21600);
  res.json(data);
});

app.get('/manga/search', async (req, res) => {
  const { q, page = 1 } = req.query;
  const data = await getCached(`manga:search:${q}:${page}`, () => fetchWithRetry(`${JIKAN_BASE}/manga`, { 
    q, 
    page, 
    limit: 20, 
    order_by: 'score', 
    sort: 'desc' 
  }), 900);
  res.json(data);
});

app.get('/manga/magazines', async (req, res) => {
  const data = await getCached('manga:magazines', () => fetchWithRetry(`${JIKAN_BASE}/magazines`, { limit: 20 }), 21600);
  res.json(data);
});

app.get('/manga/by-magazine/:id', async (req, res) => {
  const { id } = req.params;
  const { page = 1 } = req.query;
  const data = await getCached(`manga:magazine:${id}:${page}`, () => fetchWithRetry(`${JIKAN_BASE}/manga`, { 
    magazines: id, 
    order_by: 'popularity', 
    page, 
    limit: 20 
  }), 3600);
  res.json(data);
});

app.get('/manga/:id', async (req, res) => {
  const { id } = req.params;
  const data = await getCached(`manga:detail:${id}`, () => fetchWithRetry(`${JIKAN_BASE}/manga/${id}/full`), 86400);
  res.json(data);
});

app.get('/manga/:id/recommendations', async (req, res) => {
  const { id } = req.params;
  const data = await getCached(`manga:recommendations:${id}`, () => fetchWithRetry(`${JIKAN_BASE}/manga/${id}/recommendations`), 86400);
  res.json(data);
});

app.get('/manga/:id/characters', async (req, res) => {
  const { id } = req.params;
  const data = await getCached(`manga:characters:${id}`, () => fetchWithRetry(`${JIKAN_BASE}/manga/${id}/characters`), 86400);
  res.json(data);
});

// --- AniList Endpoints (GraphQL Proxy) ---

const fetchAnilist = async (query, variables = {}) => {
  const response = await axios.post(ANILIST_BASE, { query, variables });
  return response.data;
};

app.get('/anilist/trending', async (req, res) => {
  const query = `query { Page(page: 1, perPage: 15) { media(type: ANIME, sort: TRENDING_DESC) { idMal id title { english romaji } coverImage { extraLarge large } bannerImage description averageScore episodes status format genres startDate { year month day } } } }`;
  const data = await getCached('anilist:trending', () => fetchAnilist(query), 3600);
  res.json(data);
});

app.get('/anilist/seasonal', async (req, res) => {
  const query = `query { Page(page: 1, perPage: 15) { media(type: ANIME, sort: POPULARITY_DESC, status: RELEASING) { idMal id title { english romaji } coverImage { extraLarge large } bannerImage description averageScore episodes status format genres startDate { year month day } } } }`;
  const data = await getCached('anilist:seasonal', () => fetchAnilist(query), 3600);
  res.json(data);
});

app.get('/anilist/top-rated', async (req, res) => {
  const query = `query { Page(page: 1, perPage: 15) { media(type: ANIME, sort: SCORE_DESC) { idMal id title { english romaji } coverImage { extraLarge large } bannerImage description averageScore episodes status format genres startDate { year month day } } } }`;
  const data = await getCached('anilist:top', () => fetchAnilist(query), 21600);
  res.json(data);
});

app.get('/anilist/upcoming', async (req, res) => {
  const query = `query { Page(page: 1, perPage: 15) { media(type: ANIME, sort: POPULARITY_DESC, status: NOT_YET_RELEASED) { idMal id title { english romaji } coverImage { extraLarge large } bannerImage description averageScore episodes status format genres startDate { year month day } } } }`;
  const data = await getCached('anilist:upcoming', () => fetchAnilist(query), 21600);
  res.json(data);
});

app.get('/anilist/schedule', async (req, res) => {
  const { start, end } = req.query;
  const query = `query ($start: Int, $end: Int) { Page(page: 1, perPage: 50) { airingSchedules(airingAt_greater: $start, airingAt_lesser: $end, sort: TIME) { airingAt episode media { idMal title { romaji english } coverImage { large } } } } }`;
  const data = await getCached(`anilist:schedule:${start}:${end}`, () => fetchAnilist(query, { start: parseInt(start), end: parseInt(end) }), 1800);
  res.json(data);
});

app.get('/anilist/cover/:malId', async (req, res) => {
  const { malId } = req.params;
  const { type = 'ANIME' } = req.query;
  const query = `query ($id: Int) { Media(idMal: $id, type: ${type}) { coverImage { extraLarge large } } }`;
  const data = await getCached(`anilist:cover:${malId}:${type}`, () => fetchAnilist(query, { id: parseInt(malId) }), 86400);
  res.json(data);
});

app.get('/anilist/cover-by-title', async (req, res) => {
  const { q, type = 'ANIME' } = req.query;
  const query = `query ($q: String) { Media(search: $q, type: ${type}) { coverImage { extraLarge large } } }`;
  const data = await getCached(`anilist:cover_title:${q}:${type}`, () => fetchAnilist(query, { q }), 86400);
  res.json(data);
});

// --- Recommendations Endpoint ---

app.post('/recommendations', async (req, res) => {
  const answers = req.body;
  const { isManga, mood, genres = [], episodeRange, status, typeParam } = answers;

  // Generate a stable key for caching
  const cacheKey = `recommendations:${JSON.stringify(answers)}`;
  
  const data = await getCached(cacheKey, async () => {
    // This logic mimics the JikanService.getRecommendations in Flutter
    const genreIds = getGenreIds(mood, genres);
    const statusParam = getStatusParam(status, isManga);
    
    const params = {
      order_by: 'popularity',
      limit: 25,
      min_score: '6.0',
      sfw: 'true',
      genres: genreIds.join(','),
      status: statusParam,
    };
    if (typeParam) params.type = typeParam;

    let finalResults = [];
    const maxPages = 3;
    const targetSize = 12;

    for (let page = 1; page <= maxPages; page++) {
      const result = await fetchWithRetry(`${JIKAN_BASE}/${isManga ? 'manga' : 'anime'}`, { ...params, page });
      let items = result.data || [];
      
      if (items.length === 0) break;

      // Filter by episode/chapter range
      const { min, max } = getRange(episodeRange, isManga);
      if (min !== null || max !== null) {
        items = items.filter(item => {
          const count = isManga ? item.chapters : item.episodes;
          if (count === null || count === undefined) return true;
          if (min !== null && count < min) return false;
          if (max !== null && count > max) return false;
          return true;
        });
      }

      finalResults = [...finalResults, ...items];
      if (finalResults.length >= 25) break; 
    }

    // Shuffle and take 16
    finalResults.sort(() => Math.random() - 0.5);
    return { data: finalResults.slice(0, 16) };
  }, 600);

  res.json(data);
});

// Helper functions for recommendations
function getGenreIds(mood, selectedGenres) {
  const moodMap = {
    'dark': [41, 14, 7], 'funny': [4, 20], 'romantic': [22, 43], 'action': [1, 24],
    'chill': [36, 15], 'adventure': [2, 10], 'mystery': [7, 41], 'battles': [1, 17],
    'cozy': [36, 46], 'gore': [14, 41], 'sports': [30], 'sad': [8, 41]
  };
  const genreNameToId = {
    'Action': 1, 'Adventure': 2, 'Cars': 3, 'Comedy': 4, 'Dementia': 5, 'Demons': 6, 'Drama': 8,
    'Ecchi': 9, 'Fantasy': 10, 'Game': 11, 'Harem': 35, 'Historical': 13, 'Horror': 14, 'Isekai': 62,
    'Josei': 43, 'Kids': 15, 'Magic': 16, 'Martial Arts': 17, 'Mecha': 18, 'Military': 38, 'Music': 19,
    'Mystery': 7, 'Parody': 20, 'Police': 39, 'Psychological': 40, 'Romance': 22, 'Samurai': 21,
    'School': 23, 'Sci-Fi': 24, 'Seinen': 42, 'Shoujo': 25, 'Shoujo Ai': 26, 'Shounen': 27,
    'Shounen Ai': 28, 'Slice of Life': 36, 'Space': 29, 'Sports': 30, 'Super Power': 31,
    'Supernatural': 37, 'Thriller': 41, 'Vampire': 32
  };

  const ids = new Set();
  selectedGenres.forEach(g => {
    if (genreNameToId[g]) ids.add(genreNameToId[g]);
  });
  if (ids.size === 0 && moodMap[mood]) {
    ids.add(moodMap[mood][0]);
  }
  return Array.from(ids).slice(0, 2);
}

function getStatusParam(status, isManga) {
  if (isManga) {
    if (status === 'ongoing') return 'publishing';
    if (status === 'completed') return 'complete';
  } else {
    if (status === 'ongoing') return 'airing';
    if (status === 'completed') return 'complete';
  }
  return '';
}

function getRange(range, isManga) {
  if (isManga) {
    switch (range) {
      case 'short': return { min: null, max: 20 };
      case 'medium': return { min: 20, max: 100 };
      case 'long': return { min: 100, max: null };
      default: return { min: null, max: null };
    }
  } else {
    switch (range) {
      case 'short': return { min: null, max: 13 };
      case 'medium': return { min: 13, max: 50 };
      case 'long': return { min: 50, max: null };
      default: return { min: null, max: null };
    }
  }
}

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
