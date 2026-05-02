const express = require('express');
const router = express.Router();
const axios = require('axios');

const ANIWATCH_URL = process.env.ANIWATCH_API_URL;
const REDIS_TTL_SEARCH = 3600;      // 1 hour
const REDIS_TTL_EPISODES = 3600;    // 1 hour
const REDIS_TTL_SOURCES = 300;      // 5 minutes (sources expire fast)
const REDIS_TTL_SKIP = 86400;       // 24 hours (skip times rarely change)

// Helper: get Redis client from app (already set up in your backend)
function getRedis(req) {
  return req.app.get('redis'); // adjust to however you access redis
}

// ── SEARCH anime by title ──────────────────────────────────────────────────
// GET /api/stream/search?q=attack+on+titan
router.get('/search', async (req, res) => {
  const q = req.query.q?.trim();
  if (!q || q.length < 2) {
    return res.status(400).json({ error: 'Query too short' });
  }

  const cacheKey = `stream:search:${q.toLowerCase()}`;
  try {
    const redis = getRedis(req);
    const cached = await redis.get(cacheKey);
    if (cached) return res.json(JSON.parse(cached));

    const response = await axios.get(
      `${ANIWATCH_URL}/api/v2/hianime/search`,
      {
        params: { q, page: 1 },
        timeout: 10000,
      }
    );

    const data = response.data;
    await redis.setex(cacheKey, REDIS_TTL_SEARCH, JSON.stringify(data));
    return res.json(data);
  } catch (err) {
    console.error('[stream/search] error:', err.message);
    return res.status(502).json({ error: 'Search failed', detail: err.message });
  }
});

// ── GET episode list for a hianime anime ID ────────────────────────────────
// GET /api/stream/episodes/:animeId
// animeId example: "attack-on-titan-112"
router.get('/episodes/:animeId', async (req, res) => {
  const { animeId } = req.params;
  const cacheKey = `stream:episodes:${animeId}`;
  try {
    const redis = getRedis(req);
    const cached = await redis.get(cacheKey);
    if (cached) return res.json(JSON.parse(cached));

    const response = await axios.get(
      `${ANIWATCH_URL}/api/v2/hianime/anime/${animeId}/episodes`,
      { timeout: 10000 }
    );

    const data = response.data;
    await redis.setex(cacheKey, REDIS_TTL_EPISODES, JSON.stringify(data));
    return res.json(data);
  } catch (err) {
    console.error('[stream/episodes] error:', err.message);
    return res.status(502).json({ error: 'Episode fetch failed' });
  }
});

// ── GET streaming sources for an episode ──────────────────────────────────
// GET /api/stream/sources?episodeId=attack-on-titan-112?ep=230&category=sub
// category: "sub" | "dub" | "raw"
// server: "hd-1" | "hd-2" (default hd-1)
router.get('/sources', async (req, res) => {
  const { episodeId, category = 'sub', server = 'hd-1' } = req.query;
  if (!episodeId) {
    return res.status(400).json({ error: 'episodeId required' });
  }

  const cacheKey = `stream:sources:${episodeId}:${category}:${server}`;
  try {
    const redis = getRedis(req);
    const cached = await redis.get(cacheKey);
    if (cached) return res.json(JSON.parse(cached));

    const response = await axios.get(
      `${ANIWATCH_URL}/api/v2/hianime/episode/sources`,
      {
        params: { animeEpisodeId: episodeId, server, category },
        timeout: 15000,
      }
    );

    const data = response.data;
    // Only cache successful responses with actual sources
    if (data?.data?.sources?.length > 0) {
      await redis.setex(cacheKey, REDIS_TTL_SOURCES, JSON.stringify(data));
    }
    return res.json(data);
  } catch (err) {
    console.error('[stream/sources] error:', err.message);
    return res.status(502).json({ error: 'Source fetch failed' });
  }
});

// ── GET AniSkip OP/ED timestamps ──────────────────────────────────────────
// GET /api/stream/skip?malId=16498&episode=1&episodeLength=1417
router.get('/skip', async (req, res) => {
  const { malId, episode, episodeLength } = req.query;
  if (!malId || !episode) {
    return res.status(400).json({ error: 'malId and episode required' });
  }

  const cacheKey = `stream:skip:${malId}:${episode}`;
  try {
    const redis = getRedis(req);
    const cached = await redis.get(cacheKey);
    if (cached) return res.json(JSON.parse(cached));

    // AniSkip v2 API — no auth needed
    const url = `https://api.aniskip.com/v2/skip-times/${malId}/${episode}`;
    const params = {
      'types[]': ['op', 'ed'],
    };
    if (episodeLength) params.episodeLength = episodeLength;

    const response = await axios.get(url, { params, timeout: 5000 });
    const data = response.data;

    await redis.setex(cacheKey, REDIS_TTL_SKIP, JSON.stringify(data));
    return res.json(data);
  } catch (err) {
    // AniSkip returns 404 when no skip times exist — that is normal
    if (err.response?.status === 404) {
      return res.json({ found: false, results: [] });
    }
    console.error('[stream/skip] error:', err.message);
    return res.status(502).json({ error: 'Skip fetch failed' });
  }
});

module.exports = router;
