"""
Test Police Response System API Endpoints
Run with: python test_police_api.py
"""

import requests
import json

BASE_URL = "http://192.168.1.5:8000/api/emergency"

def print_section(title):
    print("\n" + "="*60)
    print(f"  {title}")
    print("="*60)

def test_police_login():
    print_section("TEST 1: Police Officer Login")
    
    url = f"{BASE_URL}/police/login/"
    data = {
        "email": "officer1@police.com",
        "password": "officer123"
    }
    
    print(f"POST {url}")
    print(f"Data: {json.dumps(data, indent=2)}")
    
    response = requests.post(url, json=data)
    print(f"\nStatus: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    if response.status_code == 200:
        print("✅ Officer login successful!")
        return response.json()['tokens']['access']
    else:
        print("❌ Officer login failed!")
        return None

def test_admin_login():
    print_section("TEST 2: Admin Login")
    
    url = f"{BASE_URL}/../accounts/login/"
    data = {
        "email": "admin@securestep.com",
        "password": "admin123"
    }
    
    print(f"POST {url}")
    print(f"Data: {json.dumps(data, indent=2)}")
    
    response = requests.post(url, json=data)
    print(f"\nStatus: {response.status_code}")
    
    if response.status_code == 200:
        result = response.json()
        print(f"Response: {json.dumps(result, indent=2)}")
        print("✅ Admin login successful!")
        return result['tokens']['access']
    else:
        print(f"Response: {response.text}")
        print("❌ Admin login failed!")
        return None

def test_get_available_officers(admin_token):
    print_section("TEST 3: Get Available Officers (Admin)")
    
    url = f"{BASE_URL}/police/officers/available/"
    headers = {"Authorization": f"Bearer {admin_token}"}
    
    print(f"GET {url}")
    print(f"Headers: Authorization: Bearer {admin_token[:20]}...")
    
    response = requests.get(url, headers=headers)
    print(f"\nStatus: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    if response.status_code == 200:
        officers = response.json()
        print(f"✅ Found {len(officers)} available officers!")
        return officers
    else:
        print("❌ Failed to get officers!")
        return []

def test_update_officer_location(officer_token):
    print_section("TEST 4: Update Officer Location")
    
    url = f"{BASE_URL}/police/officers/location/"
    headers = {"Authorization": f"Bearer {officer_token}"}
    data = {
        "latitude": 34.1695,
        "longitude": 73.2220
    }
    
    print(f"POST {url}")
    print(f"Data: {json.dumps(data, indent=2)}")
    
    response = requests.post(url, json=data, headers=headers)
    print(f"\nStatus: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    if response.status_code == 200:
        print("✅ Officer location updated!")
    else:
        print("❌ Failed to update location!")

def test_get_nearest_officer(admin_token, emergency_id):
    print_section("TEST 5: Get Nearest Officer to Emergency")
    
    url = f"{BASE_URL}/police/nearest/{emergency_id}/"
    headers = {"Authorization": f"Bearer {admin_token}"}
    
    print(f"GET {url}")
    
    response = requests.get(url, headers=headers)
    print(f"\nStatus: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    if response.status_code == 200:
        result = response.json()
        nearest = result['nearest_officer']
        print(f"✅ Nearest officer: {nearest['name']} ({nearest['badge_number']})")
        print(f"   Distance: {nearest['distance_km']} km")
        return nearest['id']
    else:
        print("❌ Failed to get nearest officer!")
        return None

def test_assign_officer(admin_token, officer_id, emergency_id):
    print_section("TEST 6: Assign Officer to Emergency")
    
    url = f"{BASE_URL}/police/dispatch/assign/"
    headers = {"Authorization": f"Bearer {admin_token}"}
    data = {
        "officer_id": officer_id,
        "emergency_id": emergency_id
    }
    
    print(f"POST {url}")
    print(f"Data: {json.dumps(data, indent=2)}")
    
    response = requests.post(url, json=data, headers=headers)
    print(f"\nStatus: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    if response.status_code == 200:
        result = response.json()
        print(f"✅ Officer assigned! Task ID: {result['task_id']}")
        return result['task_id']
    else:
        print("❌ Failed to assign officer!")
        return None

def test_get_officer_tasks(officer_token):
    print_section("TEST 7: Get Officer Tasks")
    
    url = f"{BASE_URL}/police/dispatch/tasks/"
    headers = {"Authorization": f"Bearer {officer_token}"}
    
    print(f"GET {url}")
    
    response = requests.get(url, headers=headers)
    print(f"\nStatus: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    if response.status_code == 200:
        tasks = response.json()
        print(f"✅ Found {len(tasks)} tasks!")
        return tasks
    else:
        print("❌ Failed to get tasks!")
        return []

def test_update_task_status(officer_token, task_id):
    print_section("TEST 8: Update Task Status")
    
    statuses = ['accepted', 'en_route', 'arrived', 'resolved']
    
    for new_status in statuses:
        url = f"{BASE_URL}/police/dispatch/tasks/{task_id}/status/"
        headers = {"Authorization": f"Bearer {officer_token}"}
        data = {"status": new_status}
        
        print(f"\nPUT {url}")
        print(f"Data: {json.dumps(data, indent=2)}")
        
        response = requests.put(url, json=data, headers=headers)
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        
        if response.status_code == 200:
            print(f"✅ Task status updated to: {new_status}")
        else:
            print(f"❌ Failed to update to: {new_status}")
            break

def main():
    print("\n" + "🚨"*30)
    print("  POLICE RESPONSE SYSTEM API TESTS")
    print("🚨"*30)
    
    # Test 1: Officer Login
    officer_token = test_police_login()
    if not officer_token:
        print("\n❌ Cannot continue without officer token!")
        return
    
    # Test 2: Admin Login
    admin_token = test_admin_login()
    if not admin_token:
        print("\n❌ Cannot continue without admin token!")
        return
    
    # Test 3: Get Available Officers
    officers = test_get_available_officers(admin_token)
    
    # Test 4: Update Officer Location
    test_update_officer_location(officer_token)
    
    # Test 5: Get Nearest Officer (using emergency ID 165 from test data)
    emergency_id = 165
    nearest_officer_id = test_get_nearest_officer(admin_token, emergency_id)
    
    if nearest_officer_id:
        # Test 6: Assign Officer
        task_id = test_assign_officer(admin_token, nearest_officer_id, emergency_id)
        
        if task_id:
            # Test 7: Get Officer Tasks
            test_get_officer_tasks(officer_token)
            
            # Test 8: Update Task Status
            test_update_task_status(officer_token, task_id)
    
    print_section("ALL TESTS COMPLETED!")
    print("✅ Police Response System is working correctly!")

if __name__ == "__main__":
    main()
