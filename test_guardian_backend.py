import requests
import json
import numpy as np
import scipy.io.wavfile as wav
import os

BASE_URL = "http://localhost:8000/api"

def create_dummy_audio(filename='test_audio.wav'):
    print(f"Generating dummy audio file: {filename}")
    sample_rate = 22050
    duration = 2 # seconds
    # Generate random noise
    data = np.random.uniform(-1, 1, sample_rate * duration)
    wav.write(filename, sample_rate, data.astype(np.float32))
    return filename

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

def log(message):
    print(message)
    with open('guardian_test_result.txt', 'a') as f:
        f.write(message + '\n')

def test_guardian_prediction(token):
    log("Testing Guardian Mode Prediction...")
    url = f"{BASE_URL}/emergency/predict-combined/"
    headers = {
        "Authorization": f"Bearer {token}"
    }
    
    # Create dummy audio
    audio_filename = create_dummy_audio()
    
    # Mock movement data (high variance to simulate threat)
    movement_data = {
        "x": [1.5, 2.0, 5.0, 8.0, 1.0],
        "y": [0.5, 0.8, 4.0, 7.0, 0.2],
        "z": [9.8, 9.9, 12.0, 15.0, 9.5]
    }
    
    files = {
        'audio': open(audio_filename, 'rb')
    }
    
    data = {
        'movement_data': json.dumps(movement_data),
        'location_latitude': 33.6844,
        'location_longitude': 73.0479,
        'location_address': 'Guardian Mode Test Location'
    }
    
    try:
        log(f"Sending request to {url}...")
        response = requests.post(url, headers=headers, files=files, data=data)
        
        if response.status_code == 200:
            result = response.json()
            log("Prediction successful!")
            log(f"Response: {json.dumps(result, indent=2)}")
            
            if result.get('is_threat'):
                log("✅ Threat DETECTED")
                if result.get('emergency_created'):
                    log("✅ Emergency Alert CREATED")
                else:
                    log("⚠️ Threat detected but NO emergency created")
            else:
                log("ℹ️ No threat detected")
                
        else:
            log(f"Prediction failed: {response.status_code} - {response.text}")
            
    except Exception as e:
        log(f"Error testing prediction: {e}")
    finally:
        files['audio'].close()
        if os.path.exists(audio_filename):
            os.remove(audio_filename)

if __name__ == "__main__":
    # Clear log file
    with open('guardian_test_result.txt', 'w') as f:
        f.write("Starting Guardian Test\n")
        
    token = login_user()
    if token:
        test_guardian_prediction(token)
