require('dotenv').config();
const express = require('express');
const cors = require('cors');
const Redis = require('ioredis');
const animeStreamRouter = require('./routes/anime-stream');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Redis setup
const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');
redis.on('connect', () => console.log('Redis connected'));
redis.on('error', (err) => console.error('Redis error:', err));

// Inject redis into the app for the router to use
app.set('redis', redis);

// Routes
app.use('/api/stream', animeStreamRouter);

// Basic health check
app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
