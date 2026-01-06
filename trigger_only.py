import requests
import time

BASE_URL = "http://localhost:8000/api"
USER_EMAIL = "integration_user@example.com"
PASSWORD = "password123"

def trigger():
    print("Logging in...")
    resp = requests.post(f"{BASE_URL}/auth/login/", json={"email": USER_EMAIL, "password": PASSWORD})
    if resp.status_code != 200:
        print(f"Login failed: {resp.text}")
        return

    data = resp.json()
    if 'tokens' in data:
        token = data['tokens']['access']
    elif 'access' in data:
        token = data['access']
    else:
        print("No token found")
        return

    print("Triggering Emergency...")
    headers = {"Authorization": f"Bearer {token}"}
    emergency_data = {
        "location_latitude": 34.1700, 
        "location_longitude": 73.2200,
        "location_address": "Real-time Dashboard Test"
    }
    resp = requests.post(f"{BASE_URL}/emergency/trigger/", json=emergency_data, headers=headers)
    print(f"Trigger Status: {resp.status_code}")
    print(f"Response: {resp.text}")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        delay = int(sys.argv[1])
        print(f"Waiting {delay} seconds...")
        time.sleep(delay)
    trigger()
