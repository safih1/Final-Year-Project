import requests
import json
import time

BASE_URL = "http://localhost:8000/api"
USER_EMAIL = "integration_user@example.com"
OFFICER_EMAIL = "integration_officer@example.com"
PASSWORD = "password123"

def log(msg):
    print(f"[TEST] {msg}")

def run_test():
    log("Starting Full Integration Test...")
    
    # ---------------------------------------------------------
    # 1. REGISTER USER
    # ---------------------------------------------------------
    log("1. Registering User...")
    reg_data = {
        "email": USER_EMAIL,
        "username": "integration_user",
        "full_name": "Integration User",
        "password": PASSWORD,
        "confirm_password": PASSWORD,
        "phone_number": "1112223333",
        "role": "user"
    }
    # Try register (might fail if exists, that's fine)
    try:
        requests.post(f"{BASE_URL}/auth/register/", json=reg_data)
    except: pass

    # ---------------------------------------------------------
    # 2. LOGIN USER
    # ---------------------------------------------------------
    log("2. Logging in User...")
    resp = requests.post(f"{BASE_URL}/auth/login/", json={"email": USER_EMAIL, "password": PASSWORD})
    if resp.status_code != 200:
        log(f"FAILED: User Login - {resp.text}")
        return
    log(f"   User Login Response: {resp.json()}")
    
    data = resp.json()
    if 'tokens' in data:
        user_token = data['tokens']['access']
    elif 'access' in data:
        user_token = data['access']
    else:
        log(f"FAILED: Unknown login response structure: {data}")
        return
    log("   User Logged In")

    # ---------------------------------------------------------
    # 3. REGISTER POLICE
    # ---------------------------------------------------------
    log("3. Registering Police Officer...")
    police_reg_data = {
        "email": OFFICER_EMAIL,
        "password": PASSWORD,
        "full_name": "Officer Integ",
        "badge_number": "INT-999",
        "rank": "Sergeant",
        "station": "Central Test"
    }
    try:
        requests.post(f"{BASE_URL}/emergency/police/register/", json=police_reg_data)
    except: pass

    # ---------------------------------------------------------
    # 4. LOGIN POLICE
    # ---------------------------------------------------------
    log("4. Logging in Police...")
    resp = requests.post(f"{BASE_URL}/emergency/police/login/", json={"email": OFFICER_EMAIL, "password": PASSWORD})
    if resp.status_code != 200:
        log(f"FAILED: Police Login - {resp.text}")
        return
    police_data = resp.json()
    police_token = police_data['tokens']['access']
    officer_id = police_data['officer']['id']
    log(f"   Officer Logged In (ID: {officer_id})")

    # ---------------------------------------------------------
    # 5. OFFICER GOES AVAILABLE (UPDATE LOCATION)
    # ---------------------------------------------------------
    log("5. Officer Updating Location (Going Available)...")
    loc_headers = {"Authorization": f"Bearer {police_token}"}
    # Officer at coordinates close to user
    requests.post(f"{BASE_URL}/emergency/police/officers/location/", 
                  json={"latitude": 34.1688, "longitude": 73.2215},
                  headers=loc_headers)
    log("   Officer Location Updated")

    # ---------------------------------------------------------
    # 6. USER TRIGGERS EMERGENCY
    # ---------------------------------------------------------
    log("6. User Triggering Emergency...")
    user_headers = {"Authorization": f"Bearer {user_token}"}
    emergency_data = {
        "location_latitude": 34.1690, # Very close
        "location_longitude": 73.2210,
        "location_address": "Test Location Integration"
    }
    resp = requests.post(f"{BASE_URL}/emergency/trigger/", json=emergency_data, headers=user_headers)
    if resp.status_code != 201:
        log(f"FAILED: Emergency Trigger - {resp.text}")
        return
    # Assuming response structure based on views.py (it might not return ID directly, usually serializer data)
    # Let's assume we need to query or it returns it. 
    # views.py: return Response({'message': ..., 'alert_id': ...}) ??
    # Checking views.py: return Response({...}, status=201) - doesn't explicitly return ID in top level sometimes.
    # Actually looking at views.py line 78: returns serializer.data? No wait.
    # Let's assume we can get it or finding the latest.
    
    # Let's query admin alerts to find the latest for this user
    # Or just assume it's the latest one.
    log("   Emergency Triggered. Finding ID...")
    
    # ---------------------------------------------------------
    # 7. FIND NEAREST (Simulate Dashboard)
    # ---------------------------------------------------------
    # We need the emergency ID. 
    # Helper: Get user's profile or list alerts?
    # Let's use a quick DB check helper or similar.
    # Or just use the response if standard serializer.
    # If not, we can list alerts if there's an endpoint.
    # /api/emergency/alerts/ ?
    
    resp = requests.get(f"{BASE_URL}/emergency/alerts/", headers=user_headers)
    log(f"   Alerts Response: {resp.json()}")
    
    alerts_data = resp.json()
    if isinstance(alerts_data, list):
        if not alerts_data:
            log("FAILED: No alerts found for user")
            return
        latest_alert = alerts_data[0]
    elif isinstance(alerts_data, dict) and 'results' in alerts_data:
        if not alerts_data['results']:
            log("FAILED: No alerts found in results")
            return
        latest_alert = alerts_data['results'][0]
    else:
        log(f"FAILED: Unknown alerts response format: {alerts_data}")
        return

    emergency_id = latest_alert['id']
    log(f"   Emergency ID: {emergency_id}")

    log("7. Dashboard Finding Nearest Officer...")
    # Admin/Dashboard token? Re-use police token? Usually dashboard is admin. 
    # But for test, let's see if we can use police token or user token? 
    # Actually get_nearest_officer requires IsAuthenticated.
    resp = requests.get(f"{BASE_URL}/emergency/police/nearest/{emergency_id}/", headers=user_headers)
    if resp.status_code == 200:
        nearest = resp.json()['officer']
        log(f"   Nearest found: {nearest['name']} (ID: {nearest['id']})")
    else:
        log(f"WARNING: Could not find nearest via API ({resp.status_code}). Proceeding with known ID.")

    # ---------------------------------------------------------
    # 8. DASHBOARD ASSIGNS OFFICER
    # ---------------------------------------------------------
    log("8. Dashboard Assigning Officer...")
    assign_data = {
        "officer_id": officer_id,
        "emergency_id": emergency_id
    }
    # Using police token as 'dashboard' (assuming permission allows or we login as admin)
    # assignments might need admin/dashboard rights. 
    # Let's try user_token (might fail). 
    # Actually 'assign_officer' view perms: IsAuthenticated. Any user? 
    # Ideally should be admin. Let's try.
    resp = requests.post(f"{BASE_URL}/emergency/police/dispatch/assign/", json=assign_data, headers=user_headers)
    if resp.status_code != 201:
        log(f"FAILED: Assignment - {resp.text}")
        # Try creating admin if needed?
        return
    
    task_id = resp.json()['task_id']
    log(f"   Officer Assigned. Task ID: {task_id}")

    # ---------------------------------------------------------
    # 9. OFFICER ACCEPTS TASK
    # ---------------------------------------------------------
    log("9. Officer Accepting Task...")
    # Update status to 'accepted'
    status_data = {"status": "accepted"}
    resp = requests.put(f"{BASE_URL}/emergency/police/dispatch/tasks/{task_id}/status/", 
                        json=status_data, 
                        headers=loc_headers) # Must be officer token
    if resp.status_code == 200:
        log("   Task Accepted!")
    else:
        log(f"FAILED: Accept Task - {resp.text}")
        return

    # ---------------------------------------------------------
    # 10. VERIFY status (Optional DB check or API)
    # ---------------------------------------------------------
    log("10. Verifying Final Status...")
    # Check tasks list
    resp = requests.get(f"{BASE_URL}/emergency/police/dispatch/tasks/", headers=loc_headers)
    tasks = resp.json()
    my_task = next((t for t in tasks if t['id'] == task_id), None)
    if my_task and my_task['status'] == 'accepted':
        log("SUCCESS: Integration Test Passed! ✅")
    else:
        log(f"FAILURE: Task status is {my_task['status'] if my_task else 'Not Found'}")

if __name__ == "__main__":
    run_test()
