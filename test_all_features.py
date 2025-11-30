"""
Comprehensive Feature Test for Police Response System
Tests all features in the system and reports status
"""

import requests
import json
from datetime import datetime

BASE_URL = "http://127.0.0.1:8000"

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'

def print_header(text):
    print(f"\n{Colors.BLUE}{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}{Colors.END}\n")

def print_test(name, passed, details=""):
    symbol = f"{Colors.GREEN}✓{Colors.END}" if passed else f"{Colors.RED}✗{Colors.END}"
    print(f"{symbol} {name}")
    if details:
        print(f"  {details}")

def test_feature(func):
    """Decorator to handle test execution"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            print_test(func.__name__, False, f"Error: {str(e)}")
            return False
    return wrapper

# Test Data Storage
test_data = {
    'admin_token': None,
    'officer_token': None,
    'officer_id': None,
    'victim_token': None,
    'emergency_id': None,
    'task_id': None
}

@test_feature
def test_1_admin_login():
    """Test 1: Admin Login"""
    resp = requests.post(
        f"{BASE_URL}/api/accounts/login/",
        json={"email": "admin@securestep.com", "password": "admin123"}
    )
    if resp.status_code == 200:
        data = resp.json()
        test_data['admin_token'] = data['tokens']['access']
        is_admin = data['user'].get('is_admin', False)
        print_test("Admin Login", is_admin, f"Token received, Admin: {is_admin}")
        return is_admin
    print_test("Admin Login", False, f"Status: {resp.status_code}")
    return False

@test_feature
def test_2_officer_login():
    """Test 2: Officer Login"""
    resp = requests.post(
        f"{BASE_URL}/api/emergency/police/login/",
        json={"email": "officer1@police.com", "password": "officer123"}
    )
    if resp.status_code == 200:
        data = resp.json()
        test_data['officer_token'] = data['tokens']['access']
        test_data['officer_id'] = data['officer']['id']
        print_test("Officer Login", True, f"Officer ID: {test_data['officer_id']}, Badge: {data['officer']['badge_number']}")
        return True
    print_test("Officer Login", False, f"Status: {resp.status_code}, Response: {resp.text[:100]}")
    return False

@test_feature
def test_3_get_available_officers():
    """Test 3: Get Available Officers (Admin)"""
    if not test_data['admin_token']:
        print_test("Get Available Officers", False, "No admin token")
        return False
    
    resp = requests.get(
        f"{BASE_URL}/api/emergency/police/officers/available/",
        headers={"Authorization": f"Bearer {test_data['admin_token']}"}
    )
    if resp.status_code == 200:
        officers = resp.json()
        print_test("Get Available Officers", True, f"Found {len(officers)} available officers")
        return len(officers) > 0
    print_test("Get Available Officers", False, f"Status: {resp.status_code}")
    return False

@test_feature
def test_4_update_officer_location():
    """Test 4: Update Officer Location"""
    if not test_data['officer_token']:
        print_test("Update Officer Location", False, "No officer token")
        return False
    
    resp = requests.post(
        f"{BASE_URL}/api/emergency/police/officers/location/",
        headers={"Authorization": f"Bearer {test_data['officer_token']}"},
        json={"latitude": 34.1695, "longitude": 73.2220}
    )
    if resp.status_code == 200:
        print_test("Update Officer Location", True, "Location updated successfully")
        return True
    print_test("Update Officer Location", False, f"Status: {resp.status_code}, Response: {resp.text[:100]}")
    return False

@test_feature
def test_5_victim_creates_emergency():
    """Test 5: Victim Creates Emergency Alert"""
    # Login as victim
    resp = requests.post(
        f"{BASE_URL}/api/accounts/login/",
        json={"email": "victim@test.com", "password": "victim123"}
    )
    if resp.status_code != 200:
        print_test("Victim Creates Emergency", False, "Victim login failed")
        return False
    
    test_data['victim_token'] = resp.json()['tokens']['access']
    
    # Trigger emergency
    resp = requests.post(
        f"{BASE_URL}/api/emergency/trigger/",
        headers={"Authorization": f"Bearer {test_data['victim_token']}"},
        json={
            "location": "Test Emergency Location",
            "coordinates": {"lat": 34.1700, "lng": 73.2200},
            "type": "automatic"
        }
    )
    if resp.status_code == 201:
        data = resp.json()
        test_data['emergency_id'] = data.get('alert_id')
        print_test("Victim Creates Emergency", True, f"Emergency ID: {test_data['emergency_id']}")
        return True
    print_test("Victim Creates Emergency", False, f"Status: {resp.status_code}")
    return False

@test_feature
def test_6_get_nearest_officer():
    """Test 6: Calculate Nearest Officer to Emergency"""
    if not test_data['admin_token'] or not test_data['emergency_id']:
        print_test("Get Nearest Officer", False, "Missing admin token or emergency ID")
        return False
    
    resp = requests.get(
        f"{BASE_URL}/api/emergency/police/nearest/{test_data['emergency_id']}/",
        headers={"Authorization": f"Bearer {test_data['admin_token']}"}
    )
    if resp.status_code == 200:
        data = resp.json()
        nearest = data['nearest_officer']
        print_test("Get Nearest Officer", True, 
                   f"Nearest: {nearest['name']} ({nearest['badge_number']}) - {nearest['distance_km']} km away")
        return True
    print_test("Get Nearest Officer", False, f"Status: {resp.status_code}")
    return False

@test_feature
def test_7_assign_officer_to_emergency():
    """Test 7: Admin Assigns Officer to Emergency"""
    if not test_data['admin_token'] or not test_data['officer_id'] or not test_data['emergency_id']:
        print_test("Assign Officer", False, "Missing required data")
        return False
    
    resp = requests.post(
        f"{BASE_URL}/api/emergency/police/dispatch/assign/",
        headers={"Authorization": f"Bearer {test_data['admin_token']}"},
        json={
            "officer_id": test_data['officer_id'],
            "emergency_id": test_data['emergency_id']
        }
    )
    if resp.status_code == 200:
        data = resp.json()
        test_data['task_id'] = data['task_id']
        print_test("Assign Officer", True, f"Task ID: {test_data['task_id']}")
        return True
    print_test("Assign Officer", False, f"Status: {resp.status_code}, Response: {resp.text[:100]}")
    return False

@test_feature
def test_8_officer_gets_tasks():
    """Test 8: Officer Retrieves Assigned Tasks"""
    if not test_data['officer_token']:
        print_test("Officer Gets Tasks", False, "No officer token")
        return False
    
    resp = requests.get(
        f"{BASE_URL}/api/emergency/police/dispatch/tasks/",
        headers={"Authorization": f"Bearer {test_data['officer_token']}"}
    )
    if resp.status_code == 200:
        tasks = resp.json()
        pending_tasks = [t for t in tasks if t['status'] == 'pending']
        print_test("Officer Gets Tasks", True, 
                   f"Total: {len(tasks)} tasks, Pending: {len(pending_tasks)}")
        return len(pending_tasks) > 0
    print_test("Officer Gets Tasks", False, f"Status: {resp.status_code}")
    return False

@test_feature
def test_9_officer_accepts_task():
    """Test 9: Officer Accepts Task"""
    if not test_data['officer_token'] or not test_data['task_id']:
        print_test("Officer Accepts Task", False, "Missing required data")
        return False
    
    resp = requests.put(
        f"{BASE_URL}/api/emergency/police/dispatch/tasks/{test_data['task_id']}/status/",
        headers={"Authorization": f"Bearer {test_data['officer_token']}"},
        json={"status": "accepted"}
    )
    if resp.status_code == 200:
        print_test("Officer Accepts Task", True, "Status updated to 'accepted'")
        return True
    print_test("Officer Accepts Task", False, f"Status: {resp.status_code}")
    return False

@test_feature
def test_10_officer_marks_en_route():
    """Test 10: Officer Marks En Route"""
    if not test_data['officer_token'] or not test_data['task_id']:
        print_test("Officer Marks En Route", False, "Missing required data")
        return False
    
    resp = requests.put(
        f"{BASE_URL}/api/emergency/police/dispatch/tasks/{test_data['task_id']}/status/",
        headers={"Authorization": f"Bearer {test_data['officer_token']}"},
        json={"status": "en_route"}
    )
    if resp.status_code == 200:
        print_test("Officer Marks En Route", True, "Status updated to 'en_route'")
        return True
    print_test("Officer Marks En Route", False, f"Status: {resp.status_code}")
    return False

@test_feature
def test_11_officer_marks_arrived():
    """Test 11: Officer Marks Arrived"""
    if not test_data['officer_token'] or not test_data['task_id']:
        print_test("Officer Marks Arrived", False, "Missing required data")
        return False
    
    resp = requests.put(
        f"{BASE_URL}/api/emergency/police/dispatch/tasks/{test_data['task_id']}/status/",
        headers={"Authorization": f"Bearer {test_data['officer_token']}"},
        json={"status": "arrived"}
    )
    if resp.status_code == 200:
        print_test("Officer Marks Arrived", True, "Status updated to 'arrived'")
        return True
    print_test("Officer Marks Arrived", False, f"Status: {resp.status_code}")
    return False

@test_feature
def test_12_officer_resolves_task():
    """Test 12: Officer Resolves Task"""
    if not test_data['officer_token'] or not test_data['task_id']:
        print_test("Officer Resolves Task", False, "Missing required data")
        return False
    
    resp = requests.put(
        f"{BASE_URL}/api/emergency/police/dispatch/tasks/{test_data['task_id']}/status/",
        headers={"Authorization": f"Bearer {test_data['officer_token']}"},
        json={"status": "resolved"}
    )
    if resp.status_code == 200:
        print_test("Officer Resolves Task", True, "Task marked as resolved, officer should be free")
        return True
    print_test("Officer Resolves Task", False, f"Status: {resp.status_code}")
    return False

@test_feature
def test_13_verify_officer_free():
    """Test 13: Verify Officer is Free After Resolution"""
    if not test_data['admin_token']:
        print_test("Verify Officer Free", False, "No admin token")
        return False
    
    resp = requests.get(
        f"{BASE_URL}/api/emergency/police/officers/available/",
        headers={"Authorization": f"Bearer {test_data['admin_token']}"}
    )
    if resp.status_code == 200:
        officers = resp.json()
        officer_found = any(o['id'] == test_data['officer_id'] and o['status'] == 'free' for o in officers)
        print_test("Verify Officer Free", officer_found, 
                   f"Officer {test_data['officer_id']} is {'free' if officer_found else 'not free'}")
        return officer_found
    print_test("Verify Officer Free", False, f"Status: {resp.status_code}")
    return False

def main():
    print_header("POLICE RESPONSE SYSTEM - COMPREHENSIVE FEATURE TEST")
    print(f"Testing against: {BASE_URL}")
    print(f"Test started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    # Run all tests
    tests = [
        test_1_admin_login,
        test_2_officer_login,
        test_3_get_available_officers,
        test_4_update_officer_location,
        test_5_victim_creates_emergency,
        test_6_get_nearest_officer,
        test_7_assign_officer_to_emergency,
        test_8_officer_gets_tasks,
        test_9_officer_accepts_task,
        test_10_officer_marks_en_route,
        test_11_officer_marks_arrived,
        test_12_officer_resolves_task,
        test_13_verify_officer_free,
    ]
    
    results = []
    for test in tests:
        print_header(test.__doc__)
        result = test()
        results.append(result)
    
    # Summary
    print_header("TEST SUMMARY")
    passed = sum(results)
    total = len(results)
    percentage = (passed / total * 100) if total > 0 else 0
    
    print(f"Total Tests: {total}")
    print(f"{Colors.GREEN}Passed: {passed}{Colors.END}")
    print(f"{Colors.RED}Failed: {total - passed}{Colors.END}")
    print(f"Success Rate: {percentage:.1f}%\n")
    
    if percentage == 100:
        print(f"{Colors.GREEN}🎉 ALL TESTS PASSED! System is fully functional.{Colors.END}\n")
    elif percentage >= 80:
        print(f"{Colors.YELLOW}⚠️  Most tests passed. Some issues detected.{Colors.END}\n")
    else:
        print(f"{Colors.RED}❌ Multiple failures detected. System needs attention.{Colors.END}\n")

if __name__ == "__main__":
    main()
