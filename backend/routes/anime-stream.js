const express = require('express');
const router = express.Router();
const axios = require('axios');
const { ANIME } = require('@consumet/extensions');

// Initialize the Hianime provider locally
const zoro = new ANIME.Hianime();

const REDIS_TTL_SEARCH = 3600;      // 1 hour
const REDIS_TTL_EPISODES = 3600;    // 1 hour
const REDIS_TTL_SOURCES = 300;      // 5 minutes
const REDIS_TTL_SKIP = 86400;       // 24 hours

function getRedis(req) {
  return req.app.get('redis');
}

// ── SEARCH anime by title ──────────────────────────────────────────────────
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

    // Use Consumet locally
    const results = await zoro.search(q);
    
    // Map Consumet format to our existing API format
    const data = {
      success: true,
      data: {
        animes: results.results.map(a => ({
          id: a.id,
          name: a.title,
          poster: a.image,
          type: a.type || 'TV',
          episodes: {
            sub: a.episodeCount || 0,
            dub: 0
          }
        }))
      }
    };

    await redis.setex(cacheKey, REDIS_TTL_SEARCH, JSON.stringify(data));
    return res.json(data);
  } catch (err) {
    console.error('[stream/search] error:', err.message);
    return res.status(500).json({ error: 'Search failed', detail: err.message });
  }
});

// ── GET episode list ───────────────────────────────────────────────────────
router.get('/episodes/:animeId', async (req, res) => {
  const { animeId } = req.params;
  const cacheKey = `stream:episodes:${animeId}`;
  try {
    const redis = getRedis(req);
    const cached = await redis.get(cacheKey);
    if (cached) return res.json(JSON.parse(cached));

    const info = await zoro.fetchAnimeInfo(animeId);
    
    const data = {
      success: true,
      data: {
        episodes: info.episodes.map(e => ({
          episodeId: e.id,
          number: e.number,
          title: e.title || `Episode ${e.number}`
        }))
      }
    };

    await redis.setex(cacheKey, REDIS_TTL_EPISODES, JSON.stringify(data));
    return res.json(data);
  } catch (err) {
    console.error('[stream/episodes] error:', err.message);
    return res.status(500).json({ error: 'Episode fetch failed' });
  }
});

// ── GET streaming sources ──────────────────────────────────────────────────
router.get('/sources', async (req, res) => {
  const { episodeId, category = 'sub', server = 'vidcloud' } = req.query;
  if (!episodeId) {
    return res.status(400).json({ error: 'episodeId required' });
  }

  const cacheKey = `stream:sources:${episodeId}:${category}:${server}`;
  try {
    const redis = getRedis(req);
    const cached = await redis.get(cacheKey);
    if (cached) return res.json(JSON.parse(cached));

    const sources = await zoro.fetchEpisodeSources(episodeId, server);
    
    const data = {
      success: true,
      data: {
        sources: sources.sources.map(s => ({
          url: s.url,
          isM3U8: s.isM3U8,
          quality: s.quality || 'auto'
        })),
        tracks: sources.subtitles ? sources.subtitles.map(t => ({
          file: t.url,
          label: t.lang,
          kind: 'captions',
          default: t.lang === 'English'
        })) : []
      }
    };

    if (data.data.sources.length > 0) {
      await redis.setex(cacheKey, REDIS_TTL_SOURCES, JSON.stringify(data));
    }
    return res.json(data);
  } catch (err) {
    console.error('[stream/sources] error:', err.message);
    return res.status(500).json({ error: 'Source fetch failed' });
  }
});

// ── GET AniSkip OP/ED timestamps ──────────────────────────────────────────
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

    const url = `https://api.aniskip.com/v2/skip-times/${malId}/${episode}`;
    const params = { 'types[]': ['op', 'ed'] };
    if (episodeLength) params.episodeLength = episodeLength;

    const response = await axios.get(url, { params, timeout: 5000 });
    const data = response.data;

    await redis.setex(cacheKey, REDIS_TTL_SKIP, JSON.stringify(data));
    return res.json(data);
  } catch (err) {
    if (err.response?.status === 404) {
      return res.json({ found: false, results: [] });
    }
    return res.status(500).json({ error: 'Skip fetch failed' });
  }
});

module.exports = router;
