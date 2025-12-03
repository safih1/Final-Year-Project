import requests
import json
import time

BASE_URL = "http://localhost:8000/api"

def create_user():
    print("Creating test user...")
    url = f"{BASE_URL}/auth/register/"
    data = {
        "email": "testuser@example.com",
        "username": "testuser",
        "password": "password123",
        "confirm_password": "password123",
        "full_name": "Test User",
        "phone_number": "1234567890",
        "role": "user"
    }
    try:
        response = requests.post(url, json=data)
        if response.status_code == 201:
            print("User created successfully")
            return True
        elif response.status_code == 400 and "email" in response.json() and "already exists" in str(response.json()):
            print("User already exists")
            return True
        else:
            print(f"Failed to create user: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"Error creating user: {e}")
        return False

def login_user():
    print("Logging in user...")
    url = f"{BASE_URL}/auth/login/"
    data = {
        "email": "testuser@example.com",
        "password": "password123"
    }
    try:
        response = requests.post(url, json=data)
        if response.status_code == 200:
            token = response.json().get('access')
            print("Login successful")
            return token
        else:
            print(f"Login failed: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error logging in: {e}")
        return None

def trigger_emergency(token):
    print("Triggering emergency...")
    url = f"{BASE_URL}/emergency/trigger/"
    headers = {
        "Authorization": f"Bearer {token}"
    }
    data = {
        "location_latitude": 33.6844,
        "location_longitude": 73.0479,
        "location_address": "Islamabad, Pakistan"
    }
    try:
        response = requests.post(url, json=data, headers=headers)
        if response.status_code == 201:
            print("Emergency triggered successfully!")
            print(f"Response: {response.json()}")
            return True
        else:
            print(f"Failed to trigger emergency: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"Error triggering emergency: {e}")
        return False

if __name__ == "__main__":
    if create_user():
        token = login_user()
        if token:
            trigger_emergency(token)
