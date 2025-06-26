import random
from django.core.cache import cache

def generate_otp(email):
    otp = str(random.randint(100000, 999999))
    cache.set(f"otp_{email}", otp, timeout=300)  # 5 minutes
    return otp

def validate_otp(email, otp):
    cached = cache.get(f"otp_{email}")
    return cached == otp
