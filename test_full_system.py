"""
Full System Test for Police Response System
Simulates the entire flow: Threat -> Admin -> Dispatch -> Officer -> Resolution
"""

import asyncio
import json
import requests
import websockets
import sys

BASE_URL = "http://192.168.1.5:8000/api/emergency"
WS_URL = "ws://192.168.1.5:8000/ws"

# Test Data
ADMIN_EMAIL = "admin@securestep.com"
ADMIN_PASS = "admin123"
OFFICER_EMAIL = "officer1@police.com"
OFFICER_PASS = "officer123"

async def test_full_flow():
    print("\n🚀 STARTING FULL SYSTEM TEST\n")
    
    # 1. Login
    print("1️⃣  Logging in...")
    
    # Admin Login
    resp = requests.post(f"http://192.168.1.5:8000/api/accounts/login/", 
                        json={"email": ADMIN_EMAIL, "password": ADMIN_PASS})
    if resp.status_code != 200:
        print("❌ Admin login failed")
        return
    admin_token = resp.json()['tokens']['access']
    print("   ✅ Admin logged in")

    # Officer Login
    resp = requests.post(f"{BASE_URL}/police/login/", 
                        json={"email": OFFICER_EMAIL, "password": OFFICER_PASS})
    if resp.status_code != 200:
        print("❌ Officer login failed")
        return
    officer_data = resp.json()
    officer_token = officer_data['tokens']['access']
    officer_id = officer_data['officer']['id']
    print(f"   ✅ Officer logged in (ID: {officer_id})")

    # 2. Connect WebSockets
    print("\n2️⃣  Connecting WebSockets...")
    
    async with websockets.connect(f"{WS_URL}/police/") as admin_ws, \
               websockets.connect(f"{WS_URL}/police/{officer_id}/") as officer_ws:
        
        print("   ✅ Admin Dashboard WS connected")
        print("   ✅ Officer App WS connected")

        # 3. Trigger Emergency
        print("\n3️⃣  Triggering Emergency...")
        # We'll use the trigger endpoint (simulating the victim app)
        # Need a regular user token first
        resp = requests.post(f"http://192.168.1.5:8000/api/accounts/login/", 
                            json={"email": "victim@test.com", "password": "victim123"})
        victim_token = resp.json()['tokens']['access']
        
        trigger_data = {
            "location": "Test Location",
            "coordinates": {"lat": 34.1700, "lng": 73.2200},
            "type": "automatic"
        }
        resp = requests.post(f"{BASE_URL}/trigger/", 
                            json=trigger_data,
                            headers={"Authorization": f"Bearer {victim_token}"})
        
        if resp.status_code != 201:
            print(f"❌ Failed to trigger emergency: {resp.text}")
            return
        
        emergency_id = resp.json()['alert_id']
        print(f"   ✅ Emergency triggered (ID: {emergency_id})")

        # 4. Verify Admin received alert
        print("\n4️⃣  Waiting for Admin Alert...")
        try:
            msg = await asyncio.wait_for(admin_ws.recv(), timeout=5.0)
            data = json.loads(msg)
            if data['type'] == 'new_emergency' and data['data']['alert_id'] == emergency_id:
                print("   ✅ Admin received WebSocket alert!")
            else:
                print(f"   ⚠️  Received unexpected message: {data}")
        except asyncio.TimeoutError:
            print("   ❌ Admin did not receive alert in time")

        # 5. Assign Officer
        print("\n5️⃣  Assigning Officer...")
        assign_data = {
            "officer_id": officer_id,
            "emergency_id": emergency_id
        }
        resp = requests.post(f"{BASE_URL}/police/dispatch/assign/", 
                            json=assign_data,
                            headers={"Authorization": f"Bearer {admin_token}"})
        
        if resp.status_code == 200:
            task_id = resp.json()['task_id']
            print(f"   ✅ Officer assigned (Task ID: {task_id})")
        else:
            print(f"❌ Failed to assign officer: {resp.text}")
            return

        # 6. Verify Officer received task
        print("\n6️⃣  Waiting for Officer Notification...")
        try:
            msg = await asyncio.wait_for(officer_ws.recv(), timeout=5.0)
            data = json.loads(msg)
            if data['type'] == 'task_assigned' and data['data']['task_id'] == task_id:
                print("   ✅ Officer received WebSocket task assignment!")
            else:
                print(f"   ⚠️  Received unexpected message: {data}")
        except asyncio.TimeoutError:
            print("   ❌ Officer did not receive task in time")

        # 7. Simulate Officer Polling (Background Service)
        print("\n7️⃣  Simulating Background Polling...")
        resp = requests.get(f"{BASE_URL}/police/dispatch/tasks/", 
                           headers={"Authorization": f"Bearer {officer_token}"})
        tasks = resp.json()
        my_task = next((t for t in tasks if t['id'] == task_id), None)
        
        if my_task and my_task['status'] == 'pending':
            print("   ✅ Background poll found pending task!")
        else:
            print("   ❌ Background poll failed to find task")

        # 8. Resolve Task
        print("\n8️⃣  Resolving Task...")
        # Accept
        requests.put(f"{BASE_URL}/police/dispatch/tasks/{task_id}/status/", 
                    json={"status": "accepted"},
                    headers={"Authorization": f"Bearer {officer_token}"})
        print("   -> Accepted")
        
        # Resolve
        requests.put(f"{BASE_URL}/police/dispatch/tasks/{task_id}/status/", 
                    json={"status": "resolved"},
                    headers={"Authorization": f"Bearer {officer_token}"})
        print("   -> Resolved")
        
        # 9. Verify Admin Update
        print("\n9️⃣  Verifying Admin Update...")
        # We might have missed intermediate messages, so let's check the last one
        found_resolution = False
        try:
            while True:
                msg = await asyncio.wait_for(admin_ws.recv(), timeout=2.0)
                data = json.loads(msg)
                if data['type'] == 'task_update' and data['data']['status'] == 'resolved':
                    found_resolution = True
                    print("   ✅ Admin received resolution update!")
                    break
        except asyncio.TimeoutError:
            if not found_resolution:
                print("   ⚠️  Admin didn't receive resolution update (might have timed out)")

    print("\n🎉 FULL SYSTEM TEST COMPLETED")

if __name__ == "__main__":
    try:
        asyncio.run(test_full_flow())
    except KeyboardInterrupt:
        print("\nTest stopped")
