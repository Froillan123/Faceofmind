#!/usr/bin/env python
"""
Redis Status Checker
Check Redis connection and display active users
"""

import os
import sys
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'FaceofMindAPI.settings')
django.setup()

import redis
from django.conf import settings
from coreapi.utils import get_active_users_from_redis
from coreapi.models import User

# Connect to Redis using Upstash-compatible URL
redis_client = redis.Redis.from_url(settings.REDIS_URL, decode_responses=True)

def check_redis_status():
    """Check Redis connection and display active users"""
    try:
        # Test connection
        redis_client.ping()
        print("✅ Redis connection successful!")
        
        # Get all JWT keys
        jwt_keys = redis_client.keys("jwt:*")
        print(f"📊 Total JWT tokens in Redis: {len(jwt_keys)}")
        
        # Get active users
        active_user_ids = get_active_users_from_redis()
        print(f"👥 Active users: {len(active_user_ids)}")
        
        if active_user_ids:
            print("\n🟢 Currently Active Users:")
            for user_id in active_user_ids:
                try:
                    user = User.objects.get(id=user_id)
                    print(f"   • {user.first_name} {user.last_name} ({user.email}) - {user.role}")
                except User.DoesNotExist:
                    print(f"   • User ID {user_id} (not found in database)")
        else:
            print("\n🔴 No active users found")
            
        # Show all JWT keys for debugging
        if jwt_keys:
            print(f"\n🔑 JWT Keys in Redis:")
            for key in jwt_keys[:10]:  # Show first 10 keys
                print(f"   • {key}")
            if len(jwt_keys) > 10:
                print(f"   ... and {len(jwt_keys) - 10} more")
                
    except redis.ConnectionError:
        print("❌ Redis connection failed!")
        print("Make sure Redis is running on localhost:6379")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    check_redis_status() 