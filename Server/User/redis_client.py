import redis.asyncio as aioredis
from config import settings

_redis = None

async def get_redis():
    global _redis
    if _redis is None:
        _redis = aioredis.from_url(settings.redis_url, decode_responses=True)
    return _redis

async def close_redis():
    global _redis
    if _redis:
        await _redis.close()
        _redis = None 