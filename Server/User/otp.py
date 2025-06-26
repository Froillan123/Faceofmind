import random
import string
import redis.asyncio as aioredis
from config import settings

OTP_EXPIRE_SECONDS = 300  # 5 minutes

async def get_redis():
    return aioredis.from_url(settings.redis_url, decode_responses=True)

def generate_otp(length=6):
    return ''.join(random.choices(string.digits, k=length))

async def store_otp(email: str, otp: str):
    redis = await get_redis()
    await redis.set(f"otp:{email}", otp, ex=OTP_EXPIRE_SECONDS)
    await redis.close()

async def verify_otp(email: str, otp: str):
    redis = await get_redis()
    stored_otp = await redis.get(f"otp:{email}")
    await redis.close()
    return stored_otp == otp 