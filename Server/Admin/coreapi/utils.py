import random
from django.core.cache import cache
import redis
from django.conf import settings
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
import json
from django.utils.timezone import now
import os

# Redis connection for JWT tokens (Upstash-compatible)
redis_client = redis.Redis.from_url(settings.REDIS_URL, decode_responses=True)

def get_redis():
    return redis.Redis.from_url(settings.REDIS_URL, decode_responses=True)

def generate_otp(email):
    otp = str(random.randint(100000, 999999))
    cache.set(f"otp_{email}", otp, timeout=300)  # 5 minutes
    return otp

def validate_otp(email, otp):
    cached = cache.get(f"otp_{email}")
    return cached == otp

def send_analytics_notification(message, data=None):
    """Send real-time notification to analytics WebSocket consumers"""
    try:
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            "analytics",
            {
                "type": "analytics_notification",
                "message": message,
                "data": data or {}
            }
        )
    except Exception as e:
        print(f"Error sending analytics notification: {e}")

def invalidate_analytics_cache():
    """Invalidate all analytics cache entries"""
    try:
        # Clear all analytics cache entries
        cache.delete_pattern("analytics_*")
    except Exception as e:
        print(f"Error invalidating analytics cache: {e}")

def get_active_users_from_redis():
    """Get list of active user IDs from Redis JWT tokens (supports user and admin tokens)"""
    try:
        active_user_ids = set()
        keys = redis_client.keys("jwt:*")
        for key in keys:
            parts = key.split(':')
            if len(parts) == 3:
                # Format: jwt:user_id:token
                try:
                    user_id = int(parts[1])
                    active_user_ids.add(user_id)
                except ValueError:
                    continue
            elif len(parts) >= 4:
                # Format: jwt:role:user_id:token (role can be 'admin' or others)
                try:
                    user_id = int(parts[2])
                    active_user_ids.add(user_id)
                except ValueError:
                    continue
        return list(active_user_ids)
    except Exception as e:
        print(f"Error getting active users from Redis: {e}")
        return []

def is_user_active_in_redis(user_id):
    """Check if a specific user is currently active (has JWT token in Redis)"""
    try:
        # Check both possible formats
        keys = redis_client.keys(f"jwt:{user_id}:*")  # jwt:user_id:token
        keys += redis_client.keys(f"jwt:*:{user_id}:*")  # jwt:role:user_id:token
        return len(keys) > 0
    except Exception as e:
        print(f"Error checking user activity in Redis: {e}")
        return False
