#!/usr/bin/env python3
"""
Simple test script to verify the FaceofMind User API endpoints
"""

import requests
import json

BASE_URL = "http://localhost:8000/api/v1"

def test_health():
    """Test the health endpoint"""
    try:
        response = requests.get("http://localhost:8000/health")
        print(f"Health check: {response.status_code} - {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Health check failed: {e}")
        return False

def test_register():
    """Test user registration"""
    user_data = {
        "email": "test@example.com",
        "password": "testpassword123",
        "first_name": "Test",
        "last_name": "User",
        "role": "user"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/auth/register", json=user_data)
        print(f"Register: {response.status_code}")
        if response.status_code == 200:
            print(f"User created: {response.json()}")
        else:
            print(f"Error: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Register failed: {e}")
        return False

def test_login():
    """Test user login"""
    login_data = {
        "email": "test@example.com",
        "password": "testpassword123"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/auth/login", json=login_data)
        print(f"Login: {response.status_code}")
        if response.status_code == 200:
            token_data = response.json()
            print(f"Access token received: {token_data['access_token'][:20]}...")
            return token_data['access_token']
        else:
            print(f"Error: {response.json()}")
            return None
    except Exception as e:
        print(f"Login failed: {e}")
        return None

def test_me_endpoint(token):
    """Test the /me endpoint with authentication"""
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        response = requests.get(f"{BASE_URL}/auth/me", headers=headers)
        print(f"Me endpoint: {response.status_code}")
        if response.status_code == 200:
            print(f"User info: {response.json()}")
        else:
            print(f"Error: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Me endpoint failed: {e}")
        return False

def main():
    """Run all tests"""
    print("Testing FaceofMind User API...")
    print("=" * 50)
    
    # Test health endpoint
    if not test_health():
        print("Health check failed. Make sure the server is running.")
        return
    
    print("\n" + "=" * 50)
    
    # Test registration
    if test_register():
        print("Registration successful!")
    else:
        print("Registration failed or user already exists.")
    
    print("\n" + "=" * 50)
    
    # Test login
    token = test_login()
    if token:
        print("Login successful!")
        
        print("\n" + "=" * 50)
        
        # Test authenticated endpoint
        if test_me_endpoint(token):
            print("Authenticated endpoint test successful!")
        else:
            print("Authenticated endpoint test failed!")
    else:
        print("Login failed!")
    
    print("\n" + "=" * 50)
    print("Test completed!")

if __name__ == "__main__":
    main() 